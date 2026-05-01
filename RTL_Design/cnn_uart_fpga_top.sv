/**
 * CNN Accelerator with UART Wrapper - Top-Level Integration
 * 
 * This module shows how to integrate the UART wrapper with the CNN accelerator
 * for FPGA implementation.
 * 
 * Block Diagram:
 *   UART (USB) --> UART RX --> Protocol Parser --> CNN Accelerator
 *                                   ^
 *                                   |
 *                              Result Buffer
 *                                   |
 *   UART (USB) <-- UART TX <--------+
 */

module cnn_uart_fpga_top #(
    parameter int DATA_W   = 6,
    parameter int WEIGHT_W = 2,
    parameter int ACC_W    = 13,
    parameter int ROWS     = 4,
    parameter int COLS     = 4,
    parameter int CLK_FREQ = 100_000_000,  // 100 MHz typical FPGA clock
    parameter int BAUD     = 115200
) (
    // System Signals
    input  logic clk,           // FPGA system clock (usually 100 MHz)
    input  logic rst_n,         // System reset
    
    // UART Pins (connect to FTDI/USB interface)
    input  logic uart_rx,       // From USB adapter RX pin
    output logic uart_tx,       // To USB adapter TX pin
    
    // Optional: Status LEDs
    output logic led_running,   // Blinks when accelerator is computing
    output logic led_done,      // On when accelerator completes
    output logic led_uart_rx,   // Blinks on UART RX activity
    output logic led_uart_tx    // Blinks on UART TX activity
);

    // ========================================================================
    // Internal Signals
    // ========================================================================
    
    // CNN Accelerator control signals
    logic acc_clk;
    logic acc_rst_n;
    logic acc_start;
    logic acc_done;
    
    // CNN Accelerator data signals
    logic [DATA_W-1:0]   acc_h_in0;
    logic [DATA_W-1:0]   acc_h_in1;
    logic [DATA_W-1:0]   acc_v_in0;
    logic [DATA_W-1:0]   acc_v_in1;
    logic [WEIGHT_W-1:0] acc_w_in [COLS];
    
    // CNN Accelerator outputs
    logic [ACC_W-1:0] acc_psum_out0;
    logic [ACC_W-1:0] acc_psum_out1;
    
    // LED blink logic
    logic [23:0] led_counter;
    
    // ========================================================================
    // UART Wrapper Instance
    // ========================================================================
    cnn_uart_wrapper #(
        .DATA_W(DATA_W),
        .WEIGHT_W(WEIGHT_W),
        .ACC_W(ACC_W),
        .ROWS(ROWS),
        .COLS(COLS),
        .CLK_FREQ(CLK_FREQ),
        .BAUD(BAUD)
    ) uart_wrapper_inst (
        .clk(clk),
        .rst_n(rst_n),
        
        // UART I/O
        .rx(uart_rx),
        .tx(uart_tx),
        
        // Accelerator Control
        .acc_clk(acc_clk),
        .acc_rst_n(acc_rst_n),
        .acc_start(acc_start),
        .acc_done(acc_done),
        
        // Accelerator Data Inputs
        .acc_h_in0(acc_h_in0),
        .acc_h_in1(acc_h_in1),
        .acc_v_in0(acc_v_in0),
        .acc_v_in1(acc_v_in1),
        .acc_w_in(acc_w_in),
        
        // Accelerator Data Outputs
        .acc_psum_out0(acc_psum_out0),
        .acc_psum_out1(acc_psum_out1)
    );
    
    // ========================================================================
    // CNN Accelerator Instance
    // ========================================================================
    // REPLACE THIS WITH YOUR ACTUAL CNN ACCELERATOR MODULE
    // This is a placeholder - adapt to your specific accelerator
    
    top #(
        .DATA_W(DATA_W),
        .WEIGHT_W(WEIGHT_W),
        .ACC_W(ACC_W),
        .ROWS(ROWS),
        .COLS(COLS)
    ) accelerator_inst (
        .clk(acc_clk),
        .rst_n(acc_rst_n),
        .start(acc_start),
        .done(acc_done),
        
        // Data inputs
        .h_in0(acc_h_in0),
        .h_in1(acc_h_in1),
        .v_in0(acc_v_in0),
        .v_in1(acc_v_in1),
        .w_in(acc_w_in),
        
        // Data outputs
        .psum_out0(acc_psum_out0),
        .psum_out1(acc_psum_out1)
    );
    
    // ========================================================================
    // Status Monitoring
    // ========================================================================
    
    // Track accelerator state
    logic acc_done_d1, acc_done_d2;
    logic acc_done_pulse;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_done_d1 <= 1'b0;
            acc_done_d2 <= 1'b0;
        end else begin
            acc_done_d1 <= acc_done;
            acc_done_d2 <= acc_done_d1;
        end
    end
    
    assign acc_done_pulse = acc_done_d1 && ~acc_done_d2;
    
    // ========================================================================
    // LED Drivers (Status Indication)
    // ========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led_counter <= 24'h0;
            led_running <= 1'b0;
            led_done <= 1'b0;
            led_uart_rx <= 1'b0;
            led_uart_tx <= 1'b0;
        end else begin
            // Increment counter for LED blinking
            led_counter <= led_counter + 1;
            
            // LED1: Running (blinks when start pulsed)
            if (acc_start) begin
                led_running <= 1'b1;
            end else if (led_counter[20]) begin
                led_running <= 1'b0;
            end
            
            // LED2: Done (on when computation completes)
            if (acc_done_pulse) begin
                led_done <= 1'b1;
            end else if (led_counter == 24'h0) begin
                led_done <= 1'b0;
            end
            
            // LED3: UART RX activity
            // Connect to UART RX strobe signal if available
            // led_uart_rx <= uart_rx_strobe;
            
            // LED4: UART TX activity
            // Connect to UART TX strobe signal if available
            // led_uart_tx <= uart_tx_strobe;
        end
    end

endmodule

/**
 * Alternative: Minimal Wrapper for Direct Instantiation
 * 
 * Use this if you want just the UART wrapper without extra logic
 */

module cnn_uart_minimal_top #(
    parameter int DATA_W   = 6,
    parameter int WEIGHT_W = 2,
    parameter int ACC_W    = 13,
    parameter int ROWS     = 4,
    parameter int COLS     = 4,
    parameter int CLK_FREQ = 100_000_000,
    parameter int BAUD     = 115200
) (
    input  logic clk,
    input  logic rst_n,
    
    // UART
    input  logic uart_rx,
    output logic uart_tx,
    
    // These connect directly to your CNN accelerator core
    output logic acc_clk,
    output logic acc_rst_n,
    output logic acc_start,
    input  logic acc_done,
    
    output logic [DATA_W-1:0]   acc_h_in0,
    output logic [DATA_W-1:0]   acc_h_in1,
    output logic [DATA_W-1:0]   acc_v_in0,
    output logic [DATA_W-1:0]   acc_v_in1,
    output logic [WEIGHT_W-1:0] acc_w_in [COLS],
    
    input  logic [ACC_W-1:0] acc_psum_out0,
    input  logic [ACC_W-1:0] acc_psum_out1
);

    cnn_uart_wrapper #(
        .DATA_W(DATA_W),
        .WEIGHT_W(WEIGHT_W),
        .ACC_W(ACC_W),
        .ROWS(ROWS),
        .COLS(COLS),
        .CLK_FREQ(CLK_FREQ),
        .BAUD(BAUD)
    ) wrapper (
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

endmodule
