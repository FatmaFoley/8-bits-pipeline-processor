// -------------------- 8-bit OR Gate --------------------
// Performs a logical OR on all 8 bits of the input and outputs a single bit
module OR_GATE(
    input  wire [7:0] or_in,   // 8-bit input
    output wire        or_out  // 1-bit output (OR of all bits)
);

    // OR all bits together
    assign or_out =   or_in[0] | or_in[1] | or_in[2] | or_in[3] 
                    | or_in[4] | or_in[5] | or_in[6] | or_in[7];
    
endmodule
