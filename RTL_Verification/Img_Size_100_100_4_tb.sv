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

    // ── Tile position trackers ─────────────────────────────────────
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

    // ── Derive kernel spatial row from v_cnt ──────────────────────
    // v_cnt=0        → kr=0  (row 0, served by FILL + H_SHIFTs)
    // v_cnt=1 or 2   → kr=1  (row 1, served by first V_SHIFTs)
    // v_cnt=3 or 4   → kr=2  (row 2, served by second V_SHIFTs)
    // v_cnt=5,6      → kr=2  (drain phase, no new activations needed)
    function automatic int get_kr(input logic [2:0] vc);
        if (vc == 0)            return 0;
        else if (vc <= 2)       return 1;
        else                    return 2;
    endfunction

    // ── Clock ─────────────────────────────────────────────────────
    initial clk = 0;
    always #10 clk = ~clk;

    // ─────────────────────────────────────────────────────────────
    // COMBINATIONAL INPUT DRIVING
    //
    // Activations are fed during FILL, H_SHIFT, V_SHIFT only.
    // Channel dimension uses fsm_ch_cnt so each W_LOAD/COMPUTE
    // pair sees the correct channel of the activation.
    // Kernel spatial row uses get_kr(fsm_v_cnt).
    // ─────────────────────────────────────────────────────────────

    // ── h_in0  (feeds PE[1][3] — row 1, right boundary) ──────────
    // During FILL:   row = tile_row+1, col steps with fsm_cnt
    // During H_SHIFT: row = tile_row+1, col steps with fsm_h_cnt
    assign h_in0 =
        ((fsm_state == FILL) &&
         (fsm_cnt < 8) &&
         (tile_row + get_kr(fsm_v_cnt) < IMG_SIZE) &&
         (tile_col + fsm_cnt           < IMG_SIZE)) ?
          image[tile_row + get_kr(fsm_v_cnt)]
               [tile_col + fsm_cnt]
               [fsm_ch_cnt]
      :
        ((fsm_state == H_SHIFT) &&
         (tile_row + get_kr(fsm_v_cnt) < IMG_SIZE) &&
         (tile_col + fsm_h_cnt         < IMG_SIZE)) ?
          image[tile_row + get_kr(fsm_v_cnt)]
               [tile_col + fsm_h_cnt]
               [fsm_ch_cnt]
      : '0;

    // ── h_in1  (feeds PE[3][3] — row 3, right boundary) ──────────
    assign h_in1 =
        ((fsm_state == FILL) &&
         (fsm_cnt < 8) &&
         (tile_row + get_kr(fsm_v_cnt) + 2 < IMG_SIZE) &&
         (tile_col + fsm_cnt                < IMG_SIZE)) ?
          image[tile_row + get_kr(fsm_v_cnt) + 2]
               [tile_col + fsm_cnt]
               [fsm_ch_cnt]
      :
        ((fsm_state == H_SHIFT) &&
         (tile_row + get_kr(fsm_v_cnt) + 2 < IMG_SIZE) &&
         (tile_col + fsm_h_cnt             < IMG_SIZE)) ?
          image[tile_row + get_kr(fsm_v_cnt) + 2]
               [tile_col + fsm_h_cnt]
               [fsm_ch_cnt]
      : '0;

    // ── v_in0  (feeds PE[3][0] — bottom boundary, col 0) ─────────
    assign v_in0 =
        ((fsm_state == V_SHIFT) &&
         (fsm_cnt < 4) &&
         (tile_row + get_kr(fsm_v_cnt) < IMG_SIZE) &&
         (tile_col                     < IMG_SIZE)) ?
          image[tile_row + get_kr(fsm_v_cnt)]
               [tile_col]
               [fsm_ch_cnt]
      : '0;

    // ── v_in1  (feeds PE[3][2] — bottom boundary, col 2) ─────────
    assign v_in1 =
        ((fsm_state == V_SHIFT) &&
         (fsm_cnt < 4) &&
         (tile_row + get_kr(fsm_v_cnt)  < IMG_SIZE) &&
         (tile_col + 2                  < IMG_SIZE)) ?
          image[tile_row + get_kr(fsm_v_cnt)]
               [tile_col + 2]
               [fsm_ch_cnt]
      : '0;

    // ── Weights ───────────────────────────────────────────────────
    // w_in[col] = kernel[kr][col][ch_cnt]
    // kr  is the kernel spatial row derived from v_cnt
    // ch_cnt is the channel counter — cycles 0..3 per shift phase
    always_comb begin
        foreach (w_in[i]) w_in[i] = '0;
        if (fsm_state == W_LOAD || fsm_state == COMPUTE) begin
            foreach (w_in[i])
                w_in[i] = kernel
                    [get_kr(fsm_v_cnt)]          // kernel spatial row
                    [i < 3 ? i : 2]              // kernel col (clamp to valid)
                    [fsm_ch_cnt];                // channel
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
    always @(posedge clk) begin
        if (fsm_state == PSUM_SHIFT) begin
            case (drain_cycle)
                0: begin
                    output_map[tile_row+1][tile_col+0] <= psum_out0;
                    output_map[tile_row+3][tile_col+0] <= psum_out1;
                end
                1: begin
                    output_map[tile_row+1][tile_col+1] <= psum_out0;
                    output_map[tile_row+3][tile_col+1] <= psum_out1;
                end
                2: begin
                    output_map[tile_row+1][tile_col+2] <= psum_out0;
                    output_map[tile_row+3][tile_col+2] <= psum_out1;
                end
                3: begin
                    output_map[tile_row+1][tile_col+3] <= psum_out0;
                    output_map[tile_row+3][tile_col+3] <= psum_out1;
                end
                4: begin
                    output_map[tile_row+0][tile_col+0] <= psum_out0;
                    output_map[tile_row+2][tile_col+0] <= psum_out1;
                end
                5: begin
                    output_map[tile_row+0][tile_col+1] <= psum_out0;
                    output_map[tile_row+2][tile_col+1] <= psum_out1;
                end
                6: begin
                    output_map[tile_row+0][tile_col+2] <= psum_out0;
                    output_map[tile_row+2][tile_col+2] <= psum_out1;
                end
                7: begin
                    output_map[tile_row+0][tile_col+3] <= psum_out0;
                    output_map[tile_row+2][tile_col+3] <= psum_out1;
                    $display("[TILE %0d,%0d] drain complete", tile_row, tile_col);
                end
                default: ;
            endcase
        end
    end

    // ─────────────────────────────────────────────────────────────
    // TASKS
    // ─────────────────────────────────────────────────────────────

    task automatic load_image(input string filename);
        int fd, val;
        fd = $fopen(filename, "r");
        if (fd == 0) begin $display("ERROR | Cannot open %s", filename); $finish; end
        for (int r = 0; r < IMG_SIZE; r++)
            for (int c = 0; c < IMG_SIZE; c++)
                for (int ch = 0; ch < IN_CHAN; ch++) begin
                    $fscanf(fd, "%d\n", val);
                    image[r][c][ch] = DATA_W'(val);
                end
        $fclose(fd);
        $display("Loaded image from %s", filename);
    endtask

    task automatic load_kernel(input string filename);
        int fd, val;
        fd = $fopen(filename, "r");
        if (fd == 0) begin $display("ERROR | Cannot open %s", filename); $finish; end
        for (int kr = 0; kr < 3; kr++)
            for (int kc = 0; kc < 3; kc++)
                for (int ch = 0; ch < IN_CHAN; ch++) begin
                    $fscanf(fd, "%d\n", val);
                    kernel[kr][kc][ch] = WEIGHT_W'(signed'(val));
                end
        $fclose(fd);
        $display("Loaded kernel from %s", filename);
    endtask

    task automatic load_golden(input string filename);
        int fd, val;
        fd = $fopen(filename, "r");
        if (fd == 0) begin $display("ERROR | Cannot open %s", filename); $finish; end
        for (int r = 0; r < OUT_SIZE; r++)
            for (int c = 0; c < OUT_SIZE; c++) begin
                $fscanf(fd, "%d\n", val);
                golden[r][c] = ACC_W'(signed'(val));
            end
        $fclose(fd);
        $display("Loaded golden from %s", filename);
    endtask

    task automatic start_tile();
        rst_n = 0; start = 0;
        repeat(2) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
    endtask

    task automatic wait_for_done();
        int timeout;
        timeout = 500;
        while (!done && timeout > 0) begin
            @(posedge clk); timeout--;
        end
        if (timeout == 0)
            $display("FAIL | TILE [%0d][%0d] timed out", tile_row, tile_col);
        else
            repeat(2) @(posedge clk);
    endtask

    task automatic check_output_map();
        int pass_count, fail_count;
        pass_count = 0; fail_count = 0;
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
                              r, c, output_map[r][c], golden[r][c]);
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

        drain_cycle = 0;
        tile_row    = 0;
        tile_col    = 0;

        load_image ("input_image.txt");
        load_kernel("input_kernel.txt");
        load_golden("golden_output.txt");

        for (int r = 0; r < OUT_SIZE+4; r++)
            for (int c = 0; c < OUT_SIZE+4; c++)
                output_map[r][c] = '0;

        for (tile_row = 0; tile_row < OUT_SIZE; tile_row++) begin
            for (tile_col = 0; tile_col < OUT_SIZE; tile_col++) begin
                start_tile();
                wait_for_done();
            end
        end

        check_output_map();

        repeat(5) @(posedge clk);
        $display("\n── 100x100 Convolution Verification Complete ──");
        $stop();
    end

endmodule