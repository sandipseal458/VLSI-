# VLSI Projects

My digital design and verification work, built progressively from basic
combinational gates toward complete serial protocol controllers. I am a
2nd-year ECE student at NIT Durgapur working toward semiconductor
engineering roles, and this repository is where each project lives with its
RTL, its testbench and its simulation evidence.

Every project here is synthesizable Verilog (or SystemVerilog), simulated
and documented — RTL, self-checking testbench, and the console/waveform
output that proves it works.

---

## About Me

- **Name:** Sandip Seal
- **College:** NIT Durgapur
- **Branch:** Electronics & Communication Engineering
- **Year:** 2nd Year

---

## Repository Structure

Projects are organised by difficulty level:

```
VLSI-/
├── Beginner/
│   ├── P01-4bit-adder/
│   ├── P02-4bit-mux-demux/
│   ├── P03-d-flip-flop-4bit-register/
│   ├── P04-4bit-up-down-counter/
│   ├── P05-fsm-sequence-detector-moore-mealy/
│   └── P06-4bit-arithmetic-logic-unit/
├── Intermediate/
│   ├── README.md          (one write-up for all four projects)
│   ├── P07-spi-master-slave/
│   ├── P08-i2c-master-slave/
│   ├── P09-uart-transceiver/
│   └── P10-register-file/
└── Advanced/
```

- **Beginner** — single-purpose blocks: arithmetic, mux/demux, registers,
  counters, FSMs, an ALU.
- **Intermediate** — real serial protocols and datapath components with
  self-checking testbenches: SPI, I²C, UART, register file.
- **Advanced** — processor-level work; projects land here as I build them.

---

## Project List

| # | Project | Level | Skill | Status |
|---|---------|-------|-------|--------|
| P01 | [4-bit-Adder](./Beginner/P01-4bit-adder/) | Beginner | Verilog Basics | ✅ Complete |
| P02 | [4-bit-Mux-Demux](./Beginner/P02-4bit-mux-demux/) | Beginner | Verilog Basics | ✅ Complete |
| P03 | [D-flip-flop-4-bit-Register](./Beginner/P03-d-flip-flop-4bit-register/) | Beginner | Sequential Logic | ✅ Complete |
| P04 | [4-bit-Up-Down-Counter](./Beginner/P04-4bit-up-down-counter/) | Beginner | Sequential Logic | ✅ Complete |
| P05 | [FSM Sequence Detector](./Beginner/P05-fsm-sequence-detector-moore-mealy/) | Beginner | Finite State Machines (FSM) | ✅ Complete |
| P06 | [4-bit Arithmetic Logic Unit (ALU)](./Beginner/P06-4bit-arithmetic-logic-unit/) | Beginner | Combinational Logic / ALU Design | ✅ Complete |
| P07 | [SPI Master & Slave](./Intermediate/README.md#p07--spi-master--slave) | Intermediate | Serial Protocol (SPI), Full-Duplex | ✅ Complete |
| P08 | [I2C Master & Slave](./Intermediate/README.md#p08--i2c-master--slave) | Intermediate | Serial Protocol (I²C), Open-Drain Bus | ✅ Complete |
| P09 | [UART Transceiver](./Intermediate/README.md#p09--uart-transceiver) | Intermediate | Serial Protocol (UART), Baud Timing | ✅ Complete |
| P10 | [32 × 32 Register File](./Intermediate/README.md#p10--32--32-register-file) | Intermediate | Datapath / Processor Building Block | ✅ Complete |

*More projects will be added as I keep learning.*

---

## Tools Used

- EDA Playground — online Verilog simulator
- Cadence Xcelium — simulation engine
- EPWave — waveform viewer
- Icarus Verilog (`iverilog` / `vvp`) — local simulation, used for the
  Intermediate projects' self-checking testbenches
- GTKWave — local VCD waveform viewer

---

## Contact

- **GitHub:** [sandipseal458](https://github.com/sandipseal458)
- **Email:** sandipseal458@gmail.com
- **LinkedIn:** [Sandip Seal](https://www.linkedin.com/in/sandip-seal/)
