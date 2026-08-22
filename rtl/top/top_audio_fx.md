# Phase 10: `top_audio_fx` — Switch-Controlled Live Sound Effects

## Goal

Apply real-time sound effects to the Phase 8 audio loopback. The mic signal
passes through the FPGA and comes out of the headphones with one of three
effects applied — selected and adjusted live with the slide switches.

## What You Should Hear

- **SW1/SW0 = 00** — bypass: plain mic loopback (same as Phase 8).
- **SW1/SW0 = 01** — bit-crusher: harsh lo-fi "8-bit" sound.
- **SW1/SW0 = 10** — echo: ~0.37 s slapback echo.
- **SW1/SW0 = 11** — distortion: fuzz/overdrive.

**SW3/SW2** set the intensity of the selected effect (see the table in the
effect modules). The RGB LED shows the selection: off = bypass, red = crusher,
green = echo, blue = distortion. `led[3:0]` mirrors the switches.

## Concepts

### Bit manipulation as an audio effect (crusher)

A 16-bit sample carries ~96 dB of dynamic range. Zeroing the low bits throws
away resolution: the smooth waveform becomes a staircase, and the
quantization error becomes audible as harsh, buzzy harmonics. One signed
shift-right/shift-left pair is the entire effect:

```systemverilog
assign sample_out = (sample_in >>> shift) <<< shift;
```

The arithmetic shift (`>>>`) keeps the sign bit, so negative samples crush
symmetrically.

### Memory as an audio effect (echo)

An echo is just "what happened N samples ago, added back at lower volume."
Storing N samples requires memory — at 44.1 kHz, 0.37 s of stereo audio is
16384 frames × 32 bits. That is what **block RAM** is for: the FPGA's
dedicated SRAM tiles (the Z7-10 has 60 × 36 Kb).

The delay line is a **ring buffer**: a write pointer advances one slot per
frame and wraps around; the read pointer trails it by one slot, so the value
read out was written DEPTH−1 frames ago:

```systemverilog
mem[wr_addr] <= {in_l, in_r};
rd_data      <= mem[wr_addr + 1'b1];  // oldest frame in the buffer
wr_addr      <= wr_addr + 1'b1;
```

No explicit read address or clearing logic is needed — the wrap-around does
all the work. This is the same circular-buffer idea as a software FIFO, but
in one `always_ff` block.

The wet/dry mix uses shift-based fractions (¼, ⅜, ½, ⅝), so the whole effect
needs no multipliers at all.

### Nonlinearity as an audio effect (distortion)

Distortion is gain followed by **saturation**: amplify the sample, then clip
anything beyond full scale. The flat tops generate new harmonics — the fuzz
sound. This teaches a key fixed-point skill: the amplified value is computed
in a wider register so it cannot overflow, then compared against the
full-scale limits:

```systemverilog
logic signed [WIDTH+4:0] scaled;
assign scaled = sample_in <<< shift;   // cannot overflow
// ... then saturate back to WIDTH bits
```

### Selectable datapath

All three effects run in parallel, all the time; the switches just drive a
mux that picks which output reaches `i2s_tx`. Hardware is parallel — "selecting
an effect" means selecting a wire, not starting a process. (The unused
effects keep consuming their tiny slice of logic; nothing is "turned off.")

## Block Diagram

```
                        mclk domain (44.1 kHz frames)
 mic ─► SSM2603 ─► i2s_rx ──┬──► bitcrusher ──┐
        (I2S)               ├──► echo (BRAM) ──┼── mux ──► i2s_tx ─► SSM2603 ─► headphones
                            ├──► distortion ──┤  sw[1:0]
                            └──► (bypass) ────┘
                                     ▲
                              sw[3:2] intensity
```

## Parameters

| Parameter | Default | Purpose |
|-----------|---------|---------|
| `DEBOUNCE_STABLE_US` | 10_000 | BTN0 (reset) debounce time in µs |
| `ECHO_DEPTH` | 16384 | Echo delay-line depth in frames (16384/44100 ≈ 0.37 s) |

## How to Build and Test

```bash
make build TOP=top_audio_fx
make prog TOP=top_audio_fx
```

Hardware setup: mic (TRS, or TRRS via adapter) in the **mic jack**, headphones
in the headphone jack.

1. Wait for the RGB LED to finish pulsing red (codec configured).
2. Speak into the mic with SW1/SW0 = 00 — plain loopback.
3. Flip SW0 for the crusher, SW1 for the echo, both for distortion; use
   SW3/SW2 to make each effect stronger or weaker.

### Simulation

```bash
make sim TB=tb_audio_fx        # unit tests for all three effect modules
make sim TB=tb_top_audio_fx    # integration: codec stub + effect switching
```

## Exercises

1. Add a **feedback** path to the echo (route a fraction of the delayed
   sample back into the delay-line input) to get repeating echoes instead of
   a single slapback. Watch out: the feedback gain must be below 1 or the
   buffer fills up with an ever-growing signal.
2. Make the echo delay adjustable in a few steps (hint: parameterize the
   read-pointer offset instead of using the full buffer depth).
3. Combine effects: crusher → echo in series.
4. Replace hard clipping in the distortion with a softer curve (e.g. a
   piecewise-linear soft clip) and compare the sound.
