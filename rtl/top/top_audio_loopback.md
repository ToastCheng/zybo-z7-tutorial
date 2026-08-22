# Phase 8: `top_audio_loopback` — Audio Loopback / Tone Generator

## Goal

Combine the Phase 6 (I²C) and Phase 7 (I²S) blocks into a complete audio
path. After reset, the FPGA configures the on-board **SSM2603 codec** over
I²C, then streams digital audio over I²S. **SW0** selects the source:

- **SW0 = 0** — digital loopback: mic-in → ADC → FPGA → DAC → headphones.
- **SW0 = 1** — an internally generated 1 kHz sine tone → headphones.

## What You Should See (and Hear)

- After programming, the RGB LED pulses **red** briefly (I²C configuration),
  then pulses **green** (audio running). **Blue** means the codec did not
  acknowledge a byte (error).
- With SW0 = 1 and headphones connected, you hear a steady 1 kHz tone.
- With SW0 = 0 and a microphone in the **mic jack**, you hear it on the
  headphones. The board also has a separate stereo **line-in** jack — see
  "Mic vs. line input" below.
- `led[3:0]` mirrors the four slide switches.

## Concepts

### Two chips, two buses

The SSM2603 codec is configured over **I²C** (a slow control bus, 100 kHz)
and streams samples over **I²S** (a fast audio bus, 44.1 kHz × 16 bit × 2
channels). This split — control plane vs. data plane — is common in real
hardware: you set up a chip with a simple serial bus, then push data over a
dedicated streaming interface.

### Clock domains

This design has **two clock domains**:

| Domain | Frequency | Used by |
|--------|-----------|---------|
| `clk` (sysclk) | 125 MHz | I²C master, configuration sequencer, LED status |
| `mclk` | ~11.2896 MHz | I²S transmitter/receiver, tone generator |

`audio_clock_gen` (an MMCM) derives the codec master clock from the 125 MHz
oscillator. Signals crossing between the domains must be synchronized — see
how `init_done` crosses into the MCLK domain through a two-flip-flop
synchronizer (`init_done_sync`), the same technique as the `sync` module from
Phase 1.

The I²S logic is held in reset (`i2s_rst`) until three conditions are met:
BTN0 not pressed, the MMCM locked, and codec configuration finished.

### Codec configuration sequencer

The SSM2603 needs eleven 16-bit register writes before it produces sound.
The writes live in a lookup table (`lut`), and an FSM walks through them:
START → device address → high byte → low byte → STOP, repeated per entry.
Every byte's ACK is ANDed into `ack_ok`; one NACK sends the FSM to `S_ERROR`
(blue LED) instead of `S_DONE` (green LED).

Notable register values:

- `16'h0E02` — R7: digital audio interface = **I²S, 16-bit, codec is slave**
  (the FPGA generates BCLK and LRCLK).
- `16'h1020` — R8: sample rate = **44.1 kHz** (with the ~11.29 MHz MCLK).
- `16'h1201` — R9: last step, activate the digital core.

### Mic vs. line input

The board has **two separate input jacks** wired to different codec pins: a
mono **microphone** jack (MICIN, with mic bias) and a stereo **line-in** jack
(L/RLINEIN). Register R4 selects which one reaches the ADC:

- Our configuration (`16'h0815`) sets **INSEL = 1** (mic) and
  **MICBOOST = 1** (+20 dB), because a microphone outputs only a few
  millivolts.
- A microphone plugged into the **line-in** jack is ~40 dB too quiet to hear
  — line level is around 1 Vrms. To use a line-level source (phone, PC audio
  out) instead, change R4 to select line-in: `16'h0810` (INSEL = 0, DAC
  enabled, no mic boost).

**TRS vs. TRRS plugs:** the mic jack expects a **TRS** plug (2 insulating
rings; tip = mic, ring = bias, sleeve = ground). Headset mics often have a
**TRRS** plug (3 rings, CTIA pinout) whose ground ring lands where the jack
expects mic signal and bias — the mic is then unbiased and shorted to
ground, i.e. silent. Use a TRRS→TRS adapter, as with most PC sound cards.

### Loopback vs. tone mux

The transmit samples are just a combinational select:

