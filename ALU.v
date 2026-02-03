//======================================================
// 8-bit Arithmetic Logic Unit (ALU)
// Performs arithmetic and logical operations
// based on alu_op control signal
//======================================================

module ALU (
    input  wire [7:0] A,        // Operand A
    input  wire [7:0] B,        // Operand B
    input  wire [3:0] alu_op,   // ALU operation selector
    output reg  [7:0] R,        // Result of the operation
    output reg  Z,              // Zero flag (R == 0)
    output reg  N,              // Negative flag (MSB of R)
    output reg  C,              // Carry flag
    output reg  V               // Overflow flag
);

    reg [8:0] tmp;  // Temporary register for arithmetic operations with carry

    // Combinational ALU logic
    always @(*) begin
        
        // -------------------------
        // Default values (avoid latches)
        // -------------------------
        R = 8'h00;
        Z = 0;
        N = 0;
        C = 0;
        V = 0;

        // Select operation based on alu_op
        case (alu_op)

            // ----------------------------------------------------
            // MOV : Move B to R
            // ----------------------------------------------------
            4'b0000: begin
                R = B;
            end

            // ----------------------------------------------------
            // ADD : R = A + B
            // Updates Carry (C) and Overflow (V)
            // ----------------------------------------------------
            4'b0001: begin
                {C , R} = A + B;
                // Signed overflow detection (2's complement)
                V = (~A[7] & ~B[7] &  R[7]) |
                    ( A[7] &  B[7] & ~R[7]);
            end

            // ----------------------------------------------------
            // SUB : R = A - B
            // ----------------------------------------------------
            4'b0010: begin
                {C , R} = A - B;
                // Signed overflow detection
                V = ( A[7] & ~B[7] & ~R[7]) |
                    (~A[7] &  B[7] &  R[7]);
            end

            // ----------------------------------------------------
            // AND : Bitwise AND
            // ----------------------------------------------------
            4'b0011: begin
                R = A & B;
            end

            // ----------------------------------------------------
            // OR : Bitwise OR
            // ----------------------------------------------------
            4'b0100: begin
                R = A | B;
            end

            // ----------------------------------------------------
            // RLC : Rotate Left through Carry
            // Carry gets MSB of B
            // ----------------------------------------------------
            4'b0101: begin
                C = B[7];
                R = {B[6:0], C};
            end

            // ----------------------------------------------------
            // RRC : Rotate Right through Carry
            // Carry gets LSB of B
            // ----------------------------------------------------
            4'b0110: begin
                C = B[0];
                R = {C, B[7:1]};
            end

            // ----------------------------------------------------
            // SETC : Set Carry flag
            // ----------------------------------------------------
            4'b0111: begin
                R = A;   // Result unchanged
                C = 1;
            end

            // ----------------------------------------------------
            // CLRC : Clear Carry flag
            // ----------------------------------------------------
            4'b1000: begin
                R = A;   // Result unchanged
                C = 0;
            end

            // ----------------------------------------------------
            // NOT : One's complement of B
            // ----------------------------------------------------
            4'b1001: begin
                R = ~B;
            end

            // ----------------------------------------------------
            // NEG : Two's complement negation of B
            // ----------------------------------------------------
            4'b1010: begin
                tmp = (~B + 1);
                R = tmp[7:0];
                C = tmp[8];
                // Overflow occurs when negating -128 (1000 0000)
                V = (B == 8'h80);
            end

            // ----------------------------------------------------
            // INC : Increment B by 1
            // ----------------------------------------------------
            4'b1011: begin
                tmp = B + 1;
                R = tmp[7:0];
                C = tmp[8];
                // Overflow: +127 -> -128
                V = (~B[7] &  R[7]);
            end

            // ----------------------------------------------------
            // DEC : Decrement B by 1
            // ----------------------------------------------------
            4'b1100: begin
                tmp = B - 1;
                R = tmp[7:0];
                C = tmp[8];
                // Overflow: -128 -> +127
                V = (B[7] & ~R[7]);
            end

            // ----------------------------------------------------
            // Default case
            // ----------------------------------------------------
            default: begin
                R = 8'h00;
            end
        endcase

        // --------------------------------------------------------
        // Common flag updates for all operations
        // --------------------------------------------------------
        Z = (R == 8'h00); // Zero flag
        N =  R[7];       // Negative flag (sign bit)

    end

endmodule
