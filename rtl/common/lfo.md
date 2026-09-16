# `lfo` — Low-Frequency Oscillator (Triangle)

## Goal

Generate a slow, signed control waveform (~0.1–10 Hz) to modulate effect
parameters: delay taps (chorus/vibrato) or amplitude (tremolo).

## How It Works

A 24-bit **phase accumulator** advances by `rate` once per audio frame:

```
frequency = rate * 44100 / 2^24      (at 44.1 kHz frames)
```

Handy rates: `190` ≈ 0.5 Hz (chorus), `95` ≈ 0.25 Hz (flanger),
`1903` ≈ 5 Hz (tremolo/vibrato).

The waveform is a **triangle** read straight off the phase bits — no lookup
table, no multipliers:

```
tri = phase[23] ? ~phase[22:7] : phase[22:7];   // 0..65535 up then down
out = tri ^ 16'h8000;                           // offset binary -> signed
```

The MSB picks rising vs. falling, the next 16 bits are the slope, and
flipping the sign bit converts offset binary to two's complement Q1.15.

> **Why not a sine?** A sine LUT needs 256 constants or quarter-wave
> symmetry logic. For slow modulation a triangle is nearly
> indistinguishable by ear — the only difference is a constant-rate sweep
> at the peaks instead of a smooth turn.

## Ports

| Port | Direction | Description |
|------|-----------|-------------|
| `clk` | input | Clock (any; advances only on `sample_req`) |
| `rst` | input | Synchronous reset, phase ← 0 (output starts at −full scale) |
| `sample_req` | input | 1-cycle strobe, once per audio frame |
| `rate` | input `[23:0]` | Phase increment per frame |
| `out` | output | Signed Q1.15 triangle in [−1, +1) |

## Usage

```systemverilog
lfo trem_lfo (
    .clk (mclk), .rst (i2s_rst), .sample_req (sample_req),
    .rate (24'd1903),   // ~5 Hz
    .out  (tri_wave)
);
```

## Testing

`make sim TB=tb_audio_fx_mod` verifies the period (`rate = 2^22` → exactly
4 frames per cycle) and full-scale amplitude (±32768/32767).

## Exercises

1. **Sine LUT.** Replace the triangle with a 256-entry sine table indexed
   by `phase[23:16]`. Generate the constants with Python; compare resource
   usage (LUT RAM vs. nothing).
2. **Rate from the control word.** Route two spare `ctrl` bits to `rate`
   so the UART menu can change modulation speed live.
