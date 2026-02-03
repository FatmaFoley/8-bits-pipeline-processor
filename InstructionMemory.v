`timescale 1ns/1ps

// =============================================================================
// Instruction Memory (ROM)
// =============================================================================
// This module implements the instruction memory for the processor, which stores
// the program to be executed. It behaves as a Read-Only Memory (ROM) with:
//
// CHARACTERISTICS:
// - Size: 256 bytes (addresses 0x00 to 0xFF)
// - Word size: 8 bits (one byte per instruction/data word)
// - Access: Asynchronous read (combinational, no clock required)
// - Initialization: Loaded from "imem.hex" file at simulation start
//
// SPECIAL OUTPUTS:
// - Regular instruction fetch via 'instr' output (addressed by PC)
// - Direct access to memory location 0 (typically reset/interrupt vector)
// - Direct access to memory location 1 (for special purposes/jump targets)
//
// USAGE IN PROCESSOR:
// - The Program Counter (PC) provides the address
// - The instruction at that address is immediately available (combinational)
// - Memory locations 0 and 1 are always accessible for control flow operations
//
// FILE FORMAT (imem.hex):
// - Standard hex format, one byte per line (e.g., "A5", "3F", "00")
// - Can use @address notation to set load address
// - Example:
//   @000000
//   12    // Address 0: instruction byte
//   34    // Address 1: instruction byte
//   56    // Address 2: instruction byte
// =============================================================================

module InstructionMemory (
    // =========================================================================
    // Inputs
    // =========================================================================
    input  wire [7:0] addr,         // Address input: Program Counter (PC) value
                                    // Selects which instruction byte to read
                                    // Range: 0x00 to 0xFF (256 possible addresses)

    // =========================================================================
    // Outputs
    // =========================================================================
    output wire [7:0] instr,        // Instruction output: The instruction byte
                                    // at the address specified by 'addr'
                                    // This is the main instruction fetch path

    output wire [7:0] Instr_mem0,   // Direct access to memory location 0
                                    // Typically used for:
                                    // - Reset vector (initial PC value)
                                    // - Interrupt vector base address
                                    // - Special initialization values

    output wire [7:0] Instr_mem1    // Direct access to memory location 1
                                    // Typically used for:
                                    // - Secondary vector address
                                    // - Special jump targets
                                    // - Configuration values
);

    // =========================================================================
    // Memory Array Declaration
    // =========================================================================
    // 256-byte instruction memory implemented as register array
    // - Indexed from 0 to 255 (8-bit address space)
    // - Each location stores one 8-bit instruction/data byte
    // - Synthesizes as ROM (read-only) since never written during operation
    reg [7:0] mem [0:255];

    // =========================================================================
    // Memory Initialization
    // =========================================================================
    // Load program from hex file at simulation start
    // This block executes once at time 0 in simulation
    //
    // The $readmemh system task:
    // - Reads hexadecimal values from "imem.hex" file
    // - Loads them into the mem array starting at address 0
    // - If file doesn't exist, memory contents will be undefined (X)
    // - Format: one hex byte per line, or use @address for non-sequential
    initial begin
        $display("Loading Instruction Memory from imem.hex (if exists)...");
        $readmemh("imem.hex", mem);
        // After loading, you could add verification or debug output:
        // $display("Mem[0] = %h, Mem[1] = %h", mem[0], mem[1]);
    end

    // =========================================================================
    // Asynchronous (Combinational) Read Operations
    // =========================================================================
    // All reads are asynchronous - no clock required
    // Output changes immediately when address changes (subject to propagation delay)
    // This provides zero-latency instruction fetch

    // -------------------------------------------------------------------------
    // Main instruction fetch: Read from address specified by PC
    // -------------------------------------------------------------------------
    assign instr = mem[addr];

    // -------------------------------------------------------------------------
    // Special location 0: Always accessible regardless of PC value
    // -------------------------------------------------------------------------
    // Used by processor for:
    // - Reset: PC initialized to this value
    // - Interrupts: May store interrupt vector or handler address
    assign Instr_mem0 = mem[0];

    // -------------------------------------------------------------------------
    // Special location 1: Always accessible regardless of PC value
    // -------------------------------------------------------------------------
    // Used by processor for:
    // - Secondary vectors or special jump targets
    // - Part of control flow logic in fetch stage
    assign Instr_mem1 = mem[1];

endmodule