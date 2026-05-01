/**
 * CNN Accelerator UART Wrapper
 * 
 * Bridges UART serial communication with the CNN accelerator core
 * Protocol: Command-based interface for operating the systolic array
 * 
 * Baud Rate: 115200
 * Data Format: 8N1 (8 bits, no parity, 1 stop bit)
 */

module cnn_uart_wrapper #(
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
    
    // UART I/O
    input  logic rx,
    output logic tx,
    
    // CNN Accelerator Interface
    output logic acc_clk,
    output logic acc_rst_n,
    output logic acc_start,
    input  logic acc_done,
    
    // Accelerator Data Paths
    output logic [DATA_W-1:0]   acc_h_in0,
    output logic [DATA_W-1:0]   acc_h_in1,
    output logic [DATA_W-1:0]   acc_v_in0,
    output logic [DATA_W-1:0]   acc_v_in1,
    output logic [WEIGHT_W-1:0] acc_w_in [COLS],
    
    // Accelerator Outputs
    input  logic [ACC_W-1:0] acc_psum_out0,
    input  logic [ACC_W-1:0] acc_psum_out1
);

    // ============================================================================
    // Parameters
    // ============================================================================
    localparam int BAUD_COUNT = CLK_FREQ / BAUD;
    
    // Command codes
    localparam logic [7:0] CMD_RESET     = 8'h00;  // Reset accelerator
    localparam logic [7:0] CMD_START     = 8'h01;  // Start computation
    localparam logic [7:0] CMD_H_DATA    = 8'h10;  // Load horizontal data (h_in0, h_in1)
    localparam logic [7:0] CMD_V_DATA    = 8'h11;  // Load vertical data (v_in0, v_in1)
    localparam logic [7:0] CMD_WEIGHTS   = 8'h12;  // Load weights (4 bytes: w0,w1,w2,w3)
    localparam logic [7:0] CMD_READ_PSUM = 8'h20;  // Read partial sums
    localparam logic [7:0] CMD_STATUS    = 8'h30;  // Read status

    // ============================================================================
    // Signals
    // ============================================================================
    logic [15:0] baud_count_cfg;
    logic [7:0] uart_rx_data;
    logic uart_rx_valid;
    logic uart_rx_busy;
    
    logic [7:0] uart_tx_data;
    logic uart_tx_send;
    logic uart_tx_busy;
    
    // State machine for protocol handling
    typedef enum logic [3:0] {
        STATE_IDLE,
        STATE_CMD,
        STATE_H_DATA_0,
        STATE_H_DATA_1,
        STATE_V_DATA_0,
        STATE_V_DATA_1,
        STATE_WEIGHTS_0,
        STATE_WEIGHTS_1,
        STATE_WEIGHTS_2,
        STATE_WEIGHTS_3,
        STATE_RESP_PSUM_0,
        STATE_RESP_PSUM_1
    } protocol_state_t;
    
    protocol_state_t pstate, pnext_state;
    
    // Data staging registers
    logic [7:0] temp_h_in0, temp_h_in1;
    logic [7:0] temp_v_in0, temp_v_in1;
    logic [1:0] temp_w_in [COLS];
    logic [ACC_W-1:0] temp_psum0, temp_psum1;
    
    // ============================================================================
    // UART Instantiation
    // ============================================================================
    assign baud_count_cfg = BAUD_COUNT[15:0];
    assign acc_clk = clk;
    
    uart_rx uart_rx_inst (
        .clk(clk),
        .rst_n(rst_n),
        .rx(rx),
        .baud_count(baud_count_cfg),
        .data(uart_rx_data),
        .data_valid(uart_rx_valid),
        .busy(uart_rx_busy)
    );
    
    uart_tx uart_tx_inst (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(uart_tx_data),
        .send(uart_tx_send),
        .baud_count(baud_count_cfg),
        .tx(tx),
        .busy(uart_tx_busy)
    );
    
    // ============================================================================
    // Protocol State Machine
    // ============================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pstate <= STATE_IDLE;
            acc_rst_n <= 1'b0;
            acc_start <= 1'b0;
            acc_h_in0 <= '0;
            acc_h_in1 <= '0;
            acc_v_in0 <= '0;
            acc_v_in1 <= '0;
            uart_tx_send <= 1'b0;
            uart_tx_data <= '0;
            temp_h_in0 <= '0;
            temp_h_in1 <= '0;
            temp_psum0 <= '0;
            temp_psum1 <= '0;
            
            for (int i = 0; i < COLS; i++)
                acc_w_in[i] <= '0;
                
            for (int i = 0; i < COLS; i++)
                temp_w_in[i] <= '0;
        end else begin
            pstate <= pnext_state;
            uart_tx_send <= 1'b0;  // Pulse signal
            
            case (pstate)
                // Idle - wait for command
                STATE_IDLE: begin
                    acc_start <= 1'b0;
                end
                
                // Command processing
                STATE_CMD: begin
                    if (uart_rx_valid) begin
                        case (uart_rx_data)
                            CMD_RESET: begin
                                acc_rst_n <= 1'b0;
                                // Send ACK
                                uart_tx_data <= 8'hAA;
                                uart_tx_send <= 1'b1;
                            end
                            
                            CMD_START: begin
                                acc_start <= 1'b1;
                                // Send ACK
                                uart_tx_data <= 8'hAA;
                                uart_tx_send <= 1'b1;
                            end
                            
                            // Other commands trigger state transitions
                            default: begin
                                // Send ACK for valid commands
                                if (uart_rx_data >= CMD_H_DATA && uart_rx_data <= CMD_STATUS) begin
                                    uart_tx_data <= 8'hAA;
                                    uart_tx_send <= 1'b1;
                                end
                            end
                        endcase
                    end
                end
                
                // Horizontal data input (2 bytes)
                STATE_H_DATA_0: begin
                    if (uart_rx_valid) begin
                        temp_h_in0 <= uart_rx_data[DATA_W-1:0];
                    end
                end
                
                STATE_H_DATA_1: begin
                    if (uart_rx_valid) begin
                        temp_h_in1 <= uart_rx_data[DATA_W-1:0];
                        acc_h_in0 <= temp_h_in0;
                        acc_h_in1 <= uart_rx_data[DATA_W-1:0];
                    end
                end
                
                // Vertical data input (2 bytes)
                STATE_V_DATA_0: begin
                    if (uart_rx_valid) begin
                        temp_v_in0 <= uart_rx_data[DATA_W-1:0];
                    end
                end
                
                STATE_V_DATA_1: begin
                    if (uart_rx_valid) begin
                        temp_v_in1 <= uart_rx_data[DATA_W-1:0];
                        acc_v_in0 <= temp_v_in0;
                        acc_v_in1 <= uart_rx_data[DATA_W-1:0];
                    end
                end
                
                // Weight input (4 bytes, 2 bits per byte packed)
                STATE_WEIGHTS_0: begin
                    if (uart_rx_valid) begin
                        temp_w_in[0] <= uart_rx_data[WEIGHT_W-1:0];
                    end
                end
                
                STATE_WEIGHTS_1: begin
                    if (uart_rx_valid) begin
                        temp_w_in[1] <= uart_rx_data[WEIGHT_W-1:0];
                    end
                end
                
                STATE_WEIGHTS_2: begin
                    if (uart_rx_valid) begin
                        temp_w_in[2] <= uart_rx_data[WEIGHT_W-1:0];
                    end
                end
                
                STATE_WEIGHTS_3: begin
                    if (uart_rx_valid) begin
                        temp_w_in[3] <= uart_rx_data[WEIGHT_W-1:0];
                        for (int i = 0; i < COLS; i++)
                            acc_w_in[i] <= temp_w_in[i];
                    end
                end
                
                // Send psum result (2 responses: psum0 LSB, psum0 MSB, psum1 LSB, psum1 MSB)
                STATE_RESP_PSUM_0: begin
                    temp_psum0 <= acc_psum_out0;
                    temp_psum1 <= acc_psum_out1;
                    uart_tx_data <= acc_psum_out0[7:0];
                    uart_tx_send <= 1'b1;
                end
                
                STATE_RESP_PSUM_1: begin
                    uart_tx_data <= acc_psum_out1[7:0];
                    uart_tx_send <= 1'b1;
                end
                
                default: begin
                    // Do nothing
                end
            endcase
        end
    end
    
    // Next state logic - Command dispatch
    always_comb begin
        pnext_state = STATE_IDLE;
        
        case (pstate)
            STATE_IDLE: begin
                if (uart_rx_valid) begin
                    case (uart_rx_data)
                        CMD_H_DATA:    pnext_state = STATE_H_DATA_0;
                        CMD_V_DATA:    pnext_state = STATE_V_DATA_0;
                        CMD_WEIGHTS:   pnext_state = STATE_WEIGHTS_0;
                        CMD_READ_PSUM: pnext_state = STATE_RESP_PSUM_0;
                        default:       pnext_state = STATE_CMD;
                    endcase
                end else begin
                    pnext_state = STATE_IDLE;
                end
            end
            
            STATE_CMD: begin
                pnext_state = STATE_IDLE;
            end
            
            STATE_H_DATA_0: begin
                if (uart_rx_valid) pnext_state = STATE_H_DATA_1;
                else pnext_state = STATE_H_DATA_0;
            end
            
            STATE_H_DATA_1: begin
                pnext_state = STATE_IDLE;
            end
            
            STATE_V_DATA_0: begin
                if (uart_rx_valid) pnext_state = STATE_V_DATA_1;
                else pnext_state = STATE_V_DATA_0;
            end
            
            STATE_V_DATA_1: begin
                pnext_state = STATE_IDLE;
            end
            
            STATE_WEIGHTS_0: begin
                if (uart_rx_valid) pnext_state = STATE_WEIGHTS_1;
                else pnext_state = STATE_WEIGHTS_0;
            end
            
            STATE_WEIGHTS_1: begin
                if (uart_rx_valid) pnext_state = STATE_WEIGHTS_2;
                else pnext_state = STATE_WEIGHTS_1;
            end
            
            STATE_WEIGHTS_2: begin
                if (uart_rx_valid) pnext_state = STATE_WEIGHTS_3;
                else pnext_state = STATE_WEIGHTS_2;
            end
            
            STATE_WEIGHTS_3: begin
                pnext_state = STATE_IDLE;
            end
            
            STATE_RESP_PSUM_0: begin
                if (!uart_tx_busy) pnext_state = STATE_RESP_PSUM_1;
                else pnext_state = STATE_RESP_PSUM_0;
            end
            
            STATE_RESP_PSUM_1: begin
                pnext_state = STATE_IDLE;
            end
            
            default: begin
                pnext_state = STATE_IDLE;
            end
        endcase
    end

endmodule
