// 8-bit Adder Module
// This module adds two 8-bit inputs together
// and produces an 8-bit output result

module adder_8bit(
    input  [7:0] adder_in1,   // First 8-bit input (e.g., immediate value or offset)
    input  [7:0] PC_out,      // Second 8-bit input (Program Counter output)
    output [7:0] adder_out    // 8-bit output representing the sum
);

    // Continuous assignment:
    // Adds adder_in1 and PC_out and assigns the result to adder_out
    assign adder_out = adder_in1 + PC_out;

endmodule
