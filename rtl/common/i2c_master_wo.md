# `i2c_master_wo` — Write-Only Byte-Stream I2C Master

## Goal

Provide a small, reusable **write-only I²C master** that can generate START, send bytes, receive ACK/NACK from a slave, and generate STOP. It is write-only (no read support) and drives the bus in an open-drain fashion suitable for FPGA IOBUFs.

## Concepts

### Open-drain I²C bus

The FPGA must never drive a logic-high onto SCL or SDA; it either drives low or releases the line and lets the external pull-up resistor pull it high. `i2c_master` exposes:

- `scl_oe` — active-high output-enable to drive SCL low.
- `sda_oe` — active-high output-enable to drive SDA low.
- `sda_i`  — sampled value of SDA (after the IOBUF / external pull-up).

The top-level connects these to `IOBUF` instances or tristate pads.

### Byte-stream command interface

Instead of a high-level register interface, the master exposes one command at a time:

| Command | Strobe | Effect |
|---------|--------|--------|
| START   | `cmd_start` | Generate a START condition (SDA falls while SCL is high). |
| WRITE   | `cmd_write` | Transmit `tx_data` and sample the slave ACK bit. |
| STOP    | `cmd_stop`  | Generate a STOP condition (SDA rises while SCL is high). |

The command strobes are **single-cycle pulses**.  An internal latch captures each pulse and holds the request until the bit timer accepts it in the IDLE state, so the caller does not need to align the pulse with the I²C half-period.

`busy` is high while a command runs and `done` pulses for one cycle when it finishes. After a WRITE, `ack` reflects the slave's ACK bit (`1` = ACK, `0` = NACK).

### Bit timing

A programmable timer divides `CLK_FREQ_HZ` down to `I2C_FREQ_HZ`. Each I²C bit uses a half-period counter so that SDA changes while SCL is low and is sampled while SCL is high.  The slave ACK bit is sampled in the middle of the SCL high period to tolerate input delays and slave response time.

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `CLK_FREQ_HZ` | `125_000_000` | System clock frequency in Hz. |
| `I2C_FREQ_HZ` | `100_000` | Desired I²C clock frequency in Hz (standard mode default). |

## Ports

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | input | 1 | System clock. |
| `rst` | input | 1 | Synchronous active-high reset. |
| `cmd_start` | input | 1 | Request a START condition. |
| `cmd_stop` | input | 1 | Request a STOP condition. |
| `cmd_write` | input | 1 | Request transmission of `tx_data`. |
| `tx_data` | input | 8 | Byte to transmit. |
| `busy` | output | 1 | High while the current command is executing. |
| `done` | output | 1 | One-cycle pulse when the command finishes. |
| `ack` | output | 1 | Last ACK sampled from the slave (high = ACK). |
| `scl_oe` | output | 1 | Drive SCL low when `1`; release when `0`. |
| `sda_oe` | output | 1 | Drive SDA low when `1`; release when `0`. |
| `sda_i` | input | 1 | Sensed SDA value (high = pulled up). |

## Usage Example

```systemverilog
logic i2c_busy, i2c_done, i2c_ack;
logic scl_oe, sda_oe;
logic sda_i;

i2c_master_wo #(
    .CLK_FREQ_HZ(125_000_000),
    .I2C_FREQ_HZ(100_000)
) i2c (
    .clk       (clk),
    .rst       (rst),
    .cmd_start (cmd_start),
    .cmd_stop  (cmd_stop),
    .cmd_write (cmd_write),
    .tx_data   (tx_data),
    .busy      (i2c_busy),
    .done      (i2c_done),
    .ack       (i2c_ack),
    .scl_oe    (scl_oe),
    .sda_oe    (sda_oe),
    .sda_i     (sda_i)
);

// Open-drain pad connections (example with explicit tristate).
assign scl = scl_oe ? 1'b0 : 1'bz;
assign sda = sda_oe ? 1'b0 : 1'bz;
assign sda_i = sda;
```

## Testing

See `rtl/tb/tb_i2c_master_wo.sv`. It emulates an open-drain pull-up bus and a simple slave stub that ACKs every byte and captures transmitted data. The test verifies a full START + 3-byte write + STOP transaction.
