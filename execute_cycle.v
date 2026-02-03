// ------------------------------------------------------------
// Execute Cycle
// This stage performs ALU operations, hazard forwarding,
// and passes results to the Memory stage
// ------------------------------------------------------------
module execute_cycle (
    input wire   clk, 
    input wire   mux3_s0EX , RET_flushEX, RET_enEX,
    input wire   [1:0] mux9sEX, dest_addrEX , reg_file_wenEX,
    input wire   [2:0] mux8sEX, 
    input wire   [2:0] mux10sEX,
    input wire   [3:0] alu_opEX,
    input wire   [7:0] sub_outEX , data_out1EX, data_out2EX ,pcEX , instrEX, WB_data, Imm_EX,
    input wire   Hazard_s0 , Hazard_s1 , Hazard_s2 , Hazard_s3, sp_mux_sEX,
    input wire   D_mem_renEX , D_mem_wenEX,

    output wire        D_mem_wenM, D_mem_renM, sp_mux_sM, RET_flushM, RET_enM,
    output wire [1:0]  mux9sM, dest_addrM, reg_file_wenM,
    output wire [2:0]  mux8sM, mux10sM,
    output wire [3:0]  ALU_flags,
    output wire [7:0]  ALU_resultM, pcM, sub_outM, instrM, Imm_M,
    output wire [7:0]  data_out1M, data_out2M
);

    // Internal ALU signals
    wire [7:0]  ALU_in1EX, ALU_in2EX, ALU_resultEX;

    // Outputs of intermediate multiplexers
    wire [7:0]  mux3_outEX, mux4_outEX, mux6_outEX;

    // --------------------------------------------------------
    // Mux3:
    // Selects between PC value and second operand from register
    // --------------------------------------------------------
    MUX_2_1_8bits Mux3 (
        .Mux_sel(mux3_s0EX),
        .Mux_in1(pcEX),
        .Mux_in2(data_out2EX),
        .Mux_out(mux3_outEX)
    );

    // --------------------------------------------------------
    // Mux4:
    // Hazard forwarding (MEM stage vs WB stage)
    // --------------------------------------------------------
    MUX_2_1_8bits Mux4 (
        .Mux_sel(Hazard_s1),
        .Mux_in1(ALU_resultM),
        .Mux_in2(WB_data),
        .Mux_out(mux4_outEX)
    );

    // --------------------------------------------------------
    // Mux5:
    // Selects ALU second operand
    // Normal path or forwarded data
    // --------------------------------------------------------
    MUX_2_1_8bits Mux5 (
        .Mux_sel(Hazard_s0),
        .Mux_in1(mux4_outEX),
        .Mux_in2(mux3_outEX),
        .Mux_out(ALU_in2EX)
    );

    // --------------------------------------------------------
    // Mux6:
    // Another hazard forwarding path
    // --------------------------------------------------------
    MUX_2_1_8bits Mux6 (
        .Mux_sel(Hazard_s3),
        .Mux_in1(ALU_resultM),
        .Mux_in2(WB_data),
        .Mux_out(mux6_outEX)
    );

    // --------------------------------------------------------
    // Mux7:
    // Selects ALU first operand
    // Normal register value or forwarded data
    // --------------------------------------------------------
    MUX_2_1_8bits Mux7 (
        .Mux_sel(Hazard_s2),
        .Mux_in1(data_out1EX),
        .Mux_in2(mux6_outEX),
        .Mux_out(ALU_in1EX)
    );

    // --------------------------------------------------------
    // ALU Unit
    // Performs arithmetic / logic operations
    // and generates condition flags
    // --------------------------------------------------------
    ALU ALU_Unit (
        .A(ALU_in1EX),
        .B(ALU_in2EX),
        .alu_op(alu_opEX),
        .R(ALU_resultEX),
        .Z(ALU_flags[0]),   // Zero flag
        .N(ALU_flags[1]),   // Negative flag
        .C(ALU_flags[2]),   // Carry flag
        .V(ALU_flags[3])    // Overflow flag
    );

    // --------------------------------------------------------
    // EX/MEM Pipeline Latch
    // Transfers results and control signals
    // from Execute stage to Memory stage
    // --------------------------------------------------------
    exlatch latchEX (
        .clk(clk),
        .reg_file_wenEX(reg_file_wenEX),
        .D_mem_wenEX(D_mem_wenEX),
        .D_mem_renEX(D_mem_renEX),
        .mux8sEX(mux8sEX),
        .mux9sEX(mux9sEX),
        .mux10sEX(mux10sEX),
        .dest_addrEX(dest_addrEX),
        .instrEX(instrEX),
        .data_out1EX(data_out1EX),
        .data_out2EX(data_out2EX),
        .sub_outEX(sub_outEX),
        .pcEX(pcEX),
        .ALU_resultEX(ALU_resultEX),
        .sp_mux_sEX(sp_mux_sEX),
        .Imm_EX(Imm_EX),
        .RET_flushEX(RET_flushEX),
        .RET_enEX(RET_enEX),

        .reg_file_wenM(reg_file_wenM),
        .D_mem_wenM(D_mem_wenM),
        .D_mem_renM(D_mem_renM), 
        .mux8sM(mux8sM), 
        .mux9sM(mux9sM), 
        .mux10sM(mux10sM), 
        .dest_addrM(dest_addrM),
        .instrM(instrM),  
        .data_out1M(data_out1M), 
        .data_out2M(data_out2M),
        .sub_outM(sub_outM),
        .pcM(pcM), 
        .ALU_resultM(ALU_resultM),
        .sp_mux_sM(sp_mux_sM),
        .Imm_M(Imm_M),
        .RET_flushM(RET_flushM),
        .RET_enM(RET_enM)
    );

endmodule
