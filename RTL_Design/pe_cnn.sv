module pe #(
    parameter DATA_W = 8,
    parameter ACC_W  = 24,
    parameter CH_PAR = 8
)(
    input  logic                 clk,
    input  logic                 rst_n,

    // Local clock enable (for clock gating)
    input  logic                 pe_clk_en,

    // Small, broadcast control word
    input  logic [1:0]           mode,        // 0: idle, 1: compute, 2: move
    input  logic [1:0]           sel_src,     // which neighbor to read from in move mode

    // Neighbor links
    input  logic [DATA_W-1:0]    act_from_left,
    input  logic [DATA_W-1:0]    act_from_right,
    input  logic [DATA_W-1:0]    act_from_up,
    input  logic [DATA_W-1:0]    act_from_down,

    output logic [DATA_W-1:0]    act_to_left,
    output logic [DATA_W-1:0]    act_to_right,
    output logic [DATA_W-1:0]    act_to_up,
    output logic [DATA_W-1:0]    act_to_down,

    // Weight load (local, narrow)
    input  logic                 w_ld_en,
    input  logic [DATA_W-1:0]    w_ld_data [CH_PAR-1:0],

    // Partial sums
    output logic [ACC_W-1:0]     psum_out [CH_PAR-1:0],
    input  logic                 psum_clr    // clear accumulators for new output pixel
);

    /*Dataflow:-
    1. Load weights into local registers, mode = 2'b00 (idle), w_ld_en = 1, w_ld_data valid
    2. Move activations, first shifting may take multiple cycles to propagate through the array, 
       mode = 2'b10 (move), sel_src indicates direction, act_from_* valid, act_to_* driven by PE
    3. Compute partial sums, mode = 2'b01 (compute), psum_out accumulates act_reg * rf_wgt
       psum_clr to be pulsed only when all channels of 9 activations have been processed for that output pixel, then we can clear psum_out for the next output pixel
    4. Repeat steps 2 and 3 until all 9 activation are computed with that weights,
       then we can load new weights, psum_clr might not be needed until all  channel input pixels are processed.
    */

    // Current activation (one pixel, one channel)
    logic [DATA_W-1:0] act_reg;

    // Weights for current input channel (one per output channel lane)
    logic [DATA_W-1:0] rf_wgt [CH_PAR-1:0];

    // -------------------------
    // Weight register file
    // -------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < CH_PAR; i++)
                rf_wgt[i] <= '0;
        end else if (pe_clk_en) begin
            if (w_ld_en) begin
                for (int i = 0; i < CH_PAR; i++)
                    rf_wgt[i] <= w_ld_data[i]; // Load weights for all output channels in parallel
            end
        end
    end

    // -------------------------
    // Partial sum accumulators
    // -------------------------
    // In compute mode, multiply current activation by weights and accumulate into psum_out.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < CH_PAR; i++)
                psum_out[i] <= '0;
        end else if (pe_clk_en) begin
            if (psum_clr) begin
                for (int i = 0; i < CH_PAR; i++)
                    psum_out[i] <= '0;
            end else if (mode == 2'b01) begin // compute
                for (int i = 0; i < CH_PAR; i++)
                    psum_out[i] <= psum_out[i] + act_reg * rf_wgt[i];
            end
        end
    end

    // -------------------------
    // Activation move + capture
    // -------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            act_reg      <= '0;
            act_to_left  <= '0;
            act_to_right <= '0;
            act_to_up    <= '0;
            act_to_down  <= '0;
        end else if (pe_clk_en) begin
            if (mode == 2'b10) begin // move mode
                // Forward current activation out, capture new one from selected neighbor
                unique case (sel_src)
                    // 00 is from left, forward to right =>
                    // 01 is from right, forward to left <=
                    // 10 is from up, forward to down ||
                    // 11 is from down, forward to up ||
                    2'b00: begin // from left, forward to right (example pattern)
                        act_to_right <= act_reg;
                        act_reg      <= act_from_left;

                        //set other directions to 0
                        act_to_left  <= '0;
                        act_to_up    <= '0;
                        act_to_down  <= '0;
                    end
                    2'b01: begin // from right, forward to left
                        act_to_left <= act_reg;
                        act_reg     <= act_from_right;

                        //set other directions to 0
                        act_to_right <= '0;
                        act_to_up    <= '0;
                        act_to_down  <= '0;
                    end
                    2'b10: begin // from up, forward to down
                        act_to_down <= act_reg;
                        act_reg     <= act_from_up;

                        //set other directions to 0
                        act_to_left  <= '0;
                        act_to_right <= '0;
                        act_to_up    <= '0;
                    end
                    2'b11: begin // from down, forward to up
                        act_to_up <= act_reg;
                        act_reg   <= act_from_down;

                        //set other directions to 0
                        act_to_left  <= '0;
                        act_to_right <= '0;
                        act_to_down  <= '0;
                    end
                    default: begin
                        act_to_left  <= '0;
                        act_to_right <= '0;
                        act_to_up    <= '0;
                        act_to_down  <= '0;
                    end
                endcase
            end
            // In compute mode, act_reg is held constant for that cycle;
            // neighbor outputs can either hold last value or be driven separately if needed.
        end
    end

endmodule