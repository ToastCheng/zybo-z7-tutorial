# `audio_delay_line` — Stereo Variable-Tap Delay Line

## Goal

Delay both audio channels by a run-time-selectable number of frames. This is
the building block for every time-based effect: chorus, flanger, vibrato,
and (later) reverb.

## How It Works

Both 16-bit channels are packed into one 32-bit word and written into a
BRAM ring buffer once per audio frame. The read address trails the write
address by `tap` frames:

```
rd_addr = wr_addr - tap     (mod DEPTH — AW-bit arithmetic wraps for free)
```

Because `tap` is a port (not fixed like `audio_fx_echo`), an LFO or any
other logic can modulate the delay at run time. The read is synchronous
(BRAM), so outputs update one clock after `sample_req` — one frame of
latency, irrelevant at audio rates.

## Ports

| Port | Direction | Description |
|------|-----------|-------------|
| `clk` | input | Audio master clock (MCLK domain) |
| `rst` | input | Synchronous reset (clears write pointer, not the RAM) |
| `sample_req` | input | 1-cycle strobe, once per audio frame |
| `in_l` / `in_r` | input | Signed samples |
| `tap` | input `[$clog2(DEPTH)-1:0]` | Delay in frames; use 1..DEPTH-1 (`0` wraps to a full DEPTH) |
| `out_l` / `out_r` | output | Delayed samples (registered) |

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `WIDTH` | 16 | Sample width in bits |
| `DEPTH` | 2048 | Ring buffer length in frames — must be a power of two. 2048 frames ≈ 46 ms at 44.1 kHz |

## Usage

```systemverilog
audio_delay_line #(.DEPTH(2048)) dline (
    .clk (mclk), .rst (i2s_rst), .sample_req (sample_req),
    .in_l (rx_ls), .in_r (rx_rs),
    .tap  (tap),                  // may change between frames
    .out_l (del_l), .out_r (del_r)
);
```

## Notes

- **Reset does not clear the RAM** — after reset the first DEPTH frames read
  back stale/garbage data. Effects that use this should tolerate (or mute) a
  fraction of a second of noise after reset, exactly like a real delay pedal
  power-up.
- See `rtl/tb/tb_audio_fx_mod.sv` for the exact-delay test vectors.
