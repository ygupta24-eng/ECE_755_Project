module pe #(
    parameter int DATA_W = 8,
    parameter int ACC_W  = 24
)(
    input  logic              clk,
    input  logic              rst_n,

    // Clock enable for compute domain
    input  logic              en,

    // Control
    input  logic              move_en,     // enable systolic movement
    // input  logic              compute_en,  // enable MAC
    input  logic [1:0]        dst_sel,     // 00=left, 01=right, 10=up, 11=down
    input  logic [1:0]        src_sel,     // 00=left, 01=right, 10=up, 11=down

    // Activations from neighbors
    input  logic [DATA_W-1:0] act_from_left,
    input  logic [DATA_W-1:0] act_from_right,
    input  logic [DATA_W-1:0] act_from_up,
    input  logic [DATA_W-1:0] act_from_down,

    // Activations to neighbors
    output logic [DATA_W-1:0] act_to_left,
    output logic [DATA_W-1:0] act_to_right,
    output logic [DATA_W-1:0] act_to_up,
    output logic [DATA_W-1:0] act_to_down,

    // Column-wise weight load / pass
    input  logic              w_ld_en,
    input  logic [DATA_W-1:0] w_in,
    output logic [DATA_W-1:0] w_out,

    // Partial sum
    output logic [ACC_W-1:0]  psum_out,
    input  logic              psum_clr
);

    // ------------------------------------------------------------
    // Registers
    // ------------------------------------------------------------
    logic [DATA_W-1:0] move_reg;     // systolic movement register
    // logic [DATA_W-1:0] compute_reg;  // value used for MAC
    logic [DATA_W-1:0] w_reg;        // local weight

    // ------------------------------------------------------------
    // Combinational incoming mux (based on sel_src)
    // ------------------------------------------------------------
    logic [DATA_W-1:0] incoming;

    always_comb begin
        unique case (src_sel)
            2'b00: incoming = act_from_left;
            2'b01: incoming = act_from_right;
            2'b10: incoming = act_from_up;
            2'b11: incoming = act_from_down;
            default: incoming = '0;
        endcase
    end

    // ------------------------------------------------------------
    // Weight register + column-wise shift
    // ------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w_reg <= '0;
        end else if (w_ld_en) begin //end else if (pe_clk_en && w_ld_en) begin // we want to load weight even if not computing, so that it's ready for when compute starts.
            // This PE takes weight from w_in (from PE above or input)
            w_reg <= w_in;
        end
    end

    assign w_out = w_reg; // pass weight down the column

    // ------------------------------------------------------------
    // Partial sum accumulator (single MAC)
    // ------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            psum_out <= '0;
        end else if (en) begin
            if (psum_clr) begin
                psum_out <= '0;
            end else begin  //end else if (compute_en) begin
                // MAC on previous-cycle activation (move_reg) and current weight
                psum_out <= psum_out + move_reg * w_reg;
            end
        end
    end

    // ------------------------------------------------------------
    // Movement + compute_reg capture
    // ------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            move_reg    <= '0;
            // compute_reg <= '0;

            act_to_left  <= '0;
            act_to_right <= '0;
            act_to_up    <= '0;
            act_to_down  <= '0;

        end else begin
            // MOVE: systolic propagation of activations
            if (move_en) begin
                // Forward previous move_reg to the opposite side
                unique case (dst_sel)
                    2'b00: act_to_right <= move_reg; // left -> right
                    2'b01: act_to_left  <= move_reg; // right -> left
                    2'b10: act_to_down  <= move_reg; // up -> down
                    2'b11: act_to_up    <= move_reg; // down -> up
                endcase

                // Capture new activation into move_reg
                move_reg <= incoming;
            end

            // Compute register captures the value that was in move_reg
            // This lets compute use the previous cycle's incoming data
            // if (pe_clk_en) begin
            //     compute_reg <= move_reg;
            // end
        end
    end

endmodule