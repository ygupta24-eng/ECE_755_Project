`timescale 1ns/1ps
// =============================================================================
// top_tb_v1.sv  —  RTL / Gate-level simulation testbench
// DNN MS2 Zigzag 4x4 Systolic PE Array
//
// CAPTURE STRATEGY:
// The synthesised netlist is fully flat (single module top).  Icarus cannot
// resolve escaped wire names such as \u_fsm.psum_shift_en through a dut.
// hierarchical prefix, so we do NOT probe any internal signal.
//
// Instead we use a shift-register pipeline on the public psum_out0/1 ports:
//   • done asserts at cnt == 7 of PSUM_SHIFT  (7 cycles after the valid window)
//   • valid data appears at cnt == 0           (first clock of PSUM_SHIFT)
//   • PIPE_DEPTH = 8  →  pipe[0] holds the sample from 7 cycles ago
//
// On the cycle where done is first seen high inside the while-loop, pipe[0]
// therefore holds exactly the first-shift window sample.
// =============================================================================

module top_tb_v1;

    localparam DATA_W         = 6;
    localparam WEIGHT_W       = 2;
    localparam ACC_W          = 13;
    localparam COLS           = 4;
    localparam CLK_PERIOD     = 16;
    localparam TIMEOUT_CYCLES = 3000;
    localparam PIPE_DEPTH     = 8;   // distance from valid window to done + 1

    // ── DUT signals ──────────────────────────────────────────────────
    reg                      clk;
    reg                      rst_n;
    reg                      start;
    wire                     done;
    reg  [DATA_W-1:0]        h_in0, h_in1;
    reg  [DATA_W-1:0]        v_in0, v_in1;
    reg  [WEIGHT_W-1:0]      w_in [0:COLS-1];
    wire [COLS*WEIGHT_W-1:0] w_in_flat;
    wire [ACC_W-1:0]         psum_out0;
    wire [ACC_W-1:0]         psum_out1;

    genvar gi;
    generate
        for (gi = 0; gi < COLS; gi = gi + 1) begin : g_pack
            assign w_in_flat[gi*WEIGHT_W +: WEIGHT_W] = w_in[gi];
        end
    endgenerate

    top dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (start),
        .done      (done),
        .h_in0     (h_in0),
        .h_in1     (h_in1),
        .v_in0     (v_in0),
        .v_in1     (v_in1),
        .w_in_flat (w_in_flat),
        .psum_out0 (psum_out0),
        .psum_out1 (psum_out1)
    );

    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // ── Bookkeeping ──────────────────────────────────────────────────
    integer pass_count = 0;
    integer fail_count = 0;

    // ── check ────────────────────────────────────────────────────────
    task automatic check;
        input [31:0]      test_num;
        input [ACC_W-1:0] got0, got1;
        input [ACC_W-1:0] exp0, exp1;
        input [127:0]     label;
        begin
            if (got0 === exp0 && got1 === exp1) begin
                $display("[PASS] TEST %0d (%s): psum_out0=%0d  psum_out1=%0d",
                         test_num, label, $signed(got0), $signed(got1));
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] TEST %0d (%s):", test_num, label);
                $display("       psum_out0 got=%0d (%0d signed)  expected=%0d (%0d signed)",
                         got0, $signed(got0), exp0, $signed(exp0));
                $display("       psum_out1 got=%0d (%0d signed)  expected=%0d (%0d signed)",
                         got1, $signed(got1), exp1, $signed(exp1));
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ── do_reset ─────────────────────────────────────────────────────
    task automatic do_reset;
        begin
            rst_n = 0; start = 0;
            h_in0 = 0; h_in1 = 0; v_in0 = 0; v_in1 = 0;
            w_in[0] = 0; w_in[1] = 0; w_in[2] = 0; w_in[3] = 0;
            repeat (4) @(posedge clk); #1;
            rst_n = 1;
            @(posedge clk); #1;
        end
    endtask

    // ── run_and_capture ──────────────────────────────────────────────
    // Feeds psum_out0/1 through a PIPE_DEPTH-entry shift register every
    // clock cycle while waiting for done.  When done fires (cnt==7 of
    // PSUM_SHIFT), pipe[0] holds the sample from PIPE_DEPTH-1 = 7 cycles
    // ago, which is cnt==0 — the first_shift / valid capture window.
    //
    // If results are wrong, uncomment the $display debug line and look for
    // the cycle with the correct value; count cycles back from done and
    // set PIPE_DEPTH = that_distance + 1.
    // ─────────────────────────────────────────────────────────────────
    task automatic run_and_capture;
        output [ACC_W-1:0] out0;
        output [ACC_W-1:0] out1;

        reg [ACC_W-1:0] pipe0 [0:PIPE_DEPTH-1];
        reg [ACC_W-1:0] pipe1 [0:PIPE_DEPTH-1];
        integer i, watchdog;
        begin
            out0 = {ACC_W{1'b0}};
            out1 = {ACC_W{1'b0}};

            for (i = 0; i < PIPE_DEPTH; i = i + 1) begin
                pipe0[i] = {ACC_W{1'b0}};
                pipe1[i] = {ACC_W{1'b0}};
            end

            // Assert start for one cycle
            @(posedge clk); #1;
            start = 1;
            @(posedge clk); #1;
            start = 0;

            watchdog = 0;
            while (!done) begin
                @(posedge clk); #1;
                watchdog = watchdog + 1;

                if (watchdog > TIMEOUT_CYCLES) begin
                    $display("[ERROR] Watchdog: done never asserted — check FSM");
                    $finish;
                end

                // Shift: drop oldest (index 0), push current sample at top
                for (i = 0; i < PIPE_DEPTH-1; i = i + 1) begin
                    pipe0[i] = pipe0[i+1];
                    pipe1[i] = pipe1[i+1];
                end
                pipe0[PIPE_DEPTH-1] = psum_out0;
                pipe1[PIPE_DEPTH-1] = psum_out1;

                // Uncomment to tune PIPE_DEPTH:
                // $display("  [DBG] cyc=%0d  p0=%0d  p1=%0d",
                //          watchdog, $signed(psum_out0), $signed(psum_out1));
            end

            // done just asserted.
            // pipe[0] = sample from (PIPE_DEPTH-1) = 7 cycles ago = valid window.
            out0 = pipe0[0];
            out1 = pipe1[0];

            // Let FSM complete PSUM_SHIFT → CLEAR → IDLE before next do_reset
            repeat(4) @(posedge clk); #1;
        end
    endtask

    // ── Stimulus ─────────────────────────────────────────────────────
    reg [ACC_W-1:0] result0, result1;

    initial begin
        $dumpfile("top_tb.vcd");
        $dumpvars(0, top_tb_v1);

        $display("============================================================");
        $display("  DNN Zigzag 4x4 Gate-Level Simulation — MS2 Testbench");
        $display("  CLK=%0dns  DATA_W=%0d  WEIGHT_W=%0d  ACC_W=%0d  PIPE=%0d",
                 CLK_PERIOD, DATA_W, WEIGHT_W, ACC_W, PIPE_DEPTH);
        $display("============================================================");

        // ── TEST 1: Reset / IDLE — outputs must be 0 ─────────────
        $display("\n--- TEST 1: Reset / IDLE output check ---");
        rst_n = 0; start = 0;
        h_in0 = 6'd7; h_in1 = 6'd7; v_in0 = 6'd7; v_in1 = 6'd7;
        w_in[0]=2'b01; w_in[1]=2'b01; w_in[2]=2'b01; w_in[3]=2'b01;
        repeat(4) @(posedge clk); #1;
        if (psum_out0 === {ACC_W{1'b0}} && psum_out1 === {ACC_W{1'b0}}) begin
            $display("[PASS] TEST 1: outputs are 0 during reset");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TEST 1: psum_out0=%0d psum_out1=%0d (expected 0,0)",
                     psum_out0, psum_out1);
            fail_count = fail_count + 1;
        end

        // ── TEST 2: w=+1, h_in0=5, h_in1=3 → 5, 3 ───────────────
        $display("\n--- TEST 2: weight=+1, h_in0=5, h_in1=3 ---");
        do_reset;
        h_in0=6'd5; h_in1=6'd3; v_in0=6'd0; v_in1=6'd0;
        w_in[0]=2'b01; w_in[1]=2'b01; w_in[2]=2'b01; w_in[3]=2'b01;
        run_and_capture(result0, result1);
        check(2, result0, result1, 13'd5, 13'd3, "w=+1,h0=5,h1=3");

        // ── TEST 3: w=−1 (2'b11), h_in0=5, h_in1=3 → −5, −3 ─────
        $display("\n--- TEST 3: weight=-1 (2'b11), h_in0=5, h_in1=3 ---");
        do_reset;
        h_in0=6'd5; h_in1=6'd3; v_in0=6'd0; v_in1=6'd0;
        w_in[0]=2'b11; w_in[1]=2'b11; w_in[2]=2'b11; w_in[3]=2'b11;
        run_and_capture(result0, result1);
        check(3, result0, result1, 13'h1FFB, 13'h1FFD, "w=-1,h0=5,h1=3");

        // ── TEST 4: w=0 → 0, 0 ───────────────────────────────────
        $display("\n--- TEST 4: weight=0 ---");
        do_reset;
        h_in0=6'd5; h_in1=6'd3; v_in0=6'd0; v_in1=6'd0;
        w_in[0]=2'b00; w_in[1]=2'b00; w_in[2]=2'b00; w_in[3]=2'b00;
        run_and_capture(result0, result1);
        check(4, result0, result1, 13'd0, 13'd0, "w=0");

        // ── TEST 5: w=−2 (2'b10), h_in0=4, h_in1=2 → −8, −4 ─────
        $display("\n--- TEST 5: weight=-2 (2'b10), h_in0=4, h_in1=2 ---");
        do_reset;
        h_in0=6'd4; h_in1=6'd2; v_in0=6'd0; v_in1=6'd0;
        w_in[0]=2'b10; w_in[1]=2'b10; w_in[2]=2'b10; w_in[3]=2'b10;
        run_and_capture(result0, result1);
        check(5, result0, result1, 13'h1FF8, 13'h1FFC, "w=-2,h0=4,h1=2");

        // ── TEST 6: max activation (63), weight=+1 → 63, 63 ──────
        $display("\n--- TEST 6: max activation (63), weight=+1 ---");
        do_reset;
        h_in0=6'd63; h_in1=6'd63; v_in0=6'd0; v_in1=6'd0;
        w_in[0]=2'b01; w_in[1]=2'b01; w_in[2]=2'b01; w_in[3]=2'b01;
        run_and_capture(result0, result1);
        check(6, result0, result1, 13'd63, 13'd63, "w=+1,max_act");

        // ── TEST 7: zero activations, weight=+1 → 0, 0 ───────────
        $display("\n--- TEST 7: zero activations, weight=+1 ---");
        do_reset;
        h_in0=6'd0; h_in1=6'd0; v_in0=6'd0; v_in1=6'd0;
        w_in[0]=2'b01; w_in[1]=2'b01; w_in[2]=2'b01; w_in[3]=2'b01;
        run_and_capture(result0, result1);
        check(7, result0, result1, 13'd0, 13'd0, "zero_act");

        // ── TEST 8: asymmetric h_in0=10, h_in1=20, w=+1 → 10, 20 ─
        $display("\n--- TEST 8: asymmetric h_in0=10, h_in1=20, weight=+1 ---");
        do_reset;
        h_in0=6'd10; h_in1=6'd20; v_in0=6'd0; v_in1=6'd0;
        w_in[0]=2'b01; w_in[1]=2'b01; w_in[2]=2'b01; w_in[3]=2'b01;
        run_and_capture(result0, result1);
        check(8, result0, result1, 13'd10, 13'd20, "asym_h");

        // ── Summary ───────────────────────────────────────────────
        $display("\n============================================================");
        $display("  Results: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("============================================================");
        if (fail_count == 0)
            $display("  *** ALL TESTS PASSED — gate-level functional verification OK ***");
        else begin
            $display("  *** FAILURES DETECTED — check waveform top_tb.vcd ***");
            $display("      If values look correct but offset, tune PIPE_DEPTH.");
            $display("      Uncomment [DBG] line in run_and_capture to diagnose.");
        end
        $display("============================================================\n");
        $finish;
    end

    // ── Global timeout ────────────────────────────────────────────────
    initial begin
        #(TIMEOUT_CYCLES * CLK_PERIOD * 10);
        $display("[ERROR] Global simulation timeout");
        $finish;
    end

endmodule