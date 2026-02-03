
`timescale 1ns/1ps

module testbench();

    // ========================================================================
    // 1. SIGNAL DECLARATIONS 
    // ========================================================================
    
    reg        CLK;               
    reg        RESET_IN;           
    reg        INTR_IN;
    reg [7:0]  IN_PORT;            
    wire [7:0] OUT_PORT;           
    
    // ========================================================================
    // 2. INSTANTIATE PROCESSOR (TOP MODULE)
    // ========================================================================
    
    TOP processor (
        .CLK       (CLK),
        .RESET_IN  (RESET_IN),
        .INTR_IN   (INTR_IN),
        .IN_PORT   (IN_PORT),
        .OUT_PORT  (OUT_PORT)
    );
    
    // ========================================================================
    // 3. CLOCK GENERATION (100 MHz = 10ns period)
    // ========================================================================
    
    initial begin
        CLK = 1'b0;
        forever #5 CLK = ~CLK;      // Toggle every 5ns
    end
    
    // ========================================================================
    // 4. WAVEFORM DUMPING
    // ========================================================================
    
    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, testbench);
    end
    
    // ========================================================================
    // 5. MAIN TEST SEQUENCE
    // ========================================================================
    
    initial begin
        
        $display("\n========================================================");
        $display("   8-BIT PIPELINED MICROPROCESSOR TESTBENCH");
        $display("   Instruction Memory: imem.hex");
        $display("   Time: %0t", $time);
        $display("========================================================\n");
        
        // Initialize signals
        RESET_IN = 1'b1;            // Assert reset
        INTR_IN  = 1'b0;
        IN_PORT  = 8'h00;           // No input
        
        $display("[%0t ns] Initializing testbench...", $time);
        $display("  RESET_IN = 1");
        $display("  IN_PORT = 0x00");
        
        // Apply reset
        #10 RESET_IN = 1'b0;
                
        #50;
        INTR_IN  = 1'b1;
        IN_PORT = 8'hA5;
        
        #10;
        INTR_IN  = 1'b0;
        $display("[%0t ns] IN_PORT test complete", $time);
        IN_PORT = 8'h00;  // Clear input
        
        
        #200;
        
        // ====================================================================
        // END SIMULATION
        // ====================================================================
        
        $display("\n========================================================");
        $display("   TESTBENCH COMPLETED");
        $display("   Total Time: %0t ns", $time);
        $display("   Final OUT_PORT: 0x%02h", OUT_PORT);
        $display("========================================================\n");
        
        $finish;
    end

endmodule

