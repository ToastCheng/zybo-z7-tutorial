# Phase 11: `top_audio_fx_soc` — PS-Controlled Audio Effects

## Goal

Rebuild the Phase 10 audio-effects loopback as a **PS + PL SoC design**. The
ARM processor takes over everything that is not real-time audio:

- **Codec configuration over I2C** — done by software using the PS's hardened
  I2C1 controller instead of an RTL I2C master + sequencer FSM.
- **Effect selection and intensity** — written by software into the PL
  through **AXI GPIO**, driven from a **UART menu** on the host terminal.
- **Mute control** — one more bit in the same control word.

The PL keeps the parts that must run at hardware speed with zero CPU
involvement: the audio master clock (MMCM), the I2S receive/transmit
datapath, and the effect chain itself.

## What You Should See

- After `make build_soc SOC_TOP=top_audio_fx_soc && make app APP=audio_fx
  && make run_soc SOC_TOP=top_audio_fx_soc APP=audio_fx`, the UART console
  (115200 baud) shows the codec being configured register by register, then
  a menu:

  ```
  --- Phase 11: PS-controlled audio effects ---
    0 bypass | 1 bit-crusher | 2 echo | 3 distortion
    +/- intensity | m mute/unmute | r read codec R4
  ```

- Speak into the mic and press `0`..`3` to hear the effect change live;
  `+`/`-` changes the intensity, `m` mutes, `r` reads a codec register back
  over I2C and prints it.
- The four LEDs mirror `ctrl[3:0]` (effect select + intensity) as a
  hardware-side debug view.

## Concepts

### Partitioning: software for control, hardware for data

Phase 10 proved the whole audio path can run in pure RTL — including codec
configuration over an RTL I2C master. This phase moves control to software
anyway, because that is how real Zynq systems are partitioned:

| Task | Where | Why |
|------|-------|-----|
| Codec register init | PS (I2C1) | Runs once at startup; a C table is easier to read, tweak, and debug than an FSM + LUT. The hard I2C controller is proven silicon and can also **read back** registers. |
| Effect select / intensity / mute | PS (AXI GPIO) | Human-speed control; a UART menu beats re-synthesizing for every parameter change. |
| I2S datapath + effects | PL | Sample-rate streaming with deterministic latency — the FPGA's job. |
| Audio clock (MMCM) | PL | The codec MCLK must come from the fabric clocking resources. |

### PS I2C through EMIO

The codec's I2C pins (N17/N18) are wired to the PL, not to PS MIO pads. The
PS I2C1 controller reaches them through **EMIO**: the peripheral's SCL/SDA
are routed into the fabric and out of ordinary PL pins. In the block design
(`scripts/bd/top_audio_fx_soc.tcl`) this is just:

```tcl
CONFIG.PCW_I2C1_PERIPHERAL_ENABLE {1}
CONFIG.PCW_I2C1_I2C1_IO {EMIO}
```

The wrapper exposes them as tri-state `inout` ports (`IIC_1_0_scl_io`,
`IIC_1_0_sda_io`); direction is controlled by the PS peripheral, exactly like
the EMIO GPIO in Phase 9. On the software side the `xiicps` driver is used
in polled mode (`XIicPs_MasterSend` / `XIicPs_MasterRecv`).

### AXI GPIO: the first AXI peripheral

Phase 9 used EMIO GPIO — a bare wire from PS to PL. This phase introduces
the mechanism real SoC designs use: the PS writes to PL peripherals over an
**AXI4-Lite** bus.

- `M_AXI_GP0` is the PS's general-purpose AXI master port.
- `FCLK_CLK0` is a PS-generated clock for the PL-side AXI logic.
- The **AXI Interconnect** and **proc_sys_reset** blocks are created
  automatically by `apply_bd_automation`.
- The **AXI GPIO** IP turns bus writes into a 32-bit output port
  (`gpio_io_o_0`) that our top level consumes like any other signal.

From software it is a memory-mapped register write: `XGpio_DiscreteWrite`.

### The control word

```
bit  [5]    unmute      -> ac_muten
bit  [4]    codec_ready -> releases the I2S datapath reset
bits [3:2]  intensity   -> effect modules (0..3)
bits [1:0]  fx_sel      -> 00 bypass, 01 crusher, 10 echo, 11 distortion
```

`codec_ready` replaces the RTL `init_done` from Phase 10: the I2S datapath
is held in reset until software has finished configuring the codec.

The control word is written by the PS on the FCLK clock domain and consumed
in the audio MCLK domain. It is quasi-static (changes only on keypresses),
so a plain 2-flop synchronizer per bit is sufficient; the constraints file
declares the crossing with `set_false_path` to the first sync stage.

## Block Diagram

```
 host terminal (115200 baud)
        ▲  ▼ UART1 (MIO)
┌──────────────── PS ───────────────┐
│  Cortex-A9 bare-metal app         │
│    codec init table (C)           │
│    UART menu                      │
│  I2C1 ──────── EMIO ──────────────┼──► ac_scl / ac_sda (N18/N17)
│  M_AXI_GP0 ── AXI GPIO ───────────┼──► ctrl[31:0]
└───────────────────────────────────┘        │
                                             ▼
┌──────────────── PL ───────────────┐   2-flop sync (mclk domain)
│  audio_clock_gen (MMCM) ─► ac_mclk│
│  i2s_rx ◄── ac_recdat             │
│      │                            │
│      ▼                            │
│  fx chain (crusher/echo/distort)  │ ◄── fx_sel, intensity (ctrl)
│      │                            │
│      ▼                            │
│  i2s_tx ─► ac_bclk/pblrc/pbdat    │
│  ac_muten ◄── ctrl[5]             │
└───────────────────────────────────┘
```

## Files

| File | Purpose |
|------|---------|
| `rtl/top/top_audio_fx_soc.sv` | This top level: wrapper + audio datapath |
| `scripts/bd/top_audio_fx_soc.tcl` | Block design: PS7 + I2C1/EMIO + AXI GPIO |
| `constraints/top_audio_fx_soc.xdc` | Codec pins, fabric clock, CDC constraints |
| `vitis/audio_fx/src/main.c` | Codec init, control word, UART menu |
| `vitis/audio_fx/build_app.py` | Vitis platform + app build script |

## Testing

1. `make build_soc SOC_TOP=top_audio_fx_soc` — bitstream + XSA.
2. `make app APP=audio_fx` — bare-metal ELF.
3. `make run_soc SOC_TOP=top_audio_fx_soc APP=audio_fx` — program + run.
4. Open the UART (115200 baud). Expect 11 codec writes to succeed, then the
   menu.
5. Mic in, headphones out: `0` clean loopback, `1` bit-crusher, `2` echo,
   `3` distortion; `+`/`-` changes intensity; `r` reads back codec R4
   (expect `0x015`).

## Exercises

- Add a second AXI GPIO channel as an **input** so the PS can read the slide
  switches and use them (e.g. switches select the effect, UART selects
  intensity).
- Change the echo depth at runtime: add `ctrl[10:6]` as a delay-shift
  control and modify `audio_fx_echo` to skip `1 << n` frames per sample.
- Read back **all** codec registers with `r` and diff them against the LUT.
