`timescale 1ns/1ps

// =============================================================================
// Execute-to-Memory Pipeline Latch (EX/MEM Latch)
// =============================================================================
// This module implements the pipeline register between the Execute (EX) and
// Memory (MEM) stages of a pipelined processor. It captures and holds all
// control signals, data values, and intermediate results at the rising edge
// of the clock, effectively separating the two pipeline stages.
//
// Purpose:
// - Registers all signals from Execute stage for use in Memory stage
// - Maintains pipeline timing and prevents combinational paths across stages
// - Holds instruction metadata needed for Memory and Writeback operations
// =============================================================================

module exlatch(
    // -------------------------------------------------------------------------
    // Clock input
    // -------------------------------------------------------------------------
    input wire        clk,              // System clock - updates on rising edge

    // -------------------------------------------------------------------------
    // Control signals from Execute stage
    // -------------------------------------------------------------------------
    input wire        D_mem_wenEX,      // Data memory write enable
    input wire        D_mem_renEX,      // Data memory read enable
    input wire        sp_mux_sEX,       // Stack pointer mux select
    input wire        RET_flushEX,      // Return instruction flush signal
    input wire        RET_enEX,         // Return instruction enable

    input wire [1:0]  mux9sEX,          // Mux 9 select (memory data source)
    input wire [1:0]  dest_addrEX,      // Destination register address
    input wire [1:0]  reg_file_wenEX,   // Register file write enable

    input wire [2:0]  mux8sEX,          // Mux 8 select (memory address source)
    input wire [2:0]  mux10sEX,         // Mux 10 select (writeback data source)

    // -------------------------------------------------------------------------
    // Data and instruction information from Execute stage
    // -------------------------------------------------------------------------
    input wire [7:0]  instrEX,          // Current instruction (for tracking)
    input wire [7:0]  pcEX,             // Program counter value
    input wire [7:0]  Imm_EX,           // Immediate value (for multi-word instructions)

    // -------------------------------------------------------------------------
    // Register file outputs from Execute stage
    // -------------------------------------------------------------------------
    input wire [7:0]  data_out1EX,      // Register file output 1 (source operand 1)
    input wire [7:0]  data_out2EX,      // Register file output 2 (source operand 2)

    // -------------------------------------------------------------------------
    // Computation results from Execute stage
    // -------------------------------------------------------------------------
    input wire [7:0]  sub_outEX,        // Subtraction/decrement result (for stack pointer)
    input wire [7:0]  ALU_resultEX,     // Main ALU computation result

    // =========================================================================
    // Outputs to Memory stage (registered versions of all inputs)
    // =========================================================================

    // -------------------------------------------------------------------------
    // Control signals to Memory stage
    // -------------------------------------------------------------------------
    output reg        D_mem_wenM,       // Memory write enable (registered)
    output reg        D_mem_renM,       // Memory read enable (registered)
    output reg        sp_mux_sM,        // Stack pointer mux select (registered)
    output reg        RET_flushM,       // Return flush signal (registered)
    output reg        RET_enM,          // Return enable (registered)

    output reg [1:0]  mux9sM,           // Mux 9 select (registered)
    output reg [1:0]  dest_addrM,       // Destination address (registered)
    output reg [1:0]  reg_file_wenM,    // Register write enable (registered)

    output reg [2:0]  mux8sM,           // Mux 8 select (registered)
    output reg [2:0]  mux10sM,          // Mux 10 select (registered)

    // -------------------------------------------------------------------------
    // Data and results to Memory stage
    // -------------------------------------------------------------------------
    output reg [7:0]  ALU_resultM,      // ALU result (registered)
    output reg [7:0]  sub_outM,         // Subtraction result (registered)
    output reg [7:0]  instrM,           // Instruction (registered)
    output reg [7:0]  pcM,              // Program counter (registered)
    output reg [7:0]  Imm_M,            // Immediate value (registered)
    output reg [7:0]  data_out1M,       // Register data 1 (registered)
    output reg [7:0]  data_out2M        // Register data 2 (registered)
);

    // =========================================================================
    // Pipeline Register Update Logic
    // =========================================================================
    // On every rising clock edge, capture all signals from Execute stage
    // and make them available to Memory stage. This creates a one-cycle
    // delay that separates the two pipeline stages.
    // =========================================================================
    always @(posedge clk) begin
        // ---------------------------------------------------------------------
        // Memory control signals
        // ---------------------------------------------------------------------
        D_mem_wenM    <= D_mem_wenEX;   // Register memory write enable
        D_mem_renM    <= D_mem_renEX;   // Register memory read enable

        // ---------------------------------------------------------------------
        // Register file control
        // ---------------------------------------------------------------------
        reg_file_wenM <= reg_file_wenEX; // Register write enable for writeback
        dest_addrM    <= dest_addrEX;    // Destination register address

        // ---------------------------------------------------------------------
        // Multiplexer control signals
        // ---------------------------------------------------------------------
        mux8sM        <= mux8sEX;       // Memory address source selector
        mux9sM        <= mux9sEX;       // Memory write data source selector
        mux10sM       <= mux10sEX;      // Writeback data source selector

        // ---------------------------------------------------------------------
        // Instruction and PC tracking
        // ---------------------------------------------------------------------
        instrM        <= instrEX;       // Current instruction for debugging/tracking
        pcM           <= pcEX;          // PC value for potential use in memory stage

        // ---------------------------------------------------------------------
        // Register file data outputs
        // ---------------------------------------------------------------------
        data_out1M    <= data_out1EX;   // Register operand 1 (for memory address/data)
        data_out2M    <= data_out2EX;   // Register operand 2 (for memory data)

        // ---------------------------------------------------------------------
        // Computation results
        // ---------------------------------------------------------------------
        sub_outM      <= sub_outEX;     // Stack pointer decrement result
        ALU_resultM   <= ALU_resultEX;  // Main ALU result for memory/writeback

        // ---------------------------------------------------------------------
        // Stack pointer and special control
        // ---------------------------------------------------------------------
        sp_mux_sM     <= sp_mux_sEX;    // Stack pointer operation selector
        Imm_M         <= Imm_EX;        // Immediate value for LDM/LDD/STD instructions

        // ---------------------------------------------------------------------
        // Return instruction control
        // ---------------------------------------------------------------------
        RET_flushM    <= RET_flushEX;   // Pipeline flush for RET/RTI
        RET_enM       <= RET_enEX;      // Return instruction active flag
    end

endmodule