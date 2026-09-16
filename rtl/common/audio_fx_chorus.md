# `audio_fx_chorus` — Chorus / Flanger / Vibrato

## Goal

The classic modulation-delay family: mix the signal with a copy of itself
delayed by a slowly moving amount. One module, four presets — the
difference between chorus, flanger, and vibrato is *parameters, not
structure*.

## Concepts

- **Comb filtering.** A signal plus a delayed copy has frequency response
  with evenly spaced notches (1/delay apart). Sweeping the delay makes the
  notches sweep — the "swimming" sound of chorus/flanger.
- **Delay modulation = pitch wobble.** A moving tap reads the delay line
  faster or slower than real time, slightly shifting pitch. With the dry
  signal removed (vibrato preset) you hear exactly this.
- **Parameter reuse.** Chorus vs. flanger vs. vibrato differ only in delay
  time, depth, rate, and mix — a perfect case for a preset LUT.

## Presets (`intensity`)

| `intensity` | Effect | Delay | Depth | Rate | Mix |
|-------------|--------|-------|-------|------|-----|
| 0 | chorus | 15 ms | ±6 ms | 0.5 Hz | dry + wet/2 |
| 1 | flanger | 3 ms | ±3 ms | 0.25 Hz | dry + wet/2 |
| 2 | vibrato | 10 ms | ±6 ms | 5 Hz | wet only |
| 3 | slow chorus | 15 ms | ±6 ms | 0.2 Hz | dry + wet/2 |

## How It Works

```
in ──┬──────────────────────────────► sat_add ──► out
     │                                  ▲
     └─► audio_delay_line (tap) ──► >>>1 ┘   (vibrato: wet only)
              ▲
         tap = base + (tri_wave >>> depth_shift)
              ▲
            lfo (rate)
```

- The tap offset is the LFO output shifted right — power-of-two scaling,
  no multiplier (`tri >>> 7` ≈ ±256 frames ≈ ±5.8 ms).
- Presets keep `1 ≤ tap ≤ DEPTH−2`, so the truncated address slice is safe.
- The tap moves in 1-frame (~23 µs) steps. At these rates the stepping is
  inaudible; fractional interpolation is an exercise below.

## Ports

| Port | Direction | Description |
|------|-----------|-------------|
| `clk` / `rst` | input | MCLK domain, synchronous reset |
| `sample_req` | input | Frame strobe |
| `in_l` / `in_r` | input | Signed samples |
| `intensity` | input `[1:0]` | Preset select (table above) |
| `out_l` / `out_r` | output | Mixed output (combinational from BRAM read) |

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `WIDTH` | 16 | Sample width |
| `DEPTH` | 2048 | Delay-line frames (~46 ms max); power of two |

## Testing

`make sim TB=tb_audio_fx_mod` checks: chorus DC mix = 1.5× input (dry +
wet/2 of a constant), and the flanger preset produces a delayed impulse
copy at half amplitude within the tap range.

On hardware: effect `5` in the UART menu, `+`/`-` cycles presets. Sing a
steady note — chorus thickens it, flanger sweeps visibly, vibrato bends
the pitch.

## Exercises

1. **Fractional delay.** Read two adjacent taps and linearly interpolate
   with the LFO's low bits as the fraction. Removes the 1-frame stepping.
2. **Flanger feedback.** Add a small amount of the delay output back into
   its input (`>>>2` is plenty) for the classic jet-plane whoosh. Mind the
   stability — |feedback| < 1.
3. **Stereo spread.** Use opposite LFO polarities for the left/right taps.
