//======================================================
// Condition Code Register (CCR)
// Stores processor status flags: {V, C, N, Z}
// Supports save/restore during interrupts (RTI)
//======================================================

module CCR (
    input  wire       clk,          // System clock
    input  wire       reset,          // Synchronous reset
    input  wire       RTI_en,          // Return from Interrupt enable
    input  wire       interruptD,     // Interrupt detected signal
    input  wire       ccr_wen,         // Write enable for CCR
    input  wire [3:0] ALU_Flags,      // Flags from ALU {V, C, N, Z}
    output reg  [3:0] ccr_out         // Current CCR value {V, C, N, Z}
);

    // Register used to save CCR during interrupt
    reg [3:0] ccr_saved;

    // Sequential logic: updates on rising edge of the clock
    always @(posedge clk) begin
        
        // -------------------------
        // Reset: clear CCR and saved CCR
        // -------------------------
        if (reset) begin
            ccr_out   <= 4'b0000;
            ccr_saved <= 4'b0000;
        end

        // -------------------------
        // RTI: restore CCR from saved value
        // -------------------------
        else if (RTI_en) begin
            ccr_out   <= ccr_saved;
        end

        // -------------------------
        // Interrupt detected:
        // save current CCR before interrupt handling
        // -------------------------
        else if (interruptD) begin
            ccr_saved <= ccr_out;
        end

        // -------------------------
        // Normal operation:
        // update CCR with flags from ALU
        // -------------------------
        else if (ccr_wen) begin
            ccr_out   <= ALU_Flags;
        end

    end

endmodule
