# P07 — SPI Master & Slave

Two SPI devices wired to each other: a master that generates the serial
clock and drives `MOSI`, and a slave that answers on `MISO`. Both sides
hold a full byte and exchange it one bit per clock, MSB first — the master
receives the slave's byte in exactly the eight cycles it sends its own,
which is the whole reason SPI is called full-duplex.

This is the first Intermediate project and the first time my design has to
agree with *another device* instead of a testbench that does whatever the
RTL needs. The mode is 0 — `CPOL = 0, CPHA = 0` — so `sclk` idles low,
data is launched on the falling edge and sampled on the rising edge, and
`CS` frames the transaction: low for the eight clocks of one byte, high
again between frames.

---

## Interface

| Signal | Direction | Description |
|--------|-----------|-------------|
| `clk`, `reset` | in | system clock, async reset |
| `load` | in | pulse to start one byte exchange |
| `master_tx_data[7:0]` | in | byte the master sends |
| `slave_tx_data[7:0]` | in | byte the slave sends |
| `CS` | out | chip select, active low |
| `sclk` | out | serial clock, 8 pulses per frame |
| `MOSI` | out | master-out-slave-in |
| `MISO` | out | slave-out-master-in |
| `master_rx_data[7:0]` | out | byte the master received |
| `slave_rx_data[7:0]` | out | byte the slave received |

---

## How It Works

The master counts `clk` down by four to produce `sclk`, asserts `CS` for
exactly eight serial clocks, and shifts its `tx_data` out on `MOSI` one bit
per falling edge. The slave watches `CS`: while it is low the slave shifts
its own byte out on `MISO` and samples `MOSI` on each rising `sclk` edge.
Both sides use the same discipline — sample on the edge the other side is
not driving on — which is what keeps the bits aligned without any
handshake beyond the clock itself.

```text
CS     ‾‾‾\_____________________________________________________/‾‾‾
sclk        _¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_              8 pulses
MOSI        -<b7>-<b6>-<b5>-<b4>-<b3>-<b2>-<b1>-<b0>          master →
MISO        -<b7>-<b6>-<b5>-<b4>-<b3>-<b2>-<b1>-<b0>          slave  →
```

The full-duplex claim is visible in this timing: both bytes are on the
wire during the *same* eight clocks. There is no second frame for the
reply — SPI buys its speed with wires, one dedicated line per direction.

---

## Test Cases Covered

One full exchange, watched with `$monitor` so the log itself is the check:

| Test | Exchange | What it proves |
|------|----------|----------------|
| T1 | master `0xA5` ↔ slave `0x3C` | both sides end up with the other's byte on the same eight clocks |
| CS | before/after the frame | `CS` is low mid-frame and returns high after — framing, not free-running |

The log shows `master_rx_data` and `slave_rx_data` staying `xx` until the
last clock of the frame, then updating together — the bytes really do
cross in flight.

---

## Simulation Output

![SPI Simulation Output](simulation_output.png)

---

## Waveform

One frame: `CS` drops, eight `sclk` pulses, both bytes cross in flight,
and `master_rx` / `slave_rx` update at the end of the frame with the
*other* side's transmit byte:

![SPI Waveform](waveform.png)

---

## Files

| File | Description |
|------|-------------|
| `spi_master_slave.v` | master + slave RTL |
| `tb_spi.v` | testbench — one byte exchange, `$monitor` log |
| `simulation_output.png` | console output image |
| `waveform.png` | waveform image (from the VCD dump) |

---

## Tools Used

- Icarus Verilog — simulation (`iverilog` / `vvp`)
- Surfer — waveform viewer (VCD dump; image rendered from it)

---

## What I Learned

- **Full-duplex is a sampling-edge agreement, not a feature list.** The
  master and slave exchange bytes in the same eight clocks only because
  both launch on the falling edge and sample on the rising one. Change the
  mode (`CPHA`) on one side only, and every bit shifts by one.
- **`CS` does framing work that the clock cannot.** Without `CS` between
  frames, the slave cannot tell one byte from the next — the bit counter
  would free-run. The testbench log therefore prints `CS` alongside the
  data, not just the data.
- **A `$monitor` on the right four signals shows the whole protocol.**
  `CS`, `sclk`, `MOSI`, `MISO` — the entire exchange fits in five log
  lines, which is usually all I need before reaching for the waveform.
