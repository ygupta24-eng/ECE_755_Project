/**
 * CNN UART Wrapper Testbench - Cyclone V Configuration
 * 
 * This testbench is optimized for Cyclone V FPGA (50 MHz clock)
 * and can be run on ModelSim/Questa.
 * 
 * Test cases: 3 simple input sets with expected output verification
 * No tiling - direct pixel inputs
 * 
 * To run on Questa:
 *   questa -gui
 *   File > Open Project > Select this file
 *   Compile > Compile All
 *   Simulate > Start Simulation
 *   Run > Run All
 */

`timescale 1ns/1ps

module cnn_uart_wrapper_cyclonev_tb;

    // ========================================================================
    // Cyclone V Configuration
    // ========================================================================
    localparam int CLK_FREQ_CV = 50_000_000;  // Cyclone V typical: 50 MHz
    localparam real CLK_PERIOD = 1_000_000_000.0 / CLK_FREQ_CV;  // 20 ns
    
    // CNN Accelerator parameters
    localparam int DATA_W   = 6;
    localparam int WEIGHT_W = 2;
    localparam int ACC_W    = 13;
    localparam int ROWS     = 4;
    localparam int COLS     = 4;
    localparam int BAUD     = 115200;
    
    // ========================================================================
    // Signals
    // ========================================================================
    logic clk;
    logic rst_n;
    logic uart_rx;
    logic uart_tx;
    
    // Accelerator signals
    logic acc_clk;
    logic acc_rst_n;
    logic acc_start;
    logic acc_done;
    
    logic [DATA_W-1:0]   acc_h_in0;
    logic [DATA_W-1:0]   acc_h_in1;
    logic [DATA_W-1:0]   acc_v_in0;
    logic [DATA_W-1:0]   acc_v_in1;
    logic [WEIGHT_W-1:0] acc_w_in [COLS];
    
    logic [ACC_W-1:0] acc_psum_out0;
    logic [ACC_W-1:0] acc_psum_out1;
    
    // Test signals
    logic [7:0] recv_data;
    logic [15:0] test_count = 0;
    logic [15:0] pass_count = 0;
    logic [15:0] fail_count = 0;
    
    // ========================================================================
    // Simple Behavioral Accelerator Model
    // Returns sum of inputs (placeholder for verification)
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_psum_out0 <= 13'h0;
            acc_psum_out1 <= 13'h0;
        end else begin
            // Simple model: accumulate inputs
            // psum0 = h_in0 + h_in1 + v_in0 + (w_in[0] << 2)
            // psum1 = v_in1 + w_in[1] + w_in[2] + w_in[3]
            acc_psum_out0 <= {6'h0, acc_h_in0} + {6'h0, acc_h_in1} + {6'h0, acc_v_in0} + 
                             {11'h0, acc_w_in[0]};
            acc_psum_out1 <= {10'h0, acc_v_in1} + {12'h0, acc_w_in[1]} + 
                             {12'h0, acc_w_in[2]} + {12'h0, acc_w_in[3]};
        end
    end
    
    // ========================================================================
    // DUT Instantiation (Cyclone V configuration: 50 MHz)
    // ========================================================================
    cnn_uart_wrapper #(
        .DATA_W(DATA_W),
        .WEIGHT_W(WEIGHT_W),
        .ACC_W(ACC_W),
        .ROWS(ROWS),
        .COLS(COLS),
        .CLK_FREQ(CLK_FREQ_CV),      // 50 MHz for Cyclone V
        .BAUD(BAUD)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .rx(uart_rx),
        .tx(uart_tx),
        .acc_clk(acc_clk),
        .acc_rst_n(acc_rst_n),
        .acc_start(acc_start),
        .acc_done(acc_done),
        .acc_h_in0(acc_h_in0),
        .acc_h_in1(acc_h_in1),
        .acc_v_in0(acc_v_in0),
        .acc_v_in1(acc_v_in1),
        .acc_w_in(acc_w_in),
        .acc_psum_out0(acc_psum_out0),
        .acc_psum_out1(acc_psum_out1)
    );
    
    // ========================================================================
    // Clock Generation (50 MHz for Cyclone V)
    // ========================================================================
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;  // 10 ns per half-cycle
    end
    
    // ========================================================================
    // UART Helper Tasks
    // ========================================================================
    
    /**
     * Send a single byte via UART (simulated)
     * Baud rate timing is adjusted for CLK_FREQ_CV
     */
    task uart_send_byte(input logic [7:0] data);
        localparam int BAUD_DIVIDER = CLK_FREQ_CV / BAUD;
        localparam int BAUD_CYCLES = BAUD_DIVIDER;
        localparam real BAUD_TIME_NS = (BAUD_CYCLES * CLK_PERIOD);
        
        begin
            // Start bit (low)
            uart_rx = 1'b0;
            #(BAUD_TIME_NS);
            
            // Data bits (LSB first)
            for (int i = 0; i < 8; i++) begin
                uart_rx = data[i];
                #(BAUD_TIME_NS);
            end
            
            // Stop bit (high)
            uart_rx = 1'b1;
            #(BAUD_TIME_NS);
        end
    endtask
    
    /**
     * Receive a byte from UART TX output
     */
    task uart_recv_byte(output logic [7:0] data);
        localparam int BAUD_DIVIDER = CLK_FREQ_CV / BAUD;
        localparam int BAUD_CYCLES = BAUD_DIVIDER;
        localparam real BAUD_TIME_NS = (BAUD_CYCLES * CLK_PERIOD);
        
        begin
            // Wait for start bit
            wait (uart_tx == 1'b0);
            #(BAUD_TIME_NS + BAUD_TIME_NS/2);
            
            // Read 8 data bits
            for (int i = 0; i < 8; i++) begin
                data[i] = uart_tx;
                #(BAUD_TIME_NS);
            end
            
            // Skip stop bit
            #(BAUD_TIME_NS);
        end
    endtask
    
    // ========================================================================
    // Test Cases
    // ========================================================================
    
    /**
     * Test Case 1: Simple activations with weights = -1
     * Input:  h_in0=5, h_in1=3, v_in0=4, v_in1=2, w=[3,3,3,3] (all -1)
     * Expected: psum0 = 5+3+4+(-1) = 11
     *           psum1 = 2+(-1)+(-1)+(-1) = -1
     */
    task test_case_1();
        logic [7:0] rx_ack, rx_psum0, rx_psum1;
        logic [12:0] exp_psum0, exp_psum1;
        
        begin
            $display("\n=== TEST CASE 1: Simple Activations ===");
            $display("Input: h_in0=5, h_in1=3, v_in0=4, v_in1=2");
            $display("Weights: [3, 3, 3, 3] (all -1)");
            
            test_count++;
            
            // Reset
            $display("  [1] Sending RESET...");
            uart_send_byte(8'h00);
            uart_recv_byte(rx_ack);
            if (rx_ack != 8'hAA) begin
                $display("    ✗ RESET failed: got 0x%02X instead of 0xAA", rx_ack);
                fail_count++;
                return;
            end
            $display("    ✓ RESET ACK received");
            
            #(500 * CLK_PERIOD);  // Wait 10 µs
            
            // Load horizontal data
            $display("  [2] Loading horizontal data...");
            uart_send_byte(8'h10);  // Command
            uart_send_byte(8'd5);   // h_in0 = 5
            uart_send_byte(8'd3);   // h_in1 = 3
            uart_recv_byte(rx_ack);
            if (rx_ack != 8'hAA) begin
                $display("    ✗ H_DATA failed");
                fail_count++;
                return;
            end
            $display("    ✓ Horizontal data loaded");
            
            #(500 * CLK_PERIOD);
            
            // Load vertical data
            $display("  [3] Loading vertical data...");
            uart_send_byte(8'h11);  // Command
            uart_send_byte(8'd4);   // v_in0 = 4
            uart_send_byte(8'd2);   // v_in1 = 2
            uart_recv_byte(rx_ack);
            if (rx_ack != 8'hAA) begin
                $display("    ✗ V_DATA failed");
                fail_count++;
                return;
            end
            $display("    ✓ Vertical data loaded");
            
            #(500 * CLK_PERIOD);
            
            // Load weights (all -1 = 0x03 in 2-bit signed)
            $display("  [4] Loading weights...");
            uart_send_byte(8'h12);  // Command
            uart_send_byte(8'h03);  // w[0] = -1
            uart_send_byte(8'h03);  // w[1] = -1
            uart_send_byte(8'h03);  // w[2] = -1
            uart_send_byte(8'h03);  // w[3] = -1
            uart_recv_byte(rx_ack);
            if (rx_ack != 8'hAA) begin
                $display("    ✗ WEIGHTS failed");
                fail_count++;
                return;
            end
            $display("    ✓ Weights loaded");
            
            #(500 * CLK_PERIOD);
            
            // Start computation
            $display("  [5] Starting computation...");
            uart_send_byte(8'h01);  // START
            uart_recv_byte(rx_ack);
            if (rx_ack != 8'hAA) begin
                $display("    ✗ START failed");
                fail_count++;
                return;
            end
            $display("    ✓ Computation started");
            
            // Wait for computation
            #(1000 * CLK_PERIOD);  // Wait 20 µs
            
            // Read results
            $display("  [6] Reading results...");
            uart_send_byte(8'h20);  // READ_PSUM
            uart_recv_byte(rx_ack);
            uart_recv_byte(rx_psum0);
            uart_recv_byte(rx_psum1);
            
            if (rx_ack != 8'hAA) begin
                $display("    ✗ READ_PSUM failed");
                fail_count++;
                return;
            end
            
            // Verify results
            $display("    Received: psum0_lo=0x%02X, psum1_lo=0x%02X", rx_psum0, rx_psum1);
            
            // Expected: psum0 = 11 (0x0B), psum1 = -1 (0x1F with sign extend to 13 bits = 0x1FFF)
            exp_psum0 = 13'd11;
            exp_psum1 = 13'shFFF;  // -1 in 13-bit signed
            
            if (rx_psum0 == exp_psum0[7:0] && rx_psum1 == exp_psum1[7:0]) begin
                $display("    ✓ Results match expected values!");
                $display("      psum0 = %0d (0x%02X)", rx_psum0, rx_psum0);
                $display("      psum1 = %0d (0x%02X, sign-extended)", $signed(rx_psum1), rx_psum1);
                pass_count++;
            end else begin
                $display("    ✗ Results mismatch!");
                $display("      Expected psum0=0x%02X, got 0x%02X", exp_psum0[7:0], rx_psum0);
                $display("      Expected psum1=0x%02X, got 0x%02X", exp_psum1[7:0], rx_psum1);
                fail_count++;
            end
        end
    endtask
    
    /**
     * Test Case 2: Different weights [0, 1, -1, 2]
     * Input:  h_in0=10, h_in1=8, v_in0=6, v_in1=4, w=[0,1,3,2]
     * Expected: psum0 = 10+8+6+0 = 24
     *           psum1 = 4+1+(-1)+2 = 6
     */
    task test_case_2();
        logic [7:0] rx_ack, rx_psum0, rx_psum1;
        logic [12:0] exp_psum0, exp_psum1;
        
        begin
            $display("\n=== TEST CASE 2: Different Weights ===");
            $display("Input: h_in0=10, h_in1=8, v_in0=6, v_in1=4");
            $display("Weights: [0, 1, 3 (=-1), 2]");
            
            test_count++;
            
            // Reset
            $display("  [1] Sending RESET...");
            uart_send_byte(8'h00);
            uart_recv_byte(rx_ack);
            if (rx_ack != 8'hAA) begin
                fail_count++;
                return;
            end
            $display("    ✓ RESET ACK");
            
            #(500 * CLK_PERIOD);
            
            // Load data
            $display("  [2] Loading data...");
            uart_send_byte(8'h10);
            uart_send_byte(8'd10);
            uart_send_byte(8'd8);
            uart_recv_byte(rx_ack);
            
            #(500 * CLK_PERIOD);
            
            uart_send_byte(8'h11);
            uart_send_byte(8'd6);
            uart_send_byte(8'd4);
            uart_recv_byte(rx_ack);
            
            #(500 * CLK_PERIOD);
            
            uart_send_byte(8'h12);
            uart_send_byte(8'h00);  // w[0] = 0
            uart_send_byte(8'h01);  // w[1] = 1
            uart_send_byte(8'h03);  // w[2] = -1
            uart_send_byte(8'h02);  // w[3] = 2
            uart_recv_byte(rx_ack);
            $display("    ✓ Data loaded");
            
            #(500 * CLK_PERIOD);
            
            // Start and read
            $display("  [3] Computing...");
            uart_send_byte(8'h01);
            uart_recv_byte(rx_ack);
            
            #(1000 * CLK_PERIOD);
            
            $display("  [4] Reading results...");
            uart_send_byte(8'h20);
            uart_recv_byte(rx_ack);
            uart_recv_byte(rx_psum0);
            uart_recv_byte(rx_psum1);
            
            // Expected: psum0=24 (0x18), psum1=6 (0x06)
            exp_psum0 = 13'd24;
            exp_psum1 = 13'd6;
            
            $display("    Received: psum0=0x%02X, psum1=0x%02X", rx_psum0, rx_psum1);
            
            if (rx_psum0 == exp_psum0[7:0] && rx_psum1 == exp_psum1[7:0]) begin
                $display("    ✓ Results correct!");
                pass_count++;
            end else begin
                $display("    ✗ Results mismatch!");
                $display("      Expected psum0=0x%02X, got 0x%02X", exp_psum0[7:0], rx_psum0);
                $display("      Expected psum1=0x%02X, got 0x%02X", exp_psum1[7:0], rx_psum1);
                fail_count++;
            end
        end
    endtask
    
    /**
     * Test Case 3: Maximum values to test saturation
     * Input:  h_in0=63, h_in1=63, v_in0=63, v_in1=63, w=[3,3,3,3]
     * Expected: psum0 = 63+63+63+(-1) = 188 (exceeds 8 bits)
     *           psum1 = 63+(-1)+(-1)+(-1) = 60
     */
    task test_case_3();
        logic [7:0] rx_ack, rx_psum0, rx_psum1;
        logic [12:0] exp_psum0, exp_psum1;
        
        begin
            $display("\n=== TEST CASE 3: Maximum Values ===");
            $display("Input: h_in0=63, h_in1=63, v_in0=63, v_in1=63");
            $display("Weights: [3,3,3,3] (all -1)");
            
            test_count++;
            
            // Reset
            uart_send_byte(8'h00);
            uart_recv_byte(rx_ack);
            
            #(500 * CLK_PERIOD);
            
            // Load data
            uart_send_byte(8'h10);
            uart_send_byte(8'd63);
            uart_send_byte(8'd63);
            uart_recv_byte(rx_ack);
            
            #(500 * CLK_PERIOD);
            
            uart_send_byte(8'h11);
            uart_send_byte(8'd63);
            uart_send_byte(8'd63);
            uart_recv_byte(rx_ack);
            
            #(500 * CLK_PERIOD);
            
            uart_send_byte(8'h12);
            uart_send_byte(8'h03);
            uart_send_byte(8'h03);
            uart_send_byte(8'h03);
            uart_send_byte(8'h03);
            uart_recv_byte(rx_ack);
            
            #(500 * CLK_PERIOD);
            
            // Start and read
            uart_send_byte(8'h01);
            uart_recv_byte(rx_ack);
            
            #(1000 * CLK_PERIOD);
            
            uart_send_byte(8'h20);
            uart_recv_byte(rx_ack);
            uart_recv_byte(rx_psum0);
            uart_recv_byte(rx_psum1);
            
            // Expected: psum0 = 188 (0xBC, lower 8 bits)
            //           psum1 = 60 (0x3C)
            exp_psum0 = 13'd188;
            exp_psum1 = 13'd60;
            
            $display("    Received: psum0=0x%02X, psum1=0x%02X", rx_psum0, rx_psum1);
            
            if (rx_psum0 == exp_psum0[7:0] && rx_psum1 == exp_psum1[7:0]) begin
                $display("    ✓ Results correct!");
                pass_count++;
            end else begin
                $display("    ✗ Results mismatch!");
                $display("      Expected psum0=0x%02X, got 0x%02X", exp_psum0[7:0], rx_psum0);
                $display("      Expected psum1=0x%02X, got 0x%02X", exp_psum1[7:0], rx_psum1);
                fail_count++;
            end
        end
    endtask
    
    // ========================================================================
    // Main Test Sequence
    // ========================================================================
    initial begin
        // Initialize
        rst_n = 1'b0;
        uart_rx = 1'b1;
        
        $display("\n");
        $display("╔════════════════════════════════════════════════════╗");
        $display("║  CNN UART Wrapper Testbench (Cyclone V - 50 MHz)   ║");
        $display("║  Running on ModelSim/Questa                       ║");
        $display("╚════════════════════════════════════════════════════╝");
        
        // Release reset after a few cycles
        #(100 * CLK_PERIOD);
        rst_n = 1'b1;
        
        $display("\nClock Frequency: %0.1f MHz", real'(CLK_FREQ_CV)/1e6);
        $display("Clock Period: %.1f ns", CLK_PERIOD);
        $display("Baud Rate: %0d", BAUD);
        $display("BAUD Divider: %0d cycles", CLK_FREQ_CV/BAUD);
        
        #(500 * CLK_PERIOD);  // Let system stabilize
        
        // Run test cases
        test_case_1();
        #(2000 * CLK_PERIOD);  // Delay between tests
        
        test_case_2();
        #(2000 * CLK_PERIOD);
        
        test_case_3();
        
        // Print summary
        #(2000 * CLK_PERIOD);
        
        $display("\n");
        $display("╔════════════════════════════════════════════════════╗");
        $display("║                  TEST SUMMARY                      ║");
        $display("╚════════════════════════════════════════════════════╝");
        $display("Total Tests:  %0d", test_count);
        $display("Passed:       %0d ✓", pass_count);
        $display("Failed:       %0d ✗", fail_count);
        
        if (fail_count == 0) begin
            $display("\n🎉 ALL TESTS PASSED! 🎉\n");
        end else begin
            $display("\n❌ %0d test(s) failed\n", fail_count);
        end
        
        $finish;
    end
    
    // ========================================================================
    // Optional: Waveform Dumping
    // ========================================================================
    initial begin
        // Uncomment to generate VCD file for waveform viewing
        // $dumpfile("cnn_uart_cyclonev.vcd");
        // $dumpvars(0, cnn_uart_wrapper_cyclonev_tb);
    end

endmodule
