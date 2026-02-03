//======================================================
// Decode Cycle Module
// Responsible for instruction decoding, control signal
// generation, register file access, and passing signals
// to the Execute stage
//======================================================

module decode_cycle (
    // -------------------------
    // Global control signals
    // -------------------------
    input wire         clk, interrupt,
    input wire         reset, sp_mux_sWB_out, FlushE, RET_enWB,

    // -------------------------
    // Write-back stage signals
    // -------------------------
    input wire  [1:0]  dest_addrWB, reg_file_wenWB,
    input wire  [3:0]  ALU_Flags,
    input wire  [7:0]  WB_data, ALU_resultWB,

    // -------------------------
    // Decode stage inputs
    // -------------------------
    input wire  [7:0]  instrD , pcD, Imm_D,

    // -------------------------
    // Control outputs
    // -------------------------
    output wire loop_en , mux3_s0EX, jmp_enD, load_stallEX,
                valids1_D , valids2_D, cond_jmp_stall,
                RET_enEX, ccr_wenEX,

    output wire D_mem_renEX, valids1_EX , valids2_EX,
                IR_en, RET_flushD , RET_flushEX,

    output wire D_mem_wenEX,
    output wire or_out, sp_mux_sEX,

    // -------------------------
    // Selector and control buses
    // -------------------------
    output wire [1:0] mux9_sEX, reg_file_wenEX, 
    output wire [1:0] s1EX , s2EX , dest_addrEX, s1D , s2D,
    output wire [2:0] mux1_sD,
    output wire [2:0] mux8_sEX, 
    output wire [2:0] mux10_sEX,
    output wire [3:0] alu_opEX,

    // -------------------------
    // Data outputs to EX stage
    // -------------------------
    output wire [7:0] sub_outEX, instrEX, pcEX,
    output wire [7:0] data_out1EX , data_out2EX, Imm_EX,

    // -------------------------
    // I/O related outputs
    // -------------------------
    output wire [7:0] out_port , data_out2D
);

    // --------------------------------------------------
    // Internal wires for Decode stage
    // --------------------------------------------------
    wire mux3_s0D , demux_s0, sp_mux_sD;
    wire load_stallD , RET_enD , RTI_en;
    wire D_mem_renD, D_mem_wenD;
    wire ccr_wenD;

    wire [1:0] addr_in1, addr_in2, reg_file_wenD;
    wire [1:0] dest_addrD;
    wire [2:0] mux8_sD;
    wire [1:0] mux9_sD;
    wire [2:0] mux10_sD;
    wire [3:0] ccr_data , alu_opD;

    wire [7:0] sub_outD , data_out1D, data_out2, sp_mux_out;

    // --------------------------------------------------
    // Condition Code Register (CCR)
    // Stores ALU flags and supports interrupt handling
    // --------------------------------------------------
    CCR CCR_Reg (
        .clk(clk),
        .reset(reset),
        .RTI_en(RTI_en),
        .interruptD(interrupt),
        .ccr_wen(ccr_wenEX),
        .ALU_Flags(ALU_Flags),
        .ccr_out(ccr_data)
    );

    // --------------------------------------------------
    // Stack pointer mux (WB data vs ALU result)
    // --------------------------------------------------
    MUX_2_1_8bits sp_mux (
        .Mux_sel(sp_mux_sWB_out),
        .Mux_in1(WB_data),
        .Mux_in2(ALU_resultWB),
        .Mux_out(sp_mux_out)
    );

    // --------------------------------------------------
    // Control Unit
    // Generates all control signals for Decode stage
    // --------------------------------------------------
    control_unit CU(
        .ccr_data(ccr_data),
        .instrD(instrD),
        .interruptD(interrupt),
        .valids1_D(valids1_D),
        .valids2_D(valids2_D),
        .IR_en(IR_en),
        .RTI_en(RTI_en),
        .RET_en(RET_enD),
        .RET_flush(RET_flushD),
        .RET_enWB(RET_enWB),
        .s1D(s1D),
        .s2D(s2D),
        .alu_opD(alu_opD),
        .jmp_en(jmp_enD),
        .cond_jmp_stall(cond_jmp_stall),
        .load_stall(load_stallD),
        .addr_in1(addr_in1),
        .addr_in2(addr_in2),
        .dest_addrD(dest_addrD),
        .mux1_sD(mux1_sD),
        .mux3_s0D(mux3_s0D),
        .mux8_sD(mux8_sD),
        .mux9_sD(mux9_sD),
        .mux10_sD(mux10_sD),
        .sp_mux_sD(sp_mux_sD),
        .loop_en(loop_en),
        .demux_s0(demux_s0),
        .reg_file_wenD(reg_file_wenD),
        .ccr_wen(ccr_wenD),
        .mem_wen_D(D_mem_wenD),
        .mem_ren_D(D_mem_renD)
    );

    // --------------------------------------------------
    // Register File
    // Reads source operands and writes back WB results
    // --------------------------------------------------
    RegFile RF (
        .clk(clk),
        .reset(reset),
        .addr_in1(addr_in1),
        .addr_in2(addr_in2),
        .data_out1(data_out1D),
        .data_out2(data_out2),
        .reg_file_wen(reg_file_wenWB),
        .dest_addr(dest_addrWB),
        .data_in1(WB_data),
        .data_in2(sp_mux_out)
    );

    // --------------------------------------------------
    // Subtractor (used for loop / decrement operations)
    // --------------------------------------------------
    subtractor SUB(
        .in1(data_out1D),
        .in2(8'b00000001),
        .out(sub_outD)
    );

    // --------------------------------------------------
    // OR gate (used for zero/loop detection)
    // --------------------------------------------------
    OR_GATE OR(
        .or_in(sub_outD),
        .or_out(or_out)
    );

    // --------------------------------------------------
    // Demultiplexer for output port handling
    // --------------------------------------------------
    demux Demux(
        .demux_in(data_out2),
        .demux_s0(demux_s0),
        .data_out1(out_port),
        .data_out2(data_out2D)
    );

    // --------------------------------------------------
    // Decode/Execute pipeline latch (Dlatch)
    // Passes Decode stage outputs to Execute stage
    // --------------------------------------------------
    Dlatch dlatch(
        .clk(clk),
        .FlushE(FlushE),
        .load_stallD(load_stallD),
        .valids1_D(valids1_D),
        .valids2_D(valids2_D),
        .pcD(pcD),
        .sub_outD(sub_outD),
        .s1D(s1D),
        .s2D(s2D),
        .dest_addrD(dest_addrD),
        .reg_file_wenD(reg_file_wenD),
        .mux3_s0D(mux3_s0D),
        .mux8_sD(mux8_sD),
        .mux9_sD(mux9_sD),
        .mux10_sD(mux10_sD),
        .data_out1D(data_out1D),
        .data_out2D(data_out2D),
        .instrD(instrD),
        .alu_opD(alu_opD),
        .D_mem_renD(D_mem_renD),
        .D_mem_wenD(D_mem_wenD),
        .ccr_wenD(ccr_wenD),
        .sp_mux_sD(sp_mux_sD),
        .Imm_D(Imm_D),
        .RET_flushD(RET_flushD),
        .RET_enD(RET_enD),

        // Outputs to Execute stage
        .sub_outEX(sub_outEX),
        .s1EX(s1EX),
        .s2EX(s2EX),
        .dest_addrEX(dest_addrEX),
        .data_out1EX(data_out1EX),
        .data_out2EX(data_out2EX),
        .pcEX(pcEX),
        .instrEX(instrEX),
        .reg_file_wenEX(reg_file_wenEX),
        .mux3_s0EX(mux3_s0EX),
        .mux8_sEX(mux8_sEX),
        .mux9_sEX(mux9_sEX),
        .mux10_sEX(mux10_sEX),
        .D_mem_renEX(D_mem_renEX),
        .D_mem_wenEX(D_mem_wenEX),
        .alu_opEX(alu_opEX),
        .ccr_wenEX(ccr_wenEX),
        .sp_mux_sEX(sp_mux_sEX),
        .valids1_EX(valids1_EX),
        .valids2_EX(valids2_EX),
        .load_stallEX(load_stallEX),
        .Imm_EX(Imm_EX),
        .RET_flushEX(RET_flushEX),
        .RET_enEX(RET_enEX)
    );

endmodule
