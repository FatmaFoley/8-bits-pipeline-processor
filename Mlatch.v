module Mlatch (
    input wire        clk,                    // Clock signal
    input wire        sp_mux_sM, RET_enM,     // Special signals from Memory stage
    input wire [1:0]  dest_addrM, reg_file_wenM, // Destination register info and write enable
    input wire [2:0]  mux10_sM,               // MUX select signal
    input wire [7:0]  ALU_resultM, data_mem_outM, sub_outM, instrM, // Data from Memory stage

    output reg        sp_mux_sWB, RET_enWB,   // Signals passed to Writeback stage
    output reg [1:0]  dest_addrWB, reg_file_wenWB,
    output reg [2:0]  mux10_sWB,
    output reg [7:0]  ALU_resultWB, data_mem_outWB, sub_outWB, instrWB
);

// -----------------------------
// Latch Memory → Writeback
// On each rising clock edge, store all EX/M → WB signals
// -----------------------------
always @(posedge clk) begin
        reg_file_wenWB <= reg_file_wenM;   // Write enable for register file
        mux10_sWB      <= mux10_sM;        // MUX selection signal
        ALU_resultWB   <= ALU_resultM;     // ALU result
        data_mem_outWB <= data_mem_outM;   // Data read from memory
        sub_outWB      <= sub_outM;        // Output from subtractor
        dest_addrWB    <= dest_addrM;      // Destination register address
        instrWB        <= instrM;          // Instruction to pass along
        sp_mux_sWB     <= sp_mux_sM;       // Special MUX signal
        RET_enWB       <= RET_enM;         // Return enable signal
end

endmodule
