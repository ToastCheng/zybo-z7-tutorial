//------------------------------------------------------------------------------
// main.c
// Phase 11: PS-controlled audio effects on the Zybo Z7-10.
//
// Bare-metal application running on the Zynq PS Cortex-A9.  It takes over
// everything that is not real-time audio:
//
//   1. Configures the SSM2603 codec over the PS I2C1 controller (routed
//      through EMIO to the PL codec pins).
//   2. Writes a 32-bit control word to the PL through AXI GPIO:
//        [1:0] effect select (0 bypass, 1 crusher, 2 echo, 3 distortion)
//        [3:2] intensity (0..3)
//        [4]   codec_ready (releases the PL I2S datapath reset)
//        [5]   unmute (drives ac_muten)
//   3. Runs a UART menu (115200 baud) so the effect can be changed live
//      from a terminal: 0-3 select, +/- intensity, r codec read-back.
//
// SDT flow note: peripheral configs are looked up by base address from
// xparameters.h, not by device ID.
//------------------------------------------------------------------------------

#include "xparameters.h"
#include "xiicps.h"
#include "xgpio.h"
#include "xuartps_hw.h"
#include "xil_printf.h"

#define I2C_BASEADDR    XPAR_XIICPS_0_BASEADDR   // physical I2C1 (0xE0005000)
#define GPIO_BASEADDR   XPAR_XGPIO_0_BASEADDR
#define UART_BASEADDR   XPAR_XUARTPS_0_BASEADDR  // physical UART1 (0xE0001000)

#define I2C_DEVICE_ADDR 0x1A    // SSM2603, 7-bit (8-bit write addr 0x34)
#define I2C_CLOCK_HZ    100000  // 100 kHz standard mode

// AXI GPIO control-word bits.
#define CTRL_FX_MASK    0x03
#define CTRL_INTENSITY  2
#define CTRL_READY      (1u << 4)
#define CTRL_UNMUTE     (1u << 5)

// SSM2603 configuration for I2S 16-bit playback/record at 44.1 kHz.
// Each entry packs the two bytes sent on the bus:
// {register address, data bit 8} in the high byte, data bits 7-0 low.
// (Same table as the RTL LUT in top_audio_fx.sv.)
static const u16 codec_lut[] = {
    0x0C10,  // R6: power on everything except OUT
    0x0017,  // R0: left line in, 0 dB
    0x0217,  // R1: right line in, 0 dB
    0x0479,  // R2: left headphone, 0 dB
    0x0679,  // R3: right headphone, 0 dB
    0x0815,  // R4: analog audio path (DAC on, mic input, +20 dB boost)
    0x0A04,  // R5: digital audio path
    0x0E02,  // R7: digital audio interface, I2S 16-bit, codec slave
    0x1020,  // R8: sampling rate, 44.1 kHz normal mode
    0x0C00,  // R6: power on everything
    0x1201,  // R9: activate digital core
};
#define CODEC_LUT_SIZE  (sizeof(codec_lut) / sizeof(codec_lut[0]))

static const char *fx_names[] = { "bypass", "bit-crusher", "echo", "distortion" };

static XIicPs i2c;
static XGpio  gpio;

static u32 fx_sel    = 0;
static u32 intensity = 0;

//------------------------------------------------------------------------------
// Codec I2C helpers
//------------------------------------------------------------------------------

static int codec_write(u16 reg_value)
{
    u8 buf[2] = { (u8)(reg_value >> 8), (u8)(reg_value & 0xFF) };
    return XIicPs_MasterSendPolled(&i2c, buf, sizeof(buf), I2C_DEVICE_ADDR);
}

// Read one codec register (9-bit data).  Returns the register value, or -1
// on a bus error.  Uses a repeated start: write the register address byte,
// then read two bytes without a stop in between.
static int codec_read(u8 reg_addr)
{
    u8 addr_byte = (u8)(reg_addr << 1);
    u8 buf[2]    = { 0, 0 };
    int status;

    XIicPs_SetOptions(&i2c, XIICPS_REP_START_OPTION);
    status = XIicPs_MasterSendPolled(&i2c, &addr_byte, 1, I2C_DEVICE_ADDR);
    if (status == XST_SUCCESS)
        status = XIicPs_MasterRecvPolled(&i2c, buf, sizeof(buf), I2C_DEVICE_ADDR);
    XIicPs_ClearOptions(&i2c, XIICPS_REP_START_OPTION);

    if (status != XST_SUCCESS)
        return -1;
    return ((buf[0] & 0x1) << 8) | buf[1];
}

