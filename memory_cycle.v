module memory_cycle (
    input wire        clk,
    input  wire        D_mem_wenM, D_mem_renM, sp_mux_sM, RET_enM,   // Memory control and special signals
    input  wire [1:0]  mux9sM, dest_addrM, reg_file_wenM,             // Mux select signals and register info
    input  wire [2:0]  mux8sM, mux10sM ,
    input  wire [7:0]  ALU_resultM, pcM, sub_outM, instrM, Imm_EX,   // EX stage outputs and immediate
    input  wire [7:0]  data_out1M, data_out2M,                        // Data outputs for forwarding

    output wire        sp_mux_sWB,  RET_enWB,                         // Signals to Writeback stage
    output wire [1:0]  dest_addrWB, reg_file_wenWB,
    output wire [2:0]  mux10_sWB,
    output wire [7:0]  ALU_resultWB, data_mem_outWB, sub_outWB , instrWB, data_mem_outM // WB outputs
);

wire [7:0] mux9_out, mux8_out; // Internal wires for MUX outputs

// -----------------------------
// MUX8: Selects the address/input for data memory or other operations
// -----------------------------
MUX_8_1 Mux8 (
    .Mux_in1(sub_outM),           // Option 1: decremented value from subtractor
    .Mux_in2(data_out2M),         // Option 2: data_out2 from EX stage
    .Mux_in3(data_out1M),         // Option 3: data_out1 from EX stage
    .Mux_in4(ALU_resultM),        // Option 4: result from ALU
    .Mux_in5(Imm_EX),             // Option 5: Immediate value
    .Mux_in6({RET_enWB , 7'b0}),  // Option 6: RET signal in MSB (rest don't care)
    .Mux_in7(8'b00000000),        // Option 7: don't care
    .Mux_in8(8'b00000000),        // Option 8: don't care
    .Mux_sel(mux8sM),             // Selection signal from EX/M stage
    .Mux_out(mux8_out)            // Output address/data for DataMemory
);

// -----------------------------
// MUX9: Selects data to write into Data Memory
// -----------------------------
MUX_4_1 Mux9 (
    .Mux_in1(ALU_resultM),        // Option 1: ALU result
    .Mux_in2(data_out1M),         // Option 2: data_out1
    .Mux_in3(pcM),                // Option 3: Program Counter
    .Mux_in4(8'b00000000),        // Option 4: don't care
    .Mux_sel(mux9sM),             // Selection signal from EX/M stage
    .Mux_out(mux9_out)            // Data input for DataMemory
);

// -----------------------------
// Data Memory instance
// -----------------------------
DataMemory Data_Mem (
    .clk(clk),
    .wen(D_mem_wenM),             // Write enable
    .ren(D_mem_renM),             // Read enable
    .addr(mux8_out),              // Address from MUX8
    .write_data(mux9_out),        // Data to write from MUX9
    .read_data(data_mem_outM)     // Data read from memory
);

// -----------------------------
// Memory stage latch (Mlatch)
// Stores signals from Memory stage to pass to Writeback stage
// -----------------------------
Mlatch mlatch(
    .clk(clk),
    .reg_file_wenM(reg_file_wenM),
    .dest_addrM(dest_addrM),
    .mux10_sM(mux10sM),
    .ALU_resultM(ALU_resultM),
    .data_mem_outM(data_mem_outM),
    .sub_outM(sub_outM),
    .instrM(instrM),
    .sp_mux_sM(sp_mux_sM),
    .RET_enM(RET_enM),

    .reg_file_wenWB(reg_file_wenWB),
    .dest_addrWB(dest_addrWB),
    .mux10_sWB(mux10_sWB),
    .ALU_resultWB(ALU_resultWB),
    .data_mem_outWB(data_mem_outWB),
    .sub_outWB(sub_outWB),
    .instrWB(instrWB),
    .sp_mux_sWB(sp_mux_sWB),
    .RET_enWB(RET_enWB)
);

endmodule