```systemverilog
assign tx_l = sw[0] ? tone_l : rx_l;
assign tx_r = sw[0] ? tone_r : rx_r;
```

In loopback mode the samples from `i2s_rx` go straight back into `i2s_tx` —
audio passes through the FPGA with zero processing, which makes it a great
pipe-cleaner before doing any real DSP. `tone_generator` is a DDS (direct
digital synthesis) sine source that produces a new sample whenever `i2s_tx`
raises `sample_req`.

## Block Diagram

```
                125 MHz sysclk domain
 ┌────────────────────────────────────────────┐
 │  BTN0 → debounce ──► reset                 │
 │  lut[11] → sequencer FSM → i2c_master ═╗   │
 └────────────────────────────────────────╨───┘
                      I²C (ac_scl/ac_sda)  ▼
                                     ┌──────────┐
                                     │ SSM2603  │
                                     │  codec   │
                                     └──────────┘
                MCLK domain (~11.29 MHz) ▲
 ┌────────────────────────────────────────┴─────┐
 │ audio_clock_gen (MMCM) ──► ac_mclk           │
 │ mic-in ───► i2s_rx ─►┐                        │
 │                     ├─ mux (SW0) ─► i2s_tx ─►│─► headphones
 │ tone_generator ────►┘      (1 kHz)           │
 └──────────────────────────────────────────────┘
```

## Code Walkthrough

```systemverilog
logic [15:0] lut [0:LUT_SIZE-1] = '{ 16'h0C10, ... };
```

- An **unpacked array** with an assignment pattern: the eleven codec register
  writes, in order. Power management is written twice (`16'h0C10`, then
  `16'h0C00`) because the output stage must power up after the DAC path is
  configured.

```systemverilog
always_ff @(posedge mclk or posedge db_btn0) begin
    if (db_btn0)
        init_done_sync <= '0;
    else
        init_done_sync <= {init_done_sync[0], init_done};
end
```

- Two-flip-flop synchronizer crossing `init_done` from the sysclk domain into
  the MCLK domain. `posedge db_btn0` makes the reset **asynchronous** for
  this pair so the MCLK logic resets even if `mclk` is not toggling yet.

```systemverilog
assign ac_scl = scl_oe ? 1'b0 : 1'bz;
assign ac_sda = sda_oe ? 1'b0 : 1'bz;
```

- Open-drain I²C outputs: the FPGA only ever pulls low (`1'b0`) or releases
  the line (`1'bz`); the board's pull-up resistors create the high level.

```systemverilog
assign ac_reclrc = ac_pblrc;
assign ac_muten  = init_done;
```

- The codec is the I²S slave, so the FPGA drives **both** LRCLK pins (record
  and playback share the same frame clock) and unmutes the output only after
  configuration succeeded.

## Parameters

| Parameter | Default | Purpose |
|-----------|---------|---------|
| `DEBOUNCE_STABLE_US` | 10_000 | BTN0 (reset) debounce time in µs |

## How to Build and Test

```bash
make build TOP=top_audio_loopback
make prog TOP=top_audio_loopback
```

Hardware setup: connect headphones to the **headphone out** jack and a
microphone to the **mic** jack (mono, next to line-in).

1. After programming, the RGB LED should go red → green within a second.
   Blue means the codec did not respond (check the board/jumpers, then press
   BTN0 to retry).
2. Set **SW0 = 1**: steady 1 kHz tone in the headphones.
3. Set **SW0 = 0** and speak into the microphone: loopback audio.
4. Press **BTN0** at any time to reset and re-run the codec configuration.

### Simulation

```bash
make sim TB=tb_top_audio_loopback
```

The integration testbench (`rtl/tb/tb_top_audio_loopback.sv`) stubs the codec
on both buses and checks the I²C register writes and the I²S data path.

## Exercises

1. Change the tone to 440 Hz (concert A) by adjusting the `tone_generator`
   parameter.
2. Use SW1 to select between two different tone frequencies at runtime.
3. Add a volume control: scale the loopback samples by a factor selected
   with SW3/SW2 before sending them to `i2s_tx` (watch out for clipping).
4. Route the tone only to the left channel and loopback only to the right.
