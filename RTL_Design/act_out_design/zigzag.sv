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

    input  logic [DATA_W-1:0] h_in0,   // → PE13
    input  logic [DATA_W-1:0] h_in1,   // → PE33

    input  logic [DATA_W-1:0] v_in0,   // → PE30
    input  logic [DATA_W-1:0] v_in1,   // → PE32

    input  logic              en,
    input  logic              move_en,
    input  logic              psum_shift_en,
    input  logic              psum_clr,
    input  logic              w_ld_en,
    input  logic              fifo_en,

    input  logic [WEIGHT_W-1:0] w_in [0:COLS-1],
    input  logic [1:0]          direction,

    output logic [ACC_W-1:0]  psum_out0,  // PE10
    output logic [ACC_W-1:0]  psum_out1   // PE30
);

    // ── Direction decode ─────────────────────────────────────────
    // dst_sel: 00=to_right, 01=to_left, 10=to_down, 11=to_up
    // src_sel: 00=from_left, 01=from_right, 10=from_up, 11=from_down
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
            default: begin
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

    // ── act_out: single output wire per PE ───────────────────────
    // Replaces the 4 act_to_* wires per PE
    // PE array routes act_out[r][c] to the correct neighbour's
    // act_from_* input based on dst_sel[grp(r,c)]
    logic [ACC_W-1:0] act_out [0:ROWS-1][0:COLS-1];

    // ── act_from_*: per-PE directional input wires ───────────────
    // Kept from original design — each PE still receives from 4 directions
    // but they are now sourced from neighbours' act_out via routing mux
    logic [ACC_W-1:0] act_from_right [0:ROWS-1][0:COLS-1];
    logic [ACC_W-1:0] act_from_left  [0:ROWS-1][0:COLS-1];
    logic [ACC_W-1:0] act_from_up    [0:ROWS-1][0:COLS-1];
    logic [ACC_W-1:0] act_from_down  [0:ROWS-1][0:COLS-1];

    // ── Weight column chain ───────────────────────────────────────
    logic [WEIGHT_W-1:0] w_chain [0:ROWS][0:COLS-1];
    generate
        for (genvar c = 0; c < COLS; c++) begin : g_wchain_top
            assign w_chain[0][c] = w_in[c];
        end
    endgenerate

    // ── FIFOs ────────────────────────────────────────────────────
    // wr_data now reads from act_out[r][c] directly
    // h-phase: PE30=act_out[3][0], PE32=act_out[3][2]
    // v-phase: PE20=act_out[2][0], PE22=act_out[2][2]
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

    // ── act_from_* routing connections ───────────────────────────
    // Each act_from_* wire is driven by a routing mux that reads
    // act_out of the appropriate neighbour based on dst_sel.
    //
    // Wiring rule (corrected convention):
    //   act_from_left[r][c]  ← neighbour PE[r][c-1] if its dst_sel==to_right(00)
    //   act_from_right[r][c] ← neighbour PE[r][c+1] if its dst_sel==to_left(01)
    //   act_from_up[r][c]    ← neighbour PE[r-1][c] if its dst_sel==to_down(10)
    //   act_from_down[r][c]  ← neighbour PE[r+1][c] if its dst_sel==to_up(11)
    //
    // Since dataflow always ensures sender dst matches receiver src,
    // we directly assign without checking dst_sel — the direction
    // encoding guarantees consistency.
    //
    // Area note: act_from_* wires are now sourced from a single
    // act_out wire of the neighbour rather than a dedicated directional
    // output. This removes 3×ACC_W = 39 output wires per PE (4→1)
    // but adds routing mux logic at the array level for act_from_*
    // connections that have boundary conditions (h_in, v_in, FIFO).
    generate
        for (genvar r = 0; r < ROWS; r++) begin : g_conn_row
            for (genvar c = 0; c < COLS; c++) begin : g_conn_col

                // act_from_left: sourced from left neighbour's act_out
                assign act_from_left[r][c] =
                    (c == 0) ? '0
                             : act_out[r][c-1];

                // act_from_right: sourced from right neighbour's act_out
                // boundary: PE13←h_in0, PE33←h_in1
                assign act_from_right[r][c] =
                    (r==1 && c==3) ? ACC_W'(h_in0) :
                    (r==3 && c==3) ? ACC_W'(h_in1) :
                    (c == COLS-1)  ? '0
                                   : act_out[r][c+1];

                // act_from_up: sourced from upper neighbour's act_out
                assign act_from_up[r][c] =
                    (r == 0) ? '0
                             : act_out[r-1][c];

                // act_from_down: sourced from lower neighbour's act_out
                // boundary: PE30←v_in0, PE32←v_in1, PE10←fifo1, PE12←fifo2
                assign act_from_down[r][c] =
                    (r==3 && c==0) ? ACC_W'(v_in0)  :
                    (r==3 && c==2) ? ACC_W'(v_in1)  :
                    (r==1 && c==0) ? fifo1_dout      :
                    (r==1 && c==2) ? fifo2_dout      :
                    (r == ROWS-1)  ? '0
                                   : act_out[r+1][c];

            end
        end
    endgenerate

    // ── ICG latch for psum gated clock ───────────────────────────
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
                    .clk            (clk),
                    .rst_n          (rst_n),
                    .move_en        (move_en),
                    .psum_shift_en  (psum_shift_en),
                    .dst_sel        (dst_sel[grp(r,c)]),
                    .src_sel        (src_sel[grp(r,c)]),
                    .act_from_left  (act_from_left [r][c]),
                    .act_from_right (act_from_right[r][c]),
                    .act_from_up    (act_from_up   [r][c]),
                    .act_from_down  (act_from_down [r][c]),
                    .act_out        (act_out       [r][c]),  // single output
                    .w_ld_en        (w_ld_en),
                    .w_in           (w_chain[r][c]),
                    .w_out          (w_chain[r+1][c]),
                    .psum_clr       (psum_clr),
                    .en_latched     (en_latched)
                );
            end
        end
    endgenerate

    // ── psum drain tap points ────────────────────────────────────
    // During PSUM_SHIFT (direction=2'b10, h-zigzag):
    //   grp2 (PE10, PE30) dst=to_left → act_out exits at col 0
    assign psum_out0 = act_out[1][0];  // PE10
    assign psum_out1 = act_out[3][0];  // PE30

endmodule
