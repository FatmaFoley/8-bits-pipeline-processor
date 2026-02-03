// -------------------- Register File --------------------
// 4 registers of 8 bits each. Supports reading two registers and writing to one or both.
module RegFile (
    input  wire        clk,          // clock signal
    input  wire        reset,        // synchronous reset signal
    input  wire [1:0]  reg_file_wen, // write enable: 01=write data_in1, 10=write data_in2(SP), 11=write both
    input  wire [1:0]  addr_in1,     // read address for data_out1
    input  wire [1:0]  addr_in2,     // read address for data_out2
    input  wire [1:0]  dest_addr,    // write destination address for data_in1
    input  wire [7:0]  data_in1,     // data input 1
    input  wire [7:0]  data_in2,     // data input 2 (usually for SP)
    output reg  [7:0]  data_out1,    // output from register addr_in1
    output reg  [7:0]  data_out2     // output from register addr_in2
);

    // Internal 4x8-bit register array
    reg [7:0] regfile [0:3];
    
    // Synchronous reset + write on posedge
    always @(posedge clk) begin
        if (reset) begin
            // Initialize registers with default values
            regfile[0] <= 8'h0C;
            regfile[1] <= 8'h04;
            regfile[2] <= 8'h02;
            regfile[3] <= 8'h03;   // SP = 3 (can represent stack pointer)
        end
        else if (reg_file_wen == 2'b01) begin
            // Write only to dest_addr
            regfile[dest_addr] <= data_in1;
        end
        else if (reg_file_wen == 2'b10) begin
            // Write only to register 3 (SP)
            regfile[3] <= data_in2;
        end
        else if (reg_file_wen == 2'b11) begin
            // Write both dest_addr and SP
            regfile[dest_addr] <= data_in1;
            regfile[3] <= data_in2;
        end
    end
    
    // Combinational read
    always @(*) begin
        data_out1 = regfile[addr_in1]; // Read first register
        data_out2 = regfile[addr_in2]; // Read second register
    end
    
endmodule
