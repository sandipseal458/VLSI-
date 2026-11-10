# VLSI Design & Verification Portfolio

A growing collection of digital-design projects covering foundational RTL concepts, common hardware building blocks, serial communication protocols, and verification testbenches. The repository is organized into **Academic** and **Professional** sections to make learning projects and larger implementations easy to explore.

## Repository contents

| Section | Description |
| --- | --- |
| [Academic](./Academic/) | A progressive learning path from beginner combinational and sequential logic to intermediate designs such as SPI, I²C, UART, and a register file. The [Academic README](./Academic/README.md) includes the project list, skill levels, tools, and background. |
| [Professional](./Professional/) | Project-oriented RTL work. The current project, [eSim Modbus RTU Master/Slave](./Professional/esim-modbus-rtu-master-slave/), contains UART, Modbus master and slave, and CRC-16 RTL modules, with testbenches in its `tb/` directory. |

## Academic project roadmap

The Academic section groups projects by experience level:

- **Beginner:** 4-bit adder, mux/demux, D flip-flop and register, up/down counter, FSM sequence detector, and 4-bit ALU.
- **Intermediate:** SPI master/slave, I²C master/slave, UART transceiver, and register file.
- **Advanced:** Reserved for future projects as the collection grows.

See the [Academic README](./Academic/README.md) for individual project links and further details.

## Professional project: Modbus RTU

The current professional project is organized into:

- `rtl/` — Verilog modules for Modbus master and slave functionality, UART transmit/receive, and Modbus CRC-16.
- `tb/` — testbenches covering the CRC, UART loopback, Modbus slave/system behavior, timing, and noise scenarios.

Refer to the project directory for implementation details and simulation instructions as they are documented.

## Getting started

Clone the repository and browse the section or project you are interested in:

```bash
git clone https://github.com/sandipseal458/VLSI-.git
cd VLSI-
```

Each project may have its own source files, testbench, and simulator requirements. Check its README or project files before running a simulation.

## Tools and languages

The collection primarily uses **Verilog** for RTL and testbenches. Individual projects may use different simulators or waveform viewers; see the relevant project documentation for specific requirements and commands.

## Contributing and feedback

This is a portfolio and learning repository. Suggestions, issue reports, and constructive feedback are welcome. When proposing changes, please include the affected project and enough detail to reproduce or understand the change.

## Author

**Sandip Seal** · [GitHub](https://github.com/sandipseal458) · [LinkedIn](https://www.linkedin.com/in/sandip-seal/)
