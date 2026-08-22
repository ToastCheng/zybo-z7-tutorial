# `audio_fx_bitcrusher` — Lo-Fi Bit-Crusher

## Goal

Reduce the effective bit depth of an audio sample, producing the classic
harsh "8-bit" lo-fi sound.

## How It Works

A signed arithmetic shift right followed by a shift left zeroes the lowest
`shift` bits while preserving the sign:

```systemverilog
assign sample_out = (sample_in >>> shift) <<< shift;
```

The discarded bits turn smooth waveforms into staircases; the resulting
quantization error is audible as buzzy harmonics.

## Ports

| Port | Direction | Description |
|------|-----------|-------------|
| `sample_in` | input | Signed audio sample |
| `intensity` | input `[1:0]` | 0 → keep 12 bits, 1 → 8, 2 → 6, 3 → 4 |
| `sample_out` | output | Crushed sample (combinational) |

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `WIDTH` | 16 | Sample width in bits |

## Usage

```systemverilog
audio_fx_bitcrusher crush (
    .sample_in  (rx_sample),
    .intensity  (sw[3:2]),
    .sample_out (fx_sample)
);
```

Purely combinational — no clock or reset. See `rtl/top/top_audio_fx.md` for
the full effects-chain context and `rtl/tb/tb_audio_fx.sv` for test vectors.
