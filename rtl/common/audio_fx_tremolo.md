# `audio_fx_tremolo` — Amplitude Modulation

## Goal

Tremolo: periodically vary the volume with a ~5 Hz LFO. Structurally the
simplest modulation effect — no memory, just a multiplier — and the first
module that applies a **time-varying gain** in Q1.16 format.

## How It Works

```
gain = 32768 + (tri_wave >>> depth_shift)     // Q1.16, 0 < gain < 1
out  = (sample * gain) >>> 16
```

The LFO triangle (Q1.15) is scaled by a power-of-two shift and offset to
sit around 0.5. One 16×18 multiply per channel maps to one DSP48 each.
Since the gain is always < 1, the product can never overflow — no
saturation stage needed (verify this invariant if you change the math!).

## Presets (`intensity`)

| `intensity` | Depth | Gain swing |
|-------------|-------|------------|
| 0 | subtle | 0.44 – 0.56 |
| 1 | mild | 0.375 – 0.625 |
| 2 | deep | 0.25 – 0.75 |
| 3 | full | 0.0 – 1.0 |

## Ports

| Port | Direction | Description |
|------|-----------|-------------|
| `clk` / `rst` | input | MCLK domain, synchronous reset |
| `sample_req` | input | Frame strobe; output registers on it |
| `in_l` / `in_r` | input | Signed samples |
| `intensity` | input `[1:0]` | Depth preset (table above) |
| `out_l` / `out_r` | output | Modulated samples (1 frame latency) |

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `WIDTH` | 16 | Sample width |

## Testing

`make sim TB=tb_audio_fx_mod` drives DC at full depth and checks the output
envelope swings from ≈0 to ≈full input over one LFO cycle.

On hardware: effect `6` in the UART menu. At full depth a held note chops
on/off 5 times per second.

## Exercises

1. **Ring modulation.** Raise the LFO rate into the audio range
   (`rate` ≈ 30 Hz+). The amplitude "modulation" becomes audible sidebands
   — the same math, a very different sound.
2. **Rate control.** Wire spare `ctrl` bits to the LFO rate (see the
   `lfo.md` exercise) and sweep tremolo speed from the UART menu.
