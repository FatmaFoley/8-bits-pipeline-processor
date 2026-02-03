// ------------------------------------------------------------
// Fetch-to-Decode Latch (Pipeline Register)
// This module transfers instruction and PC
// from Fetch stage (F) to Decode stage (D)
// ------------------------------------------------------------
module Flatch(
    input       clk,        // system clock
    input       FlushD,      // flush signal for Decode stage
    input       StallD,      // stall signal (freeze Decode stage)
    input       [7:0] instrF,// instruction from Fetch stage
    input       [7:0] pcF,   // program counter from Fetch stage

    output reg  [7:0] instrD,// instruction to Decode stage
    output reg  [7:0] pcD    // program counter to Decode stage
);

    // Sequential logic: triggered on rising clock edge
    always @(posedge clk) begin

        // ----------------------------------------------------
        // Flush Decode stage (insert NOP)
        // Used for branch / control hazards
        // ----------------------------------------------------
        if(FlushD) begin
            instrD <= 8'b0;
            pcD    <= 8'b0;
        end 

        // ----------------------------------------------------
        // Normal operation (no stall):
        // pass Fetch values to Decode stage
        // ----------------------------------------------------
        else if(!StallD) begin
            instrD <= instrF;
            pcD    <= pcF;      
        end     

        // If StallD = 1:
        // Hold previous values (no update)
    end
endmodule
