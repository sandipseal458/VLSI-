# P10 — 32 × 32 Register File

The last Intermediate project is not a protocol — it is the storage a
processor reads and writes: thirty-two 32-bit registers, one synchronous
write port, two asynchronous read ports. It is the `regs[]` array at the
heart of every RISC-V core, sized down just enough to keep the testbench
readable while the structure stays real.

This is the first project in the repository whose consumer is a *CPU*
rather than another chip on a wire. Everything before it in Intermediate
moved bytes between devices; this one holds the operands that the ALU
from P06 will one day consume — so the interface choices here are really
datapath choices.

---

## Interface

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `clk`, `reset` | in | 1 | system clock, async reset |
| `wt_enable` | in | 1 | write strobe |
| `w_add` | in | 5 | write address |
| `w_data` | in | 32 | write data |
| `r_add1`, `r_add2` | in | 5 | read addresses |
| `r_data1`, `r_data2` | out | 32 | read data (async) |

---

## How It Works

Writes are clocked: on a rising edge, if `wt_enable` is high, `w_data` is
stored at register `w_add`. Reads are combinational: `r_data1`
continuously returns the contents of `r_add1`, and likewise for port 2 —
so a value written on one edge is visible to both read ports immediately
after, the same "write first" behaviour a CPU datapath expects.

```text
                     ┌────────────────────────────┐
  w_add[4:0] ──────► │                            │
  w_data[31:0] ────► │   x[0..31]                 │ ───► r_data1[31:0]
  wt_enable ───────► │   one write port           │      (r_add1 selects)
  clk / reset ─────► │   two async read ports     │ ───► r_data2[31:0]
                     └────────────────────────────┘      (r_add2 selects)
```

One `always` block with a `for` loop clears all registers on reset and
writes the selected one on a clock edge; the two read ports are
continuous assignments. The design decision worth naming: reads are
*asynchronous* — deliberately, to match a single-cycle CPU's
register-read stage — so there is no read clock and no read latency. The
register index *is* the output. The trade-off I am accepting is that this
read path now sits in the design's critical timing loop.

---

## Test Cases Covered

Six test phases with a golden model in the testbench — 6 checks covering
every structural claim:

| Test | Scenario | What it proves |
|------|----------|----------------|
| T1 | reset clears all 32 words | no stale state after reset |
| T2 | write and read back all 32 words | every address decodes; golden-model compare |
| T3 | dual-port read of two different words | both ports are independent |
| T4 | write attempt with `wt_enable` low | writes are strobed, not free-running |
| T5 | consecutive write/read of different words | back-to-back transactions, no holdover |
| T6 | write `0xFEED_FACE`, read immediately | write-first visibility on the same cycle |

T2 is one loop against a software array the testbench keeps in parallel:
each register gets a pattern derived from its own address, and every read
is compared against the model. Any addressing bug shows up as a mismatch
instead of a hand-checked table — one loop covers all thirty-two words.

---

## Simulation Output

![Register File Simulation Output](simulation_output.png)

---

## Waveform

The reset pulse, then thirty-two back-to-back writes — `w_add` counts up,
`w_data` carries the golden-model pattern — followed by the read-back
checks at the end of the run:

![Register File Waveform](waveform.png)

---

## Files

| File | Description |
|------|-------------|
| `register_file.v` | register file RTL |
| `tb_register.v` | self-checking testbench — 6 checks |
| `simulation_output.txt` | console log |
| `simulation_output.png` | console output image |
| `waveform.png` | waveform image (from the VCD dump) |

---

## Tools Used

- Icarus Verilog — simulation (`iverilog` / `vvp`)
- GTKWave — waveform viewer (VCD dump; image rendered from it)

---

## What I Learned

- **Async reads are a real design choice, not laziness.** Making the read
  ports combinational is what lets a single-cycle processor fetch two
  operands in the execute stage; the cost is that the read path is now in
  the critical timing loop, and that trade-off is visible from the day you
  draw the block.
- **A golden model in the testbench pays for itself.** Deriving expected
  data from the address and looping over all 32 words turned a
  thirty-two-row hand-checked table into one comparison — and any
  addressing bug reports itself.
- **`wt_enable` needs its own negative test.** T4 writes with the strobe
  low and proves nothing changed; designs that forget the enable decode
  fail this in one line.
- **This array is where "processor" starts.** The ALU from P06 and this
  register file are two halves of the same datapath — the next step is a
  fetch-decode-execute loop that drives both.
