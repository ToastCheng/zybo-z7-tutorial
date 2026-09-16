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
//        [3:0] effect select (0 bypass, 1 crusher, 2 echo, 3 distortion,
//                             4 biquad filter, 5 chorus/flanger/vibrato,
//                             6 tremolo, 7 noise gate, 8 compressor)
//        [5:4] intensity (0..3; per-effect preset)
//        [6]   codec_ready (releases the PL I2S datapath reset)
//        [7]   unmute (drives ac_muten)
//   3. Runs a UART menu (115200 baud) so the effect can be changed live
//      from a terminal: 0-8 select, +/- intensity, m mute.
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
#define CTRL_FX_MASK    0x0F
#define CTRL_INTENSITY  4
#define CTRL_READY      (1u << 6)
#define CTRL_UNMUTE     (1u << 7)

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

static const char *fx_names[] = { "bypass", "bit-crusher", "echo", "distortion",
                                  "filter", "mod-delay", "tremolo",
                                  "gate", "comp/limiter" };

// Per-effect preset names for effects 4..8 (indexed by intensity 0..3).
static const char *filt_names[] = { "low-pass", "high-pass", "band-pass",
                                    "notch" };
static const char *mod_names[]  = { "chorus", "flanger", "vibrato",
                                    "slow chorus" };
static const char *trem_names[] = { "subtle", "mild", "deep", "full" };
static const char *gate_names[] = { "-50 dB", "-40 dB", "-30 dB", "-20 dB" };
static const char *comp_names[] = { "-6 dB", "-12 dB", "-18 dB", "-24 dB" };

static const char *preset_name(u32 fx, u32 i)
{
    switch (fx) {
    case 4:  return filt_names[i];
    case 5:  return mod_names[i];
    case 6:  return trem_names[i];
    case 7:  return gate_names[i];
    case 8:  return comp_names[i];
    default: return "";
    }
}

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

//------------------------------------------------------------------------------
// Control word -> PL
//------------------------------------------------------------------------------

static void update_control(void)
{
    u32 ctrl = (fx_sel & CTRL_FX_MASK)
             | ((intensity & 0x3) << CTRL_INTENSITY)
             | CTRL_READY | CTRL_UNMUTE;
    XGpio_DiscreteWrite(&gpio, 1, ctrl);
    if (fx_sel >= 4) {
        xil_printf("-> effect %d (%s), preset %s\r\n",
                   (int)fx_sel, fx_names[fx_sel], preset_name(fx_sel, intensity));
    } else {
        xil_printf("-> effect %d (%s), intensity %d\r\n",
                   (int)fx_sel, fx_names[fx_sel], (int)intensity);
    }
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
    xil_printf("\r\n--- Phase 11-14: PS-controlled audio effects ---\r\n");
    xil_printf("  0 bypass | 1 crusher | 2 echo | 3 distortion | 4 filter\r\n");
    xil_printf("  5 chorus/flanger | 6 tremolo | 7 gate | 8 comp/limiter\r\n");
    xil_printf("  +/- intensity (per-effect preset) | m mute/unmute\r\n");
}

int main(void)
{
    xil_printf("\r\nPhase 11-14: PS-controlled audio effects\r\n");

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
        case '0': case '1': case '2': case '3': case '4':
        case '5': case '6': case '7': case '8':
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
        case 'h': case '?':
            print_menu();
            break;
        default:
            break;
        }
    }

    return 0;
}
