`timescale 1ns/1ps

module top_tb_100x100 #(
    parameter int DATA_W   = 6,
    parameter int WEIGHT_W = 2,
    parameter int ACC_W    = 13,
    parameter int ROWS     = 4,
    parameter int COLS     = 4,
    parameter int UNQ_DIR  = 4,
    parameter int IMG_SIZE = 100,
    parameter int OUT_SIZE = 98
)();

    // ── Signals ───────────────────────────────────────────────────
    logic clk, rst_n;
    logic start, done;

    logic [DATA_W-1:0]   h_in0, h_in1;
    logic [DATA_W-1:0]   v_in0, v_in1;
    logic [WEIGHT_W-1:0] w_in [0:COLS-1];
    logic [ACC_W-1:0]    psum_out0;
    logic [ACC_W-1:0]    psum_out1;

    // ── Image, Kernel, Output storage ─────────────────────────────
    logic [DATA_W-1:0]          image      [0:IMG_SIZE-1][0:IMG_SIZE-1];
    logic signed [WEIGHT_W-1:0] kernel     [0:2][0:2];
    logic signed [ACC_W-1:0]    output_map [0:OUT_SIZE-1][0:OUT_SIZE-1];

    // ── Tile position trackers ────────────────────────────────────
    int tile_row, tile_col;

    // ── Channel counter ───────────────────────────────────────────
    // Tracks which of the 4 channels is currently being computed
    int ch_idx;

    // ── DUT ───────────────────────────────────────────────────────
    top #(
        .DATA_W  (DATA_W),
        .WEIGHT_W(WEIGHT_W),
        .ACC_W   (ACC_W),
        .ROWS    (ROWS),
        .COLS    (COLS),
        .UNQ_DIR (UNQ_DIR)
    ) iDUT (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (start),
        .done     (done),
        .h_in0    (h_in0),
        .h_in1    (h_in1),
        .v_in0    (v_in0),
        .v_in1    (v_in1),
        .w_in     (w_in),
        .psum_out0(psum_out0),
        .psum_out1(psum_out1)
    );

    // ── Probe FSM state directly ──────────────────────────────────
    // This is the key — we watch the FSM state and react to it
    wire [2:0] fsm_state    = iDUT.u_fsm.state;
    wire [1:0] fsm_h_cnt    = iDUT.u_fsm.h_cnt;
    wire [2:0] fsm_v_cnt    = iDUT.u_fsm.v_cnt;
    wire [1:0] fsm_ch_cnt   = iDUT.u_fsm.ch_cnt;
    wire       fsm_w_ld_en  = iDUT.u_fsm.w_ld_en;

    // ── FSM state encoding (matches zigzag_fsm) ───────────────────
    localparam IDLE        = 3'd0;
    localparam CLEAR       = 3'd1;
    localparam FILL        = 3'd2;
    localparam W_LOAD      = 3'd3;
    localparam COMPUTE     = 3'd4;
    localparam H_SHIFT     = 3'd5;
    localparam V_SHIFT     = 3'd6;
    localparam PSUM_SHIFT  = 3'd7;

    // ── Clock ─────────────────────────────────────────────────────
    initial clk = 0;
    always #10 clk = ~clk;

    // ─────────────────────────────────────────────────────────────
    // FSM-STATE-DRIVEN INPUT LOGIC
    // All inputs are driven based on what state the FSM is in
    // No manual cycle counting — FSM leads, testbench follows
    // ─────────────────────────────────────────────────────────────

    // ── Drive h_in0/h_in1 based on FSM state ─────────────────────
    // FILL state    → feed initial patch row activations
    // H_SHIFT state → feed next column's activations
    always @(posedge clk) begin
        case (fsm_state)
            FILL, H_SHIFT: begin
                // h_in0 feeds into PE[1][3] — row (tile_row+1)
                // h_in1 feeds into PE[3][3] — row (tile_row+3)
                // tile_col offset by h_cnt to move the window right
                h_in0 <= (tile_row+1 < IMG_SIZE) ?
                          image[tile_row+1][tile_col + fsm_h_cnt] : '0;
                h_in1 <= (tile_row+3 < IMG_SIZE) ?
                          image[tile_row+3][tile_col + fsm_h_cnt] : '0;
            end
            default: begin
                h_in0 <= '0;
                h_in1 <= '0;
            end
        endcase
    end

    // ── Drive v_in0/v_in1 based on FSM state ─────────────────────
    // V_SHIFT state → feed next row's activations
    // v_cnt tells us which vertical shift we are on
    always @(posedge clk) begin
        case (fsm_state)
            V_SHIFT: begin
                // v_in0 feeds into PE[3][0] — col tile_col
                // v_in1 feeds into PE[3][2] — col tile_col+2
                // tile_row offset by v_cnt to move the window down
                v_in0 <= (tile_row + fsm_v_cnt < IMG_SIZE) ?
                          image[tile_row + fsm_v_cnt][tile_col]   : '0;
                v_in1 <= (tile_row + fsm_v_cnt < IMG_SIZE) ?
                          image[tile_row + fsm_v_cnt][tile_col+2] : '0;
            end
            default: begin
                v_in0 <= '0;
                v_in1 <= '0;
            end
        endcase
    end

    // ── Drive weights based on FSM state ─────────────────────────
    // W_LOAD state → feed kernel weights for current channel
    // ch_cnt tells us which channel we are loading
    always @(posedge clk) begin
        case (fsm_state)
            W_LOAD, COMPUTE: begin
                // ch_cnt selects which kernel row to load
                // All columns get the same weight for simplicity
                foreach (w_in[i])
                    w_in[i] <= kernel[fsm_ch_cnt][i < 3 ? i : 2];
            end
            default: begin
                foreach (w_in[i]) w_in[i] <= '0;
            end
        endcase
    end

    // ── Collect psum outputs during PSUM_SHIFT ────────────────────
    // When FSM is draining, capture psum_out0/1 into output_map
    always @(posedge clk) begin
        if (fsm_state == PSUM_SHIFT) begin
            if (psum_out0 !== '0) begin
                output_map[tile_row  ][tile_col] <= psum_out0;
                $display("  STORED | out[%0d][%0d] = %0d",
                          tile_row, tile_col, psum_out0);
            end
            if (psum_out1 !== '0) begin
                output_map[tile_row+2][tile_col] <= psum_out1;
                $display("  STORED | out[%0d][%0d] = %0d",
                          tile_row+2, tile_col, psum_out1);
            end
        end
    end

    // ─────────────────────────────────────────────────────────────
    // TASKS
    // ─────────────────────────────────────────────────────────────

    // ── Reset + start one tile ────────────────────────────────────
    task automatic start_tile();
        rst_n = 0;
        start = 0;
        repeat(2) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
        $display("[TILE %0d,%0d] FSM started", tile_row, tile_col);
    endtask

    // ── Wait for FSM to reach a state ─────────────────────────────
    task automatic wait_for_state(input logic [2:0] target);
        int timeout;
        timeout = 500;
        while (fsm_state !== target && timeout > 0) begin
            @(posedge clk);
            timeout--;
        end
        if (timeout == 0)
            $display("TIMEOUT | state %0d never reached", target);
    endtask

    // ── Wait for done and collect outputs ─────────────────────────
    task automatic wait_for_done();
        int timeout;
        timeout = 500;
        while (!done && timeout > 0) begin
            @(posedge clk);
            timeout--;
        end
        if (timeout == 0)
            $display("FAIL | TILE [%0d][%0d] done never asserted",
                      tile_row, tile_col);
        else
            $display("[TILE %0d,%0d] done asserted", tile_row, tile_col);
    endtask

    // ── Check output map ──────────────────────────────────────────
    // With image=1s and kernel=1s, every output = 9
    task automatic check_output_map();
        int pass_count, fail_count;
        pass_count = 0;
        fail_count = 0;
        $display("\n>> Checking output map (expected all = 9) <<");
        for (int r = 0; r < OUT_SIZE; r++) begin
            for (int c = 0; c < OUT_SIZE; c++) begin
                if (output_map[r][c] === 13'sd9)
                    pass_count++;
                else begin
                    fail_count++;
                    $display("FAIL | output_map[%0d][%0d] = %0d (expected 9)",
                              r, c, output_map[r][c]);
                end
            end
        end
        $display("\n>> Results: %0d PASS | %0d FAIL out of %0d pixels",
                  pass_count, fail_count, OUT_SIZE * OUT_SIZE);
    endtask

    // ─────────────────────────────────────────────────────────────
    // STIMULUS — FSM leads, testbench just starts each tile
    // ─────────────────────────────────────────────────────────────
    initial begin
        $dumpfile("top_tb_100x100.vcd");
        $dumpvars(0, top_tb_100x100);

        // ── Initialize image — all pixels = 1 ────────────────────
        for (int r = 0; r < IMG_SIZE; r++)
            for (int c = 0; c < IMG_SIZE; c++)
                image[r][c] = 6'd1;

        // ── Initialize kernel — all weights = +1 ─────────────────
        for (int kr = 0; kr < 3; kr++)
            for (int kc = 0; kc < 3; kc++)
                kernel[kr][kc] = 2'b01;

        // ── Clear output map ──────────────────────────────────────
        for (int r = 0; r < OUT_SIZE; r++)
            for (int c = 0; c < OUT_SIZE; c++)
                output_map[r][c] = '0;

        // ── Tile loop ─────────────────────────────────────────────
        // For each output pixel position, start the FSM and let it run
        // The always blocks above handle driving the right inputs
        // at the right time based on FSM state
        for (tile_row = 0; tile_row < OUT_SIZE; tile_row++) begin
            for (tile_col = 0; tile_col < OUT_SIZE; tile_col++) begin

                $display("\n════ TILE [%0d][%0d] ════", tile_row, tile_col);

                // Start FSM for this tile
                start_tile();

                // Just wait for FSM to complete —
                // inputs are driven automatically by always blocks above
                wait_for_done();
            end
        end

        // ── Verify all outputs ────────────────────────────────────
        check_output_map();

        repeat(5) @(posedge clk);
        $display("\n── 100×100 Convolution Complete ──");
        $stop();
    end

endmodule