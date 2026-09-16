# `audio_fx_gate` — Noise Gate

## Goal

Silence below a loudness threshold, pass signal above it. The demo effect:
with the mic idle, background hiss disappears; the moment you speak, the
gate opens.

## Concepts

- **Hysteresis.** One threshold would chatter (open/close/open…) when the
  envelope hovers near it. The gate *opens* above `open_thr` and *closes*
  below `open_thr/2` — two thresholds, a 6 dB dead band.
- **Gain ramping, not switching.** Multiplying by a gain that jumps
  0 ↔ 1 mid-waveform is a discontinuity — a click. The gain ramps instead:
  fast up (`>> 3`, ~8-frame time constant) and slower down (`>> 6`,
  ~64 frames), so the gate is felt, not heard.
- **One gain for both channels.** The envelope watches the left channel
  and both channels share the gain — independent per-channel gates would
  make the stereo image wobble.

## How It Works

```
in_l ──► audio_fx_envelope ──► env
                                   │  hysteresis: open > thr, close < thr/2
                                   ▼
                    gate_open ──► gain ramp ──► × (both channels) ──► out
```

Threshold presets (`intensity`), full scale = 32767:

| `intensity` | Open threshold | Level |
|-------------|----------------|-------|
| 0 | 104 | −50 dB |
| 1 | 328 | −40 dB |
| 2 | 1036 | −30 dB |
| 3 | 3277 | −20 dB |

## Ports

| Port | Direction | Description |
|------|-----------|-------------|
| `clk` / `rst` | input | MCLK domain, synchronous reset (gate closed, gain 0) |
| `sample_req` | input | Frame strobe |
| `in_l` / `in_r` | input | Signed samples |
| `intensity` | input `[1:0]` | Threshold preset |
| `out_l` / `out_r` | output | Gated samples (1 frame latency) |

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `WIDTH` | 16 | Sample width |

## Testing

`make sim TB=tb_audio_fx_dyn`: a 200-LSB sine stays fully muted, a
10000-LSB sine opens the gate and passes at full amplitude.

On hardware: effect `7`. Start a fan or hum near the mic and walk the
threshold up with `+` until the hiss drops out between words.

## Exercises

1. **Click audibility.** Replace the gain ramp with an instant switch and
   listen at the threshold. Then put the ramp back.
2. **Ducker.** Feed the envelope of one source (e.g. your voice) to gate
   *down* another — the radio-DJ effect. Needs a second input path.
3. **Watchdog exercise:** what happens if `close_thr == open_thr`?
   Predict the chatter, then try it in simulation.
