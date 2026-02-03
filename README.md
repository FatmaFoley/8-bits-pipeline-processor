🧠 8-bit Pipelined Processor Design (Verilog)
📌 Overview

This project implements a simple 8-bit RISC-like processor designed for the Advanced Processor Architecture course (ELC 3030) at Cairo University – Faculty of Engineering.

The processor supports a custom Instruction Set Architecture (ISA), interrupt handling, stack operations, and conditional branching. The design emphasizes resource sharing, FSM-based control, and correct handling of flags and interrupts.

🎯 Project Objectives

Design and implement an 8-bit pipelined processor

Support Harvard architecture

Implement a control unit

Efficiently share resources, especially single memory

Fully comply with the provided ISA specification

Simulate and verify functionality using waveform analysis

🏗️ Processor Architecture

Word size: 8 bits

Memory size: 256 bytes (byte-addressable)

Registers:

R0 – R3 (8-bit general-purpose)

R3 also acts as Stack Pointer (SP)

Program Counter: 8-bit

Condition Code Register (CCR):

Z – Zero flag

N – Negative flag

C – Carry flag

V – Overflow flag

⚙️ Supported Instruction Formats
1️⃣ A-Format (Arithmetic & Logic)

ADD, SUB, AND, OR

MOV, INC, DEC, NEG, NOT

Stack & I/O: PUSH, POP, IN, OUT

Shift & flag ops: RLC, RRC, SETC, CLRC

2️⃣ B-Format (Control Flow)

Conditional branches: JZ, JN, JC, JV

Looping: LOOP

Subroutines & interrupts: CALL, RET, RTI

Unconditional jump: JMP

3️⃣ L-Format (Memory Operations)

Immediate & direct addressing: LDM, LDD, STD

Indirect addressing: LDI, STI

🚨 Interrupt Handling

Supports a non-maskable interrupt

On interrupt:

Current PC is pushed onto the stack

Processor jumps to address stored at M[1]

RTI restores flags and resumes execution

🧪 Simulation & Verification

Simulated using EDA Playground

VCD dump enabled for waveform analysis

Verified using multiple test cases covering:

Arithmetic & logic operations

Branching & loops

Stack operations

Interrupt handling
