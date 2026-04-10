`timescale 1ns/1ps

module top_tb_100x100 #(
    parameter int DATA_W   = 6,
    parameter int WEIGHT_W = 2,
    parameter int ACC_W    = 13,
    parameter int ROWS     = 4,
    parameter int COLS     = 4,
    parameter int UNQ_DIR  = 4,
    parameter int IMG_SIZE = 100,
    parameter int OUT_SIZE = 98,
    parameter int IN_CHAN  = 4
)();

    // ── Signals ───────────────────────────────────────────────────
    logic clk, rst_n;
    logic start, done;

    logic [DATA_W-1:0]          h_in0, h_in1;
    logic [DATA_W-1:0]          v_in0, v_in1;
    logic [WEIGHT_W-1:0]        w_in [0:COLS-1];
    logic signed [ACC_W-1:0]    psum_out0;
    logic signed [ACC_W-1:0]    psum_out1;

    // ── Image, Kernel, Output storage ─────────────────────────────
    logic [DATA_W-1:0]          image      [0:IMG_SIZE-1]
                                            [0:IMG_SIZE-1]
                                            [0:IN_CHAN-1];
    logic signed [WEIGHT_W-1:0] kernel     [0:2][0:2][0:IN_CHAN-1];
    logic signed [ACC_W-1:0]    output_map [0:OUT_SIZE+3][0:OUT_SIZE+3];
    logic signed [ACC_W-1:0]    golden     [0:OUT_SIZE-1][0:OUT_SIZE-1];

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

    // ── Probe FSM signals directly ────────────────────────────────
    wire [2:0] fsm_state  = iDUT.u_fsm.state;
    wire [1:0] fsm_h_cnt  = iDUT.u_fsm.h_cnt;
    wire [2:0] fsm_v_cnt  = iDUT.u_fsm.v_cnt;
    wire [1:0] fsm_ch_cnt = iDUT.u_fsm.ch_cnt;
    wire [3:0] fsm_cnt    = iDUT.u_fsm.cnt;

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

    // ── h_in0 ─────────────────────────────────────────────────────
    // FILL:    feed col+0..col+3 in first 4 cycles only
    //          pipeline is full after 4 cycles — zeros stop shifting
    // H_SHIFT: feed column at fsm_h_cnt offset
    assign h_in0 =
        ((fsm_state == FILL) &&
         (fsm_cnt < 4) &&
         (tile_row+1 < IMG_SIZE) &&
         (tile_col + fsm_cnt < IMG_SIZE)) ?
          image[tile_row+1]
               [tile_col + fsm_cnt]
               [fsm_ch_cnt < IN_CHAN ? fsm_ch_cnt : IN_CHAN-1]
      :
        ((fsm_state == H_SHIFT) &&
         (tile_row+1 < IMG_SIZE) &&
         (tile_col + fsm_h_cnt < IMG_SIZE)) ?
          image[tile_row+1]
               [tile_col + fsm_h_cnt]
               [fsm_ch_cnt < IN_CHAN ? fsm_ch_cnt : IN_CHAN-1]
      : '0;

    // ── h_in1 ─────────────────────────────────────────────────────
    assign h_in1 =
        ((fsm_state == FILL) &&
         (fsm_cnt < 4) &&
         (tile_row+3 < IMG_SIZE) &&
         (tile_col + fsm_cnt < IMG_SIZE)) ?
          image[tile_row+3]
               [tile_col + fsm_cnt]
               [fsm_ch_cnt < IN_CHAN ? fsm_ch_cnt : IN_CHAN-1]
      :
        ((fsm_state == H_SHIFT) &&
         (tile_row+3 < IMG_SIZE) &&
         (tile_col + fsm_h_cnt < IMG_SIZE)) ?
          image[tile_row+3]
               [tile_col + fsm_h_cnt]
               [fsm_ch_cnt < IN_CHAN ? fsm_ch_cnt : IN_CHAN-1]
      : '0;

    // ── v_in0 ─────────────────────────────────────────────────────
    // V_SHIFT: feed correct image row based on v_cnt
    // v_cnt 0..5 maps to image rows tile_row+0 .. tile_row+5
    // only feed in first 4 cycles of each V_SHIFT
    assign v_in0 =
        ((fsm_state == V_SHIFT) &&
         (fsm_cnt < 4) &&
         (tile_row + fsm_v_cnt < IMG_SIZE) &&
         (tile_col < IMG_SIZE)) ?
          image[tile_row + fsm_v_cnt]
               [tile_col]
               [fsm_ch_cnt < IN_CHAN ? fsm_ch_cnt : IN_CHAN-1]
      : '0;

    // ── v_in1 ─────────────────────────────────────────────────────
    assign v_in1 =
        ((fsm_state == V_SHIFT) &&
         (fsm_cnt < 4) &&
         (tile_row + fsm_v_cnt < IMG_SIZE) &&
         (tile_col+2 < IMG_SIZE)) ?
          image[tile_row + fsm_v_cnt]
               [tile_col+2]
               [fsm_ch_cnt < IN_CHAN ? fsm_ch_cnt : IN_CHAN-1]
      : '0;

    // ── weights ───────────────────────────────────────────────────
    always_comb begin
        foreach (w_in[i]) w_in[i] = '0;
        if (fsm_state == W_LOAD || fsm_state == COMPUTE) begin
            foreach (w_in[i])
                w_in[i] = kernel
                    [fsm_ch_cnt < 3      ? fsm_ch_cnt : 2      ]
                    [i          < 3      ? i          : 2      ]
                    [fsm_ch_cnt < IN_CHAN ? fsm_ch_cnt : IN_CHAN-1];
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
    // ✅ KEY FIX: cases now start at 0 not 1
    // drain_cycle=0 fires on FIRST cycle of PSUM_SHIFT
    // cy0-3: rows 1,3 drain (PE[1][0..3] and PE[3][0..3])
    // cy4-7: rows 0,2 drain (PE[0][0..3] and PE[2][0..3])
    always @(posedge clk) begin
        if (fsm_state == PSUM_SHIFT) begin
            case (drain_cycle)
                0: begin
                    output_map[tile_row+1][tile_col+0] <= psum_out0;
                    output_map[tile_row+3][tile_col+0] <= psum_out1;
                    $display("  DRAIN cy%0d | PE[1][0]=%0d PE[3][0]=%0d",
                              drain_cycle, psum_out0, psum_out1);
                end
                1: begin
                    output_map[tile_row+1][tile_col+1] <= psum_out0;
                    output_map[tile_row+3][tile_col+1] <= psum_out1;
                    $display("  DRAIN cy%0d | PE[1][1]=%0d PE[3][1]=%0d",
                              drain_cycle, psum_out0, psum_out1);
                end
                2: begin
                    output_map[tile_row+1][tile_col+2] <= psum_out0;
                    output_map[tile_row+3][tile_col+2] <= psum_out1;
                    $display("  DRAIN cy%0d | PE[1][2]=%0d PE[3][2]=%0d",
                              drain_cycle, psum_out0, psum_out1);
                end
                3: begin
                    output_map[tile_row+1][tile_col+3] <= psum_out0;
                    output_map[tile_row+3][tile_col+3] <= psum_out1;
                    $display("  DRAIN cy%0d | PE[1][3]=%0d PE[3][3]=%0d",
                              drain_cycle, psum_out0, psum_out1);
                end
                4: begin
                    output_map[tile_row+0][tile_col+0] <= psum_out0;
                    output_map[tile_row+2][tile_col+0] <= psum_out1;
                    $display("  DRAIN cy%0d | PE[0][0]=%0d PE[2][0]=%0d",
                              drain_cycle, psum_out0, psum_out1);
                end
                5: begin
                    output_map[tile_row+0][tile_col+1] <= psum_out0;
                    output_map[tile_row+2][tile_col+1] <= psum_out1;
                    $display("  DRAIN cy%0d | PE[0][1]=%0d PE[2][1]=%0d",
                              drain_cycle, psum_out0, psum_out1);
                end
                6: begin
                    output_map[tile_row+0][tile_col+2] <= psum_out0;
                    output_map[tile_row+2][tile_col+2] <= psum_out1;
                    $display("  DRAIN cy%0d | PE[0][2]=%0d PE[2][2]=%0d",
                              drain_cycle, psum_out0, psum_out1);
                end
                7: begin
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

    // ── Load image from file ──────────────────────────────────────
    task automatic load_image(input string filename);
        int fd, val;
        fd = $fopen(filename, "r");
        if (fd == 0) begin
            $display("ERROR | Cannot open %s", filename);
            $finish;
        end
        for (int r = 0; r < IMG_SIZE; r++)
            for (int c = 0; c < IMG_SIZE; c++)
                for (int ch = 0; ch < IN_CHAN; ch++) begin
                    $fscanf(fd, "%d\n", val);
                    image[r][c][ch] = DATA_W'(val);
                end
        $fclose(fd);
        $display("Loaded image from %s", filename);
    endtask

    // ── Load kernel from file ─────────────────────────────────────
    task automatic load_kernel(input string filename);
        int fd, val;
        fd = $fopen(filename, "r");
        if (fd == 0) begin
            $display("ERROR | Cannot open %s", filename);
            $finish;
        end
        for (int kr = 0; kr < 3; kr++)
            for (int kc = 0; kc < 3; kc++)
                for (int ch = 0; ch < IN_CHAN; ch++) begin
                    $fscanf(fd, "%d\n", val);
                    kernel[kr][kc][ch] = WEIGHT_W'(signed'(val));
                end
        $fclose(fd);
        $display("Loaded kernel from %s", filename);
    endtask

    // ── Load golden output from file ──────────────────────────────
    task automatic load_golden(input string filename);
        int fd, val;
        fd = $fopen(filename, "r");
        if (fd == 0) begin
            $display("ERROR | Cannot open %s", filename);
            $finish;
        end
        for (int r = 0; r < OUT_SIZE; r++)
            for (int c = 0; c < OUT_SIZE; c++) begin
                $fscanf(fd, "%d\n", val);
                golden[r][c] = ACC_W'(signed'(val));
            end
        $fclose(fd);
        $display("Loaded golden from %s", filename);
    endtask

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
    // Extra cycles after done to ensure cy7 drain completes
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
        else begin
            $display("[TILE %0d,%0d] done asserted", tile_row, tile_col);
            repeat(2) @(posedge clk); // ✅ wait for final drain cycles
        end
    endtask

    // ── Compare output map against golden ─────────────────────────
    task automatic check_output_map();
        int pass_count, fail_count;
        pass_count = 0;
        fail_count = 0;
        $display("\n>> Comparing output_map against golden_output.txt <<");
        for (int r = 0; r < OUT_SIZE; r++) begin
            for (int c = 0; c < OUT_SIZE; c++) begin
                if ((r + 3 >= IMG_SIZE) || (c + 3 >= IMG_SIZE)) begin
                    $display("SKIP | boundary [%0d][%0d]", r, c);
                    continue;
                end
                if (output_map[r][c] === golden[r][c])
                    pass_count++;
                else begin
                    fail_count++;
                    $display("FAIL | [%0d][%0d] Got=%0d Expected=%0d",
                              r, c,
                              output_map[r][c],
                              golden[r][c]);
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

        // ── Load from files ───────────────────────────────────────
        load_image ("input_image.txt");
        load_kernel("input_kernel.txt");
        load_golden("golden_output.txt");

        // ── Clear output map ──────────────────────────────────────
        for (int r = 0; r < OUT_SIZE+4; r++)
            for (int c = 0; c < OUT_SIZE+4; c++)
                output_map[r][c] = '0;

        // ── Tile loop ─────────────────────────────────────────────
        for (tile_row = 0; tile_row < OUT_SIZE; tile_row++) begin
            for (tile_col = 0; tile_col < OUT_SIZE; tile_col++) begin

                $display("\n════ TILE [%0d][%0d] ════",
                          tile_row, tile_col);

                start_tile();
                wait_for_done();

            end
        end

        // ── Compare against golden ────────────────────────────────
        check_output_map();

        repeat(5) @(posedge clk);
        $display("\n── 100×100 Convolution Verification Complete ──");
        $stop();
    end

endmodule