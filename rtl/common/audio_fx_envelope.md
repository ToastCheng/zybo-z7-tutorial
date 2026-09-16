# `audio_fx_envelope` — Peak Envelope Follower

## Goal

Answer "how loud is the signal right now?" as a number the hardware can
use. This is the sensor that drives every dynamics effect: noise gates,
compressors, limiters, auto-wah, duckers.

## How It Works

Full-wave rectify, then track with instant attack and exponential release:

```
rect = |x|
env  = rect                        if rect > env    (attack)
     = env - (env >> RELEASE)      otherwise        (release)
```

The release is a shift, not a multiply: with `RELEASE_SHIFT = 7` the
envelope falls by 1/128 per frame — a ~2.9 ms time constant at 44.1 kHz.

> **Steady-state ripple.** Attack fires only when `rect > env`, so a
> constant input makes the envelope sit one release step *below* the peak
> (39/5000 = 0.8% with the default shift). Harmless, but it shows up in
> the testbench — `tb_audio_fx_dyn` measures it.

> **Rectifier saturation.** `|−32768|` doesn't fit in 16 bits, so the
> rectifier clamps to 32767 — a 0.003% error on exactly one sample value.

## Ports

| Port | Direction | Description |
|------|-----------|-------------|
| `clk` / `rst` | input | MCLK domain, synchronous reset |
| `sample_req` | input | Frame strobe |
| `sample_in` | input | Signed sample |
| `env` | output `[WIDTH-1:0]` | Unsigned magnitude estimate (0–32767) |

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `WIDTH` | 16 | Sample width |
| `RELEASE_SHIFT` | 7 | Release rate; time constant ≈ 2^SHIFT frames |

## Usage

Feedforward (noise gate — watch the input) vs. feedback (compressor —
watch the output) are the two classic ways to wire this block; see
`audio_fx_gate.md` and `audio_fx_comp.md`.

## Testing

`make sim TB=tb_audio_fx_dyn` checks attack on a step input and release
decay below a bound after 600 frames.
