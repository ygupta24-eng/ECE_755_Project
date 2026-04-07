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
    logic signed [ACC_W-1:0]    output_map [0:OUT_SIZE+3][0:OUT_SIZE+3];

    // ── Tile position trackers ────────────────────────────────────
    int tile_row, tile_col;

    // ── Drain cycle counter ───────────────────────────────────────
    int drain_cycle;

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
    wire [2:0] fsm_state  = iDUT.u_fsm.state;
    wire [1:0] fsm_h_cnt  = iDUT.u_fsm.h_cnt;
    wire [2:0] fsm_v_cnt  = iDUT.u_fsm.v_cnt;
    wire [1:0] fsm_ch_cnt = iDUT.u_fsm.ch_cnt;

    // ── FSM state encoding ────────────────────────────────────────
    localparam IDLE       = 3'd0;
    localparam CLEAR      = 3'd1;
    localparam FILL       = 3'd2;
    localparam W_LOAD     = 3'd3;
    localparam COMPUTE    = 3'd4;
    localparam H_SHIFT    = 3'd5;
    localparam V_SHIFT    = 3'd6;
    localparam PSUM_SHIFT = 3'd7;

    // ── Clock ─────────────────────────────────────────────────────
    initial clk = 0;
    always #10 clk = ~clk;

    // ─────────────────────────────────────────────────────────────
    // COMBINATIONAL INPUT DRIVING
    // ─────────────────────────────────────────────────────────────

    // ── h_in0/h_in1 — feed during FILL and H_SHIFT ───────────────
    assign h_in0 = ((fsm_state == FILL || fsm_state == H_SHIFT) &&
                    (tile_row+1 < IMG_SIZE) &&
                    (tile_col + fsm_h_cnt < IMG_SIZE)) ?
                    image[tile_row+1][tile_col + fsm_h_cnt] : '0;

    assign h_in1 = ((fsm_state == FILL || fsm_state == H_SHIFT) &&
                    (tile_row+3 < IMG_SIZE) &&
                    (tile_col + fsm_h_cnt < IMG_SIZE)) ?
                    image[tile_row+3][tile_col + fsm_h_cnt] : '0;

    // ── v_in0/v_in1 — feed during V_SHIFT ────────────────────────
    assign v_in0 = ((fsm_state == V_SHIFT) &&
                    (tile_row + fsm_v_cnt < IMG_SIZE) &&
                    (tile_col < IMG_SIZE)) ?
                    image[tile_row + fsm_v_cnt][tile_col]   : '0;

    assign v_in1 = ((fsm_state == V_SHIFT) &&
                    (tile_row + fsm_v_cnt < IMG_SIZE) &&
                    (tile_col+2 < IMG_SIZE)) ?
                    image[tile_row + fsm_v_cnt][tile_col+2] : '0;

    // ── weights — feed during W_LOAD and COMPUTE ─────────────────
    // FIX: clamp fsm_ch_cnt to kernel row range [0:2]
    // fsm_ch_cnt goes 0,1,2,3 but kernel only has rows 0,1,2
    // ch_cnt=3 without clamping → kernel[3][x] → out of bounds → x
    always_comb begin
        foreach (w_in[i]) w_in[i] = '0;  // default zero
        if (fsm_state == W_LOAD || fsm_state == COMPUTE) begin
            foreach (w_in[i])
                w_in[i] = kernel[fsm_ch_cnt < 3 ? fsm_ch_cnt : 2]
                                 [i          < 3 ? i          : 2];
        end
    end

    // ── Drain cycle counter ───────────────────────────────────────
    always @(posedge clk) begin
        if (fsm_state == PSUM_SHIFT)
            drain_cycle <= drain_cycle + 1;
        else
            drain_cycle <= 0;
    end

    // ── Collect psum outputs during PSUM_SHIFT ────────────────────
    // Cycle 1-4: rows 1,3 drain (PE[1][0..3] and PE[3][0..3])
    // Cycle 5-8: rows 0,2 drain (PE[0][0..3] and PE[2][0..3])
    always @(posedge clk) begin
        if (fsm_state == PSUM_SHIFT) begin
            case (drain_cycle)
                1: begin
                    output_map[tile_row+1][tile_col+0] <= psum_out0;
                    output_map[tile_row+3][tile_col+0] <= psum_out1;
                    $display("  DRAIN cy%0d | PE[1][0]=%0d PE[3][0]=%0d",
                              drain_cycle, psum_out0, psum_out1);
                end
                2: begin
                    output_map[tile_row+1][tile_col+1] <= psum_out0;
                    output_map[tile_row+3][tile_col+1] <= psum_out1;
                    $display("  DRAIN cy%0d | PE[1][1]=%0d PE[3][1]=%0d",
                              drain_cycle, psum_out0, psum_out1);
                end
                3: begin
                    output_map[tile_row+1][tile_col+2] <= psum_out0;
                    output_map[tile_row+3][tile_col+2] <= psum_out1;
                    $display("  DRAIN cy%0d | PE[1][2]=%0d PE[3][2]=%0d",
                              drain_cycle, psum_out0, psum_out1);
                end
                4: begin
                    output_map[tile_row+1][tile_col+3] <= psum_out0;
                    output_map[tile_row+3][tile_col+3] <= psum_out1;
                    $display("  DRAIN cy%0d | PE[1][3]=%0d PE[3][3]=%0d",
                              drain_cycle, psum_out0, psum_out1);
                end
                5: begin
                    output_map[tile_row+0][tile_col+0] <= psum_out0;
                    output_map[tile_row+2][tile_col+0] <= psum_out1;
                    $display("  DRAIN cy%0d | PE[0][0]=%0d PE[2][0]=%0d",
                              drain_cycle, psum_out0, psum_out1);
                end
                6: begin
                    output_map[tile_row+0][tile_col+1] <= psum_out0;
                    output_map[tile_row+2][tile_col+1] <= psum_out1;
                    $display("  DRAIN cy%0d | PE[0][1]=%0d PE[2][1]=%0d",
                              drain_cycle, psum_out0, psum_out1);
                end
                7: begin
                    output_map[tile_row+0][tile_col+2] <= psum_out0;
                    output_map[tile_row+2][tile_col+2] <= psum_out1;
                    $display("  DRAIN cy%0d | PE[0][2]=%0d PE[2][2]=%0d",
                              drain_cycle, psum_out0, psum_out1);
                end
                8: begin
                    output_map[tile_row+0][tile_col+3] <= psum_out0;
                    output_map[tile_row+2][tile_col+3] <= psum_out1;
                    $display("  DRAIN cy%0d | PE[0][3]=%0d PE[2][3]=%0d",
                              drain_cycle, psum_out0, psum_out1);
                end
                default: ;
            endcase
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

    // ── Wait for done ─────────────────────────────────────────────
    task automatic wait_for_done();
        int timeout;
        timeout = 500;
        while (!done && timeout > 0) begin
            @(posedge clk);
            timeout--;
        end
        if (timeout == 0)
            $display("FAIL | TILE [%0d][%0d] timed out",
                      tile_row, tile_col);
        else
            $display("[TILE %0d,%0d] done asserted", tile_row, tile_col);
    endtask

    // ── Check output map ──────────────────────────────────────────
    // image=all 1s, kernel=all +1s
    // Each PE accumulates across 9 pixel positions × 4 channels
    // Each MAC = 1×1 = 1
    // But each PE only sees 1 activation per pixel position
    // So expected psum per PE = 9 × 1 = 9
    task automatic check_output_map();
        int pass_count, fail_count;
        pass_count = 0;
        fail_count = 0;
        $display("\n>> Checking output map (expected all = 9) <<");
        for (int r = 0; r < OUT_SIZE; r++) begin
            for (int c = 0; c < OUT_SIZE; c++) begin
                // Skip boundary tiles
                if ((r + 3 >= IMG_SIZE) || (c + 3 >= IMG_SIZE)) begin
                    $display("SKIP | boundary [%0d][%0d]", r, c);
                    continue;
                end
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
    // STIMULUS
    // ─────────────────────────────────────────────────────────────
    initial begin
        $dumpfile("top_tb_100x100.vcd");
        $dumpvars(0, top_tb_100x100);

        // ── Initialize ────────────────────────────────────────────
        drain_cycle = 0;
        tile_row    = 0;
        tile_col    = 0;

        // ── Image — all pixels = 1 ────────────────────────────────
        for (int r = 0; r < IMG_SIZE; r++)
            for (int c = 0; c < IMG_SIZE; c++)
                image[r][c] = 6'd1;

        // ── Kernel — all weights = +1 ─────────────────────────────
        for (int kr = 0; kr < 3; kr++)
            for (int kc = 0; kc < 3; kc++)
                kernel[kr][kc] = 2'b01;  // +1

        // ── Clear output map ──────────────────────────────────────
        for (int r = 0; r < OUT_SIZE+4; r++)
            for (int c = 0; c < OUT_SIZE+4; c++)
                output_map[r][c] = '0;

        // ── Tile loop ─────────────────────────────────────────────
        for (tile_row = 0; tile_row < OUT_SIZE; tile_row++) begin
            for (tile_col = 0; tile_col < OUT_SIZE; tile_col++) begin

                $display("\n════ TILE [%0d][%0d] ════",
                          tile_row, tile_col);

                // Start FSM — combinational assigns handle inputs
                start_tile();

                // Wait for FSM to complete
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