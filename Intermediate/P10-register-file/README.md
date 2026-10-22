# P10 — 32 × 32-Bit Register File (1W / 2R)

The register file is the quiet heart of any processor: it holds the
architectural registers and feeds the ALU. This one is the classic shape —
32 words of 32 bits, one synchronous write port, two asynchronous read
ports — which is exactly the arrangement a RISC-V core needs to read `rs1`
and `rs2` in the same cycle that it writes back to `rd`.

It looks like the simplest block in the repository, and that is precisely
why it is a good interview subject: the questions are all about semantics
(read-before-write or write-before-read?), reset strategy, and what the
hardware actually looks like when you synthesise it.

---

## Interface

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `clk` | in | 1 | Write clock |
| `reset` | in | 1 | Synchronous, active-high, clears all 32 words |
| `wt_enable` | in | 1 | Write strobe — no write without it |
| `w_add` | in | 5 | Write address (0–31) |
| `w_data` | in | 32 | Write data |
| `r_add1` | in | 5 | Read port 1 address |
| `r_add2` | in | 5 | Read port 2 address |
| `r_data1` | out | 32 | Read port 1 data (combinational) |
| `r_data2` | out | 32 | Read port 2 address (combinational) |

---

## How It Works

```verilog
always @(posedge clk)
begin
    if (reset) begin
        for (i = 0; i < 32; i = i + 1)
            memory[i] <= 0;
    end else if (wt_enable) begin
        memory[w_add] <= w_data;
    end
end

assign r_data1 = memory[r_add1];
assign r_data2 = memory[r_add2];
```

Three decisions worth being able to defend:

**Writes are synchronous, reads are combinational.** The write happens on
`posedge clk` gated by `wt_enable`; the reads are plain `assign` statements
so the data appears as soon as the address is valid. That makes the block
*write-first* (read-after-write in the same cycle returns the new value),
because the flop updates on the edge and the read path is transparent
afterwards. A pipeline with a read-before-write requirement would need the
opposite choice — there is no universally right answer, only the one that
matches the surrounding logic, and stating which one you picked is what
matters.

**Reset is synchronous and clears everything.** Synchronous reset means no
asynchronous recovery path in timing analysis, which is the industry default
for FPGA and standard-cell designs. Clearing all 32 words costs one loop of
32 flops' reset logic instead of relying on power-on state.

**`wt_enable` is a real gate, not decoration.** Without a write strobe, a
mere change of `w_add` would corrupt a register on every clock edge. The
testbench deliberately attempts a write with `wt_enable` low to prove the
stored value does not move.

---

## Verification — `tb_register.v`

The testbench keeps a golden model of all 32 words in parallel with the
DUT, applies every write on a real clock edge, and compares **both** read
ports against the model:

| Test | Scenario | Checks |
|------|----------|--------|
| T1 | Release synchronous reset | all 32 words read back as `0` |
| T2 | Write a pattern to all 32 words | every word reads back correctly on port 1 |
| T3 | Port 1 and port 2 on different addresses | both return their own word in the same cycle |
| T4 | Write attempt with `wt_enable = 0` | stored value unchanged |
| T5 | Both ports on the same address | identical values |
| T6 | Write `0xFEED_FACE`, read immediately | new value visible (write-first semantics) |

```text
 RESULT: PASSED  (6 checks)
```

**A note on the previous testbench.** The original `tb_register` ran its
write loop with no delay between iterations, so all 32 writes happened in
one simulation timestep, only the last one landed on a clock edge, and the
read loop printed `xxxxxxxx` for every word. It *looked* like output but it
proved nothing. The rewrite clocks every write, feeds a scoreboard, and
prints `PASS`/`FAIL` per check — the difference between a testbench that
demonstrates a design and one that just produces console noise.

Simulation log: [`simulation_output.txt`](simulation_output.txt)

### Running it

```bash
iverilog -g2005 -o sim.out *.v
vvp sim.out          # writes tb_register.vcd as well
```

---

## Files

| File | Description |
|------|-------------|
| `register_file.v` | `register` RTL — 32 × 32, 1 write, 2 async reads |
| `tb_register.v` | Self-checking testbench with a golden model (6 checks) |
| `simulation_output.txt` | Console log from the simulation run |

---

## What I Would Improve

- **A read-first variant.** Duplicating the block with the opposite
  semantics would make the trade-off concrete, and the difference is two
  lines of RTL.
- **Synchronous reads for timing.** Combinational reads through a 32-deep
  mux are fine at this size, but a deep register file in a real core
  registers the read data to cut the critical path — the classic
  "read data latch" stage.
- **Synthesis check.** I would run this through Yosys next and look at
  whether it maps to distributed RAM or to discrete flops, because that
  tells you the cost of the two read ports.

---

## Interview Notes

- *Why two read ports?* A processor reads both operands of an instruction
  in one cycle; one port would force a stall or a second cycle.
- *What happens on a read and write to the same address?* With this
  combinational-read implementation, the reader sees the new value
  (write-first). It is a deliberate choice, not an accident.
- *Synchronous or asynchronous reset — which and why?* Synchronous: no
  async recovery timing, cleaner timing closure, and it is the norm for
  synthesised FPGA/ASIC logic.
- *What would you check first in a register file bug?* The write strobe
  and the read timing relationship — most register-file bugs are
  "someone forgot `wt_enable`" or "the pipeline expected read-before-write".

---

## Tools

- Icarus Verilog (`iverilog`/`vvp`) for simulation
- GTKWave / EPWave for the VCD waveform
