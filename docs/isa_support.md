# ISA Support

Instruction set and CSR support for the MOOR core.

| Property | Value |
|---|---|
| Base ISA | RV32E |
| Register file | 16 × 32-bit (`x0`–`x15`), `x0` hardwired to 0 |
| Instruction length | 32-bit only |
| Privilege modes | M-mode only |
| Extensions | `Zmmul` |
| Unaligned access | Not supported |
| Illegal instruction trap | Not implemented |

---

## Base Integer Instructions

### Upper Immediate

| Instruction | Status |
|---|---|
| `LUI` | ✓ |
| `AUIPC` | ✓ |

### Control Transfer

| Instruction | Status |
|---|---|
| `JAL` | ✓ |
| `JALR` | ✓ |
| `BEQ` | ✓ |
| `BNE` | ✓ |
| `BLT` | ✓ |
| `BGE` | ✓ |
| `BLTU` | ✓ |
| `BGEU` | ✓ |

### Loads

| Instruction | Status |
|---|---|
| `LB` | ✓ |
| `LH` | ✓ |
| `LW` | ✓ |
| `LBU` | ✓ |
| `LHU` | ✓ |

### Stores

| Instruction | Status |
|---|---|
| `SB` | ✓ |
| `SH` | ✓ |
| `SW` | ✓ |

### Integer Register-Immediate

| Instruction | Status |
|---|---|
| `ADDI` | ✓ |
| `SLTI` | ✓ |
| `SLTIU` | ✓ |
| `XORI` | ✓ |
| `ORI` | ✓ |
| `ANDI` | ✓ |
| `SLLI` | ✓ |
| `SRLI` | ✓ |
| `SRAI` | ✓ |

### Integer Register-Register

| Instruction | Status |
|---|---|
| `ADD` | ✓ |
| `SUB` | ✓ |
| `SLL` | ✓ |
| `SLT` | ✓ |
| `SLTU` | ✓ |
| `XOR` | ✓ |
| `SRL` | ✓ |
| `SRA` | ✓ |
| `OR` | ✓ |
| `AND` | ✓ |
| `MUL` | ✓ (`Zmmul`) |
| `MULH` | ✓ (`Zmmul`) |
| `MULHSU` | ✓ (`Zmmul`) |
| `MULHU` | ✓ (`Zmmul`) |

---

## System Instructions

### CSR

| Instruction | Status |
|---|---|
| `CSRRW` | ✓ |
| `CSRRS` | ✓ |
| `CSRRC` | ✓ |
| `CSRRWI` | ✓ |
| `CSRRSI` | ✓ |
| `CSRRCI` | ✓ |

### Privileged

| Instruction | Status |
|---|---|
| `ECALL` | ✓ |
| `EBREAK` | ✗ |
| `MRET` | ✓ |
| `WFI` | ✓ |

---

## CSR Map

| CSR | Address | Fields | Access |
|---|---|---|---|
| `mstatus` | `0x300` | `MIE`, `MPIE`, `MPP` (hardwired `11`) | R/W |
| `mie` | `0x304` | `MSIE`, `MTIE`, `MEIE` | R/W |
| `mtvec` | `0x305` | Base, direct mode | R/W |
| `mepc` | `0x341` | Base | R/W |
| `mip` | `0x344` | `MSIP`, `MTIP`, `MEIP` | Read-only |
| `mhartid` | `0xF14` | `HART_ID` parameter | Read-only |

Unimplemented CSRs return 0 on read and ignore writes.

---

## Interrupts

### Supported Sources

| Source | `mie` bit | `mip` bit | Trigger |
|---|---|---|---|
| Software | `MSIE` (bit 3) | `MSIP` (bit 3) | `swIrq` input |
| Timer | `MTIE` (bit 7) | `MTIP` (bit 7) | `timerIrq` input |
| External | `MEIE` (bit 11) | `MEIP` (bit 11) | `extIrq` input |

Each source has a dedicated IRQ input at the SoC boundary and a corresponding enable bit in `mie`. A source is only taken when `mstatus.MIE` is set and the matching `mie` bit is enabled.

### Behavior

Interrupts are taken between instructions. The controller samples `irqTake` in `DECODE` and enters the trap in `EXECUTE`. On trap, `mstatus.MIE` is saved to `mstatus.MPIE`, `mstatus.MIE` is cleared, the current PC is written to `mepc`, and the PC is redirected to `mtvec`.

`MRET` restores `MIE` from `MPIE` and redirects to `mepc`.

`ECALL` shares the same trap path.

**Not supported:** nested interrupts, U-mode or S-mode interrupts, fast interrupts, vectored `mtvec`, `mcause`/`mtval`, interrupt prioritization when multiple sources are pending.

---

## Not Implemented

| Category | Instructions |
|---|---|
| System | `EBREAK`, `WFI` |
| Memory ordering | `FENCE`, `FENCE.I` |
| M extension | `MUL`, `MULH`, `MULHSU`, `MULHU`, `DIV`, `DIVU`, `REM`, `REMU` |
| Atomics | `LR.W`, `SC.W`, `AMO*` |
| Compressed | All `C.*` |
| Floating point | All `F`/`D` |

Undecoded instructions behave as no-ops. No illegal-instruction trap is raised.

---

## Known Deviations

- **Unaligned loads/stores**: natural alignment assumed; no alignment exception.
- **`CSRRW`/`CSRRWI` with `rd = x0`**: CSR is still read. Harmless for the implemented CSRs, which have no read side effects.
