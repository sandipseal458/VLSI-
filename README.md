# VLSI Design and Verification Portfolio

A structured collection of digital design projects focused on RTL development, verification, and sequential logic design. This repository documents my learning and implementation journey in VLSI, beginning with foundational digital blocks and advancing toward serial communication protocols and professional-grade system design.

## Overview

This repository is organized into two main areas:

- [Academic](./Academic/) — a progressive learning track covering digital logic fundamentals, combinational and sequential circuits, and protocol-level design.
- [Professional](./Professional/) — applied RTL work and system-level design projects focused on real-world interfaces and verification.

The goal is to build a strong portfolio of synthesizable Verilog/SystemVerilog implementations, simulation-based validation, and reusable digital design practices.

## Repository Structure

```text
VLSI-/
├── Academic/
│   ├── Beginner/
│   ├── Intermediate/
│   └── Advanced/
├── Professional/
│   └── esim-modbus-rtu-master-slave/
├── README.md
└── .gitignore
```

## Academic Track

The Academic section follows a gradual learning path:

### Beginner
Core digital design fundamentals including:
- 4-bit adder
- Mux/demux
- D flip-flop and register design
- Up/down counter
- FSM sequence detector
- 4-bit arithmetic logic unit (ALU)

### Intermediate
More advanced digital design topics covering:
- SPI master/slave communication
- I²C master/slave communication
- UART transceiver
- Register file design

### Advanced
A forward-looking section for increasingly complex designs and processor-related digital blocks as the portfolio grows.

For detailed project listings and structure, see the [Academic README](./Academic/README.md).

## Professional Track

The current professional project is:

- [esim-modbus-rtu-master-slave](./Professional/esim-modbus-rtu-master-slave/)

This project includes:
- Modbus master and slave RTL design
- UART transmit/receive modules
- CRC-16 Modbus checksum generation
- Verification testbenches for timing, noise, system behavior, and UART loopback operation

The design is structured around a realistic communication stack and follows the practical workflow of digital hardware verification: RTL implementation, testbench creation, and simulation validation.

## Skills and Focus Areas

- RTL Design in Verilog
- Digital Logic Design
- Finite State Machines (FSM)
- Sequential Circuit Design
- Serial Protocols: SPI, I²C, UART
- CRC and Error Detection
- Testbench Development
- Simulation and Waveform Analysis

## Tools and Simulation Environment

The projects in this repository are built around hardware-design workflows and simulation tooling such as:
- Verilog/SystemVerilog
- Icarus Verilog
- EDA Playground
- EPWave
- waveform viewers and logic debugging tools

## Learning Philosophy

This repository reflects an iterative approach to VLSI learning:

1. Build fundamental digital blocks
2. Understand timing and control behavior
3. Implement communication protocols
4. Validate with testbenches and waveform analysis
5. Progress toward robust system-level hardware design

## Getting Started

Clone the repository locally:

```bash
git clone https://github.com/sandipseal458/VLSI-.git
cd VLSI-
```

Then open the relevant section:

- `Academic/` for learning-based designs
- `Professional/` for advanced or application-oriented projects

## Roadmap

The repository is continuously expanding with:
- new RTL designs
- protocol-based implementations
- verification-focused projects
- larger integrated digital systems

## Author

Sandip Seal

- GitHub: https://github.com/sandipseal458
- LinkedIn: https://www.linkedin.com/in/sandip-seal/
- Email: sandipseal458@gmail.com

## License

This repository is intended for educational and portfolio purposes. Please respect the source usage and attribution terms of any associated materials or project references.
