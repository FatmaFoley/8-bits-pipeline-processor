// 1-to-2 Demultiplexer Module
// Routes the 8-bit input to one of two outputs
// based on the select signal demux_s0

module demux(
    input  wire  [7:0] demux_in,   // 8-bit input data
    input  wire        demux_s0,    // select signal
    output wire  [7:0] data_out1,   // output when demux_s0 = 1
    output wire  [7:0] data_out2    // output when demux_s0 = 0
);

    // If demux_s0 = 1:
    //   data_out1 gets demux_in, data_out2 = 0
    // If demux_s0 = 0:
    //   data_out2 gets demux_in, data_out1 = 0
    assign data_out1 = demux_s0 ? demux_in : 8'b0;
    assign data_out2 = demux_s0 ? 8'b0     : demux_in;

endmodule
