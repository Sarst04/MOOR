# MOOR — Minimal RV32E RISC-V Core

MOOR is an area-focused, multi-cycle RISC-V processor written in SystemVerilog. The goal is simple: **build a small practical RV32E-class core with machine-mode interrupts, while keeping the hardware as small as reasonably possible.**

> **Built in one night, with AI assistance.** MOOR was developed in a single-night sprint with help from ChatGPT, Claude, and DeepSeek. AI accelerated exploration, implementation, and debugging; the RTL still needs careful architectural verification.

MOOR is an experimental design and a work in progress. It aims to grow toward a complete, well-tested RV32E implementation; this repository should not yet be treated as a claim of full RISC-V ISA or privileged-spec compliance.

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

## Memory interface notes

MOOR exposes separate instruction and data interfaces through `MOOR_axi_if`. The current adapter is intended for a simple, single-beat memory model and assumes responses are available without additional wait states. It does **not** yet implement general AXI4 transaction sequencing for arbitrary `ARREADY`, `AWREADY`, and `WREADY` stalls or delayed responses. Treat the interface as an integration starting point rather than a fully general AXI4 master.

The load/store unit assumes naturally aligned halfword and word accesses. Misaligned-access exceptions and a complete memory-ordering implementation are not currently part of the documented feature set.

## AI-assisted development

MOOR was created in a one-night development sprint with assistance from **ChatGPT (GPT), Claude, and DeepSeek**. The project is also an experiment in using AI tools to accelerate RTL development. Generated suggestions are not assumed to be correct: simulation, code review, synthesis, and architectural testing remain necessary.
