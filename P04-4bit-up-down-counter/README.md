# P04 - 4-Bit Up/Down Counter

A sequential logic circuit that counts upward or downward on every
rising clock edge. The design uses a synchronous active-high reset,
an enable signal, and a direction control signal to decide whether
the 4-bit output should increment, decrement, or hold its current value.

---

## What This Project Contains

This project implements a 4-bit binary up/down counter in Verilog.
A counter is one of the most common sequential circuits in digital
systems. It is used in timers, frequency dividers, address generation,
event counting, state machines, and many other hardware blocks.

The counter stores its current value in a 4-bit register named `out`.
On every rising edge of `clk`, the circuit first checks `reset`.
If reset is high, the output becomes `0000`. If reset is low and
`ebl` is high, the counter either increments or decrements depending
on `up_down`. If `ebl` is low, the counter keeps its previous value.

---

## How It Works

The design is written using `always @(posedge clk)`, which means all
state changes happen only on the rising edge of the clock. This makes
the circuit synchronous and predictable for simulation and synthesis.

```
Behaviour:
On posedge clk:
  if reset = 1       -> out = 0000      (clear counter)
  else if ebl = 1:
       if up_down=1 -> out = out + 1   (count up)
       if up_down=0 -> out = out - 1   (count down)
  else              -> out holds value (no change)
```

Because `out` is only 4 bits wide, the counter naturally wraps around.
When counting up from `1111`, the next value becomes `0000`.
When counting down from `0000`, the next value becomes `1111`.
This is normal binary counter overflow and underflow behavior.

---

## Input and Output Signals

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `clk` | Input | 1 bit | Clock signal |
| `reset` | Input | 1 bit | Synchronous active-high reset |
| `ebl` | Input | 1 bit | Enable signal for counting |
| `up_down` | Input | 1 bit | Direction control: `1` counts up, `0` counts down |
| `out` | Output | 4 bits | Current counter value |

---

## Block Diagram

```
              +-------------------------+
      clk --->|                         |
    reset --->|                         |
      ebl --->|   4-Bit Up/Down Counter |---> out[3:0]
  up_down --->|                         |
              |                         |
              +-------------------------+
```

---

## Counting Example

### Count Up

```
reset = 0, ebl = 1, up_down = 1

0000 -> 0001 -> 0010 -> 0011 -> 0100 -> ...
```

### Count Down

```
reset = 0, ebl = 1, up_down = 0

0000 -> 1111 -> 1110 -> 1101 -> 1100 -> ...
```

### Hold State

```
reset = 0, ebl = 0

out keeps its previous value
```

---

## Simulation Output

![Simulation Output](simulation_output.png)

---

## EPWave Waveform

![EPWave Waveform](epwave_waveform.png)

---

## Test Cases

The testbench verifies the main operating modes of the counter.

First, reset is asserted at the beginning of simulation so the counter
starts from a known value of `0000`.

Second, reset is released while `ebl = 1` and `up_down = 1`, so the
counter begins counting upward on each positive clock edge.

Third, `ebl` is set to `0` to confirm that the output holds its current
value even while the clock continues running.

Fourth, `ebl` is set back to `1`, allowing the counter to resume
counting from the held value.

Fifth, reset is asserted during operation to verify that synchronous
reset clears the output back to `0000` on the next rising clock edge.

Finally, `up_down` is changed to `0`, so the counter switches direction
and begins counting downward.

---

## Files

| File | Description |
|------|-------------|
| `four_bit_up_down_counter.v` | RTL design - 4-bit up/down counter |
| `test_four_bit_up_down_counter.v` | Testbench for the counter |
| `simulation_output.png` | Console simulation output |
| `epwave_waveform.png` | EPWave waveform screenshot |

---

## Tools Used

- EDA Playground - online Verilog/SystemVerilog simulator
- Cadence Xcelium - simulation engine
- EPWave - waveform viewer

---

## What I Learned

This project shows how sequential circuits can store and update state
over time. The `always @(posedge clk)` block makes the counter update
only on clock edges, while non-blocking assignments (`<=`) correctly
model register behavior in Verilog.

The enable signal is important because it allows the circuit to pause
without losing its stored value. The `up_down` control shows how one
piece of RTL can describe two different counting directions. The project
also makes overflow and underflow visible: a 4-bit counter wraps from
`1111` to `0000` when counting up, and from `0000` to `1111` when
counting down.
