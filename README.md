# DMA-controller
SystemVerilog implementation of a DMA Controller with UART-based command parsing and flexible memory access modes.

[![Language](https://img.shields.io/badge/Language-SystemVerilog-blue.svg)](https://en.wikipedia.org/wiki/SystemVerilog)
[![Target](https://img.shields.io/badge/Target-RTL%20Verification%20%7C%20YADRO%20Internship-orange.svg)](https://yadro.com/)

## Project Overview
This repository contains the RTL implementation of a **Direct Memory Access (DMA) Controller** designed for efficient data transfers without CPU intervention. The project features a specialized **UART Command Interpreter** that mimics processor interactions, allowing for remote memory management and DMA configuration via a serial interface.

Developed as a technical showcase for RTL Design and Verification roles, with a focus on robust Finite State Machine (FSM) architectures and packet processing logic.

## Key Features
* **Dual Operating Modes:**
    * **Direct Access (CPU Emulation):** Direct read/write operations to memory via UART commands.
    * **DMA Mode:** Autonomous block transfers between memory regions triggered by specific UART descriptors.
* **Command Parsing Engine:** A centralized FSM decodes variable-length UART packets to extract opcodes, source/destination addresses, and block lengths.
* **RISC-V Logic:** Implementation of an instruction decoder for a significant subset of **RISC-V pseudo-instructions** mapped to hardware operations.
* **Modular Design:** Separate RTL modules for UART RX/TX, Command Parser, DMA Control Logic, and Memory Interface.

## Repository Structure
* `src/` — Synthesizable SystemVerilog RTL (FSMs, Decoders, DMA Core).
* `tb/` — Class-based Verification Environment (Drivers, Monitors, Scoreboards).
* `docs/` — Architecture diagrams and command protocol specifications.

## Command Protocol
The controller interprets packets following the format: `[OPCODE] [ADDR_H] [ADDR_L] [LEN/DATA...]`

| Opcode | Name | Description |
|:---:|:---|:---|
| **0x10** | **MEM_WRITE** | Directly writes data to the specified memory address. |
| **0x20** | **MEM_READ** | Reads data from memory and sends it back via UART. |
| **0x30** | **DMA_START** | Triggers the DMA FSM to begin a block transfer. |
| **0x40** | **SET_CONFIG** | Configures DMA source, destination, and transfer length. |

## Verification
The design is verified using an **Automated OOP-style Testbench**. The verification suite focuses on:
* Packet integrity and handling of asynchronous UART streams.
* Memory arbitration between Direct Access and DMA requests.
* Validation of the RISC-V pseudo-instruction decoding logic.

---
**Author:** Sergey Azov  
*Candidate for Intern RTL Design/Verification role at YADRO*
