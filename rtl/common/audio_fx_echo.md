# `audio_fx_echo` — BRAM Delay-Line Echo

## Goal

Add an echo to the audio stream: the input, plus a delayed, quieter copy of
itself.

## How It Works

Both 16-bit channels are packed into one 32-bit word and stored in a ring
buffer in block RAM, one slot per audio frame. The read pointer trails the
write pointer by one slot, so the value read out was written DEPTH−1 frames
ago:

```systemverilog
mem[wr_addr] <= {in_l, in_r};
rd_data      <= mem[wr_addr + 1'b1];  // oldest frame in the buffer
wr_addr      <= wr_addr + 1'b1;
```

The delayed copy is scaled by a shift-based fraction (¼, ⅜, ½, or ⅝ — no
multiplier needed) and added to the dry input with a saturating add.

With the default `DEPTH = 16384` and a 44.1 kHz frame rate, the delay is
about 0.37 s. Resource cost: DEPTH × 32 bits of block RAM (16 of the Z7-10's
60 BRAM36 tiles at the default depth).

## Ports

| Port | Direction | Description |
|------|-----------|-------------|
| `clk` | input | Clock (audio mclk domain) |
| `rst` | input | Synchronous active-high reset |
| `sample_req` | input | One-cycle strobe: advance the delay line by one frame |
| `in_l`, `in_r` | input | Signed stereo samples |
| `intensity` | input `[1:0]` | Wet mix level: 0 → ¼, 1 → ⅜, 2 → ½, 3 → ⅝ |
| `out_l`, `out_r` | output | Dry + wet mix (combinational from the registered read) |

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `WIDTH` | 16 | Sample width in bits per channel |
| `DEPTH` | 16384 | Delay-line depth in frames (must be a power of two) |

## Usage

```systemverilog
audio_fx_echo #(.DEPTH(16384)) echo (
    .clk        (mclk),
    .rst        (rst),
    .sample_req (sample_req),   // from i2s_tx
    .in_l       (rx_l),
    .in_r       (rx_r),
    .intensity  (sw[3:2]),
    .out_l      (fx_l),
    .out_r      (fx_r)
);
```

See `rtl/top/top_audio_fx.md` for the full effects-chain context and
`rtl/tb/tb_audio_fx.sv` for test vectors.
