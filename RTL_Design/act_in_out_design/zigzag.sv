module zig_zag_4x4 #(
    parameter int DATA_W   = 6,
    parameter int WEIGHT_W = 2,
    parameter int ACC_W    = 13,
    parameter int ROWS     = 4,
    parameter int COLS     = 4,
    parameter int UNQ_DIR  = 4
)(
    input  logic clk,
    input  logic rst_n,

    // Horizontal boundary inputs — DATA_W wide (zero-extended internally)
    input  logic [DATA_W-1:0] h_in0,   // → PE13
    input  logic [DATA_W-1:0] h_in1,   // → PE33

    // Vertical boundary inputs
    input  logic [DATA_W-1:0] v_in0,   // → PE30
    input  logic [DATA_W-1:0] v_in1,   // → PE32

    // Control
    input  logic              en,
    input  logic              move_en,
    input  logic              psum_shift_en,
    input  logic              psum_clr,
    input  logic              w_ld_en,
    input  logic              fifo_en,

    input  logic [WEIGHT_W-1:0] w_in [0:COLS-1],

    input  logic [1:0]          direction,

    // psum drain outputs
    output logic [ACC_W-1:0]  psum_out0,  // PE10
    output logic [ACC_W-1:0]  psum_out1   // PE30
);

    // ── Direction decode ─────────────────────────────────────────
    // dst_sel: where each group sends its act_out
    //   00=right, 01=left, 10=down, 11=up
    // src_sel: where each group reads its act_in from
    //   00=from_left, 01=from_right, 10=from_up, 11=from_down
    logic [1:0] dst_sel [0:UNQ_DIR-1];
    logic [1:0] src_sel [0:UNQ_DIR-1];

    always_comb begin : direction_encoding
        unique case (direction)
            2'b11: begin  // circular
                dst_sel[0] = 2'b10; src_sel[0] = 2'b01;
                dst_sel[1] = 2'b01; src_sel[1] = 2'b11;
                dst_sel[2] = 2'b00; src_sel[2] = 2'b10;
                dst_sel[3] = 2'b11; src_sel[3] = 2'b00;
            end
            2'b10: begin  // horizontal zigzag
                dst_sel[0] = 2'b10; src_sel[0] = 2'b01;
                dst_sel[1] = 2'b01; src_sel[1] = 2'b11;
                dst_sel[2] = 2'b01; src_sel[2] = 2'b10;
                dst_sel[3] = 2'b11; src_sel[3] = 2'b01;
            end
            2'b01: begin  // vertical zigzag
                dst_sel[0] = 2'b11; src_sel[0] = 2'b01;
                dst_sel[1] = 2'b01; src_sel[1] = 2'b11;
                dst_sel[2] = 2'b00; src_sel[2] = 2'b11;
                dst_sel[3] = 2'b11; src_sel[3] = 2'b00;
            end
            default: begin  // default circular
                dst_sel[0] = 2'b10; src_sel[0] = 2'b01;
                dst_sel[1] = 2'b01; src_sel[1] = 2'b11;
                dst_sel[2] = 2'b00; src_sel[2] = 2'b10;
                dst_sel[3] = 2'b11; src_sel[3] = 2'b00;
            end
        endcase
    end

    // ── Group lookup ─────────────────────────────────────────────
    function automatic logic [1:0] grp(input int r, input int c);
        if (r%2==0 && c%2==0) return 2'd0;
        if (r%2==0 && c%2==1) return 2'd1;
        if (r%2==1 && c%2==0) return 2'd2;
        return 2'd3;
    endfunction

    // ── Single act_out wire per PE ───────────────────────────────
    // Each PE drives one output — array routes it to the right neighbour
    logic [ACC_W-1:0] act_out [0:ROWS-1][0:COLS-1];

    // ── act_in per PE — selected by array routing mux ────────────
    // src_sel of PE[r][c] determines which neighbour's act_out it reads
    // Routing law (corrected wiring convention):
    //   src=from_left  (00): read act_out of PE[r][c-1] IF that PE has dst=right(00)
    //   src=from_right (01): read act_out of PE[r][c+1] IF that PE has dst=left(01)
    //   src=from_up    (10): read act_out of PE[r-1][c] IF that PE has dst=down(10)
    //   src=from_down  (11): read act_out of PE[r+1][c] IF that PE has dst=up(11)
    //
    // Since all PEs in a group share src_sel and the dataflow is always
    // consistent (sender dst matches receiver src), we just wire directly:
    //   from_left  → act_out[r][c-1]  (left neighbour)
    //   from_right → act_out[r][c+1]  (right neighbour)
    //   from_up    → act_out[r-1][c]  (upper neighbour's act_out, sent downward)
    //   from_down  → act_out[r+1][c]  (lower neighbour's act_out, sent upward)
    //
    // Boundary conditions and FIFO inputs handled per PE below
    logic [ACC_W-1:0] act_in [0:ROWS-1][0:COLS-1];

    // ── Weight column chain ───────────────────────────────────────
    logic [WEIGHT_W-1:0] w_chain [0:ROWS][0:COLS-1];
    generate
        for (genvar c = 0; c < COLS; c++) begin : g_wchain_top
            assign w_chain[0][c] = w_in[c];
        end
    endgenerate

    // ── FIFOs ────────────────────────────────────────────────────
    // FIFO1: captures PE30 output (h-phase) or PE20 output (v-phase) → feeds PE10
    // FIFO2: captures PE32 output (h-phase) or PE22 output (v-phase) → feeds PE12
    logic [ACC_W-1:0] fifo1_dout, fifo2_dout;
    logic             fifo1_full, fifo1_empty;
    logic             fifo2_full, fifo2_empty;

    fifo9 #(.DATA_W(ACC_W)) u_fifo1 (
        .clk     (clk),
        .rst_n   (rst_n),
        .wr_en   (move_en && fifo_en && !psum_shift_en &&
                  ((direction == 2'b10) || (direction == 2'b01))),
        .wr_data ((direction == 2'b10) ? act_out[3][0]   // PE30 h-phase
                                       : act_out[2][0]), // PE20 v-phase
        .full    (fifo1_full),
        .rd_en   (move_en && !psum_shift_en && (direction == 2'b01)),
        .rd_data (fifo1_dout),
        .empty   (fifo1_empty)
    );

    fifo9 #(.DATA_W(ACC_W)) u_fifo2 (
        .clk     (clk),
        .rst_n   (rst_n),
        .wr_en   (move_en && fifo_en && !psum_shift_en &&
                  ((direction == 2'b10) || (direction == 2'b01))),
        .wr_data ((direction == 2'b10) ? act_out[3][2]   // PE32 h-phase
                                       : act_out[2][2]), // PE22 v-phase
        .full    (fifo2_full),
        .rd_en   (move_en && !psum_shift_en && (direction == 2'b01)),
        .rd_data (fifo2_dout),
        .empty   (fifo2_empty)
    );

    // ── act_in routing mux ───────────────────────────────────────
    // For each PE[r][c], act_in is selected based on src_sel[grp(r,c)]
    // which tells us which neighbour is the source this cycle.
    //
    // Area implication: this is a 4-to-1 mux (ACC_W wide) per PE
    // = 16 PEs × 13 bits × 4-to-1 = 832 mux inputs
    // vs current design: fixed wires (0 mux gates, just routing)
    // This is the area increase we are measuring.
    generate
        for (genvar r = 0; r < ROWS; r++) begin : g_in_row
            for (genvar c = 0; c < COLS; c++) begin : g_in_col
                always_comb begin
                    case (src_sel[grp(r,c)])
                        // from_left (00): receive from PE to the left
                        2'b00: begin
                            if (c == 0)
                                act_in[r][c] = '0;
                            else
                                act_in[r][c] = act_out[r][c-1];
                        end

                        // from_right (01): receive from PE to the right
                        //   special: PE13 ← h_in0, PE33 ← h_in1 (boundary)
                        2'b01: begin
                            if      (r==1 && c==3) act_in[r][c] = ACC_W'(h_in0);
                            else if (r==3 && c==3) act_in[r][c] = ACC_W'(h_in1);
                            else if (c == COLS-1)  act_in[r][c] = '0;
                            else                   act_in[r][c] = act_out[r][c+1];
                        end

                        // from_up (10): receive from PE above
                        //   wiring law: PE above sends DOWN, read its act_out
                        2'b10: begin
                            if (r == 0)
                                act_in[r][c] = '0;
                            else
                                act_in[r][c] = act_out[r-1][c];
                        end

                        // from_down (11): receive from PE below
                        //   wiring law: PE below sends UP, read its act_out
                        //   special: FIFO outputs and v_in boundary inputs
                        2'b11: begin
                            if      (r==3 && c==0) act_in[r][c] = ACC_W'(v_in0);
                            else if (r==3 && c==2) act_in[r][c] = ACC_W'(v_in1);
                            else if (r==1 && c==0) act_in[r][c] = fifo1_dout;
                            else if (r==1 && c==2) act_in[r][c] = fifo2_dout;
                            else if (r == ROWS-1)  act_in[r][c] = '0;
                            else                   act_in[r][c] = act_out[r+1][c];
                        end

                        default: act_in[r][c] = '0;
                    endcase
                end
            end
        end
    endgenerate

    // ── ICG latch for psum gated clock ───────────────────────────
    // en is latched on negedge to create glitch-free enable for each PE
    // All 16 PEs share the same en signal so one latch is sufficient
    logic en_latched;
    always_latch begin
        if (!clk) en_latched = en;
    end

    // ── PE instantiation ─────────────────────────────────────────
    generate
        for (genvar r = 0; r < ROWS; r++) begin : g_pe_row
            for (genvar c = 0; c < COLS; c++) begin : g_pe_col
                pe #(
                    .DATA_W   (DATA_W),
                    .WEIGHT_W (WEIGHT_W),
                    .ACC_W    (ACC_W)
                ) u_pe (
                    .clk          (clk),
                    .rst_n        (rst_n),
                    .move_en      (move_en),
                    .psum_shift_en(psum_shift_en),
                    // dst_sel removed from PE — routing handled above
                    .src_sel      (src_sel[grp(r,c)]),
                    .act_in       (act_in  [r][c]),   // from routing mux
                    .act_out      (act_out [r][c]),   // single output
                    .w_ld_en      (w_ld_en),
                    .w_in         (w_chain[r][c]),
                    .w_out        (w_chain[r+1][c]),
                    .psum_clr     (psum_clr),
                    .en_latched   (en_latched)
                );
            end
        end
    endgenerate

    // ── psum drain tap points ────────────────────────────────────
    // During PSUM_SHIFT (direction=h-zigzag=2'b10):
    //   grp2 (PE10, PE30) has dst=left → act_out exits left at col 0
    // act_out[1][0] = PE10 output, act_out[3][0] = PE30 output
    assign psum_out0 = act_out[1][0];  // PE10
    assign psum_out1 = act_out[3][0];  // PE30

endmodule
