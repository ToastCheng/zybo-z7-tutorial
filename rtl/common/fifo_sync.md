# `fifo_sync` — Synchronous FIFO

## Goal

Provide a small, reusable **first-in, first-out** buffer that decouples a producer and a consumer sharing the same clock.

## Concepts

### FIFO pointers

The FIFO tracks two positions in a circular memory:

- **Write pointer**: where the next incoming value will be stored.
- **Read pointer**: where the oldest stored value can be read.

Both pointers wrap around when they reach the end of the memory. An extra **wrap bit** is stored with each pointer so that the circuit can tell the difference between *empty* and *full* when the two address fields happen to be equal.

### Registered read data

When `rd_en` is asserted, the oldest unread entry is latched into `dout` and the read pointer advances in the same clock cycle. `dout` therefore holds the value that was just read, and remains valid until the next read.

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | `8` | Width of each stored word. |
| `DEPTH` | `16` | Number of entries. Must be at least 2. |

## Ports

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | input | 1 | System clock. |
| `rst` | input | 1 | Synchronous active-high reset/clear. |
| `wr_en` | input | 1 | Write the value on `din` into the FIFO. Ignored if `full` is high. |
| `din` | input | `DATA_WIDTH` | Data to write. |
| `full` | output | 1 | High when the FIFO cannot accept more writes. |
| `rd_en` | input | 1 | Advance the read pointer. Ignored if `empty` is high. |
| `dout` | output | `DATA_WIDTH` | Oldest unread data (show-ahead). |
| `empty` | output | 1 | High when the FIFO has no data. |

## Usage Example

```systemverilog
fifo_sync #(
    .DATA_WIDTH(8),
    .DEPTH     (16)
) fifo_inst (
    .clk   (clk),
    .rst   (fifo_clear),
    .wr_en (write_request),
    .din   (write_data),
    .full  (fifo_full),
    .rd_en (read_request),
    .dout  (read_data),
    .empty (fifo_empty)
);
```

## Testing

See `rtl/tb/tb_fifo_sync.sv`. It verifies reset, basic writes/reads, full and empty flags, wrap-around, and ignored writes when full.