//------------------------------------------------------------------------------
// Control word -> PL
//------------------------------------------------------------------------------

static void update_control(void)
{
    u32 ctrl = (fx_sel & CTRL_FX_MASK)
             | ((intensity & 0x3) << CTRL_INTENSITY)
             | CTRL_READY | CTRL_UNMUTE;
    XGpio_DiscreteWrite(&gpio, 1, ctrl);
    xil_printf("-> effect %d (%s), intensity %lu\r\n",
               fx_sel, fx_names[fx_sel], intensity);
}

//------------------------------------------------------------------------------
// Init helpers
//------------------------------------------------------------------------------

static int i2c_init(void)
{
    XIicPs_Config *config = XIicPs_LookupConfig(I2C_BASEADDR);
    if (config == NULL) {
        xil_printf("ERROR: PS I2C1 config not found\r\n");
        return XST_FAILURE;
    }
    if (XIicPs_CfgInitialize(&i2c, config, config->BaseAddress) != XST_SUCCESS) {
        xil_printf("ERROR: PS I2C1 init failed\r\n");
        return XST_FAILURE;
    }
    XIicPs_SetSClk(&i2c, I2C_CLOCK_HZ);
    return XST_SUCCESS;
}

static int gpio_init(void)
{
    if (XGpio_Initialize(&gpio, GPIO_BASEADDR) != XST_SUCCESS) {
        xil_printf("ERROR: AXI GPIO init failed\r\n");
        return XST_FAILURE;
    }
    XGpio_SetDataDirection(&gpio, 1, 0x00000000);  // all outputs
    XGpio_DiscreteWrite(&gpio, 1, 0x00000000);     // muted, PL held in reset
    return XST_SUCCESS;
}

static int codec_init(void)
{
    for (unsigned int i = 0; i < CODEC_LUT_SIZE; i++) {
        if (codec_write(codec_lut[i]) != XST_SUCCESS) {
            xil_printf("ERROR: codec register write %u (0x%04X) failed\r\n",
                       i, codec_lut[i]);
            return XST_FAILURE;
        }
    }
    xil_printf("Codec configured (%u register writes)\r\n", CODEC_LUT_SIZE);
    return XST_SUCCESS;
}

//------------------------------------------------------------------------------
// UART menu
//------------------------------------------------------------------------------

static void print_menu(void)
{
    xil_printf("\r\n--- Phase 11: PS-controlled audio effects ---\r\n");
    xil_printf("  0 bypass | 1 bit-crusher | 2 echo | 3 distortion\r\n");
    xil_printf("  +/- intensity | m mute/unmute | r read codec R4\r\n");
}

int main(void)
{
    xil_printf("\r\nPhase 11: PS-controlled audio effects\r\n");

    if (i2c_init() != XST_SUCCESS || gpio_init() != XST_SUCCESS)
        return 1;

    if (codec_init() != XST_SUCCESS)
        xil_printf("WARNING: continuing without codec configuration\r\n");

    // Codec is ready: release the PL datapath and unmute.
    update_control();
    print_menu();

    u32 muted = 0;
    while (1) {
        // Blocking read of one key from the UART terminal.
        char c = (char)XUartPs_RecvByte(UART_BASEADDR);

        switch (c) {
        case '0': case '1': case '2': case '3':
            fx_sel = (u32)(c - '0');
            update_control();
            break;
        case '+':
            if (intensity < 3) intensity++;
            update_control();
            break;
        case '-':
            if (intensity > 0) intensity--;
            update_control();
            break;
        case 'm': {
            muted = !muted;
            u32 ctrl = XGpio_DiscreteRead(&gpio, 1);
            if (muted) ctrl &= ~CTRL_UNMUTE; else ctrl |= CTRL_UNMUTE;
            XGpio_DiscreteWrite(&gpio, 1, ctrl);
            xil_printf("-> %s\r\n", muted ? "muted" : "unmuted");
            break;
        }
        case 'r': {
            int value = codec_read(4);   // R4: analog audio path
            if (value < 0)
                xil_printf("ERROR: codec read failed\r\n");
            else
                xil_printf("R4 = 0x%03X (wrote 0x015)\r\n", value);
            break;
        }
        case 'h': case '?':
            print_menu();
            break;
        default:
            break;
        }
    }

    return 0;
}
