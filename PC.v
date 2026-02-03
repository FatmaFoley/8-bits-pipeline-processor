// -------------------- Program Counter (PC) --------------------
// Holds the current instruction address and updates it on each clock cycle
module PC (
    input  wire        clk,       // clock signal
    input  wire        reset,     // synchronous reset signal (active high)
    input  wire        StallF,    // stall signal for fetch stage
    input  wire [7:0]  mux1_out,  // next PC value from MUX
    input  wire [7:0]  mem0,      // value of memory at address 0 (used for reset)
    output reg [7:0]   pc_out     // current PC value
);

    always @(posedge clk) begin
        if (reset) begin
            // On reset, set PC to the first memory address (M[0])
            pc_out <= mem0;
        end 
        else if(!StallF) begin
            // If no stall, update PC with the next value
            pc_out <= mux1_out;
        end 
        // If StallF is high, hold the current PC value
    end
endmodule
