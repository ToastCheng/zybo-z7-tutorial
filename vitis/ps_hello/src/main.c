//------------------------------------------------------------------------------
// main.c
// Phase 9: PS bring-up - hello message over UART on button press.
//
// Bare-metal (standalone) application running on the Zynq PS Cortex-A9.
// It polls the push-button BTN0, which is wired from the PL into the PS
// through EMIO GPIO bit 0, and prints a hello message over UART1 (the
// PROG/UART micro-USB port, 115200 baud) once per button press.
//
// PS GPIO pins 0-53 are MIO; the first EMIO GPIO bit is pin 54.
//------------------------------------------------------------------------------

#include "xparameters.h"
#include "xgpiops.h"
#include "xil_printf.h"
#include "sleep.h"

#define BTN_PIN         54      // EMIO GPIO bit 0 (MIO occupies pins 0-53)
#define POLL_PERIOD_US  10000   // 10 ms poll -> ~20 ms debounce

int main(void)
{
    XGpioPs gpio;
    XGpioPs_Config *config;
    int status;

    xil_printf("\r\nPhase 9: PS hello - press BTN0\r\n");

    // Look up and initialize the PS GPIO peripheral (SDT flow: the config is
    // looked up by base address, not device ID).
    config = XGpioPs_LookupConfig(XPAR_XGPIOPS_0_BASEADDR);
    if (config == NULL) {
        xil_printf("ERROR: PS GPIO config not found\r\n");
        return 1;
    }

    status = XGpioPs_CfgInitialize(&gpio, config, config->BaseAddr);
    if (status != XST_SUCCESS) {
        xil_printf("ERROR: PS GPIO init failed\r\n");
        return 1;
    }

    // Button pin is an input.
    XGpioPs_SetDirectionPin(&gpio, BTN_PIN, 0);

    // Poll with edge detection + debounce: a new stable level is only
    // accepted after it differs from the last *stable* level, so press and
    // release bounce are filtered out.
    u32 prev_raw = 0;
    u32 stable   = 0;
    u32 count    = 0;

    while (1) {
        u32 raw = XGpioPs_ReadPin(&gpio, BTN_PIN);

        if (raw != prev_raw) {
            // Level changed - wait one more poll period before trusting it.
            prev_raw = raw;
        } else if (raw != stable) {
            stable = raw;
            if (stable) {
                count++;
                xil_printf("Hello from PS! BTN0 pressed (%lu)\r\n", count);
            }
        }

        usleep(POLL_PERIOD_US);
    }

    return 0;
}
