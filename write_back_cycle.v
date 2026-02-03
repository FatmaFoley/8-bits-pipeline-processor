// ------------------------- Write Back Stage -------------------------
// Selects the correct data to write back to the Register File or SP
// Data can come from ALU, Memory, Subtractor, Immediate, or Input Port
module write_back_cycle (
    input  wire        sp_mux_sWB,        // Special signal to select SP
    input  wire [7:0]  port_in_data,      // Data from external input port
    input  wire [7:0]  Imm_M,             // Immediate value from instruction
    input  wire [1:0]  reg_file_wenWB_IN, // Register File write enable input
    input  wire [2:0]  mux10_sWB,         // Selector for WB MUX
    input  wire [7:0]  ALU_resultWB,      // Result from ALU
    input  wire [7:0]  data_mem_outWB,    // Data from Memory
    input  wire [7:0]  sub_outWB,         // Result from subtractor
    output wire        sp_mux_sWB_out,    // Output SP selection signal
    output wire [1:0]  reg_file_wenWB,    // Register File write enable output
    output wire [7:0]  WB_data            // Data to write back
);

    // Pass the write enable and SP select signals through
    assign reg_file_wenWB = reg_file_wenWB_IN;
    assign sp_mux_sWB_out = sp_mux_sWB;

    // Select which data to write back using an 8-to-1 MUX
    MUX_8_1 Mux8 (
        .Mux_in1(8'b00000000),   // Default / don't care
        .Mux_in2(port_in_data),  // From external input port
        .Mux_in3(ALU_resultWB),  // From ALU
        .Mux_in4(data_mem_outWB),// From Data Memory
        .Mux_in5(sub_outWB),     // From Subtractor
        .Mux_in6(Imm_M),         // Immediate value
        .Mux_in7(8'b00000000),   // Don't care
        .Mux_in8(8'b00000000),   // Don't care
        .Mux_sel(mux10_sWB),     // Select signal
        .Mux_out(WB_data)        // Output to write back
    );

endmodule
