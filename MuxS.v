// ------------------- 2-to-1 MUX (8-bit) --------------------
// Selects between two 8-bit inputs based on Mux_sel
module MUX_2_1_8bits (
    input  wire       Mux_sel,       // Selector: 0 -> Mux_in2, 1 -> Mux_in1
    input  wire [7:0] Mux_in1, Mux_in2, // 8-bit inputs
    output wire [7:0] Mux_out        // 8-bit output
);
    assign Mux_out = Mux_sel ? Mux_in1 : Mux_in2;
endmodule


// ------------------- 2-to-1 MUX (1-bit) --------------------
// Selects between two 1-bit inputs based on Mux_sel
module MUX_2_1 (
    input  wire  Mux_sel,            // Selector: 0 -> Mux_in2, 1 -> Mux_in1
    input  wire  Mux_in1, Mux_in2,   // 1-bit inputs
    output wire  Mux_out              // 1-bit output
);
    assign Mux_out = Mux_sel ? Mux_in1 : Mux_in2;
endmodule


// -------------------- 4-to-1 MUX (8-bit) --------------------
// Selects one of four 8-bit inputs based on 2-bit Mux_sel
module MUX_4_1 (
    input  wire [7:0] Mux_in1, Mux_in2, Mux_in3, Mux_in4, // 8-bit inputs
    input  wire [1:0] Mux_sel,                             // 2-bit selector
    output reg  [7:0] Mux_out                               // 8-bit output
);
    always @(*) begin
        case (Mux_sel)
            2'b00: Mux_out = Mux_in1;
            2'b01: Mux_out = Mux_in2;
            2'b10: Mux_out = Mux_in3;
            2'b11: Mux_out = Mux_in4;
        endcase
    end
endmodule


// -------------------- 8-to-1 MUX (8-bit) --------------------
// Selects one of eight 8-bit inputs based on 3-bit Mux_sel
module MUX_8_1 (
    input  wire [7:0] Mux_in1, Mux_in2, Mux_in3, Mux_in4,
                      Mux_in5, Mux_in6, Mux_in7, Mux_in8, // 8-bit inputs
    input  wire [2:0] Mux_sel,                            // 3-bit selector
    output reg  [7:0] Mux_out                              // 8-bit output
);
    always @(*) begin
        case (Mux_sel)
            3'b000: Mux_out = Mux_in1;
            3'b001: Mux_out = Mux_in2;
            3'b010: Mux_out = Mux_in3;
            3'b011: Mux_out = Mux_in4;
            3'b100: Mux_out = Mux_in5;
            3'b101: Mux_out = Mux_in6;
            3'b110: Mux_out = Mux_in7;
            3'b111: Mux_out = Mux_in8;
        endcase
    end
endmodule
