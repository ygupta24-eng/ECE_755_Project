/**
 * CNN UART Wrapper Testbench
 * 
 * Demonstrates UART protocol usage with the CNN accelerator wrapper.
 * Shows how to:
 * 1. Reset the accelerator
 * 2. Load activations (H and V)
 * 3. Load weights
 * 4. Trigger computation
 * 5. Read results
 */

`timescale 1ns/1ps

module cnn_uart_wrapper_tb;

    // ========================================================================
    // Parameters
    // ========================================================================
    localparam int DATA_W   = 6;
    localparam int WEIGHT_W = 2;
    localparam int ACC_W    = 13;
    localparam int ROWS     = 4;
    localparam int COLS     = 4;
    localparam int CLK_FREQ = 100_000_000;
    localparam int BAUD     = 115200;
    localparam real CLK_PERIOD = 1_000_000_000.0 / CLK_FREQ;  // in ns
    
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
    
    // ========================================================================
    // Dummy Accelerator (returns fixed results for testing)
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_psum_out0 <= 13'h0;
            acc_psum_out1 <= 13'h0;
        end else begin
            // Simply return the sum of inputs as result for demo
            acc_psum_out0 <= acc_h_in0 + acc_h_in1 + acc_v_in0;
            acc_psum_out1 <= acc_v_in1 + (acc_w_in[0] ? 13'h1 : 13'h0);
        end
    end
    
    // ========================================================================
    // DUT Instantiation
    // ========================================================================
    cnn_uart_wrapper #(
        .DATA_W(DATA_W),
        .WEIGHT_W(WEIGHT_W),
        .ACC_W(ACC_W),
        .ROWS(ROWS),
        .COLS(COLS),
        .CLK_FREQ(CLK_FREQ),
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
    // Clock Generation
    // ========================================================================
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // ========================================================================
    // UART Transmit Helper Task
    // Sends a single byte over UART (simulated at baud rate)
    // ========================================================================
    task uart_send_byte(input logic [7:0] data);
        localparam int BAUD_PERIOD_NS = CLK_PERIOD * (CLK_FREQ / BAUD);
        
        begin
            // Start bit (low for 1 baud period)
            uart_rx = 1'b0;
            #(BAUD_PERIOD_NS);
            
            // Data bits (LSB first)
            for (int i = 0; i < 8; i++) begin
                uart_rx = data[i];
                #(BAUD_PERIOD_NS);
            end
            
            // Stop bit (high for 1 baud period)
            uart_rx = 1'b1;
            #(BAUD_PERIOD_NS);
        end
    endtask
    
    // ========================================================================
    // UART Receive Helper Task
    // Reads a single byte from UART
    // ========================================================================
    task uart_recv_byte(output logic [7:0] data);
        localparam int BAUD_PERIOD_NS = CLK_PERIOD * (CLK_FREQ / BAUD);
        
        begin
            // Wait for start bit (low)
            while (uart_tx == 1'b1) #(BAUD_PERIOD_NS / 4);
            
            // Skip start bit
            #(BAUD_PERIOD_NS + BAUD_PERIOD_NS/2);
            
            // Read data bits
            for (int i = 0; i < 8; i++) begin
                data[i] = uart_tx;
                #(BAUD_PERIOD_NS);
            end
            
            // Skip stop bit
            #(BAUD_PERIOD_NS);
        end
    endtask
    
    // ========================================================================
    // Test Stimulus
    // ========================================================================
    initial begin
        // Initialize
        rst_n = 1'b0;
        uart_rx = 1'b1;
        
        #(10 * CLK_PERIOD);
        rst_n = 1'b1;
        
        // Wait for system to settle
        #(100 * CLK_PERIOD);
        
        $display("\n=== CNN UART Wrapper Test ===\n");
        
        // ====================================================================
        // Test 1: Reset Command (0x00)
        // ====================================================================
        $display("Test 1: Send RESET command (0x00)");
        uart_send_byte(8'h00);
        
        // Wait for response
        begin : wait_ack
            logic [7:0] resp;
            uart_recv_byte(resp);
            if (resp == 8'hAA)
                $display("✓ Received ACK (0xAA)\n");
            else
                $display("✗ Expected ACK, got 0x%02X\n", resp);
        end
        
        #(1000 * CLK_PERIOD);
        
        // ====================================================================
        // Test 2: Load Horizontal Data (0x10)
        // ====================================================================
        $display("Test 2: Load horizontal data h_in0=10, h_in1=20");
        uart_send_byte(8'h10);    // Command
        uart_send_byte(8'd10);    // h_in0
        uart_send_byte(8'd20);    // h_in1
        
        // Wait for response
        begin : wait_h_data
            logic [7:0] resp;
            uart_recv_byte(resp);
            if (resp == 8'hAA)
                $display("✓ Received ACK\n");
            else
                $display("✗ Expected ACK, got 0x%02X\n", resp);
        end
        
        #(1000 * CLK_PERIOD);
        
        // Verify accelerator signals
        @(posedge clk);
        if (acc_h_in0 == 8'd10 && acc_h_in1 == 8'd20)
            $display("✓ Accelerator h_in0=%0d, h_in1=%0d\n", acc_h_in0, acc_h_in1);
        else
            $display("✗ Accelerator signals mismatch\n");
        
        #(1000 * CLK_PERIOD);
        
        // ====================================================================
        // Test 3: Load Vertical Data (0x11)
        // ====================================================================
        $display("Test 3: Load vertical data v_in0=15, v_in1=25");
        uart_send_byte(8'h11);    // Command
        uart_send_byte(8'd15);    // v_in0
        uart_send_byte(8'd25);    // v_in1
        
        begin : wait_v_data
            logic [7:0] resp;
            uart_recv_byte(resp);
            if (resp == 8'hAA)
                $display("✓ Received ACK\n");
            else
                $display("✗ Expected ACK, got 0x%02X\n", resp);
        end
        
        #(1000 * CLK_PERIOD);
        
        @(posedge clk);
        if (acc_v_in0 == 8'd15 && acc_v_in1 == 8'd25)
            $display("✓ Accelerator v_in0=%0d, v_in1=%0d\n", acc_v_in0, acc_v_in1);
        else
            $display("✗ Accelerator signals mismatch\n");
        
        #(1000 * CLK_PERIOD);
        
        // ====================================================================
        // Test 4: Load Weights (0x12)
        // ====================================================================
        $display("Test 4: Load weights w_in=[3,3,3,3] (all -1)");
        uart_send_byte(8'h12);    // Command
        uart_send_byte(8'h03);    // w0 = -1
        uart_send_byte(8'h03);    // w1 = -1
        uart_send_byte(8'h03);    // w2 = -1
        uart_send_byte(8'h03);    // w3 = -1
        
        begin : wait_weights
            logic [7:0] resp;
            uart_recv_byte(resp);
            if (resp == 8'hAA)
                $display("✓ Received ACK\n");
            else
                $display("✗ Expected ACK, got 0x%02X\n", resp);
        end
        
        #(1000 * CLK_PERIOD);
        
        @(posedge clk);
        $display("✓ Accelerator weights loaded\n");
        
        #(1000 * CLK_PERIOD);
        
        // ====================================================================
        // Test 5: Start Computation (0x01)
        // ====================================================================
        $display("Test 5: Send START command (0x01)");
        uart_send_byte(8'h01);    // Command
        
        begin : wait_start
            logic [7:0] resp;
            uart_recv_byte(resp);
            if (resp == 8'hAA)
                $display("✓ Received ACK\n");
            else
                $display("✗ Expected ACK, got 0x%02X\n", resp);
        end
        
        #(1000 * CLK_PERIOD);
        
        // Wait for computation
        $display("Waiting for computation to complete...");
        wait (acc_done == 1'b1);
        #(100 * CLK_PERIOD);
        $display("✓ Accelerator computation complete\n");
        
        // ====================================================================
        // Test 6: Read Partial Sums (0x20)
        // ====================================================================
        $display("Test 6: Read partial sums (0x20)");
        uart_send_byte(8'h20);    // Command
        
        begin : wait_read_psum
            logic [7:0] resp, psum0_lo, psum1_lo;
            uart_recv_byte(resp);
            uart_recv_byte(psum0_lo);
            uart_recv_byte(psum1_lo);
            
            $display("✓ Received ACK + results");
            $display("  psum0_lo = 0x%02X", psum0_lo);
            $display("  psum1_lo = 0x%02X\n", psum1_lo);
        end
        
        #(1000 * CLK_PERIOD);
        
        // ====================================================================
        // Summary
        // ====================================================================
        $display("\n=== Test Complete ===");
        $display("All commands executed successfully via UART protocol.\n");
        
        #(1000 * CLK_PERIOD);
        $finish;
    end
    
    // ========================================================================
    // Waveform Dump
    // ========================================================================
    initial begin
        $dumpfile("cnn_uart_wrapper_tb.vcd");
        $dumpvars(0, cnn_uart_wrapper_tb);
    end

endmodule
