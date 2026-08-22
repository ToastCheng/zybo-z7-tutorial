# `audio_fx_distortion` — Gain + Hard-Clip Distortion

## Goal

Amplify an audio sample and clip it at full scale, producing a fuzz /
overdrive effect.

## How It Works

The sample is multiplied by a power-of-two gain (a left shift), then
saturated. The amplified value is computed in a widened register so it
cannot overflow before the clip:

```systemverilog
logic signed [WIDTH+4:0] scaled;
assign scaled = sample_in <<< shift;      // x2, x4, x8, or x16
// then saturate to the WIDTH-bit full-scale range
```

Clipping flattens the waveform peaks, which adds the odd harmonics that make
the distortion sound.

## Ports

| Port | Direction | Description |
|------|-----------|-------------|
| `clk` | input | Clock (audio mclk domain) |
| `rst` | input | Synchronous active-high reset |
| `sample_in` | input | Signed audio sample |
| `intensity` | input `[1:0]` | 0 → ×2, 1 → ×4, 2 → ×8, 3 → ×16 |
| `sample_out` | output | Clipped sample (registered, 1-cycle latency) |

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `WIDTH` | 16 | Sample width in bits |

## Usage

```systemverilog
audio_fx_distortion fuzz (
    .clk        (mclk),
    .rst        (rst),
    .sample_in  (rx_sample),
    .intensity  (sw[3:2]),
    .sample_out (fx_sample)
);
```

See `rtl/top/top_audio_fx.md` for the full effects-chain context and
`rtl/tb/tb_audio_fx.sv` for test vectors.
