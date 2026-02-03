`timescale 1ns/1ps

// =============================================================================
// Instruction Register (IR) - Immediate Value Holder
// =============================================================================
// This module implements a special-purpose register that captures and holds
// immediate values or direct addresses for multi-word instructions.
//
// PURPOSE:
// Many instruction set architectures use multi-word (multi-byte) instructions
// where the first word contains the opcode and register specifiers, and the
// second word contains an immediate value or memory address. This register
// captures that second word so it's available throughout instruction execution.
//
// EXAMPLES OF MULTI-WORD INSTRUCTIONS:
//
// 1. LDM (Load Immediate):
//    Cycle 1: Fetch opcode byte (e.g., 0xC1) - "LDM R1, #imm"
//            Control unit sets IR_en = 1
//    Cycle 2: Fetch immediate value (e.g., 0x42)
//            IR captures 0x42 and holds it
//    Execute: R1 ← 0x42 (using Imm_Out)
//
// 2. LDD (Load Direct):
//    Cycle 1: Fetch opcode (0xC5) - "LDD R1, [addr]"
//    Cycle 2: Fetch address (0x80)
//            IR captures the direct memory address
//    Execute: R1 ← Memory[0x80]
//
// 3. STD (Store Direct):
//    Cycle 1: Fetch opcode (0xCA) - "STD [addr], R2"
//    Cycle 2: Fetch address (0x90)
//    Execute: Memory[0x90] ← R2
//
// BEHAVIOR:
// - On clock edge with IR_en = 1: Captures new immediate value
// - On clock edge with IR_en = 0: Holds previous value
// - Value remains stable until next enabled clock edge
// - Provides immediate/address to decode and execute stages
//
// CONTROL FLOW:
// The control unit (control_unit module) asserts IR_en when it decodes
// a multi-word instruction (opcodes 0xC_ typically: LDM, LDD, STD).
// =============================================================================

module IR(
    // =========================================================================
    // Inputs
    // =========================================================================
    input  wire clk,                // System clock - captures data on rising edge

    input  wire IR_en,              // Instruction Register Enable
                                    // 1 = Capture new immediate value from Imm_In
                                    // 0 = Hold current value in Imm_Out
                                    // Set by control unit when multi-word
                                    // instruction is detected

    input  wire [7:0] Imm_In,       // Immediate value input
                                    // Connected to instruction memory output
                                    // Contains the second word of multi-word
                                    // instructions (immediate value or address)

    // =========================================================================
    // Outputs
    // =========================================================================
    output reg  [7:0] Imm_Out       // Immediate value output (registered)
                                    // Holds the captured immediate/address value
                                    // Remains stable throughout instruction execution
                                    // Used by execute stage for:
                                    // - LDM: immediate data to load
                                    // - LDD: memory address to read from
                                    // - STD: memory address to write to
);

    // =========================================================================
    // Synchronous Capture Logic
    // =========================================================================
    // On every rising clock edge, check if we should capture a new value
    // This implements an enabled register (register with load enable)
    always @(posedge clk) begin
        // ---------------------------------------------------------------------
        // Capture new immediate value when enabled
        // ---------------------------------------------------------------------
        // IR_en is asserted by the control unit during the second cycle
        // of multi-word instructions to capture the immediate/address byte
        if(IR_en) begin
            Imm_Out <= Imm_In;      // Load new immediate value
        end
        // ---------------------------------------------------------------------
        // Hold current value when not enabled
        // ---------------------------------------------------------------------
        // When IR_en = 0, the register retains its previous value
        // This is implicit in the 'if' without 'else' - the register
        // naturally holds its value when not being written
        // (No explicit else clause needed)
    end

endmodule