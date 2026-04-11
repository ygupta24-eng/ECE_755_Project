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
    input  logic              fifo_en,  // gate FIFO wr during initial fill

    input  logic [WEIGHT_W-1:0] w_in [0:COLS-1],

    input  logic [1:0]          direction,

    // psum drain — via act_to_left at col 0
    output logic [ACC_W-1:0]  psum_out0,  // PE10
    output logic [ACC_W-1:0]  psum_out1   // PE30
);

    logic en_latched;
    // Level-sensitive latch: transparent when clk=0, holds when clk=1
    always_latch begin
        if (~clk)
            en_latched = en;   // sample en directly — no pipeline delay needed
    end

    // ── Direction decode ─────────────────────────────────────────
    logic [1:0] dst_sel [0:UNQ_DIR-1];
    logic [1:0] src_sel [0:UNQ_DIR-1];

    //direction decoding
    // dst_sel   // 00 to_right , 01 to_left   , 10 to_down, 11 to_up
    // src_sel   // 00 from_left, 01 from_right, 10 from_up, 11 from_down

    // dst_sel 0 and src_sel 0 for PE00, PE02, PE20, PE22
    // dst_sel 1 and src_sel 1 for PE01, PE03, PE21, PE23
    // dst_sel 2 and src_sel 2 for PE10, PE12, PE30, PE32
    // dst_sel 3 and src_sel 3 for PE11, PE13, PE31, PE33

    always_comb begin : direction_encoding
        unique case (direction)
            //circular shift
            2'b11: begin
                dst_sel[0] = 2'b10; // to down
                src_sel[0] = 2'b01; // from right

                dst_sel[1] = 2'b01; // to left
                src_sel[1] = 2'b11; // from down

                dst_sel[2] = 2'b00; // to_right
                src_sel[2] = 2'b10; // from up

                dst_sel[3] = 2'b11; // to up
                src_sel[3] = 2'b00; // from left    
            end

            // horizontal zig-zag
            2'b10: begin
                dst_sel[0] = 2'b10; // to down
                src_sel[0] = 2'b01; // from right

                dst_sel[1] = 2'b01; // to left
                src_sel[1] = 2'b11; // from down

                dst_sel[2] = 2'b01; // to left
                src_sel[2] = 2'b10; // from up

                dst_sel[3] = 2'b11; // to up
                src_sel[3] = 2'b01; // from right  
            end

            // vertical zig-zag
            2'b01: begin
                dst_sel[0] = 2'b11; // to up
                src_sel[0] = 2'b01; // from right

                dst_sel[1] = 2'b01; // to left
                src_sel[1] = 2'b11; // from down

                dst_sel[2] = 2'b00; // to_right
                src_sel[2] = 2'b11; // from down

                dst_sel[3] = 2'b11; // to up
                src_sel[3] = 2'b00; // from left 
            end

            //default to circular shift
            default : begin
                dst_sel[0] = 2'b10; // to down
                src_sel[0] = 2'b01; // from right

                dst_sel[1] = 2'b01; // to left
                src_sel[1] = 2'b11; // from down

                dst_sel[2] = 2'b00; // to_right
                src_sel[2] = 2'b10; // from up

                dst_sel[3] = 2'b11; // to up
                src_sel[3] = 2'b00; // from left 
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

    // ── Inter-PE wires ───────────────────────────────────────────
    logic [ACC_W-1:0] act_to_right  [0:ROWS-1][0:COLS-1];
    logic [ACC_W-1:0] act_to_left   [0:ROWS-1][0:COLS-1];
    logic [ACC_W-1:0] act_to_up     [0:ROWS-1][0:COLS-1];
    logic [ACC_W-1:0] act_to_down   [0:ROWS-1][0:COLS-1];
    logic [ACC_W-1:0] act_from_right[0:ROWS-1][0:COLS-1];
    logic [ACC_W-1:0] act_from_left [0:ROWS-1][0:COLS-1];
    logic [ACC_W-1:0] act_from_up   [0:ROWS-1][0:COLS-1];
    logic [ACC_W-1:0] act_from_down [0:ROWS-1][0:COLS-1];

    // ── Weight column chain ──────────────────────────────────────
    logic [WEIGHT_W-1:0] w_chain [0:ROWS][0:COLS-1];
    generate
        for (genvar c = 0; c < COLS; c++) begin : g_wchain_top
            assign w_chain[0][c] = w_in[c];
        end
    endgenerate

    // ── FIFOs ───────────────────────────────────────────────────
    logic [ACC_W-1:0] fifo1_dout, fifo2_dout;
    logic             fifo1_full, fifo1_empty;
    logic             fifo2_full, fifo2_empty;

    fifo9 #(.DATA_W(ACC_W)) u_fifo1 (
        .clk     (clk),
        .rst_n   (rst_n),
        .wr_en   (move_en && fifo_en && !psum_shift_en &&   // fix: gate psum_shift
                  ((direction == 2'b10) || (direction == 2'b01))),
        .wr_data ((direction == 2'b10) ? act_to_left[3][0]
                                       : act_to_up[2][0]),
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
        .wr_data ((direction == 2'b10) ? act_to_left[3][2]
                                       : act_to_up[2][2]),
        .full    (fifo2_full),
        .rd_en   (move_en && !psum_shift_en && (direction == 2'b01)), //vertical only
        .rd_data (fifo2_dout),
        .empty   (fifo2_empty)
    );

    // ── Neighbour connections ────────────────────────────────────
    generate
        for (genvar r = 0; r < ROWS; r++) begin : g_conn_row
            for (genvar c = 0; c < COLS; c++) begin : g_conn_col

                assign act_from_left[r][c] =
                    (c == 0) ? '0
                             : act_to_right[r][c-1];

                // explicit zero-extend h_in to ACC_W
                assign act_from_right[r][c] =
                    (r==1 && c==3) ? ACC_W'(h_in0) :  // fix: explicit cast
                    (r==3 && c==3) ? ACC_W'(h_in1) :
                    (c == COLS-1)  ? '0
                                   : act_to_left[r][c+1];

                assign act_from_up[r][c] =
                    (r == 0) ? '0
                             : act_to_down[r-1][c];

                // explicit zero-extend v_in to ACC_W
                assign act_from_down[r][c] =
                    (r==3 && c==0) ? ACC_W'(v_in0)  :  // fix: explicit cast
                    (r==3 && c==2) ? ACC_W'(v_in1)  :
                    (r==1 && c==0) ? fifo1_dout      :
                    (r==1 && c==2) ? fifo2_dout      :
                    (r == ROWS-1)  ? '0
                                   : act_to_up[r+1][c];

            end
        end
    endgenerate

    // ── PE instantiation ────────────────────────────────────────
    generate
        for (genvar r = 0; r < ROWS; r++) begin : g_pe_row
            for (genvar c = 0; c < COLS; c++) begin : g_pe_col
                pe #(
                    .DATA_W   (DATA_W),
                    .WEIGHT_W (WEIGHT_W),  // fix: was missing
                    .ACC_W    (ACC_W)
                ) u_pe (
                    .clk            (clk),
                    .rst_n          (rst_n),
                    .en             (en),
                    .move_en        (move_en),
                    .psum_shift_en  (psum_shift_en),
                    .dst_sel        (dst_sel[grp(r,c)]),
                    .src_sel        (src_sel[grp(r,c)]),
                    .act_from_left  (act_from_left [r][c]),
                    .act_from_right (act_from_right[r][c]),
                    .act_from_up    (act_from_up   [r][c]),
                    .act_from_down  (act_from_down [r][c]),
                    .act_to_left    (act_to_left   [r][c]),
                    .act_to_right   (act_to_right  [r][c]),
                    .act_to_up      (act_to_up     [r][c]),
                    .act_to_down    (act_to_down   [r][c]),
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
    // grp2 dst=to_left during h-zigzag (direction=2'b10)
    // psum_shift reuses h-zigzag direction so PE10/PE30 drain leftward
    // no psum_shift_en gate needed — act_to_left is cleared by PE
    // when not in shift mode (shift_falling clears it)
    assign psum_out0 = act_to_left[1][0];  // PE10 fix: left not right
    assign psum_out1 = act_to_left[3][0];  // PE30 fix: left not right

endmodule