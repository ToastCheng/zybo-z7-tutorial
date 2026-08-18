# `i2c_master` — Read/Write Byte-Stream I2C Master

## Goal

Provide a small, reusable **I²C master** that can generate START, repeated-START, byte writes, byte reads, and STOP. It is suitable for driving the Zybo Z7-10 on-board SSM2603 audio codec and other I²C slaves from FPGA fabric.

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
| START   | `cmd_start`     | Generate a START condition (SDA falls while SCL is high). |
| REP START | `cmd_rep_start` | Generate a repeated START condition (no intervening STOP). |
| WRITE   | `cmd_write`     | Transmit `tx_data` and sample the slave ACK bit. |
| READ    | `cmd_read`      | Receive one byte into `rx_data`. |
| STOP    | `cmd_stop`      | Generate a STOP condition (SDA rises while SCL is high). |

The command strobes are **single-cycle pulses**.  An internal latch captures each pulse and holds the request until the bit timer accepts it in IDLE, so the caller does not need to align pulses with the I²C half-period.

`busy` is high while a command runs and `done` pulses for one cycle when it finishes.

- After a WRITE, `ack` reflects the slave's ACK bit (`1` = ACK, `0` = NACK).
- After a READ, `rx_data` holds the received byte.  The caller must set `ack_in` before issuing `cmd_read`:
  - `ack_in = 1` -> the master ACKs the byte and the slave should send the next one.
  - `ack_in = 0` -> the master NACKs the byte, telling the slave this is the last byte.

### Bit timing

A programmable timer divides `CLK_FREQ_HZ` down to `I2C_FREQ_HZ`. Each I²C bit uses a half-period counter so that SDA changes while SCL is low and is sampled while SCL is high.  The slave ACK bit and read data bits are sampled in the middle of the SCL high period to tolerate input delays and slave response time.

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
| `cmd_rep_start` | input | 1 | Request a repeated START condition. |
| `cmd_write` | input | 1 | Request transmission of `tx_data`. |
| `cmd_read` | input | 1 | Request reception of one byte. |
| `cmd_stop` | input | 1 | Request a STOP condition. |
| `tx_data` | input | 8 | Byte to transmit. |
| `ack_in` | input | 1 | Master ACK/NACK for read byte (`1` = ACK, `0` = NACK). |
| `busy` | output | 1 | High while the current command is executing. |
| `done` | output | 1 | One-cycle pulse when the command finishes. |
| `ack` | output | 1 | Last slave ACK sampled during a WRITE (`1` = ACK). |
| `rx_data` | output | 8 | Last byte received during a READ. |
| `scl_oe` | output | 1 | Drive SCL low when `1`; release when `0`. |
| `sda_oe` | output | 1 | Drive SDA low when `1`; release when `0`. |
| `sda_i` | input | 1 | Sensed SDA value (high = pulled up). |

## Usage Example

```systemverilog
logic i2c_busy, i2c_done, i2c_ack;
logic [7:0] i2c_rx;
logic scl_oe, sda_oe;
logic sda_i;

i2c_master #(
    .CLK_FREQ_HZ(125_000_000),
    .I2C_FREQ_HZ(100_000)
) i2c (
    .clk          (clk),
    .rst          (rst),
    .cmd_start    (cmd_start),
    .cmd_rep_start(cmd_rep_start),
    .cmd_stop     (cmd_stop),
    .cmd_write    (cmd_write),
    .cmd_read     (cmd_read),
    .tx_data      (tx_data),
    .ack_in       (ack_in),
    .busy         (i2c_busy),
    .done         (i2c_done),
    .ack          (i2c_ack),
    .rx_data      (i2c_rx),
    .scl_oe       (scl_oe),
    .sda_oe       (sda_oe),
    .sda_i        (sda_i)
);

// Open-drain pad connections (example with explicit tristate).
assign scl = scl_oe ? 1'b0 : 1'bz;
assign sda = sda_oe ? 1'b0 : 1'bz;
assign sda_i = sda;
```

## Typical read transaction

Reading a register from a device such as the SSM2603:

```systemverilog
// 1. START
// 2. Write device address with R/W = 0
// 3. Write register address
// 4. Repeated START
// 5. Write device address with R/W = 1
// 6. Read first byte, ACK to request second byte
// 7. Read second byte, NACK to finish
// 8. STOP
```

## Testing

See `rtl/tb/tb_i2c_master.sv`. It emulates an open-drain pull-up bus and a simple slave stub that ACKs every byte, captures transmitted data, and drives read data. The test verifies full write transactions and multi-byte read transactions with repeated START.
