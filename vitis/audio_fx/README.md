# `vitis/audio_fx` — Phase 11 Bare-Metal Application

PS-side software for `top_audio_fx_soc`: configures the SSM2603 codec over
the PS I2C1 controller (EMIO), then runs a UART menu that writes the PL
control word over AXI GPIO.

See `rtl/top/top_audio_fx_soc.md` for the full phase documentation.

## Build & Run

```bash
make build_soc SOC_TOP=top_audio_fx_soc   # once per hardware change
make app APP=audio_fx                     # builds this application
make run_soc SOC_TOP=top_audio_fx_soc APP=audio_fx
```

Open a serial terminal on the PROG/UART port at 115200 baud.

## UART Menu

| Key | Action |
|-----|--------|
| `0` | Bypass (pure loopback) |
| `1` | Bit-crusher |
| `2` | Echo |
| `3` | Distortion |
| `+` / `-` | Intensity up / down (0–3) |
| `m` | Mute / unmute |
| `h` / `?` | Reprint the menu |

Note: there is deliberately no register read-back command — the SSM2603
control interface is effectively write-only (read attempts return constant
garbage on this board).

## Control Word (AXI GPIO channel 1)

| Bits | Meaning |
|------|---------|
| `[1:0]` | Effect select (0 bypass, 1 crusher, 2 echo, 3 distortion) |
| `[3:2]` | Intensity |
| `[4]` | `codec_ready` — releases the PL I2S datapath reset |
| `[5]` | Unmute — drives `ac_muten` |

## Files

- `src/main.c` — the whole application (codec table, I2C init, menu loop)
- `build_app.py` — Vitis Python build script; generated files land in
  `build/vitis_ws/` (git-ignored)
