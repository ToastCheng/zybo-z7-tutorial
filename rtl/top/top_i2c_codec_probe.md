# `top_i2c_codec_probe` — I2C Codec Configuration Probe

## Goal

Configure the Zybo Z7-10 on-board audio codec over I²C and display the result on the LEDs. This is an intermediate step before adding I²S audio streaming: it proves that the FPGA can talk to the SSM2603.

## Concepts

### On-board audio codec

The Zybo Z7-10 includes an **Analog Devices SSM2603** codec connected to the FPGA fabric with:

- `ac_scl` — I²C clock (open-drain, external pull-up).
- `ac_sda` — I²C data (open-drain, external pull-up).
- `ac_mclk`, `ac_bclk`, `ac_lrclk`, `ac_dac_sdata`, `ac_adc_sdata` — I²S signals (used later).

This top-level only uses the I²C pins. The SDA pin is driven through a tristate (`1'bz` when released) so the FPGA can either pull it low or let the board pull-up resistor pull it high.

### Status display

- `led[3:0]` shows the current configuration step (0..11).
- The RGB LED uses these colors:
  - **Red** pulsing = busy, a register write is in progress.
  - **Green** pulsing = done, all registers have been configured successfully.
  - **Blue** pulsing = error, the codec did not acknowledge a byte.
  - **Off** = idle, waiting for `SW0` to be toggled.

The RGB channels are dimmed to a very low PWM duty cycle so the status lights are not distracting.

## Hardware

- Zybo Z7-10 board.
- No external peripherals are required; the codec is on the board.

## Build and Run

```bash
make build TOP=top_i2c_codec_probe
make prog TOP=top_i2c_codec_probe
```

After programming:

1. Make sure `SW0` is OFF, then toggle it ON to start the first register write.
2. Each subsequent ON toggle sends the next register write.
3. Observe the LEDs/RGB LED:
   - Red = busy.
   - Green = all done.
   - Blue = error (codec did not ACK).
   - Off = idle, waiting for the next toggle.
4. Press `BTN0` to reset the sequencer.

## Testing

### Simulation

The underlying I²C transaction is verified by `rtl/tb/tb_i2c_master.sv`, which emulates an open-drain pull-up bus and a simple slave stub that ACKs every byte and checks the byte values against the expected SSM2603 writes.

Run it with:

```bash
make sim TB=tb_i2c_master
```

### Hardware

After `make prog`, toggle `SW0` to step through the register writes and observe the LED/RGB status. A successful run ends with the green LED on and no blue LED.
