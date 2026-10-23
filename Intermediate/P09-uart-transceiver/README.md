# P09 — UART Transceiver

UART is the protocol with no clock line at all: one wire in each
direction, two sides that agree in advance on a baud rate and frame each
byte with a start bit and a stop bit. This project is a full transceiver —
baud generator, transmitter, and receiver — wired into a loopback so the
byte that leaves the TX pin comes back in on the RX pin.

After SPI and I²C, this was the point where I stopped thinking about
"wires per protocol" and started thinking about *timing assumptions*.
SPI hands you a clock; I²C puts the clock on the bus; UART makes both
sides pretend they already know each other's speed. Everything that makes
UART interesting follows from that one absence.

---

## Interface

| Signal | Direction | Description |
|--------|-----------|-------------|
| `clk`, `reset` | in | system clock, async reset |
| `wt_enable` | in | pulse to transmit the byte on `data_in` |
| `data_in[7:0]` | in | byte to send |
| `tx` | out | serial output (idle high) |
| `rx` | in | serial input |
| `busy` | out | transmitter is shifting a frame |
| `rdy` | out | receiver has a complete byte |
| `rdy_clr` | in | acknowledge the received byte |
| `data_out[7:0]` | out | byte the receiver decoded |

---

## How It Works

Frame format is 8N1: one start bit (low), eight data bits LSB first, one
stop bit (high).

```text
tx   ___/b0\b1/b2\b3/b4\b5/b6\b7/‾‾‾‾‾‾‾‾‾‾‾‾
     idle  start    data (LSB first)    stop    idle
```

The transmitter is a small FSM: idle → start → 8 data → stop → idle. On
`wt_enable` it drops `tx` low for one bit period, shifts `data_in` out LSB
first, returns `tx` high for the stop bit, and raises `busy` for the whole
frame. The receiver counts sixteen `clk` ticks per bit; when the start bit
is seen it waits eight ticks — the middle of the start bit — verifies the
line is still low, then samples every sixteen ticks, the centre of each
data bit, and raises `rdy` once the stop bit is in.

Sampling at the bit *centre* is the whole receiver design. A sender's
baud generator is never exactly yours; drift accumulates across a frame,
and the last bit is where it hurts. Taking each sample as far from both
edges as possible buys the maximum tolerance for that drift — 16×
oversampling is just sixteen chances to land in the middle.

### What went wrong the first time

The first version of the TX FSM I wrote latched its outputs instead of
being a real registered FSM — it looked fine in inspection and synthesised
as storage exactly where I wanted none. The RX was worse: its bit counter
compared against a constant it could never reach, so the receiver sat in
"waiting for start" forever and the loopback test hung until the watchdog
fired. Rewriting both as explicit next-state machines with one shared
bit-timing constant fixed the design; the same test vectors then passed
unchanged.

---

## Test Cases Covered

Three loopback bytes through the full TX → wire → RX path, three checks
per byte — 12 checks:

| Test | Byte | Pattern |
|------|------|---------|
| T1 | `0x55` | alternating `01010101` — every bit boundary toggles |
| T2 | `0xAA` | alternating `10101010` — the complement |
| T3 | `0x00` | all zeros — longest low run, start/stop still frame it |

Each test checks that `busy` releases after the frame, `rdy` asserts, and
the received byte equals the sent one. `0x55`/`0xAA` maximise transitions
for sampling; `0x00` is the quietest possible frame — together they cover
start-bit detection, mid-bit sampling, and stop-bit framing.

---

## Simulation Output

![UART Simulation Output](simulation_output.png)

---

## Waveform

The first loopback byte, `0x55`: `wt_enable` starts the frame, `busy`
holds high for ten bit periods, the serial line carries start + 8 data
bits + stop, and `rdy` pulses when the receiver has decoded the byte —
`data_out` updates to `0x55` at that moment:

![UART Waveform](waveform.png)

---

## Files

| File | Description |
|------|-------------|
| `uart_top.v` | baud generator + TX + RX RTL |
| `tb_uart.v` | self-checking loopback testbench — 12 checks |
| `simulation_output.txt` | console log |
| `simulation_output.png` | console output image |
| `waveform.png` | waveform image (from the VCD dump) |

---

## Tools Used

- Icarus Verilog — simulation (`iverilog` / `vvp`)
- Surfer — waveform viewer (VCD dump; image rendered from it)

---

## What I Learned

- **A protocol with no clock line is an agreement, not a circuit.** SPI
  hands you timing; UART makes both sides *assume* the same timing and
  everything works only within that tolerance. Oversampling at the bit
  centre is how a receiver keeps the assumption honest.
- **Registered FSMs, not latched outputs.** The latch version "worked" in
  casual inspection and failed every structural question — synthesis would
  infer storage exactly where I wanted none. Explicit next-state logic
  removed the ambiguity.
- **`busy`/`rdy` handshakes are the interface contract.** The testbench
  waits on `busy` falling and `rdy` rising; that is also exactly how a
  processor's UART driver would use the block. Designing the status flags
  *for the consumer* made the testbench almost trivial.
- **A watchdog in the testbench catches hangs, not just wrong values.**
  The dead RX counter didn't fail a check — it never reached one. Timeouts
  are how a self-checking testbench reports silence as a failure.
