# `audio_fx_comp` — Compressor / Limiter (Feedback AGC)

## Goal

Push loud sounds down to a target level while leaving quiet sounds alone —
a compressor with an infinite:1 ratio above the target, i.e. a limiter,
with gentle automatic recovery.

## Concepts

- **Why feedback?** A textbook compressor computes `gain = target/env`,
  which needs a divider — expensive in hardware. This module closes a loop
  instead: the envelope follower watches the **output**, and the gain
  walks up or down every frame until the output envelope sits at the
  target. The arithmetic is just shifts and adds; the loop does the
  division implicitly.
- **Attack vs. release asymmetry.** The attack step is coarse
  (`(env − target) >> 4`) so peaks get caught fast; the release is fine
  (`(UNITY − gain) >> 9`, ~12 ms time constant) so the level recovers
  smoothly. A coarse release makes the loop *ratchet* past the target —
  measured as ~40 % overshoot in the testbench before this was fixed.
- **Settling error.** The loop idles with a small limit cycle slightly
  above the target (attack/release steps balance where
  `(env − target) >> 4 ≈ release step`). Measured: ~9300 against a target
  of 8192 for a 20000-LSB input — about 1 dB hot, inaudible for a guitar
  pedal, and a great example of why control loops need simulation.

## How It Works

```
in ──► × gain ──► out ──► audio_fx_envelope ──► env
       ▲                                          │
       └──── gain +=/-= step ◄── compare env vs target
```

Target presets (`intensity`), full scale = 32767:

| `intensity` | Target | Level |
|-------------|--------|-------|
| 0 | 16384 | −6 dB |
| 1 | 8192 | −12 dB |
| 2 | 4096 | −18 dB |
| 3 | 2048 | −24 dB |

One DSP48 multiplier per channel; `gain ≤ 32768` (unity), so
`|out| ≤ |in|` — no overflow possible.

## Ports

| Port | Direction | Description |
|------|-----------|-------------|
| `clk` / `rst` | input | MCLK domain, synchronous reset (gain ← unity) |
| `sample_req` | input | Frame strobe |
| `in_l` / `in_r` | input | Signed samples |
| `intensity` | input `[1:0]` | Target-level preset |
| `out_l` / `out_r` | output | Compressed samples (1 frame latency) |

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `WIDTH` | 16 | Sample width |

## Testing

`make sim TB=tb_audio_fx_dyn`: a 20000-LSB sine is limited to the 8192
target (within the settling error above), and a 2000-LSB sine passes at
unity gain.

On hardware: effect `8`. Distortion (effect `3`) followed by the limiter
is the classic pairing — drive hard, then catch the peaks.

## Exercises

1. **Feedforward comp.** Compute gain from the input envelope with a
   piecewise gain curve — needs the division this module avoids. Compare
   settling behaviour and resource usage.
2. **Adjustable ratio.** Change the attack shift with `intensity` for
   2:1 / 4:1 / limiter ratios instead of target levels.
3. **Loop stability.** Set the attack shift to `>> 2` in simulation and
   watch the gain oscillate. Where is the stability boundary?
