# Phase 7: `top_i2s_tone` — I²S Tone Generator

## Goal

Stream digital audio for the first time. After reset, the FPGA configures
the on-board **SSM2603 codec** over I²C, then plays a **1 kHz sine tone**
through the headphone jack using the **I²S** audio interface.

This phase combines Phase 6 (I²C codec configuration) with three new blocks:
`audio_clock_gen` (codec master clock), `tone_generator` (DDS sine source),
and `i2s_tx` (I²S serializer).

## What You Should See (and Hear)

- After programming, the RGB LED pulses **red** briefly (I²C configuration),
  then pulses **green** (tone playing). **Blue** means the codec did not
  acknowledge a byte (error).
- With headphones connected, you hear a steady 1 kHz tone.
- **BTN0** resets the design and re-runs the codec configuration.

## Concepts

### I²S: a bus made for audio samples

I²S (Inter-IC Sound) is a simple synchronous serial bus for stereo PCM audio.
It uses three data signals (plus a master clock):

| Signal | SSM2603 pin | Direction | Purpose |
|--------|-------------|-----------|---------|
| MCLK | `ac_mclk` | FPGA → codec | Master clock, 256 × sample rate (~11.29 MHz for 44.1 kHz) |
| BCLK | `ac_bclk` | FPGA → codec | Bit clock: one cycle per transmitted bit |
| LRCLK | `ac_pblrc` | FPGA → codec | Left/right word select: low = left, high = right; one period = one sample period (44.1 kHz) |
| DACDAT | `ac_pbdat` | FPGA → codec | Serial sample data, MSB first |

For 16-bit stereo, each LRCLK half-period carries one 16-bit sample, so BCLK
runs at 44_100 × 2 × 32 = 2.8224 MHz (32 bit-slots per channel — the I²S
frame reserves 32 slots even though only 16 carry data).

The codec is configured as **I²S slave** (register R7 = `16'h0E02`), which
means the FPGA generates BCLK and LRCLK — see `rtl/common/i2s_tx.sv`.

### Master-slave roles

I²C and I²S have opposite roles here: on I²C the FPGA is the **master** (it
configures the codec), while on I²S the codec is the **slave** (it follows
the FPGA's clocks). The FPGA also drives the record-side LRCLK
(`ac_reclrc = ac_pblrc`) even though recording is unused in this phase.

### DDS tone generation

`tone_generator` is a **direct digital synthesizer**: a phase accumulator
advances by a fixed step every sample and indexes a sine lookup table. The
frequency is set by the step size — here `FREQ_HZ(1_000)` at
`SAMPLE_RATE_HZ(44_100)`. It produces a new sample whenever `i2s_tx` raises
`sample_req`, so the tone is always in lockstep with the I²S frame rate.

### Two clock domains

Like Phase 6, the I²C sequencer runs on the 125 MHz system clock. The audio
logic runs on the MCLK domain from `audio_clock_gen` (an MMCM). `init_done`
crosses into the MCLK domain through a two-flip-flop synchronizer, and the
I²S logic stays in reset until the MMCM is locked **and** codec configuration
has finished:

```systemverilog
assign i2s_rst = db_btn0 || !audio_locked || !init_done_mclk;
```

## Block Diagram

```
                125 MHz sysclk domain
 ┌────────────────────────────────────────────┐
 │  BTN0 → debounce ──► reset                 │
 │  lut[11] → sequencer FSM → i2c_master ═╗   │
 └────────────────────────────────────────╨───┘
                      I²C (ac_scl/ac_sda)  ▼
                                     ┌──────────┐
                                     │ SSM2603  │────► headphones
                                     │  codec   │
                                     └──────────┘
                MCLK domain (~11.29 MHz) ▲
 ┌────────────────────────────────────────┴─────┐
 │ audio_clock_gen (MMCM) ──► ac_mclk           │
 │ tone_generator ──► i2s_tx ──► ac_bclk/lrclk/ │
 │    (1 kHz DDS)          pbdat                │
 └──────────────────────────────────────────────┘
```

## Code Walkthrough

The codec configuration LUT and the sequencer FSM are identical to Phase 6 /
Phase 8 — see `rtl/top/top_audio_loopback.md` for a detailed walkthrough.
What is new in this phase is the audio data path:

```systemverilog
tone_generator #(
    .SAMPLE_RATE_HZ(44_100),
    .FREQ_HZ       (1_000)
) tone (
    .clk        (mclk),
    .rst        (i2s_rst),
    .sample_req (sample_req),
    .sample_l   (tone_l),
    .sample_r   (tone_r)
);
```

- The tone generator runs in the MCLK domain and only advances when the I²S
  transmitter asks for the next sample (`sample_req`) — the transmitter is
  the pace-setter for the whole audio pipeline.

```systemverilog
i2s_tx i2s (
    .mclk (mclk),
    ...
    .bclk  (ac_bclk),
    .lrclk (ac_pblrc),
    .pbdat (ac_pbdat)
);
```

- `i2s_tx` derives BCLK and LRCLK from MCLK by division (256 → 64 → 1 per
  frame) and shifts each 16-bit sample out MSB-first on `pbdat`.

```systemverilog
assign ac_muten = init_done;
```

- The headphone output stays muted until codec configuration succeeds, so
  you never hear power-up pops or garbage.

## Parameters

| Parameter | Default | Purpose |
|-----------|---------|---------|
| `DEBOUNCE_STABLE_US` | 10_000 | BTN0 (reset) debounce time in µs |

## How to Build and Test

```bash
make build TOP=top_i2s_tone
make prog TOP=top_i2s_tone
```

Hardware setup: connect headphones to the **headphone out** jack.

1. After programming, the RGB LED should go red → green within a second.
   Blue means the codec did not respond — press BTN0 to retry.
2. A steady 1 kHz tone plays in the headphones.

### Simulation

```bash
make sim TB=tb_top_i2s_tone    # integration: I2C writes + I2S tone output
make sim TB=tb_i2s_tx          # unit test of the I2S serializer
```

## Exercises

1. Change `FREQ_HZ` to 440 and listen for concert A.
2. Make the tone frequency selectable with the slide switches (hint: expose a
   frequency input on `tone_generator` instead of using the parameter).
3. Send different samples to the left and right channels (e.g. tone on the
   left, silence on the right).
4. Sweep the tone frequency slowly upward over a few seconds (a chirp) by
   varying the DDS phase step over time.
