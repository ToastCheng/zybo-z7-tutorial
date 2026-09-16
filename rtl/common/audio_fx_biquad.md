# `audio_fx_biquad` — Second-Order IIR Filter

## Goal

Add real frequency-selective filtering to the effects chain: low-pass,
high-pass, band-pass, and notch presets, selectable at runtime. This is the
first effect that requires **multiplication by non-power-of-two constants**
and **feedback** — the two things that make DSP hardware interesting.

## Concepts

- **IIR filter / biquad.** A second-order infinite-impulse-response filter:
  the output depends on the last two inputs *and* the last two outputs
  (feedback). Two poles + two zeros is enough for most tone-shaping filters;
  higher-order filters are built by cascading biquads.
- **Fixed-point arithmetic.** FPGAs have no floating point in the datapath
  unless you pay for it. We use Q2.16 coefficients and a wide accumulator.
- **DSP48 slices.** The Zynq-7000's dedicated multiply-accumulate blocks.
  A 16×18-bit signed multiply plus a 48-bit accumulate maps onto exactly
  one DSP48 per product term.

## The Math

The filter computes, once per audio frame:

```
y[n] = b0·x[n] + b1·x[n-1] + b2·x[n-2] + a1·y[n-1] + a2·y[n-2]
```

> **Sign convention pitfall.** Textbooks write the recurrence with the
> a-terms *subtracted*: `y[n] = Σb·x − Σa·y`. We store the a-coefficients
> **already negated**, so all five terms add. Forgetting this turns a
> stable filter into an oscillator.

The presets use the RBJ audio-EQ cookbook with fs = 44.1 kHz, fc = 1 kHz,
Q = 1/√2 (Butterworth). Example, low-pass:

```
ω0 = 2π·fc/fs,  α = sin(ω0)/(2Q)
b0 = (1−cos ω0)/2,  b1 = 1−cos ω0,  b2 = (1−cos ω0)/2
a0 = 1+α,  a1 = −2cos ω0,  a2 = 1−α        (then divide all by a0)
```

Coefficients are quantized to **Q2.16**: one sign bit, one integer bit,
16 fractional bits, range ±2 — just wide enough for biquad coefficients.
Rounding error shifts the responses slightly; the DC gains after
quantization are LP ≈ 1.0008, HP/BP ≈ 0.0008, notch ≈ 1.0000 — inaudible.

> **Truncation limit cycle.** The `>>> FRAC` step rounds toward −∞, so the
> feedback path can idle at a tiny non-zero value (measured: about −0.4% of
> a DC input on the HP preset). Inaudible at ~70 dB below full scale, but
> worth knowing: this is why the HP DC test tolerance is ±64, not ±1.

## Block Diagram

```
            b0 ──────────────┐
x[n] ──z⁻¹── b1 ──┐          │
            └─z⁻¹─ b2        │
                  │          ▼
                  └───────> ( + ) ──▶ saturate ──▶ y[n]
                            ( + )         │
                  ┌───────> ( + )    ┌────┘
            a1 ───┘          ▲       z⁻¹ (y1)
            └─ z⁻¹ (y2) ─ a2 ┘
```

Five 16×18 multiplies (five DSP48s per channel), one 48-bit add, then the
16 fractional bits are dropped and the result is saturated back to 16 bits.
The *saturated* value feeds back into the y delay line, so the filter
recovers after an overload instead of wrapping.

## Code Walkthrough

- The coefficient LUT is a combinational `case` on `intensity` — switching
  presets is glitch-free because coefficients change only between frames.
- `sample_req` is the frame strobe from `i2s_tx`. All state (`x1`, `x2`,
  `y1`, `y2`, `sample_out`) updates only on that strobe, so the five
  multiplies have ~256 MCLK cycles to settle.
- `ACC_W'(p_b0)` is a SystemVerilog **size cast**: it sign-extends the
  34-bit product to 48 bits. A plain width mismatch would also sign-extend
  here, but the cast makes the intent explicit.
- `y_full = acc >>> FRAC` converts Q.16 back to integer samples.

## Ports

| Port | Direction | Description |
|------|-----------|-------------|
| `clk` | input | Audio master clock (MCLK domain) |
| `rst` | input | Synchronous reset, clears all state |
| `sample_req` | input | 1-cycle strobe, once per audio frame |
| `sample_in` | input | Signed audio sample |
| `intensity` | input `[1:0]` | 0 → low-pass, 1 → high-pass, 2 → band-pass, 3 → notch |
| `sample_out` | output | Filtered sample (registered, 1 frame latency) |

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `WIDTH` | 16 | Sample width in bits |

## Usage

```systemverilog
audio_fx_biquad filt_l (
    .clk        (mclk),
    .rst        (i2s_rst),
    .sample_req (sample_req),
    .sample_in  (rx_ls),
    .intensity  (intensity_mclk),
    .sample_out (filt_l)
);
```

## Testing

`make sim TB=tb_audio_fx_biquad` checks:

- DC gain: LP passes a constant input (≈ unity), HP blocks it (≈ zero).
- Frequency response with synthesized sine waves: LP passes 100 Hz and
  attenuates 10 kHz by >25 dB; notch kills a 1 kHz tone; HP passes 10 kHz.

On hardware, select the filter effect and sweep `intensity`: talk into the
mic and listen to the muffled (LP), tinny (HP), telephone-like (BP), and
mid-scooped (notch) sounds.

## Exercises

1. **Retune the presets.** Recompute coefficients for fc = 500 Hz or
   Q = 4 and hear the difference. (The RBJ formulas above + a calculator
   or Python are all you need.)
2. **Make a wah pedal.** Sweep fc over time by stepping between several
   coefficient sets. This previews the LFO-modulated effects in a later
   phase.
3. **Cascade two biquads** for a 4th-order (24 dB/oct) low-pass. Check
   the DSP48 count in the utilization report before and after.
