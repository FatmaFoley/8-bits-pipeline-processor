`timescale 1ns/1ps

// =============================================================================
// Fetch Cycle Module
// =============================================================================
// This module implements the Instruction Fetch (IF) stage of a pipelined 
// processor. It is responsible for:
// - Fetching instructions from instruction memory based on the Program Counter
// - Managing PC updates (sequential, jumps, branches, loops, interrupts)
// - Handling pipeline control (stalls, flushes)
// - Supporting multi-word instructions through the Instruction Register (IR)
//
// The fetch stage contains:
// - Program Counter (PC) register
// - Instruction Memory
// - PC calculation logic (adder and multiplexers)
// - Fetch/Decode pipeline latch
// - Instruction Register for immediate values
// =============================================================================

module fetch_cycle (
    // -------------------------------------------------------------------------
    // Clock and Reset
    // -------------------------------------------------------------------------
    input  wire        clk,             // System clock
    input  wire        reset,           // Asynchronous reset signal
    
    // -------------------------------------------------------------------------
    // Pipeline Control Signals
    // -------------------------------------------------------------------------
    input  wire        IR_en,           // Instruction Register enable (for 2-word instructions)
    input  wire        FlushD,          // Flush decode stage (clear IF/ID latch)
    input  wire        StallF,          // Stall fetch stage (freeze PC)
    input  wire        StallD,          // Stall decode stage (freeze IF/ID latch)
    
    // -------------------------------------------------------------------------
    // Branch/Jump Control
    // -------------------------------------------------------------------------
    input  wire        loop_en,         // Loop instruction enable
    input  wire        or_out,          // Loop condition result (counter != 0)
    input  wire  [2:0] mux1_sel,        // PC source select:
                                        // 000 = PC+1 (sequential)
                                        // 001 = Register (JMP/Jcc)
                                        // 010 = Interrupt vector
                                        // 011 = Memory (RET/RTI return address)
                                        // 100 = Special cases
                                        // 101 = Immediate from instruction
    
    // -------------------------------------------------------------------------
    // Data Inputs for PC Calculation
    // -------------------------------------------------------------------------
    input  wire  [7:0] data_out2,       // Register file output 2 (for jump target)
    input  wire  [7:0] data_mem_out,    // Data memory output (for RET/RTI return address)
    
    // -------------------------------------------------------------------------
    // Outputs to Decode Stage
    // -------------------------------------------------------------------------
    output wire  [7:0] instrD,          // Instruction in decode stage (from IF/ID latch)
    output wire  [7:0] pcD,             // PC value in decode stage (from IF/ID latch)
    output wire  [7:0] Imm_D,           // Immediate value for multi-word instructions
    output wire  [3:0] Opcode           // Opcode extracted from current instruction in fetch

    // =========================================================================
    // Internal Signals
    // =========================================================================
);

    // -------------------------------------------------------------------------
    // PC Mux and Adder Signals
    // -------------------------------------------------------------------------
    wire        mux1_s0_out;            // LSB of PC source select (after loop logic)
    wire [7:0]  adder_out;              // PC+1 result from adder
    wire [7:0]  mux1_out;               // Selected next PC value
    
    // -------------------------------------------------------------------------
    // Fetch Stage Internal Signals
    // -------------------------------------------------------------------------
    wire [7:0]  instrF;                 // Instruction fetched from memory (fetch stage)
    wire [7:0]  pcF;                    // Current PC value in fetch stage
    
    // -------------------------------------------------------------------------
    // Instruction Memory Outputs
    // -------------------------------------------------------------------------
    wire [7:0]  mem0;                   // Instruction memory location 0 (interrupt vector)
    wire [7:0]  mem1;                   // Instruction memory location 1 (possible jump target)

    // =========================================================================
    // Opcode Extraction
    // =========================================================================
    // Extract the 4-bit opcode from the fetched instruction
    // Used by control unit for early decode and hazard detection
    assign Opcode = instrF[7:4];

    // =========================================================================
    // PC Source Selection Multiplexer (8-to-1)
    // =========================================================================
    // Selects the next PC value based on instruction type and control signals
    // Inputs (selected by mux1_sel):
    // 000: adder_out     - Sequential execution (PC+1)
    // 001: data_out2     - Register-based jump (JMP, Jcc, CALL)
    // 010: mem1          - Fixed address jump (could be interrupt vector)
    // 011: data_mem_out  - Return from subroutine/interrupt (stack-based)
    // 100: instrF        - Immediate value from instruction (not common)
    // 101: 8'b00000000   - Reset/special case (jump to address 0)
    // 110: pcF           - Hold current PC (for stalls)
    // 111: adder_out     - Default to sequential (redundant with 000)
    MUX_8_1 Mux1 (
        .Mux_in1(adder_out),            // Input 0: PC+1 (normal sequential)
        .Mux_in2(data_out2),            // Input 1: Register value (jump target)
        .Mux_in3(mem1),                 // Input 2: Memory location 1
        .Mux_in4(data_mem_out),         // Input 3: Return address from stack
        .Mux_in5(instrF),               // Input 4: Immediate from instruction
        .Mux_in6(8'b00000000),          // Input 5: Address 0 (reset vector)
        .Mux_in7(pcF),                  // Input 6: Current PC (stall)
        .Mux_in8(adder_out),            // Input 7: PC+1 (alternate)
        .Mux_sel({mux1_sel[2:1], mux1_s0_out}), // 3-bit select signal
        .Mux_out(mux1_out)              // Selected next PC value
    );

    // =========================================================================
    // Loop Control Multiplexer (2-to-1)
    // =========================================================================
    // For LOOP instruction: decides whether to branch based on counter != 0
    // - If loop_en = 1: Use or_out (loop condition result)
    // - If loop_en = 0: Use mux1_sel[0] (normal LSB of PC source select)
    MUX_2_1 Mux2 (
        .Mux_sel(loop_en),              // Select signal: 1=loop active, 0=normal
        .Mux_in1(or_out),               // Input 0: Loop condition (counter != 0)
        .Mux_in2(mux1_sel[0]),          // Input 1: Normal PC select LSB
        .Mux_out(mux1_s0_out)           // Output: Effective LSB of PC select
    );

    // =========================================================================
    // PC Incrementer (8-bit Adder)
    // =========================================================================
    // Calculates PC+1 for sequential instruction execution
    // Input 1: Always 1 (increment value)
    // Input 2: Current PC value
    // Output: PC+1 (next sequential address)
    adder_8bit Adder1 (
        .adder_in1(8'b00000001),        // Constant: increment by 1
        .PC_out(pcF),                   // Current PC value
        .adder_out(adder_out)           // Result: PC+1
    );

    // =========================================================================
    // Instruction Memory
    // =========================================================================
    // Stores program instructions and provides:
    // - Current instruction at PC address
    // - Fixed memory locations (mem0, mem1) for special purposes
    //   (interrupt vectors, reset vectors, etc.)
    InstructionMemory InstMem (
        .addr(pcF),                     // Address input: current PC
        .instr(instrF),                 // Instruction output: fetched instruction
        .Instr_mem0(mem0),              // Memory location 0 (special/interrupt vector)
        .Instr_mem1(mem1)               // Memory location 1 (special purposes)
    );

    // =========================================================================
    // Program Counter (PC) Register
    // =========================================================================
    // Stores the current instruction address
    // - Updates on clock edge with next PC value from Mux1
    // - Can be stalled (frozen) via StallF signal
    // - Resets to mem0 (typically address 0 or interrupt vector)
    PC pc_reg (
        .clk(clk),                      // System clock
        .reset(reset),                  // Asynchronous reset
        .StallF(StallF),                // Stall signal: 1=freeze PC, 0=update PC
        .mux1_out(mux1_out),            // Next PC value (from Mux1)
        .mem0(mem0),                    // Reset vector (typically 0x00)
        .pc_out(pcF)                    // Current PC output
    );

    // =========================================================================
    // Fetch/Decode Pipeline Latch (IF/ID Register)
    // =========================================================================
    // Pipeline register between Fetch and Decode stages
    // - Captures instruction and PC on clock edge
    // - Can be flushed (cleared to NOP) via FlushD signal
    // - Can be stalled (held) via StallD signal
    // Purpose: Separates fetch and decode stages, enables pipelining
    Flatch flatch (
        .clk(clk),                      // System clock
        .instrF(instrF),                // Instruction from fetch stage
        .pcF(pcF),                      // PC from fetch stage
        .FlushD(FlushD),                // Flush signal: 1=insert NOP (bubble)
        .StallD(StallD),                // Stall signal: 1=hold current values
        .instrD(instrD),                // Instruction to decode stage
        .pcD(pcD)                       // PC to decode stage
    );

    // =========================================================================
    // Instruction Register (IR)
    // =========================================================================
    // Holds immediate values for multi-word instructions (LDM, LDD, STD)
    // - Enabled by IR_en signal (set by control unit for 2-word instructions)
    // - Captures the second word of instruction (immediate/address value)
    // - The first word is the opcode, second word is stored here
    //
    // Example: LDM R1, #5
    //   Cycle 1: Fetch opcode (LDM R1), set IR_en=1
    //   Cycle 2: Fetch immediate (#5), IR captures it as Imm_D
    IR IR_reg (
        .clk(clk),                      // System clock
        .IR_en(IR_en),                  // Enable: 1=capture new immediate
        .Imm_In(instrF),                // Immediate value input (from instruction memory)
        .Imm_Out(Imm_D)                 // Immediate value output (to decode/execute)
    );

endmodule