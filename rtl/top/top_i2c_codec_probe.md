# `top_i2c_codec_probe` — I2C Codec Configuration Probe

## Goal

Configure the Zybo Z7-10 on-board audio codec over I²C and display the result on the LEDs. This is an intermediate step before adding I²S audio streaming: it proves that the FPGA can talk to the SSM2603.

## Concepts

### On-board audio codec

The Zybo Z7-10 includes an **Analog Devices SSM2603** codec connected to the FPGA fabric with:

- `ac_scl` — I²C clock (open-drain, external pull-up).
- `ac_sda` — I²C data (open-drain, external pull-up).
- `ac_mclk`, `ac_bclk`, `ac_lrclk`, `ac_dac_sdata`, `ac_adc_sdata` — I²S signals (used later).

This top-level only uses the I²C pins. The SDA pin is driven through an `IOBUF` so the FPGA can either pull it low or tri-state it and read the pulled-up value.

### Status display

- `led[3:0]` shows the last captured status nibble (`busy`, `done`, `error`, last ACK).
- `rgb_led[0]` (red) pulses while configuration is in progress.
- `rgb_led[1]` (green) pulses when configuration completed successfully.
- `rgb_led[2]` (blue) pulses when the codec did not acknowledge a write.

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

1. Set `SW0` to the ON position to start the configuration sequence.
2. Observe the LEDs/RGB LED:
   - Red = busy.
   - Green = done.
   - Blue = error (codec did not ACK).
3. Toggle `SW0` OFF and ON again to re-run the sequence.

## Testing

### Simulation

The underlying I²C transaction is verified by `rtl/tb/tb_i2c_master.sv`, which simulates a slave stub that ACKs every byte and checks the byte values against the expected SSM2603 writes.

Run it with:

```bash
make sim TB=tb_i2c_master
```

### Hardware

After `make prog`, use `SW0` to trigger the sequence and observe the LED/RGB status. A successful run ends with the green LED on and no blue LED.
