# P08 — I2C Master & Slave

I²C is SPI's opposite number: two wires shared by every device on the bus
(`sclk` and `sda`), open-drain so any device can pull the line low and
release it high, and addressing instead of chip-selects. Here a master
talks to one slave at address `0x28`, writing and reading single bytes,
and the slave latches whatever the master writes into a small register it
can hand back on a read.

I built this straight after SPI on purpose: same job — move a byte
between two chips — with the opposite constraints. Where SPI added wires
to gain simplicity, I²C removes wires and pays with protocol state. The
two bugs I hit below are both that price showing up.

---

## Interface

| Signal | Direction | Description |
|--------|-----------|-------------|
| `clk`, `reset` | in | system clock, async reset |
| `sda` | inout | serial data, open-drain |
| `sclk` | out | serial clock |
| `master_addr[6:0]` | in | address the master targets |
| `rw` | in | 0 = write, 1 = read |
| `data_in[7:0]` | in | byte the master sends |
| `start` | in | pulse to begin a transaction |
| `master_rdata[7:0]` | out | byte the master read back |
| `slave_addr[6:0]` | in | address the slave answers to |
| `slave_data_valid` | out | pulses when the slave latched a written byte |

---

## How It Works

A transaction is a fixed frame: `START` (a falling `sda` while `sclk` is
high), the 7-bit address plus the `R/W` bit, one ACK clock from the slave,
then — for a write — the data byte and its ACK, or — for a read — eight
bits driven by the slave and an ACK the master sends back. `STOP` (a
rising `sda` while `sclk` is high) releases the bus. The slave compares
every address byte against its own `slave_addr` and stays silent on a
mismatch.

```text
START  addr[6:0] + W   ACK   data[7:0]   ACK   STOP
  \      8 clocks     / 1   8 clocks    / 1     /
   sda falls while    slave pulls      slave    sda rises while
   sclk is high       sda low          ACKs     sclk is high
```

Open-drain changes the physical picture: nobody drives a logic 1 — every
device either pulls the wire low or releases it, and a pull-up resistor
provides the high. Contention is impossible by construction, and one
device can hold `sda` low (the ACK) while the master is still clocking.

### Two bugs the wire taught me

1. **The master emitted `START` on the wrong `sclk` edge.** `START` and
   `STOP` are defined as `sda` edges *while `sclk` is high*; my first
   version toggled `sda` on the same edge that moved `sclk`, so the
   condition never appeared cleanly on the bus — the slave never saw a
   frame begin. The fix was a small state machine that holds `sclk` high
   for the dedicated `START`/`STOP` states and only moves `sda` inside
   them.
2. **The slave counted the `START` edge as a data bit.** The edge detector
   feeding the slave's bit counter fired on the same transition that
   begins the frame, so the address arrived shifted by one bit and the
   slave never recognised itself. Gating the counter with an
   in-transaction flag fixed it — the first *real* bit is bit 6 of the
   address, not a phantom bit 7.

Both were invisible in the text log — the waveform showed each in one
glance, which is the strongest argument I have for dumping VCDs even when
the printed result looks right.

---

## Test Cases Covered

One write followed by one read, the two things I²C exists for:

| Test | Scenario | What it proves |
|------|----------|----------------|
| T1 | write `0xA5` to `0x28` | slave latches the byte — `data_valid` pulses and the log prints `slave received = a5` |
| T2 | read from `0x28` | master receives the slave's byte — the log prints `master read = c3` |

The `$monitor` line also catches `master_rdata` filling in bit by bit
during the read (`0x80 → 0xC0 → 0xC2 → 0xC3`), which is the easiest way
to see the slave really shifted its register out rather than a value
appearing at the end.

---

## Simulation Output

![I2C Simulation Output](simulation_output.png)

---

## Waveform

The whole testbench run, seen from inside the master and inside the
slave.

Master — `sda` carries both transactions, `rw` flips for the read,
`slave_address` assembles `0x50` then `0x51`, and `master_rdata` fills
in bit by bit (`80 → c0 → c2 → c3`):

![I2C master waveform](waveform_master.png)

Slave — `start_cond` / `stop_cond` mark the frame edges, `data_reg`
shifts the written byte in (`80 → a0 → a4 → a5`), and `data_valid`
pulses when it lands in `data_out`:

![I2C slave waveform](waveform_slave.png)

---

## Files

| File | Description |
|------|-------------|
| `i2c_master.v` | master RTL |
| `i2c_slave.v` | slave RTL |
| `tb_i2c.v` | testbench — one write and one read |
| `simulation_output.png` | console output image |
| `waveform_master.png` | master-side waveform image |
| `waveform_slave.png` | slave-side waveform image |

---

## Tools Used

- Icarus Verilog — simulation (`iverilog` / `vvp`)
- Surfer — waveform viewer (VCD dump; image rendered from it)

---

## What I Learned

- **I²C's control signals live in the *other* wire's idle time.** `START`
  and `STOP` are not clocked events — they are `sda` edges while `sclk` is
  high, which means the controller has to schedule bus changes around the
  clock, not along with it.
- **Open-drain is a physical-layer decision that simplifies everything
  above it.** Nobody can short anybody by driving the wrong level; the ACK
  works because the slave holds the line while the master keeps clocking.
- **Address decode is a one-bit-counter bug away from silent failure.**
  The off-by-one sampling bug looked, in the log, exactly like "the slave
  is broken". The waveform showed the real story in one glance — the state
  machine never left its address state.
- **Watch the latch pulse, not just the final value.** `data_valid`
  tells me the byte landed mid-frame; a correct-looking output register
  alone could just be a stale value from an earlier transaction.
