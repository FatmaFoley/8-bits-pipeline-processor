// -------------------- 8-bit Subtractor --------------------
// Subtracts in2 from in1 and outputs the result
module subtractor(
    input  wire [7:0] in1,   // First operand
    input  wire [7:0] in2,   // Second operand
    output wire [7:0] out    // Result of in1 - in2
);
    assign out = in1 - in2;  // Perform subtraction
endmodule
