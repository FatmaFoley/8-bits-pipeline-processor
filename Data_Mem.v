//======================================================
// Data Memory Module
// 256 x 8-bit memory
// Supports asynchronous read and synchronous write
//======================================================

module DataMemory (
    input  wire        clk,         // System clock
    input  wire        wen,         // Write enable (for STD, STI)
    input  wire        ren,         // Read enable  (for LDD, LDI)
    input  wire [7:0]  addr,        // 8-bit memory address (0–255)
    input  wire [7:0]  write_data,  // Data to be written into memory
    output reg  [7:0]  read_data    // Data read from memory
);

    // --------------------------------------------------
    // Memory array: 256 locations, each 8 bits wide
    // --------------------------------------------------
    reg [7:0] mem [0:255];

    // --------------------------------------------------
    // Optional initialization:
    // Load memory contents at simulation start
    // Useful for testing and debugging
    // --------------------------------------------------
    initial begin
        $display("Loading Data Memory if dmem.hex exists...");
        $readmemh("imem.hex", mem);   // Optional memory preload
    end

    // --------------------------------------------------
    // Asynchronous READ operation
    // Data is available immediately when ren is asserted
    // --------------------------------------------------
    always @(*) begin
        if (ren)
            read_data = mem[addr];
        else
            read_data = 8'h00;        // Default output when read disabled
    end

    // --------------------------------------------------
    // Synchronous WRITE operation
    // Data is written on the rising edge of the clock
    // --------------------------------------------------
    always @(posedge clk) begin
        if (wen)
            mem[addr] <= write_data;
    end

endmodule
