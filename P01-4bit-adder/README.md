# P01 — 4-Bit Ripple Carry Adder in Verilog

A behavioral RTL implementation of a 4-bit binary adder
with carry output, written in Verilog and simulated on
EDA Playground using Cadence Xcelium.

---

## What It Does

This module takes two 4-bit binary numbers as inputs
(x and y and carry input) and produces a 4-bit sum and a 1-bit carry
output. When the addition result exceeds 15 — the
maximum value a 4-bit number can hold — the carry bit
is set to 1, indicating overflow into a fifth bit.

---

## How It Works

The design uses a single behavioral `always @(*)` block,
which means the output updates immediately whenever any
input changes — this is correct for combinational logic
that has no clock. The concatenation `{carryout, sum} = x + y + carryin`
is the key line: by making the left-hand side 5 bits wide
(1 carry + 4 sum), Verilog automatically captures the
fifth bit of the addition result as the carry output.
The testbench verifies five cases including the corner
cases of 0+0 (minimum) and 15+15 (maximum with carry).

---

## Simulation Output

![Simulation Output](simulation_output.png)

---

## EPWave Waveform

![EPWave Waveform](epwave_waveform.png)

---

## Files

- `four_bit_adder.v` — RTL design module
- `testbench.v` — Testbench with 4 test cases

---

## Tools Used

- EDA Playground — online Verilog simulator
- Cadence Xcelium — simulation engine
- EPWave — waveform viewer

---

## What I Learned

Before this project I did not understand why `always @(*)`
is used instead of `assign` for combinational logic. I
learned that both produce the same hardware after synthesis,
but `always @(*)` is preferred when the logic involves
multiple conditions or lines. I also learned that the `+`
operator in Verilog handles carry automatically, whereas
using `^` (XOR) would require me to manually compute carry
for each bit, which is the underlying gate-level operation
that `+` abstracts away.
