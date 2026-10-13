# MOOR — Minimal RV32E RISC-V Core

MOOR is an area-focused, multi-cycle RISC-V processor written in SystemVerilog. The goal is simple: **build a small practical RV32E-class core with machine-mode interrupts, while keeping the hardware as small as reasonably possible.**

> **Built in one night, with AI assistance.** MOOR was developed in a single-night sprint with help from ChatGPT, Claude, and DeepSeek. AI accelerated exploration, implementation, and debugging.

## Design goals

- Keep area low by sharing datapath hardware and avoiding unnecessary state.
- Use a multi-cycle controller rather than a fully pipelined architecture.
- Support basic machine-mode control, traps, and interrupt handling.
- Keep the RTL modular and configurable for implementation experiments.
- Preserve a simple integration boundary for instruction and data memory.


## Features

| Feature | Current implementation |
| --- | --- |
| Architecture target | 32-bit RV32E-style core (15 integer registers in addition to hardwire `x0`) |
| Datapath | Multi-cycle, shared ALU |
| Integer operations | Add/subtract, comparisons, logical operations, shifts |
| Control flow | Conditional branches, `JAL`, `JALR` |
| Memory operations | `LB`, `LH`, `LW`, `LBU`, `LHU`, `SB`, `SH`, `SW` |
| Upper-immediate operations | `LUI`, `AUIPC` |
| Machine control | Minimal CSR implementation, `ECALL`, `MRET` |
| Interrupt inputs | Software, timer, and external interrupt signals |
| Idle instruction | `WFI` with a `HALT` state and interrupt-based wakeup |
| Register file | Selectable latch-based or flip-flop-based storage |
| Shifter | Configurable multi-cycle shifter: chunked or serial mode |
| Memory interface | Single-beat AXI-style interface with current zero-latency response assumptions |

## Interrupts and WFI

The core exposes three interrupt inputs:

| Input | Intended use | CSR enable bit |
| --- | --- | --- |
| `swIrq` | Machine software interrupt | `mie.MSIE` |
| `timerIrq` | Machine timer interrupt | `mie.MTIE` |
| `extIrq` | Machine external interrupt | `mie.MEIE` |

The current interrupt-take condition requires global `mstatus.MIE` and the corresponding per-source `mie` bit. The CSR block contains a minimal implementation of `mstatus`, `mie`, `mtvec`, `mepc`, `mip`, and parameterized `mhartid` reads.

`WFI` advances past the instruction and enters `HALT` when no eligible interrupt is being taken. In the current controller, `irqTake` is also the HALT wake condition. The implementation does not yet provide a complete privileged-architecture trap model: for example, there is no `mcause` CSR or full vectored-interrupt handling. **Verify wakeup behavior against your intended platform and interrupt policy before relying on it**.


## Parameters

| Parameter | Default | Purpose |
| --- | --- | --- |
| `RESET_PC` | `32'h0000_0000` | Reset instruction address |
| `MTVEC_RESET` | `30'd0` | Reset value for the stored trap-vector base |
| `PC_BITS` | `12` | Instruction-address width at the core boundary |
| `USE_LATCH` | `1'b1` | Select latch-based (`1`) or FF-based (`0`) register-file storage |
| `SERIAL_SHIFTER` | `1'b0` | Select serial (`1`) or chunked multi-cycle (`0`) shifting |
| `HART_ID` | `32'd0` | Value returned by the `mhartid` CSR read |

With the default `PC_BITS = 12`, the instruction address exposed at the core boundary is limited to 12 bits and is zero-extended to 32 bits. Increase this parameter if the target memory map requires a wider instruction address.

## Memory interface

MOOR has separate instruction and data interfaces using `MOOR_axi_if`. The interface uses single-beat AXI-style channels:

- Instruction fetch uses `ARADDR`/`ARVALID` and consumes `RDATA`/`RVALID`; `RREADY` is held high.
- Data loads use the read channel; stores use the write-address, write-data, and write-response channels.
- The core's request/ready handshake is adapted to the interface at the top level.
- The current integration configuration assumes prompt memory responses and is intended for a simple single-beat memory model.

The LSU supports naturally aligned byte, halfword, and word accesses, using byte strobes for stores and sign/zero extension for loads.


## AI-assisted development

MOOR was built in a one-night development sprint with assistance from **ChatGPT (GPT), Claude, and DeepSeek**. The project explores how AI tools can accelerate RTL design, implementation, and debugging under a tight time constraint. AI was used as a development aid, alongside RTL iteration, synthesis, and static timing analysis.


## Synthesis and timing results

MOOR was synthesized with **Yosys and the Nangate45 standard-cell library**, then evaluated with **OpenSTA**. Results below are from the supplied synthesis/timing run.

### Top-level results

| Flow | Mapped cells | Reported cell area |
| --- | ---: | ---: |
| Modular/hierarchical synthesis | 2,772 | 4,436.614 |
| Flattened synthesis | 2,457 | 4,126.192 |

In this run, flattening reduced the mapped cell count by 315 cells (about **11.4%**) and reported area by 310.422 units (about **7.0%**). The reported area is the sum of Nangate45 library cell-area values, not a floorplan or die-area estimate.

### Timing

| Metric | Result |
| --- | ---: |
| Minimum clock period reported by OpenSTA | 3.71 ns |
| Corresponding maximum frequency | 269.61 MHz |

The frequency is calculated from the reported minimum period and reflects the constraints and timing model used in this run.

### local module areas

The following values are from the modular report. They are local module areas excluding child submodules, so they do not sum to the flattened top-level area.

<p align="center">
  <img src="docs/assests/moor_area_by_module.svg" 
       alt="MOOR module areas"
       width="900">
</p>


The register file is the largest module in the modular report, followed by the shared ALU and shifter. The latch-based register file includes 480 `DLH_X1` cells for the 15 × 32-bit stored registers, along with write-data sampling and read/write-selection logic.

For meaningful comparisons, use the same library, tool versions, timing constraints, optimization options, and parameter overrides. The reported run used Yosys 0.65+57 and OpenSTA 3.1.0; the RTL defaults include `PC_BITS=12`, `USE_LATCH=1`, and `SERIAL_SHIFTER=0`.

## License

MOOR is licensed under the **CERN Open Hardware Licence Version 2 – Strongly Reciprocal (CERN-OHL-S-2.0)**.

You are free to use, modify, and manufacture hardware based on this project,
provided you comply with the terms of the CERN-OHL-S v2.

See the [LICENSE](LICENSE) file for details.
