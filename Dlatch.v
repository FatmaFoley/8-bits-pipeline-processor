// ------------------------------------------------------------
// Decode-to-Execute Latch (Pipeline Register)
// This module transfers control signals and data
// from Decode stage (D) to Execute stage (EX)
// ------------------------------------------------------------
module Dlatch(
    input  wire       clk , load_stallD, FlushE, 
    input  wire       mux3_s0D , D_mem_renD , D_mem_wenD, ccr_wenD, sp_mux_sD, 
    input  wire       valids1_D , valids2_D, RET_flushD, RET_enD,
    input  wire [1:0] mux9_sD , s1D , s2D , dest_addrD, reg_file_wenD,
    input  wire [2:0] mux8_sD, 
    input  wire [2:0] mux10_sD, 
    input  wire [3:0] alu_opD, 
    input  wire [7:0] data_out2D , instrD, data_out1D, Imm_D,
    input  wire [7:0] pcD   , sub_outD  ,

    output reg        mux3_s0EX , D_mem_renEX , D_mem_wenEX, ccr_wenEX, sp_mux_sEX, 
    output reg        load_stallEX , valids1_EX , valids2_EX, RET_flushEX,RET_enEX,
    output reg  [1:0] mux9_sEX, s1EX , s2EX , dest_addrEX , reg_file_wenEX,
    output reg  [2:0] mux8_sEX, 
    output reg  [2:0] mux10_sEX,
    output reg  [3:0] alu_opEX,
    output reg  [7:0] sub_outEX , data_out1EX, data_out2EX ,pcEX , instrEX, Imm_EX
);

    // Sequential logic: update on rising edge of the clock
    always @(posedge clk) begin

        // ----------------------------------------------------
        // Flush Execute stage (insert NOP)
        // Used in branch misprediction / hazards
        // ----------------------------------------------------
        if (FlushE) begin
                pcEX           <= 8'b0;
                sub_outEX      <= 8'b0;
                reg_file_wenEX <= 2'b00;
                s1EX           <= 2'b00;
                s2EX           <= 2'b00;
                dest_addrEX    <= 2'b00;
                mux3_s0EX      <= 1'b0;
                mux8_sEX       <= 3'b000;  
                mux9_sEX       <= 2'b00;   
                mux10_sEX      <= 3'b000; 
                data_out1EX    <= 8'b0;
                data_out2EX    <= 8'b0;
                instrEX        <= 8'b0;
                alu_opEX       <= 4'b0000; 
                D_mem_renEX    <= 1'b0;
                D_mem_wenEX    <= 1'b0; 
                ccr_wenEX      <= 1'b0; 
                sp_mux_sEX     <= 1'b0;
                load_stallEX   <= 1'b0;
                valids1_EX     <= 1'b0;
                valids2_EX     <= 1'b0;
        end 

        // ----------------------------------------------------
        // Normal operation:
        // Transfer Decode-stage signals to Execute-stage
        // ----------------------------------------------------
        else begin
                pcEX           <= pcD;
                sub_outEX      <= sub_outD;
                reg_file_wenEX <= reg_file_wenD;
                s1EX           <= s1D;
                s2EX           <= s2D;
                dest_addrEX    <= dest_addrD;
                mux3_s0EX      <= mux3_s0D;
                mux8_sEX       <= mux8_sD;  
                mux9_sEX       <= mux9_sD;   
                mux10_sEX      <= mux10_sD; 
                data_out1EX    <= data_out1D;
                data_out2EX    <= data_out2D;
                instrEX        <= instrD;
                alu_opEX       <= alu_opD; 
                D_mem_renEX    <= D_mem_renD;
                D_mem_wenEX    <= D_mem_wenD; 
                ccr_wenEX      <= ccr_wenD; 
                sp_mux_sEX     <= sp_mux_sD;
                load_stallEX   <= load_stallD;
                valids1_EX     <= valids1_D;
                valids2_EX     <= valids2_D;
                Imm_EX         <= Imm_D;
                RET_flushEX    <= RET_flushD;
                RET_enEX       <= RET_enD;
        end
    
    end
    
endmodule
