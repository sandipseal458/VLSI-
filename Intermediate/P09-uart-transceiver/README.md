# P09 — UART Transceiver (8N1 Loopback)

A full UART in three modules: a baud-rate generator that produces the timing,
a transmitter that turns a parallel byte into a serial line, and a receiver
that turns the serial line back into a parallel byte. The top level wires
the transmitter's output straight into the receiver's input, so the design
tests itself — whatever byte I push in has to come back out.

I built this because UART is the first protocol where timing *is* the
design: there is no clock on the wire, so both ends have to agree on the
baud rate by arithmetic alone. That constraint changed how I think about
sampling, and debugging it taught me more about FSM coding style than any
tutorial did.

---

## Interface (`uart_top`)

| Signal | Direction | Description |
|--------|-----------|-------------|
| `clk` | in | System clock (100 MHz in simulation) |
| `reset` | in | Active-high, resets TX and RX |
| `wt_enable` | in | One-cycle request to transmit `data_in` |
| `data_in[7:0]` | in | Byte to send |
| `busy` | out | Transmitter occupied (from request until the stop bit ends) |
| `rdy_clr` | in | One-cycle pulse to clear `rdy` after reading |
| `rdy` | out | Receiver has a new byte on `data_out` |
| `data_out[7:0]` | out | Byte received |

---

## Design Notes

**Baud-rate generator.** Two free-running counters derive the timing from
`clk` alone:

- `tx_count` wraps every 5209 cycles → one `tx_enable` pulse per bit period
  (≈52.1 µs, i.e. a 9600-style baud rate for a 100 MHz clock).
- `rx_count` wraps every 326 cycles → sixteen `rx_enable` pulses per bit.

Sixteen samples per bit is the classic oversampling ratio: the receiver can
find the *middle* of every bit, which is the most noise-tolerant place to
sample, and it can verify the start bit instead of trusting a single edge.
The counters are 16.009:1 apart, so a frame drifts by well under one sample
over ten bits.

**Transmitter — one bit per baud tick.** The FSM (`IDLE → START → DATA_IN
→ STOP`) advances *only* on a baud tick, so bit length is defined by the
baud generator and nothing else. `wt_enable` is captured into a `pending`
flag while idle, and the frame begins on the next tick; `busy` is high from
that moment until the stop bit has been sent. The byte goes out LSB first
inside `START → DATA_IN → STOP`, with the line idle high between frames.

**Receiver — start-bit confirmation, then mid-bit sampling.** On a falling
edge of `rx` the receiver arms itself, counts eight samples (middle of the
start bit) and checks the line is still low — a glitch on the line never
becomes a frame. From there every data bit is sampled at its centre (the
16th sample tick after the previous one), and the stop bit is checked too:
if it is not high, the byte is discarded as a framing error instead of
being handed to the user with `rdy`.

```text
idle __|‾‾‾‾|_________________________|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
      start        d0 d1 d2 d3 d4 d5 d6 d7              stop
                   LSB first                     (must be high)
```

---

## Three Bugs This Project Fixed

Worth knowing because each one is a different *kind* of bug:

1. **The original transmitter was a combinational latch FSM.** `tx`,
   `data_count` and `next_state` were assigned inside `always @(*)` guarded
   by `if (enable)`. The block read `data_count` while writing it, so on a
   single baud tick the counter raced from 0 to 7 and all eight data bits
   collapsed into one. I rewrote it as a single clocked block where every
   transition happens on the tick — the kind of review comment I would
   expect in a real code review (never write state into a combinational
   block).

2. **The original receiver could never leave its START state.** The sample
   counter only incremented when `data_sample != 0`, but nothing ever made
   it non-zero, so `wait(rdy)` hung the simulation forever. On top of that
   the stop condition checked the bit counter *before* the eighth bit had
   been captured, which would have silently dropped the MSB of every byte.
   The rewrite samples bit 7, then moves on to check the stop bit.

3. **The baud counters started as X.** The generator has no reset port, so
   `tx_count` began as `X` in simulation and `tx_enable` never asserted —
   `busy` stayed high forever. Power-on values (`= 13'd0`) on the two
   counters fixed it. On FPGA this is exactly what bitstream
   initialisation does, which is why the pattern is legitimate in RTL as
   long as you are deliberate about it.

---

## Verification — `tb_uart.v`

The testbench pushes four bytes through the loopback and checks each one
against what was sent, with a bounded wait for both `busy` and `rdy` so a
dead FSM reports a failure instead of hanging the run:

| Test | Byte | Why this byte |
|------|------|---------------|
| T1 | `0x55` | alternating `0101_0101` — transitions on every bit |
| T2 | `0xAA` | the complement, catches bit-order mistakes |
| T3 | `0x00` | longest low run; the stop bit must still end the frame |
| T4 | `0xFF` | line high through the whole data field |

```text
 RESULT: PASSED  (12 checks)
```

Simulation log: [`simulation_output.txt`](simulation_output.txt)

### Running it

```bash
iverilog -g2005 -o sim.out *.v
vvp sim.out          # writes tb_uart.vcd as well
```

---

## Files

| File | Description |
|------|-------------|
| `uart_top.v` | `baud_rate_generator`, `transmitter`, `receiver`, `uart_top` |
| `tb_uart.v` | Self-checking loopback testbench (12 checks) |
| `simulation_output.txt` | Console log from the simulation run |

---

## What I Would Improve

- **A framing-error output.** The receiver already checks the stop bit; it
  just throws the byte away silently. Exposing `frame_err` would make the
  failure visible to software.
- **Parameterised baud divisor.** The numbers 5208 and 325 are hard-coded.
  Making them `parameter`s (or a clock-divide input) is a five-minute change
  that makes the block reusable at 115200.
- **Real serial pins.** `uart_top` loops back internally. The next step is
  separate `rx`/`tx` pads with a synchroniser on `rx` and a proper
  connection to two FPGA pins.

---

## Interview Notes

- *Why sample in the middle of a bit?* The sampling edge is furthest from
  the transitions, so jitter and slow edges matter least there.
- *How do the two ends agree without a clock?* Both derive the bit period
  from their own clock; that is why baud-rate tolerance (typically ±2–3 %)
  is specified as a protocol requirement.
- *What happens if the sender and receiver baud rates differ by 5 %?* The
  receiver walks across the bit as the frame progresses and eventually
  samples the wrong bit — usually detected as a framing error at the stop
  bit.
- *What did the latch bug teach you?* State belongs in a clocked block.
  A combinational block that assigns its own read variables is both a
  simulation hazard and an invitation to infer latches at synthesis.

---

## Tools

- Icarus Verilog (`iverilog`/`vvp`) for simulation
- GTKWave / EPWave for the VCD waveform
