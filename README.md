# UART-Driven DMA Controller Core

[![SystemVerilog](https://img.shields.io/badge/Language-SystemVerilog-blue.svg)](https://en.wikipedia.org/wiki/SystemVerilog)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Project Overview
This project implements a **Direct Memory Access (DMA) Controller** with a Command-Line Interface via **UART**. The system allows a host to either interact with memory directly (CPU-less access) or configure and trigger high-speed block transfers between internal memory regions.

The design is centered around a centralized Finite State Machine (FSM) that orchestrates interactions between the UART transceiver, a dedicated Register File for DMA descriptors, and a Dual-Port RAM.

## System Architecture
* **Top Module:** Integrates UART, DMA Engine, Register File, and RAM.
* **UART Interface:** Standard 8-N-1 serial communication (9600 baud default).
* **DMA Engine:** Handles autonomous block data movement.
* **Dual-Port RAM:** Port A for direct UART access, Port B for DMA operations.

## Command Protocol (Opcodes)
The controller parses 8-bit opcodes to determine the operation mode:

| Opcode | Name | Description | Response (ACK) |
|:---:|:---|:---|:---|
| **0xA1** | **DIRECT_WRITE** | Write 1 byte to specific address: `[0xA1][ADDR][DATA]` | `0x01` (Success) |
| **0xA2** | **DIRECT_READ** | Read 1 byte from specific address: `[0xA2][ADDR]` | `[DATA_FROM_RAM]` |
| **0xD1** | **DMA_LEN** | Set DMA transfer block length | - |
| **0xD2** | **DMA_SRC** | Set DMA source starting address | - |
| **0xD3** | **DMA_DST** | Set DMA destination starting address | - |
| **0xD0** | **DMA_START** | Execute DMA block transfer | `0x02` (Done) |

### Error Codes
* `0xE0`: Unknown Command.
* `0xE1`: DMA Engine Error Signal detected.
* `0xE2`: Command rejected (DMA is currently busy).

## Implementation Details
* **Technology:** RTL SystemVerilog.
* **FSM States:** `COMMAND` (IDLE/Parsing), `DATA` (Payload acquisition), `REALISE` (Memory execution), `DMA` (Wait for engine), `ASK` (UART Response).
* **Clocking:** Configurable `CLK_FREQ` parameter with internal clock dividers for UART and 1MHz strobes.

## How to Simulate
1. Load all files in `src/` into your simulator (ModelSim/Vivado/Questasim).
2. Run `tb_top_module.sv`.
3. Observe UART TX responses to verify command execution.

---
**Author:** Sergey Azov  
*Candidate for Intern RTL Design at YADRO*
