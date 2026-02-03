`timescale 1ns/1ps

// =============================================================================
// Hazard Detection and Forwarding Unit
// =============================================================================
// This module detects and resolves data hazards and control hazards in a 
// pipelined processor. It implements two main strategies:
//
// 1. DATA FORWARDING (Bypassing):
//    - Detects when an instruction needs data from a previous instruction
//      that hasn't written back to the register file yet
//    - Generates forwarding control signals to bypass data from later stages
//      (Memory or Writeback) directly to the Execute stage
//    - Handles forwarding for both source operands (s1 and s2)
//
// 2. PIPELINE STALLING:
//    - Detects hazards that cannot be resolved by forwarding (load-use hazards)
//    - Generates stall signals to freeze earlier pipeline stages
//    - Inserts pipeline bubbles (NOPs) to allow data to become available
//
// 3. PIPELINE FLUSHING:
//    - Detects control hazards (jumps, branches, returns)
//    - Generates flush signals to clear invalid instructions from the pipeline
//
// The unit monitors register addresses across pipeline stages and compares
// source registers in Execute stage with destination registers in Memory
// and Writeback stages to determine if forwarding or stalling is needed.
// =============================================================================

module hazard_unit(
    // =========================================================================
    // Register Address Inputs - Track data flow through pipeline
    // =========================================================================
    
    // -------------------------------------------------------------------------
    // Decode Stage Register Addresses
    // -------------------------------------------------------------------------
    input  wire [1:0] s1D,              // Source register 1 in Decode stage
    input  wire [1:0] s2D,              // Source register 2 in Decode stage
    
    // -------------------------------------------------------------------------
    // Execute Stage Register Addresses
    // -------------------------------------------------------------------------
    input  wire [1:0] s1EX,             // Source register 1 in Execute stage
    input  wire [1:0] s2EX,             // Source register 2 in Execute stage
    input  wire [1:0] dest_addrEX,      // Destination register in Execute stage
    
    // -------------------------------------------------------------------------
    // Memory Stage Register Addresses
    // -------------------------------------------------------------------------
    input  wire [1:0] dest_addrM,       // Destination register in Memory stage
    
    // -------------------------------------------------------------------------
    // Writeback Stage Register Addresses
    // -------------------------------------------------------------------------
    input  wire [1:0] dest_addrWB,      // Destination register in Writeback stage
    
    // =========================================================================
    // Control Signal Inputs
    // =========================================================================
    
    // -------------------------------------------------------------------------
    // Instruction Decode Information
    // -------------------------------------------------------------------------
    input  wire [3:0] Opcode,           // Current opcode in Fetch stage (for special handling)
    
    // -------------------------------------------------------------------------
    // Register Write Enable Signals
    // -------------------------------------------------------------------------
    input  wire [1:0] reg_file_wenM,    // Register write enable in Memory stage
                                        // 00=no write, 01=normal, 10=SP, 11=both
    input  wire [1:0] reg_file_wenWB,   // Register write enable in Writeback stage
    
    // -------------------------------------------------------------------------
    // Control Flow Signals
    // -------------------------------------------------------------------------
    input  wire       jmp_enD,          // Jump enable in Decode stage
    input  wire       or_out,           // Loop condition result (counter != 0)
    input  wire       loop_en,          // Loop instruction active
    input  wire       cond_jmp_stall,   // Conditional jump stall (waiting for condition evaluation)
    
    // -------------------------------------------------------------------------
    // Hazard Detection Signals
    // -------------------------------------------------------------------------
    input  wire       load_stall,       // Load instruction detected (potential load-use hazard)
    input  wire       valids1_EX,       // Source 1 in Execute is valid (used by instruction)
    input  wire       valids2_EX,       // Source 2 in Execute is valid (used by instruction)
    input  wire       valids1_D,        // Source 1 in Decode is valid (used by instruction)
    input  wire       valids2_D,        // Source 2 in Decode is valid (used by instruction)
    
    // -------------------------------------------------------------------------
    // Return Instruction Flush Signals
    // -------------------------------------------------------------------------
    input  wire       RET_flushD,       // Return instruction flush from Decode
    input  wire       RET_flushEX,      // Return instruction flush from Execute
    input  wire       RET_flushM,       // Return instruction flush from Memory

    // =========================================================================
    // Forwarding Control Outputs
    // =========================================================================
    // These signals control multiplexers in the Execute stage to select
    // the correct data source for each operand (register file, Memory stage,
    // or Writeback stage)
    
    // -------------------------------------------------------------------------
    // Source 2 Forwarding Control (2-bit encoding)
    // -------------------------------------------------------------------------
    output reg        D_Hazard_s0,      // Forwarding control for source 2, bit 0
    output reg        D_Hazard_s1,      // Forwarding control for source 2, bit 1
                                        // 00 = Use register file (no forwarding)
                                        // 10 = Forward from Writeback stage
                                        // 11 = Forward from Memory stage
    
    // -------------------------------------------------------------------------
    // Source 1 Forwarding Control (2-bit encoding)
    // -------------------------------------------------------------------------
    output reg        D_Hazard_s2,      // Forwarding control for source 1, bit 0
    output reg        D_Hazard_s3,      // Forwarding control for source 1, bit 1
                                        // 10 = Use register file (no forwarding)
                                        // 00 = Forward from Writeback stage
                                        // 01 = Forward from Memory stage
    
    // =========================================================================
    // Pipeline Control Outputs
    // =========================================================================
    output wire       FlushD,           // Flush Decode stage (insert bubble/NOP)
    output wire       FlushE,           // Flush Execute stage (insert bubble/NOP)
    output wire       StallD,           // Stall Decode stage (freeze IF/ID latch)
    output wire       StallF            // Stall Fetch stage (freeze PC)
);

    // =========================================================================
    // Internal Signals
    // =========================================================================
    reg FlushD_i;                       // Internal flush Decode signal
    reg FlushE_i;                       // Internal flush Execute signal
    reg StallD_i;                       // Internal stall Decode signal
    reg lwstall;                        // Load-use hazard stall signal
    wire StallF_i;                      // Internal stall Fetch signal
    
    // -------------------------------------------------------------------------
    // Special Opcode Detection
    // -------------------------------------------------------------------------
    // Detects opcode 1011 (control flow: JMP, CALL, RET, RTI)
    // Used to insert stalls for certain instruction sequences
    wire Opcode_i = ((Opcode[3] & ~Opcode[2] & ~Opcode[1] & Opcode[0]) | 0);

    // =========================================================================
    // Initialization - Default Forwarding State
    // =========================================================================
    // Set default forwarding to "use register file" (no forwarding)
    // This ensures defined behavior at simulation start
    initial begin
        D_Hazard_s0 = 1'b0;             // Source 2: no forwarding
        D_Hazard_s1 = 1'b0;
        D_Hazard_s2 = 1'b1;             // Source 1: no forwarding (bit pattern 10)
        D_Hazard_s3 = 1'b0;
    end

    // =========================================================================
    // DATA FORWARDING LOGIC - SOURCE 1 (s1)
    // =========================================================================
    // Detects Read-After-Write (RAW) hazards for source operand 1
    // Priority: Memory stage forwarding > Writeback stage forwarding > No forwarding
    //
    // Forwarding is needed when:
    // 1. Execute stage instruction reads a register (valids1_EX = 1)
    // 2. A previous instruction will write to that same register
    // 3. The write hasn't reached the register file yet
    always @(*) begin
        // ---------------------------------------------------------------------
        // Case 1: Forward from Memory stage (most recent data)
        // ---------------------------------------------------------------------
        // Instruction in Memory stage will write to the register that
        // Execute stage instruction is trying to read
        if (((s1EX == dest_addrM) && reg_file_wenM && valids1_EX)) begin
            D_Hazard_s2 = 1'b0;         // Forwarding control = 01
            D_Hazard_s3 = 1'b1;         // Select Memory stage data
        end
        // ---------------------------------------------------------------------
        // Case 2: Forward from Writeback stage (older data)
        // ---------------------------------------------------------------------
        // Instruction in Writeback stage will write to the register that
        // Execute stage instruction is trying to read
        // Only used if Memory stage is not providing the data
        else if (((s1EX == dest_addrWB) && reg_file_wenWB && valids1_EX)) begin
            D_Hazard_s2 = 1'b0;         // Forwarding control = 00
            D_Hazard_s3 = 1'b0;         // Select Writeback stage data
        end
        // ---------------------------------------------------------------------
        // Case 3: No forwarding needed (use register file)
        // ---------------------------------------------------------------------
        // Either no hazard exists, or source 1 is not used by instruction
        else begin
            D_Hazard_s2 = 1'b1;         // Forwarding control = 10
            D_Hazard_s3 = 1'b0;         // Select register file (don't care for s3)
        end
    end
    
    // =========================================================================
    // DATA FORWARDING LOGIC - SOURCE 2 (s2)
    // =========================================================================
    // Similar logic to source 1, but for the second source operand
    // Encoding is different: 00=no forward, 10=WB forward, 11=MEM forward
    always @(*) begin
        // ---------------------------------------------------------------------
        // Case 1: Forward from Memory stage
        // ---------------------------------------------------------------------
        if (((s2EX == dest_addrM) && reg_file_wenM && valids2_EX)) begin
            D_Hazard_s0 = 1'b1;         // Forwarding control = 11
            D_Hazard_s1 = 1'b1;         // Select Memory stage data
        end
        // ---------------------------------------------------------------------
        // Case 2: Forward from Writeback stage
        // ---------------------------------------------------------------------
        else if (((s2EX == dest_addrWB) && reg_file_wenWB && valids2_EX)) begin
            D_Hazard_s0 = 1'b1;         // Forwarding control = 10
            D_Hazard_s1 = 1'b0;         // Select Writeback stage data
        end
        // ---------------------------------------------------------------------
        // Case 3: No forwarding needed
        // ---------------------------------------------------------------------
        else begin
            D_Hazard_s0 = 1'b0;         // Forwarding control = 00
            D_Hazard_s1 = 1'b0;         // Select register file (don't care for s1)
        end
    end

    // =========================================================================
    // LOAD-USE HAZARD DETECTION
    // =========================================================================
    // Detects the special case where a load instruction is immediately followed
    // by an instruction that uses the loaded data. This cannot be resolved by
    // forwarding because the data isn't available until after the Memory stage.
    //
    // Solution: Insert a 1-cycle stall (bubble) to delay the dependent instruction
    //
    // Condition: Load instruction in Execute stage AND
    //           (Decode instruction reads the load's destination register)
    always @(*) begin
        lwstall = load_stall & (((s1D == dest_addrEX) && valids1_D) | 
                                 ((s2D == dest_addrEX) && valids2_D));
    end
    
    // =========================================================================
    // DECODE STAGE STALL LOGIC
    // =========================================================================
    // Stalls the Decode stage when a load-use hazard is detected
    // This freezes the IF/ID pipeline register, preventing the dependent
    // instruction from advancing to Execute stage
    always @(*) begin
        StallD_i = lwstall;
    end

    // =========================================================================
    // FETCH STAGE STALL LOGIC
    // =========================================================================
    // Stalls the Fetch stage when:
    // 1. Decode stage is stalled (propagate stall backward)
    // 2. Special opcode detected (for instruction sequencing)
    // Exception: Don't stall if waiting for conditional jump evaluation
    assign StallF_i = (StallD_i | Opcode_i);

    // =========================================================================
    // DECODE STAGE FLUSH LOGIC
    // =========================================================================
    // Flushes (clears) the Decode stage by inserting a NOP when:
    // 1. Jump instruction executes (jmp_enD)
    // 2. Loop branches back (or_out & loop_en)
    // 3. Return instruction executes at any stage (RET_flushD/EX/M)
    //
    // Flushing is needed because the instructions that were fetched after
    // a control flow change are invalid and should not execute
    always @(*) begin
        FlushD_i = (jmp_enD | (or_out & loop_en) | (RET_flushD | RET_flushEX | RET_flushM));
    end

    // =========================================================================
    // EXECUTE STAGE FLUSH LOGIC
    // =========================================================================
    // Flushes the Execute stage when a load-use hazard stall occurs
    // This inserts a bubble (NOP) in the pipeline to give the load time to complete
    always @(*) begin
        FlushE_i = (lwstall);
    end

    // =========================================================================
    // OUTPUT ASSIGNMENT WITH X/Z PROTECTION
    // =========================================================================
    // These assignments protect against unknown (X) or high-impedance (Z) values
    // in simulation by defaulting to 0 if the internal signal is not 0 or 1
    // This prevents X propagation which could mask bugs during simulation
    //
    // Also applies special logic to StallF for conditional jump handling
    assign FlushD = (FlushD_i !== 1'b0 && FlushD_i !== 1'b1) ? 1'b0 : FlushD_i;
    assign FlushE = (FlushE_i !== 1'b0 && FlushE_i !== 1'b1) ? 1'b0 : FlushE_i;
    assign StallD = (StallD_i !== 1'b0 && StallD_i !== 1'b1) ? 1'b0 : StallD_i;
    assign StallF = (StallF_i !== 1'b0 && StallF_i !== 1'b1) ? 1'b0 : 
                    (StallF_i & !cond_jmp_stall);  // Don't stall during conditional jump evaluation
    
endmodule