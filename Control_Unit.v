`timescale 1ns/1ps

// =============================================================================
// Control Unit Module
// =============================================================================
// This module decodes instructions and generates control signals for a 
// pipelined processor. It handles various instruction types including:
// - Arithmetic/Logic operations (ADD, SUB, AND, OR, etc.)
// - Memory operations (LDM, LDD, STD, LDI, STI)
// - Control flow (JMP, CALL, RET, RTI, conditional jumps, LOOP)
// - Stack operations (PUSH, POP)
// - I/O operations (IN, OUT)
// - Special operations (interrupts, flag manipulation)
// =============================================================================

module control_unit(
    // Interrupt and return signals
    input  wire interruptD,           // Interrupt signal in decode stage
    input  wire RET_enWB,             // Return enable from writeback stage
    
    // Condition Code Register (CCR) input: {V, C, N, Z}
    input  wire [3:0]  ccr_data,      // V=overflow, C=carry, N=negative, Z=zero
    
    // Instruction from decode stage
    input  wire [7:0]  instrD,        // 8-bit instruction word
    
    // Register file control signals
    output reg [1:0] s1D,             // Source register 1 select
    output reg [1:0] s2D,             // Source register 2 select
    output reg [1:0] reg_file_wenD,   // Register file write enable (00=disabled, 01=normal, 10=SP, 11=both)
    output reg [1:0] dest_addrD,      // Destination register address
    output reg [1:0] addr_in1,        // Address input 1 for register file
    output reg [1:0] addr_in2,        // Address input 2 for register file
    
    // Multiplexer control signals
    output reg [1:0] mux9_sD,         // Mux 9 select (data memory address source)
    output reg [2:0] mux1_sD,         // Mux 1 select (PC source)
    output reg [2:0] mux8_sD,         // Mux 8 select (memory address source)
    output reg [2:0] mux10_sD,        // Mux 10 select (register writeback data source)
    
    // ALU control
    output reg [3:0] alu_opD,         // ALU operation code
    
    // Single-bit control signals
    output reg       mux3_s0D,        // Mux 3 select (CALL instruction specific)
    output reg       loop_en,         // Loop instruction enable
    output reg       demux_s0,        // Demux select (for OUT instruction)
    output reg       sp_mux_sD,       // Stack pointer mux select
    output reg       cond_jmp_stall,  // Conditional jump stall signal
    output reg       RTI_en,          // Return from interrupt enable
    output reg       ccr_wen,         // Condition code register write enable
    output reg       jmp_en,          // Jump enable (for PC update)
    output reg       load_stall,      // Load instruction stall signal
    output reg       valids1_D,       // Valid source 1 (for data hazard detection)
    output reg       valids2_D,       // Valid source 2 (for data hazard detection)
    output reg       RET_flush,       // Return instruction flush signal
    output reg       RET_en,          // Return instruction enable
    
    // Memory control signals
    output reg       mem_wen_D,       // Data memory write enable
    output reg       IR_en,           // Instruction register enable (for 2-word instructions)
    output reg       mem_ren_D        // Data memory read enable
);

// =============================================================================
// Instruction Decode Fields
// =============================================================================
// Extract fields from the 8-bit instruction word
// Format: [7:4] = opcode, [3:2] = ra (first operand), [1:0] = rb (second operand)
wire [3:0] opcode = instrD[7:4];    // Operation code
wire [1:0] ra     = instrD[3:2];    // First register operand / modifier
wire [1:0] rb     = instrD[1:0];    // Second register operand

// =============================================================================
// Condition Code Register (CCR) Bit Mapping
// =============================================================================
// Extract individual condition flags from CCR
wire Z = ccr_data[0];               // Zero flag
wire N = ccr_data[1];               // Negative flag
wire C = ccr_data[2];               // Carry flag
wire V = ccr_data[3];               // Overflow flag

// Internal state registers for multi-cycle instructions
reg LDM_en;                         // Load immediate (2nd cycle) enable
reg LDD_en;                         // Load direct (2nd cycle) enable
reg STD_en;                         // Store direct (2nd cycle) enable

// =============================================================================
// Main Combinational Logic - Instruction Decode and Control Signal Generation
// =============================================================================
always @(*) begin
    // -------------------------------------------------------------------------
    // Default Values - All control signals initialized to inactive state
    // -------------------------------------------------------------------------
    ccr_wen         = 1'b0;         // Don't update CCR by default
    alu_opD         = 4'b0000;      // ALU operation = NOP
    mem_wen_D       = 1'b0;         // Memory write disabled
    mem_ren_D       = 1'b0;         // Memory read disabled
    s1D             = 2'b00;        // Source 1 = R0
    s2D             = 2'b00;        // Source 2 = R0
    dest_addrD      = 2'b00;        // Destination = R0
    addr_in1        = 2'b00;        // Address input 1 = R0
    reg_file_wenD   = 2'b00;        // Register write disabled
    addr_in2        = 2'b00;        // Address input 2 = R0
    demux_s0        = 1'b0;         // Demux select = 0
    mux1_sD         = 3'b000;       // PC source = PC+1
    mux3_s0D        = 1'b0;         // Mux 3 select = 0
    mux8_sD         = 3'b000;       // Memory address source = default
    mux9_sD         = 2'b00;        // Memory data source = default
    mux10_sD        = 3'b000;       // Writeback data source = default
    loop_en         = 1'b0;         // Loop disabled
    sp_mux_sD       = 1'b0;         // Stack pointer mux = default
    jmp_en          = 1'b0;         // Jump disabled
    valids1_D       = 1'b0;         // Source 1 not valid (no hazard)
    valids2_D       = 1'b0;         // Source 2 not valid (no hazard)
    cond_jmp_stall  = 1'b0;         // No conditional jump stall
    IR_en           = 1'b0;         // Instruction register update disabled
    RTI_en          = 1'b0;         // Return from interrupt disabled
    load_stall      = 1'b0;         // No load stall
    RET_flush       = 1'b0;         // No return flush

    // -------------------------------------------------------------------------
    // Interrupt Handling - Highest Priority
    // -------------------------------------------------------------------------
    // When an interrupt occurs:
    // 1. Save PC to stack (mem write)
    // 2. Decrement SP
    // 3. Jump to interrupt handler
    if(interruptD) begin
        alu_opD         = 4'b1100;  // ALU op = decrement (for SP--)
        mem_wen_D       = 1'b1;     // Write PC to memory
        s1D             = 2'b11;    // Source 1 = SP
        dest_addrD      = 2'b11;    // Destination = SP
        reg_file_wenD   = 2'b10;    // Write to SP register
        addr_in2        = 2'b11;    // Address = SP
        mux1_sD         = 3'b010;   // PC source = interrupt vector
        mux8_sD         = 3'b001;   // Memory address = SP (before decrement)
        mux9_sD         = 2'b10;    // Memory data = PC (to save it)
        valids1_D       = 1'b1;     // SP is valid source
        jmp_en          = 1'b1;     // Enable jump to interrupt handler
        LDM_en          = 1'b0;
        LDD_en          = 1'b0;
        STD_en          = 1'b0;
        RET_en          = 1'b0;
    end 
    else begin
        // ---------------------------------------------------------------------
        // Normal Instruction Processing - Decode based on opcode
        // ---------------------------------------------------------------------
        case (opcode)
        
        // =====================================================================
        // Opcode 0000: NOP / Multi-cycle instruction continuation
        // =====================================================================
        // NOP is used both as a true no-operation and as the second cycle
        // of multi-word instructions (LDM, LDD, STD, RET)
        4'b0000: begin // NOP
            if(LDM_en) begin
                // Second cycle of LDM (Load Immediate) - write immediate value to register
                dest_addrD    = rb;         // Destination register
                mux10_sD      = 3'b101;     // Writeback source = immediate value
            end 
            else if(LDD_en)begin
                // Second cycle of LDD (Load Direct) - read from direct address
                mem_ren_D     = 1'b1;       // Enable memory read
                dest_addrD    = rb;         // Destination register
                mux10_sD      = 3'b011;     // Writeback source = memory data
            end 
            else if(STD_en) begin
                // Second cycle of STD (Store Direct) - write to direct address
                s1D           = rb;         // Source register to store
                addr_in1      = rb;
                mux8_sD       = 3'b100;     // Memory address = direct address
                mux9_sD       = 2'b01;      // Memory data = register value
                valids1_D     = 1'b1;       // Source register is valid
            end
            else if(RET_en) begin
                // Second cycle of RET - read return address from stack
                alu_opD       = 4'b1011;    // ALU op = increment (for SP++)
                s1D           = 2'b11;      // Source = SP
                mem_ren_D     = 1'b1;       // Read from memory
                dest_addrD    = 2'b11;      // Update SP
                reg_file_wenD = 2'b10;      // Write to SP
                addr_in2      = 2'b11;
                mux8_sD       = 3'b011;     // Memory address = SP
                mux10_sD      = 3'b010;     // SP writeback = incremented value
                valids1_D     = 1'b1;

                // Handle data hazard with RET in writeback stage
                if(RET_enWB) begin
                    mux1_sD = 3'b000;       // PC source = normal (no forwarding needed)
                end 
                else begin
                    mux1_sD = 3'b011;       // PC source = memory (forward return address)
                end
            end
            // Clear multi-cycle instruction flags
            LDM_en = 1'b0;
            LDD_en = 1'b0;
            STD_en = 1'b0;
            RET_en = 1'b0;
        end

        // =====================================================================
        // Opcode 0001: MOV - Move register to register
        // =====================================================================
        // Format: MOV ra, rb  (ra = rb)
        4'b0001: begin // MOV
            s1D             = rb;           // Source = rb
            dest_addrD      = ra;           // Destination = ra
            reg_file_wenD   = 2'b01;        // Enable normal register write
            mux10_sD        = 3'b010;       // Writeback source = register data
            addr_in2        = rb;
            valids1_D       = 1'b1;         // Source is valid
            LDM_en          = 1'b0;
            LDD_en          = 1'b0;
            STD_en          = 1'b0;
            RET_en          = 1'b0;
        end
        
        // =====================================================================
        // Opcode 0010: ADD - Add two registers
        // =====================================================================
        // Format: ADD ra, rb  (ra = ra + rb, update CCR)
        4'b0010: begin // ADD
            ccr_wen         = 1'b1;         // Update condition codes
            alu_opD         = 4'b0001;      // ALU operation = ADD
            s1D             = ra;           // First operand = ra
            s2D             = rb;           // Second operand = rb
            dest_addrD      = ra;           // Result destination = ra
            addr_in1        = ra;
            reg_file_wenD   = 2'b01;        // Enable register write
            addr_in2        = rb;
            mux10_sD        = 3'b010;       // Writeback = ALU result
            valids1_D       = 1'b1;         // Both sources are valid
            valids2_D       = 1'b1;
            LDM_en          = 1'b0;
            LDD_en          = 1'b0;
            STD_en          = 1'b0;
            RET_en          = 1'b0;
        end

        // =====================================================================
        // Opcode 0011: SUB - Subtract two registers
        // =====================================================================
        // Format: SUB ra, rb  (ra = ra - rb, update CCR)
        4'b0011: begin // SUB
            ccr_wen         = 1'b1;         // Update condition codes
            alu_opD         = 4'b0010;      // ALU operation = SUB
            s1D             = ra;
            s2D             = rb;
            dest_addrD      = ra;
            addr_in1        = ra;
            reg_file_wenD   = 2'b01;
            addr_in2        = rb;
            mux10_sD        = 3'b010;
            valids1_D       = 1'b1;
            valids2_D       = 1'b1;
            LDM_en          = 1'b0;
            LDD_en          = 1'b0;
            STD_en          = 1'b0;
            RET_en          = 1'b0;
        end

        // =====================================================================
        // Opcode 0100: AND - Bitwise AND
        // =====================================================================
        // Format: AND ra, rb  (ra = ra & rb, update CCR)
        4'b0100: begin // AND
            ccr_wen         = 1'b1;
            alu_opD         = 4'b0011;      // ALU operation = AND
            s1D             = ra;
            s2D             = rb;
            dest_addrD      = ra;
            addr_in1        = ra;
            reg_file_wenD   = 2'b01;
            addr_in2        = rb;
            mux10_sD        = 3'b010;
            valids1_D       = 1'b1;
            valids2_D       = 1'b1;
            LDM_en          = 1'b0;
            LDD_en          = 1'b0;
            STD_en          = 1'b0;
            RET_en          = 1'b0;
        end
        
        // =====================================================================
        // Opcode 0101: OR - Bitwise OR
        // =====================================================================
        // Format: OR ra, rb  (ra = ra | rb, update CCR)
        4'b0101: begin // OR
            ccr_wen         = 1'b1;
            alu_opD         = 4'b0100;      // ALU operation = OR
            s1D             = ra;
            s2D             = rb;
            dest_addrD      = ra;
            addr_in1        = ra;
            reg_file_wenD   = 2'b01;
            addr_in2        = rb;
            mux10_sD        = 3'b010;
            valids1_D       = 1'b1;
            valids2_D       = 1'b1;
            LDM_en          = 1'b0;
            LDD_en          = 1'b0;
            STD_en          = 1'b0;
            RET_en          = 1'b0;
        end
        
        // =====================================================================
        // Opcode 0110: Rotate and Carry Flag Instructions
        // =====================================================================
        // ra field selects specific operation:
        // 00 = RLC (Rotate Left through Carry)
        // 01 = RRC (Rotate Right through Carry)
        // 10 = SETC (Set Carry flag)
        // 11 = CLRC (Clear Carry flag)
        4'b0110: begin 
            if(ra == 2'b00) begin // RLC - Rotate Left through Carry
                ccr_wen         = 1'b1;     // Update carry flag
                alu_opD         = 4'b0101;  // ALU op = RLC
                s1D             = rb;       // Register to rotate
                dest_addrD      = rb;       // Result back to same register
                reg_file_wenD   = 2'b01;
                addr_in2        = rb;
                mux10_sD        = 3'b010;
                valids2_D       = 1'b1;
            end 
            else if(ra == 2'b01) begin // RRC - Rotate Right through Carry
                ccr_wen         = 1'b1;
                alu_opD         = 4'b0110;  // ALU op = RRC
                s1D             = rb;
                reg_file_wenD   = 2'b01;
                addr_in2        = rb;
                mux10_sD        = 3'b010;
                dest_addrD      = rb;
                valids2_D       = 1'b1;
            end 
            else if(ra == 2'b10) begin // SETC - Set Carry flag to 1
                ccr_wen         = 1'b1;
                alu_opD         = 4'b0111;  // ALU op = SETC
            end 
            else if(ra == 2'b11) begin // CLRC - Clear Carry flag to 0
                ccr_wen         = 1'b1;
                alu_opD         = 4'b1000;  // ALU op = CLRC
            end
            LDM_en          = 1'b0;
            LDD_en          = 1'b0;
            STD_en          = 1'b0;
            RET_en          = 1'b0;
        end
        
        // =====================================================================
        // Opcode 0111: Stack and I/O Instructions
        // =====================================================================
        // ra field selects operation:
        // 00 = PUSH (push register onto stack)
        // 01 = POP (pop from stack to register)
        // 10 = OUT (output register to I/O port)
        // 11 = IN (input from I/O port to register)
        4'b0111: begin
            if(ra == 2'b00) begin // PUSH - Push register onto stack
                alu_opD         = 4'b1100;  // ALU op = decrement (SP--)
                mem_wen_D       = 1'b1;     // Write to memory
                s1D             = 2'b11;    // Source 1 = SP
                s2D             = rb;       // Source 2 = register to push
                addr_in1        = rb;
                reg_file_wenD   = 2'b10;    // Update SP
                addr_in2        = 2'b11;
                mux8_sD         = 3'b001;   // Memory address = SP (before dec)
                mux9_sD         = 2'b01;    // Memory data = register value
                valids1_D       = 1'b1;
                valids2_D       = 1'b1;
            end 
            else if(ra == 2'b01) begin // POP - Pop from stack to register
                alu_opD         = 4'b1011;  // ALU op = increment (SP++)
                mem_ren_D       = 1'b1;     // Read from memory
                s1D             = 2'b11;    // Source = SP
                dest_addrD      = rb;       // Destination register
                reg_file_wenD   = 2'b11;    // Write both register and SP
                addr_in2        = 2'b11;
                mux8_sD         = 3'b011;   // Memory address = SP
                mux10_sD        = 3'b011;   // Writeback = memory data
                valids1_D       = 1'b1;
            end 
            else if(ra == 2'b10) begin // OUT - Output register to port
                s1D             = rb;       // Source register
                addr_in2        = rb;
                demux_s0        = 1'b1;     // Select output port
                valids1_D       = 1'b1;
            end 
            else if(ra == 2'b11) begin // IN - Input from port to register
                dest_addrD      = rb;       // Destination register
                reg_file_wenD   = 2'b01;    // Enable register write
                mux10_sD        = 3'b001;   // Writeback = input port data
            end
            LDM_en          = 1'b0;
            LDD_en          = 1'b0;
            STD_en          = 1'b0;
            RET_en          = 1'b0;
        end

        // =====================================================================
        // Opcode 1000: Unary ALU Operations
        // =====================================================================
        // ra field selects operation:
        // 00 = NOT (bitwise complement)
        // 01 = NEG (two's complement negation)
        // 10 = INC (increment by 1)
        // 11 = DEC (decrement by 1)
        4'b1000: begin
            if(ra == 2'b00) begin // NOT - Bitwise complement
                alu_opD  = 4'b1001;         // ALU op = NOT
            end 
            else if(ra == 2'b01) begin // NEG - Two's complement negation
                alu_opD  = 4'b1010;         // ALU op = NEG
            end 
            else if(ra == 2'b10) begin // INC - Increment
                alu_opD  = 4'b1011;         // ALU op = INC
            end 
            else if(ra == 2'b11) begin // DEC - Decrement
                alu_opD  = 4'b1100;         // ALU op = DEC
            end

            ccr_wen         = 1'b1;         // Update condition codes
            s1D             = rb;           // Operand register
            dest_addrD      = rb;           // Result to same register
            reg_file_wenD   = 2'b01;
            addr_in2        = rb;
            mux10_sD        = 3'b010;       // Writeback = ALU result
            valids1_D       = 1'b1;
            LDM_en          = 1'b0;
            LDD_en          = 1'b0;
            STD_en          = 1'b0;
            RET_en          = 1'b0;
        end

        // =====================================================================
        // Opcode 1001: Conditional Jump Instructions
        // =====================================================================
        // ra field selects condition:
        // 00 = JZ (Jump if Zero)
        // 01 = JN (Jump if Negative)
        // 10 = JC (Jump if Carry)
        // 11 = JV (Jump if Overflow)
        // rb contains target address register
        4'b1001: begin
            if(ra == 2'b00) begin // JZ - Jump if Zero flag set
                if (Z == 1) begin
                    s1D             = rb;   // Target address register
                    addr_in2        = rb;
                    mux1_sD         = 3'b001; // PC source = register
                    mux10_sD        = 3'b010;
                    valids1_D       = 1'b1;
                end
                jmp_en          = Z;        // Jump only if Z=1
                cond_jmp_stall  = 1'b1;     // Stall for condition evaluation
            end 
            else if(ra == 2'b01) begin // JN - Jump if Negative flag set
                if (N == 1) begin
                    s1D             = rb;
                    addr_in2        = rb;
                    mux1_sD         = 3'b001;
                    mux10_sD        = 3'b010;
                    valids1_D       = 1'b1;
                end
                jmp_en          = N;
                cond_jmp_stall  = 1'b1;
            end 
            else if(ra == 2'b10) begin // JC - Jump if Carry flag set
                if (C == 1) begin
                    s1D             = rb;
                    addr_in2        = rb;
                    mux1_sD         = 3'b001;
                    mux10_sD        = 3'b010;
                    valids1_D       = 1'b1;
                end
                jmp_en          = C;
                cond_jmp_stall  = 1'b1;
            end 
            else if(ra == 2'b11) begin // JV - Jump if Overflow flag set
                if (V == 1) begin
                    s1D             = rb;
                    addr_in2        = rb;
                    mux1_sD         = 3'b001;
                    mux10_sD        = 3'b010;
                    valids1_D       = 1'b1;
                end
                jmp_en          = V;
                cond_jmp_stall  = 1'b1;
            end
            LDM_en          = 1'b0;
            LDD_en          = 1'b0;
            STD_en          = 1'b0;
            RET_en          = 1'b0;
        end

        // =====================================================================
        // Opcode 1010: LOOP - Decrement and branch if not zero
        // =====================================================================
        // Format: LOOP ra, rb
        // Decrements ra, jumps to address in rb if ra != 0 after decrement
        4'b1010: begin // LOOP
            s1D             = ra;           // Counter register
            s2D             = rb;           // Target address register
            dest_addrD      = ra;           // Update counter
            addr_in1        = ra;
            reg_file_wenD   = 2'b01;        // Write decremented counter
            addr_in2        = rb;
            mux10_sD        = 3'b100;       // Writeback = decremented value
            loop_en         = 1'b1;         // Enable loop logic
            valids1_D       = 1'b1;
            valids2_D       = 1'b1;
            LDM_en          = 1'b0;
            LDD_en          = 1'b0;
            STD_en          = 1'b0;
            RET_en          = 1'b0;
        end

        // =====================================================================
        // Opcode 1011: Control Flow Instructions
        // =====================================================================
        // ra field selects operation:
        // 00 = JMP (unconditional jump)
        // 01 = CALL (call subroutine)
        // 10 = RET (return from subroutine)
        // 11 = RTI (return from interrupt)
        4'b1011: begin
            if(ra == 2'b00) begin // JMP - Unconditional jump
                s1D             = rb;       // Target address register
                addr_in2        = rb;
                mux1_sD         = 3'b001;   // PC source = register
                jmp_en          = 1'b1;     // Enable jump
                valids1_D       = 1'b1;
            end 
            else if(ra == 2'b01) begin // CALL - Call subroutine
                // Save return address (PC+1) to stack and jump
                alu_opD         = 4'b1011;  // ALU op = increment (for PC+1)
                mem_wen_D       = 1'b1;     // Write return address to stack
                s1D             = 2'b11;    // SP for stack operation
                s2D             = rb;       // Target address
                dest_addrD      = 2'b11;    // Update SP
                addr_in1        = 2'b11;
                reg_file_wenD   = 2'b10;    // Write to SP
                addr_in2        = rb;
                mux1_sD         = 3'b001;   // PC source = register (jump)
                mux3_s0D        = 1'b1;     // Select PC+1 for saving
                mux8_sD         = 3'b010;   // Memory address calculation
                mux10_sD        = 3'b100;   // SP writeback
                sp_mux_sD       = 1'b1;     // SP operation
                jmp_en          = 1'b1;
                valids1_D       = 1'b1;
                valids2_D       = 1'b1;
            end 
            else if(ra == 2'b10) begin // RET - Return from subroutine
                // First cycle: initiate stack read for return address
                alu_opD         = 4'b1011;  // ALU op = increment (SP++)
                s1D             = 2'b11;    // Source = SP
                mem_ren_D       = 1'b1;     // Read return address from stack
                dest_addrD      = 2'b11;    // Update SP
                reg_file_wenD   = 2'b10;    // Write to SP
                addr_in2        = 2'b11;
                mux1_sD         = 3'b011;   // PC source = memory (return addr)
                mux8_sD         = 3'b011;   // Memory address = SP
                mux10_sD        = 3'b010;   // SP writeback = incremented
                valids1_D       = 1'b1;
                RET_en          = 1'b1;     // Mark as RET instruction
                RET_flush       = 1'b1;     // Flush pipeline
            end 
            else if(ra == 2'b11) begin // RTI - Return from interrupt
                // Similar to RET but also restores interrupt state
                alu_opD         = 4'b1011;
                s1D             = 2'b11;
                mem_ren_D       = 1'b1;
                dest_addrD      = 2'b11;
                reg_file_wenD   = 2'b10;
                addr_in2        = 2'b11;
                mux1_sD         = 3'b011;
                mux8_sD         = 3'b011;
                mux10_sD        = 3'b010;
                valids1_D       = 1'b1;
                RET_en          = 1'b1;
                RET_flush       = 1'b1;
                RTI_en          = 1'b1;     // Enable interrupt restoration
            end
            LDM_en          = 1'b0;
            LDD_en          = 1'b0;
            STD_en          = 1'b0;
            RET_en          = 1'b0; 
        end

        // =====================================================================
        // Opcode 1100: Multi-word Memory Instructions
        // =====================================================================
        // These are 2-word instructions where second word is in next cycle
        // ra field selects operation:
        // 00 = LDM (Load immediate value)
        // 01 = LDD (Load from direct address)
        // 10 = STD (Store to direct address)
        4'b1100: begin
            if(ra == 2'b00) begin // LDM - Load immediate (1st cycle)
                dest_addrD      = rb;       // Destination register
                reg_file_wenD   = 2'b01;
                mux10_sD        = 3'b101;   // Writeback = immediate value
                jmp_en          = 1'b1;     // Advance PC
                LDM_en          = 1'b1;     // Flag for 2nd cycle
                LDD_en          = 1'b0;
                STD_en          = 1'b0;
                RET_en          = 1'b0;
            end 
            else if(ra == 2'b01) begin // LDD - Load direct (1st cycle)
                ccr_wen         = 1'b0;
                mem_wen_D       = 1'b0;
                mem_ren_D       = 1'b1;     // Read from memory
                dest_addrD      = rb;
                reg_file_wenD   = 2'b01;
                demux_s0        = 1'b0;
                mux1_sD         = 3'b000;
                mux8_sD         = 3'b100;   // Address = direct address (from next word)
                mux10_sD        = 3'b011;   // Writeback = memory data
                loop_en         = 1'b0;
                jmp_en          = 1'b1;     // Advance PC
                valids1_D       = 1'b0;
                valids2_D       = 1'b0;
                cond_jmp_stall  = 1'b0;
                LDD_en          = 1'b1;     // Flag for 2nd cycle
                LDM_en          = 1'b0;
                STD_en          = 1'b0;
                RET_en          = 1'b0;
            end 
            else if(ra == 2'b10) begin // STD - Store direct (1st cycle)
                mem_wen_D       = 1'b1;     // Write to memory
                s1D             = rb;       // Source register to store
                addr_in1        = rb;
                mux8_sD         = 3'b100;   // Address = direct address
                mux9_sD         = 2'b01;    // Data = register value
                jmp_en          = 1'b1;     // Advance PC
                valids1_D       = 1'b1;
                STD_en          = 1'b1;     // Flag for 2nd cycle
                LDM_en          = 1'b0;
                LDD_en          = 1'b0;
                RET_en          = 1'b0;
            end 
            else begin
                LDM_en          = 1'b0;
                LDD_en          = 1'b0;
                STD_en          = 1'b0;
                RET_en          = 1'b0;
            end
            IR_en           = 1'b1;         // Enable IR to capture next word
        end 

        // =====================================================================
        // Opcode 1101: LDI - Load Indirect
        // =====================================================================
        // Format: LDI ra, rb  (rb = Memory[ra])
        // Load value from memory address contained in ra into rb
        4'b1101: begin // LDI
            mem_ren_D       = 1'b1;         // Read from memory
            s1D             = ra;           // Address register
            dest_addrD      = rb;           // Destination register
            addr_in1        = ra;
            reg_file_wenD   = 1'b1;         // Enable register write
            mux8_sD         = 3'b010;       // Memory address = register value
            mux10_sD        = 3'b011;       // Writeback = memory data
            load_stall      = 1'b1;         // Stall for load-use hazard
            valids1_D       = 1'b1;         // Source is valid
            LDM_en          = 1'b0;
            LDD_en          = 1'b0;
            STD_en          = 1'b0;
            RET_en          = 1'b0;
        end
        
        // =====================================================================
        // Opcode 1110: STI - Store Indirect
        // =====================================================================
        // Format: STI ra, rb  (Memory[rb] = ra)
        // Store value from ra to memory address contained in rb
        4'b1110: begin // STI
            mem_wen_D       = 1'b1;         // Write to memory
            s1D             = ra;           // Source data register
            s2D             = rb;           // Address register
            addr_in1        = rb;
            addr_in2        = ra;
            mux8_sD         = 3'b001;       // Memory address = register value
            mux9_sD         = 2'b01;        // Memory data = register value
            valids1_D       = 1'b1;         // Both sources valid
            valids2_D       = 1'b1;
            LDM_en          = 1'b0;
            LDD_en          = 1'b0;
            STD_en          = 1'b0;
            RET_en          = 1'b0;
        end
        
        // =====================================================================
        // Default case - Unknown opcode
        // =====================================================================
        default: begin
            LDM_en          = 1'b0;
            LDD_en          = 1'b0;
            STD_en          = 1'b0;
            RET_en          = 1'b0;
        end
        endcase
    end
end

endmodule