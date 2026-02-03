// ------------------------- TOP Module -------------------------
// Integrates all pipeline stages: Fetch, Decode, Execute, Memory, WriteBack
// Handles hazards and control signals for proper instruction execution
module TOP(
    input  wire        CLK,        // System clock
    input  wire        RESET_IN,   // System reset
    input  wire        INTR_IN,    // Interrupt input
    input  wire [7:0]  IN_PORT,    // Input port for external data
    output wire [7:0]  OUT_PORT    // Output port
);

    // ------------------------- Control & Hazard Signals -------------------------
    wire       loop_en, or_out;
    wire       valids1_D , valids2_D , valids1_EX , valids2_EX , IR_en;
    wire       Hazard_s0 , Hazard_s1 , Hazard_s2 , Hazard_s3;
    wire       jmp_enD , load_stallEX;
    wire       FlushD ,FlushE , StallF, StallD;
    wire       sp_mux_sWB_out , ccr_wenEX;
    wire       cond_jmp_stall , RET_flushD , RET_flushEX , RET_flushM;
    wire       RET_enEX , RET_enM , RET_enWB;
    wire       D_mem_wenEX, D_mem_renEX;
    wire       D_mem_wenM,  D_mem_renM;
    wire       mux3_s0EX, sp_mux_sEX, sp_mux_sM, sp_mux_sWB;

    // ------------------------- Register & ALU Signals -------------------------
    wire [1:0] s1D , s2D, s1EX, s2EX, dest_addrEX;
    wire [1:0] dest_addrM, dest_addrWB;
    wire [1:0] reg_file_wenEX, reg_file_wenM, reg_file_wenWB , reg_file_wenWB_IN;
    wire [1:0] mux9_sEX, mux9_sM;
    wire [2:0] mux8_sEX, mux8_sM, mux10_sEX, mux10_sM, mux10_sWB, mux1_sel;
    wire [3:0] alu_opEX;
    wire [3:0] ALU_flags , Opcode;

    wire [7:0] data_out2D, instrD, instrEX , instrM , instrWB , Imm_D , Imm_EX , Imm_M;
    wire [7:0] pcF, pcD, pcEX, pcM;
    wire [7:0] sub_outEX, sub_outM, sub_outWB;
    wire [7:0] data_out1EX, data_out2EX;
    wire [7:0] data_out1M,  data_out2M;
    wire [7:0] WB_data;
    wire [7:0] ALU_resultM, ALU_resultWB;
    wire [7:0] data_mem_outM, data_mem_outWB;

    // ------------------------- Fetch Stage -------------------------
    fetch_cycle fetch_stage (
        .clk          (CLK),
        .reset        (RESET_IN),
        .loop_en      (loop_en),
        .IR_en        (IR_en),
        .Imm_D        (Imm_D),
        .FlushD       (FlushD),
        .StallF       (StallF),
        .StallD       (StallD),
        .or_out       (or_out),
        .mux1_sel     (mux1_sel),
        .data_out2    (data_out2D),
        .data_mem_out (data_mem_outM),
        .instrD       (instrD),
        .Opcode       (Opcode),
        .pcD          (pcD)
    );

    // ------------------------- Decode Stage -------------------------
    decode_cycle decode_stage (
        .clk            (CLK),
        .reset          (RESET_IN),
        .interrupt      (INTR_IN),
        .Imm_D          (Imm_D),
        .FlushE         (FlushE),
        .ALU_Flags      (ALU_flags),
        .WB_data        (WB_data),
        .instrD         (instrD),
        .pcD            (pcD),
        .dest_addrWB    (dest_addrWB),
        .ccr_wenEX      (ccr_wenEX),
        .ALU_resultWB   (ALU_resultWB),
        .loop_en        (loop_en),
        .or_out         (or_out),
        .s1D            (s1D),
        .s2D            (s2D),
        .RET_flushD     (RET_flushD),
        .RET_enWB       (RET_enWB),
        .reg_file_wenEX (reg_file_wenEX),
        .reg_file_wenWB (reg_file_wenWB),
        .mux3_s0EX      (mux3_s0EX),
        .D_mem_renEX    (D_mem_renEX),
        .D_mem_wenEX    (D_mem_wenEX),
        .sp_mux_sWB_out (sp_mux_sWB_out),
        .jmp_enD        (jmp_enD),
        .load_stallEX   (load_stallEX),
        .cond_jmp_stall (cond_jmp_stall),
        .mux1_sD        (mux1_sel),
        .mux8_sEX       (mux8_sEX),
        .mux9_sEX       (mux9_sEX),
        .mux10_sEX      (mux10_sEX),
        .valids1_D      (valids1_D),
        .valids2_D      (valids2_D),
        .valids1_EX     (valids1_EX),
        .valids2_EX     (valids2_EX),
        .IR_en          (IR_en),
        .alu_opEX       (alu_opEX),
        .sub_outEX      (sub_outEX),
        .instrEX        (instrEX),
        .pcEX           (pcEX),
        .s1EX           (s1EX),
        .s2EX           (s2EX),
        .Imm_EX         (Imm_EX),
        .RET_enEX       (RET_enEX),
        .RET_flushEX    (RET_flushEX),
        .dest_addrEX    (dest_addrEX),
        .data_out1EX    (data_out1EX),
        .data_out2EX    (data_out2EX),
        .sp_mux_sEX     (sp_mux_sEX),
        .data_out2D     (data_out2D),
        .out_port       (OUT_PORT)
    );

    // ------------------------- Execute Stage -------------------------
    execute_cycle execute_stage (
        .clk            (CLK),
        .mux3_s0EX      (mux3_s0EX),
        .reg_file_wenEX (reg_file_wenEX),
        .RET_enEX       (RET_enEX),
        .alu_opEX       (alu_opEX),
        .Hazard_s0      (Hazard_s0),
        .Hazard_s1      (Hazard_s1),
        .Hazard_s2      (Hazard_s2),
        .Hazard_s3      (Hazard_s3),
        .instrEX        (instrEX),
        .WB_data        (WB_data),
        .data_out1EX    (data_out1EX),
        .data_out2EX    (data_out2EX),
        .sub_outEX      (sub_outEX),
        .Imm_EX         (Imm_EX),
        .RET_flushEX    (RET_flushEX),
        .dest_addrEX    (dest_addrEX),
        .pcEX           (pcEX),

        .D_mem_wenEX    (D_mem_wenEX),
        .D_mem_renEX    (D_mem_renEX),
        .mux8sEX        (mux8_sEX),
        .mux9sEX        (mux9_sEX),
        .mux10sEX       (mux10_sEX),

        .mux8sM         (mux8_sM),
        .mux9sM         (mux9_sM),
        .mux10sM        (mux10_sM),
        .sp_mux_sEX     (sp_mux_sEX),
        .pcM            (pcM),
        .Imm_M          (Imm_M),
        .dest_addrM     (dest_addrM),
        .D_mem_renM     (D_mem_renM),
        .D_mem_wenM     (D_mem_wenM),
        .reg_file_wenM  (reg_file_wenM),
        .ALU_flags      (ALU_flags),
        .ALU_resultM    (ALU_resultM),
        .sub_outM       (sub_outM),
        .instrM         (instrM),
        .data_out1M     (data_out1M),
        .data_out2M     (data_out2M),
        .RET_flushM     (RET_flushM),
        .RET_enM        (RET_enM),
        .sp_mux_sM      (sp_mux_sM)
    );

    // ------------------------- Memory Stage -------------------------
    memory_cycle mem_stage (
        .clk              (CLK),
        .pcM              (pcM),
        .reg_file_wenM    (reg_file_wenM),
        .D_mem_wenM       (D_mem_wenM),
        .D_mem_renM       (D_mem_renM),
        .data_mem_outM    (data_mem_outM),
        .mux9sM           (mux9_sM),
        .mux8sM           (mux8_sM),
        .mux10sM          (mux10_sM),
        .sp_mux_sM        (sp_mux_sM),
        .dest_addrM       (dest_addrM),
        .ALU_resultM      (ALU_resultM),
        .sub_outM         (sub_outM),
        .instrM           (instrM),
        .data_out1M       (data_out1M),
        .data_out2M       (data_out2M),
        .Imm_EX           (Imm_EX),
        .RET_enM          (RET_enM),
        .reg_file_wenWB   (reg_file_wenWB_IN),
        .dest_addrWB      (dest_addrWB),
        .ALU_resultWB     (ALU_resultWB),
        .data_mem_outWB   (data_mem_outWB),
        .sub_outWB        (sub_outWB),
        .mux10_sWB        (mux10_sWB),
        .instrWB          (instrWB),
        .sp_mux_sWB       (sp_mux_sWB),
        .RET_enWB         (RET_enWB)
    );

    // ------------------------- Write Back Stage -------------------------
    write_back_cycle write_stage (
        .reg_file_wenWB_IN (reg_file_wenWB_IN),
        .reg_file_wenWB    (reg_file_wenWB),
        .mux10_sWB         (mux10_sWB),
        .sp_mux_sWB        (sp_mux_sWB),
        .Imm_M             (Imm_M),

        .port_in_data      (IN_PORT),
        .ALU_resultWB      (ALU_resultWB),
        .data_mem_outWB    (data_mem_outWB),
        .sub_outWB         (sub_outWB),
        .WB_data           (WB_data),
        .sp_mux_sWB_out    (sp_mux_sWB_out)
    );

    // ------------------------- Hazard Detection Unit -------------------------
    hazard_unit HU (
        .s1EX             (s1EX),
        .s2EX             (s2EX),
        .s1D              (s1D),
        .s2D              (s2D),
        .Opcode           (Opcode),
        .RET_flushD       (RET_flushD),
        .RET_flushEX      (RET_flushEX),
        .RET_flushM       (RET_flushM),
        .dest_addrM       (dest_addrM),
        .dest_addrWB      (dest_addrWB),
        .dest_addrEX      (dest_addrEX),
        .valids1_D        (valids1_D),
        .valids2_D        (valids2_D),
        .valids1_EX       (valids1_EX),
        .valids2_EX       (valids2_EX),
        .reg_file_wenM    (reg_file_wenM),
        .reg_file_wenWB   (reg_file_wenWB),
        .D_Hazard_s0      (Hazard_s0),
        .D_Hazard_s1      (Hazard_s1),
        .D_Hazard_s2      (Hazard_s2),
        .D_Hazard_s3      (Hazard_s3),
        .jmp_enD          (jmp_enD),
        .cond_jmp_stall   (cond_jmp_stall),
        .load_stall       (load_stallEX),
        .loop_en          (loop_en),
        .or_out           (or_out),
        .FlushD           (FlushD),
        .FlushE           (FlushE),
        .StallD           (StallD),
        .StallF           (StallF)
    );

endmodule
