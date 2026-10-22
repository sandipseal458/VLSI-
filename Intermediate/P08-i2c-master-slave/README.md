# P08 — I2C Master and Slave with a Self-Checking Testbench

This project implements one complete I²C link: a master that starts
transactions, addresses a slave, writes a byte or reads a byte, and a slave
that decodes the bus, ACKs its own address, and hands the received byte to
the outside world. The interesting part of this project was not writing the
FSMs — it was debugging two timing bugs that only show up when you actually
look at the bus edge by edge, and then writing a testbench that would have
caught them.

---

## Interface

### Master

| Signal | Direction | Description |
|--------|-----------|-------------|
| `clk`, `reset` | in | System clock, async active-high reset |
| `start` | in | Request a transaction (held until the START condition appears) |
| `rw` | in | `0` = write, `1` = read |
| `slave_addr[6:0]` | in | 7-bit address to talk to |
| `data_in[7:0]` | in | Byte to write |
| `data_out[7:0]` | out | Byte captured from a read |
| `sda` | inout | Open-drain data line (needs a pull-up) |
| `sclk` | out | Serial clock |

### Slave

| Signal | Direction | Description |
|--------|-----------|-------------|
| `clk`, `reset` | in | Same system clock as the master |
| `slave_addr[6:0]` | in | The address this slave answers to (`0x28` in the testbench) |
| `data_in[7:0]` | in | Byte to return when the master reads |
| `data_out[7:0]` | out | Byte received from a write |
| `data_valid` | out | One-cycle pulse when a byte has been latched |
| `sda` | inout | Open-drain data line |
| `scl` | in | Serial clock from the master |

Both sides drive `sda` the way I²C requires: driving means pulling **low**,
releasing means letting the pull-up take it high. In simulation that pull-up
is an explicit `pullup` primitive in the testbench; on a board it is a
physical resistor.

---

## How the Protocol Maps onto the RTL

The master walks through a fixed sequence of states:

```text
IDLE → START → SLAVE_ADD → ACK → ┬ WRITE_DATA → ACK_WAIT → STOP → DONE
                                  └ READ_DATA  → ACK_WAIT → STOP → DONE
```

- **START** — SDA is pulled low while SCL is high. This is the one moment
  when SDA is allowed to move while SCL is high.
- **SLAVE_ADD** — eight bits (7-bit address + R/W) go out on the falling
  edges of SCL, MSB first.
- **ACK** — the master releases SDA for one clock; an ACK is the slave
  pulling it low, a NACK is the line staying high.
- **WRITE_DATA / READ_DATA** — eight more bits. During a read the master
  releases SDA and samples it on the rising edge of SCL.
- **STOP** — SDA is held low while SCL rises, then released: SDA rising
  while SCL is high ends the transaction.

The slave runs its own small FSM (`SLAVE_ADD → ACK → WRITE_DATA/READ_DATA`)
and only ever compares the address it decoded against its own. If they do
not match it returns to idle and stays quiet for the rest of the frame,
which is exactly how a real I²C device ignores traffic meant for someone
else.

---

## Two Bugs I Found and Fixed

These are the reason this project is more than copy-paste FSM code, and
they are what I would talk about in an interview.

**Bug 1 — the START condition could land on the wrong edge (master).**
The master's `IDLE` state jumped to `START` on whatever clock cycle `start`
happened to be high. If that cycle coincided with SCL falling, SDA was
pulled low *while SCL was already low* — which is not a START condition at
all. The slave correctly ignored it, the master waited for an ACK that
never came, saw a NACK and aborted. The fix is one line: only leave `IDLE`
while SCL is high, so SDA's falling edge is always a legal START.

```verilog
next_state = (start && sclk) ? START : IDLE;
```

**Bug 2 — the slave shifted the address by one bit.**
The slave decremented its bit counter on the falling edge of SCL. The
falling edge that *ends the START phase* arrives while the slave is already
in `SLAVE_ADD`, so it was counted as a data bit before any bit had been
sampled. The decoded address came out shifted (`00101000` instead of
`0101000`), the compare failed, and every transaction was NACKed. The fix
was to arm the counter only after the first bit has actually been sampled
(`bit_armed`), so the START phase's falling edge is not mistaken for data.

Both bugs were invisible in the state diagrams I drew beforehand — they
only appeared once I dumped the bus and compared the value the slave
captured against the value the master sent, bit by bit. That is the habit
this project taught me: **assert the value on the wire, don't assume it.**

---

## Verification — `tb_i2c.v`

The testbench is written at protocol level: it drives `start`, waits for
the START condition on the bus, follows the transaction by counting SCL
edges, and compares outcomes against expected values. It never reaches
into the DUT's internals, so it survives a refactor of the RTL. The slave's
`data_valid` pulse is what feeds the scoreboard for writes.

| Test | Scenario | Checks |
|------|----------|--------|
| T1 | Write `0xA5` to address `0x28` | slave latched exactly one byte, value is `0xA5` |
| T2 | Write `0x5A` to the same address | bus reusable back-to-back |
| T3 | Read from `0x28` | master received `0xC3` |
| T4 | Write to `0x29` (wrong address) | slave ignored it — no byte latched |
| T5 | Write `0x11` then read `0x22` | two transactions in a row, both correct |
| T6 | Reset mid-session, then write `0x99` | recovery after reset |

```text
 RESULT: PASSED  (10 checks)
```

Every transaction is bounded by a timeout and the whole run has a watchdog,
so a hung FSM reports `FAIL` instead of freezing the simulator.

Simulation log: [`simulation_output.txt`](simulation_output.txt)

### Running it

```bash
iverilog -g2005 -o sim.out *.v
vvp sim.out          # writes tb_i2c.vcd as well
```

---

## Files

| File | Description |
|------|-------------|
| `i2c_master.v` | Master FSM (START/STOP generation, address, R/W, ACK/NACK) |
| `i2c_slave.v` | Slave FSM (address decode, ACK, write latch, read drive) |
| `tb_i2c.v` | Self-checking testbench, 10 checks + watchdog |
| `simulation_output.txt` | Console log from the simulation run |

---

## What I Would Improve

- **Clock stretching and multi-byte transfers.** Right now every
  transaction moves one byte and stops. A real slave holds SCL low to slow
  the master down, and both sides support repeated STARTs for register
  access — that is the next feature.
- **Timing parameters.** SCL is produced by a counter in the master, so
  setup/hold around the data changes are implicit in the divider. I would
  make the high/low phases separately programmable for standard-mode
  (100 kHz) vs fast-mode (400 kHz).
- **A proper bus monitor** in the testbench that reconstructs START, every
  byte, ACK/NACK and STOP from `sda`/`scl` alone — that would let me check
  the *protocol* independently of what the master thinks it did.

---

## Interview Notes

- *How do you distinguish START from a data bit?* Only SDA transitions
  while SCL is high are START/STOP; data is sampled on the rising edge and
  must be stable there.
- *Why open-drain?* So two devices can share the line without fighting:
  anyone can pull low, nobody drives high — the pull-up wins when everyone
  releases.
- *What does an ACK look like electrically?* The receiver holds SDA low
  during the ninth clock pulse; the sender just listens.
- *Which simulation observation surprised you?* The slave's captured
  address was shifted one bit because a control edge was being counted as a
  data edge — a classic "who owns this counter, and when does it tick"
  problem.

---

## Tools

- Icarus Verilog (`iverilog`/`vvp`) for simulation
- GTKWave / EPWave for the VCD waveform
