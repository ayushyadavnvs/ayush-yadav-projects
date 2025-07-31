# 5-Stage Pipelined MIPS32 Processor  
**Built using Verilog | RTL-based CPU Design | NPTEL Guided Project**

## Overview

This project is a custom-designed 32-bit **5-stage pipelined MIPS32 processor**, developed as part of the NPTEL course *Hardware Modeling using Verilog* by **Prof. Indranil Sengupta**. It supports MIPS-style instructions and handles various pipeline hazards using efficient architectural techniques.

The processor simulates instruction execution through five stages:  
**IF → ID → EX → MEM → WB**, with custom hazard resolution mechanisms for **data**, **control**, and **structural hazards**.

---

## Instruction Format

The MIPS32 instruction set architecture supports three types of instructions:

![Instruction Formats](quick.png)

- **R-type**: Used for register-to-register ALU operations
- **I-type**: Used for immediate operations, memory access, and branches
- **J-type**: Used for jump instructions (not included in this processor)

---

## Key Features

- Fully functional **32-bit pipelined CPU** in Verilog
- Supports 14 custom MIPS-style instructions (R-type, I-type, load/store, branch, halt)
- Efficient handling of **data**, **control**, and **structural hazards**
- Branch resolution using **early condition check** and **pipeline flushing**
- Memory and instruction storage using **separate modules**
- Two-phase clocking system to separate pipeline stages

---

## Architecture and Data Flow

The processor follows the classic 5-stage pipeline and manages instruction/control flow through a datapath consisting of the following elements:

![Processor Datapath](flow.png)

### Pipelined Stages

1. **IF (Instruction Fetch)**  
   Fetches instruction from memory and calculates next PC.

2. **ID (Instruction Decode & Register Fetch)**  
   Decodes opcode, reads registers, and performs sign extension for immediate values.

3. **EX (Execution/Address Calculation)**  
   Executes ALU operations or computes branch target addresses.

4. **MEM (Memory Access)**  
   Loads data from memory or writes to memory.

5. **WB (Write Back)**  
   Writes result back to register file.

---

## Instruction Set

| Opcode   | Instruction     | Type     | Description                             |
|----------|------------------|----------|-----------------------------------------|
| `000000` | ADD              | RR-ALU   | Register-register addition              |
| `000001` | SUB              | RR-ALU   | Register-register subtraction           |
| `000010` | AND              | RR-ALU   | Bitwise AND                             |
| `000011` | OR               | RR-ALU   | Bitwise OR                              |
| `000100` | SLT              | RR-ALU   | Set less than                           |
| `000101` | MUL              | RR-ALU   | Multiplication                          |
| `001000` | LW               | LOAD     | Load word from memory                   |
| `001001` | SW               | STORE    | Store word to memory                    |
| `001010` | ADDI             | RM-ALU   | Add immediate                           |
| `001011` | SUBI             | RM-ALU   | Subtract immediate                      |
| `001100` | SLTI             | RM-ALU   | Set less than immediate                 |
| `001101` | BNEQZ            | BRANCH   | Branch if not equal to zero             |
| `001110` | BEQZ             | BRANCH   | Branch if equal to zero                 |
| `111111` | HLT              | HALT     | Halt the processor                      |

---

## Clock Cycle Execution

The pipelined design allows multiple instructions to be in different stages of execution simultaneously. Below is a visual representation:

![Pipeline Clock Cycle](clockcycles.png)

Each instruction progresses one stage per clock cycle, and the pipeline is kept busy with new instructions entering every cycle.

---

## Hazard Handling

- **Data Hazards**  
  Managed using **two-phase clocking** and controlled **stalling**. This ensures that operands are ready before being used in the ALU or memory stages.

- **Control Hazards**  
  Handled by evaluating branch conditions in the **EX stage**. If a branch is taken, the IF and ID stages are **flushed**, resulting in minimal penalty.

- **Structural Hazards**  
  Eliminated by using **separate instruction and data memories**, and a **two-read, one-write register file**.

---

## Design Decisions

- Inter-stage pipeline registers (e.g., `IF_ID_IR`, `ID_EX_A`) store intermediate values and control signals.
- Memory is modeled as a 1KB array (`Mem[1023:0]`).
- Register file consists of 32 general-purpose registers (`Reg[31:0]`).
- Custom `TYPE` control values distinguish instruction categories in pipeline stages.

---

## Technologies Used

- **Verilog HDL**
- **RTL Design Methodology**
- **Digital Logic and Computer Architecture**
- Simulated using **ModelSim**, **Vivado**, or other compatible tools

---

## Project Highlights

- Built a functional pipelined processor with support for branching, arithmetic, and memory operations
- Gained practical exposure to instruction-level parallelism and pipeline design
- Implemented clean hazard handling and flushing mechanisms
- Reinforced key concepts of datapath design and control signal management

---

## How to Run

1. Load the Verilog source code into a simulator (e.g., Vivado, ModelSim).
2. Initialize `Mem` with encoded instruction binaries.
3. Use alternating clock signals (`clk1` and `clk2`) to simulate pipelined flow.
4. Observe pipeline register contents (`IF_ID_IR`, `ID_EX_A`, etc.) and register values.
5. Validate memory outputs and register file for correctness.


