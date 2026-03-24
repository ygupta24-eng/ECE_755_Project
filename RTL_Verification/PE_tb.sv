`timescale 1ns/1ps

module pe_tb;

    // ── Parameters ────────────────────────────────────────────────
    parameter int DATA_W   = 6;
    parameter int WEIGHT_W = 2;
    parameter int ACC_W    = 13;
    parameter int CLK_PERIOD = 10;

    // ── DUT Signals ───────────────────────────────────────────────
    logic              clk, rst_n;
    logic              en, move_en, psum_shift_en, psum_clr;
    logic [1:0]        dst_sel, src_sel;

    logic [ACC_W-1:0]  act_from_left, act_from_right;
    logic [ACC_W-1:0]  act_from_up,   act_from_down;
    logic [ACC_W-1:0]  act_to_left,   act_to_right;
    logic [ACC_W-1:0]  act_to_up,     act_to_down;

    logic              w_ld_en;
    logic [WEIGHT_W-1:0] w_in, w_out;

    // ── DUT Instantiation ─────────────────────────────────────────
    pe #(
        .DATA_W   (DATA_W),
        .WEIGHT_W (WEIGHT_W),
        .ACC_W    (ACC_W)
    ) dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .en             (en),
        .move_en        (move_en),
        .psum_shift_en  (psum_shift_en),
        .dst_sel        (dst_sel),
        .src_sel        (src_sel),
        .act_from_left  (act_from_left),
        .act_from_right (act_from_right),
        .act_from_up    (act_from_up),
        .act_from_down  (act_from_down),
        .act_to_left    (act_to_left),
        .act_to_right   (act_to_right),
        .act_to_up      (act_to_up),
        .act_to_down    (act_to_down),
        .w_ld_en        (w_ld_en),
        .w_in           (w_in),
        .w_out          (w_out),
        .psum_clr       (psum_clr)
    );

    // ── Clock ─────────────────────────────────────────────────────
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // ── Tasks ─────────────────────────────────────────────────────
    task init_dut();
        rst_n         = 0;
        en            = 0;
        move_en       = 0;
        psum_shift_en = 0;
        psum_clr      = 0;
        w_ld_en       = 0;
        w_in          = '0;
        src_sel       = 2'b01;   // from_right
        dst_sel       = 2'b11;   // to_up
        act_from_left  = '0;
        act_from_right = '0;
        act_from_up    = '0;
        act_from_down  = '0;
        repeat(2) @(posedge clk);
        rst_n = 1;
        @(posedge clk);
    endtask

    task load_weight(input logic [WEIGHT_W-1:0] w);
        @(posedge clk);
        w_ld_en = 1;
        w_in    = w;
        @(posedge clk);
        w_ld_en = 0;
    endtask

    // Circulate activation for 8 cycles — one per PE in ZigZag chain
    task circulate(input logic [DATA_W-1:0] act_seq [0:7]);
        en      = 0;
        move_en = 1;
        for (int i = 0; i < 8; i++) begin
            act_from_right = ACC_W'(act_seq[i]);
            @(posedge clk);
        end
        move_en = 0;
    endtask

    // Assert en for 1 cycle to trigger MAC
    task compute();
        en      = 1;
        move_en = 1;
        @(posedge clk);
        en      = 0;
        move_en = 0;
    endtask

    task check_psum(input logic signed [ACC_W-1:0] expected, input string test_name);
        @(negedge clk);  // sample mid-cycle for stability
        if (dut.psum_out === expected)
            $display("PASS | %-20s | psum_out = %0d", test_name, dut.psum_out);
        else
            $display("FAIL | %-20s | Expected = %0d | Got = %0d",
                      test_name, expected, dut.psum_out);
    endtask

    // ── Stimulus ──────────────────────────────────────────────────
    // 8-element activation sequences (one per PE in ZigZag chain)
    // move_reg captures the 8th (last) value when compute() fires
    logic [DATA_W-1:0] act_seq1 [0:7] = '{10, 20, 30, 40, 10, 20, 30, 40};
    logic [DATA_W-1:0] act_seq2 [0:7] = '{5,  5,  5,  5,  5,  5,  5,  5};
    logic [DATA_W-1:0] act_zero [0:7] = '{0,  0,  0,  0,  0,  0,  0,  0};
    logic [DATA_W-1:0] act_max  [0:7] = '{63, 63, 63, 63, 63, 63, 63, 63};

    initial begin
        $dumpfile("tb_pe.vcd");
        $dumpvars(0, pe_tb);

        // ── Test 1: Basic MAC ─────────────────────────────────────
        // weight=1, move_reg holds last val = 40
        // psum = 40 * 1 = 40
        init_dut();
        load_weight(2'b01);
        circulate(act_seq1);
        compute();
        check_psum(13'sd40, "Basic MAC");

        // ── Test 2: Accumulation across compute cycles ────────────
        // weight=1, move_reg = 5 (all 5s sequence)
        // psum = 40 + 5 = 45
        circulate(act_seq2);
        compute();
        check_psum(13'sd45, "Accumulation");

        // ── Test 3: Negative weight ───────────────────────────────
        // weight=-1, move_reg = 40
        // psum = 40 * -1 = -40
        init_dut();
        load_weight(2'b11);
        circulate(act_seq1);
        compute();
        check_psum(-13'sd40, "Negative weight");

        // ── Test 4: Weight = -2 (min value, 2'b10) ───────────────
        // weight=-2, move_reg = 40
        // psum = 40 * -2 = -80
        init_dut();
        load_weight(2'b10);
        circulate(act_seq1);
        compute();
        check_psum(-13'sd80, "Min weight (-2)");

        // ── Test 5: Zero activation ───────────────────────────────
        // psum should remain 0
        init_dut();
        load_weight(2'b01);
        circulate(act_zero);
        compute();
        check_psum(13'sd0, "Zero activation");

        // ── Test 6: Max activation (63), weight=1 ────────────────
        // psum = 63 * 1 = 63
        init_dut();
        load_weight(2'b01);
        circulate(act_max);
        compute();
        check_psum(13'sd63, "Max activation");

        // ── Test 7: Max activation, weight=-2 ────────────────────
        // psum = 63 * -2 = -126
        init_dut();
        load_weight(2'b10);
        circulate(act_max);
        compute();
        check_psum(-13'sd126, "Max act, min weight");

        // ── Test 8: psum_clr mid-accumulation ────────────────────
        // Accumulate once (psum=40), clear, accumulate again (psum=5)
        init_dut();
        load_weight(2'b01);
        circulate(act_seq1);         // move_reg = 40
        compute();                   // psum = 40
        @(posedge clk);
        en       = 1;
        psum_clr = 1;                // clear while en=1
        @(posedge clk);
        psum_clr = 0;
        en       = 0;
        circulate(act_seq2);         // move_reg = 5
        compute();                   // psum = 0 + 5 = 5
        check_psum(13'sd5, "psum_clr mid-accum");

        // ── Test 9: psum_shift_en drain ──────────────────────────
        // Two consecutive computes: 20 + 25 = 45
        // Then drain and check act_to_up = 45
        init_dut();
        load_weight(2'b01);
        src_sel = 2'b01;             // from_right
        dst_sel = 2'b11;             // to_up
        circulate('{10, 20, 30, 40, 10, 20, 30, 20});  // last val=20
        compute();                   // psum = 20
        circulate('{10, 20, 30, 40, 10, 20, 30, 25});  // last val=25
        compute();                   // psum = 20+25 = 45
        // Now drain
        en = 1'b0;
        move_en       = 1;
        psum_shift_en = 1;
        act_from_right = ACC_W'(6'd10);
        @(posedge clk);
        @(negedge clk);
        if (act_to_up === 13'sd45)
            $display("PASS | %-20s | act_to_up = %0d (psum drained)", "psum_shift drain", act_to_up);
        else
            $display("FAIL | %-20s | Expected 45, Got %0d", "psum_shift drain", act_to_up);
        @(posedge clk);
        move_en       = 0;
        psum_shift_en = 0;

        // ── Test 10: dst_sel routing check ───────────────────────
        // dst_sel=00 → act_to_right should carry activation value
        init_dut();
        load_weight(2'b01);
        src_sel = 2'b01;             // from_right
        dst_sel = 2'b00;             // to_right
        act_from_right = ACC_W'(6'd15);
        move_en = 1;
        @(posedge clk);
        @(posedge clk);
        move_en = 0;
        @(negedge clk);
        if (act_to_right === ACC_W'(6'd15))
            $display("PASS | %-20s | act_to_right = %0d", "dst_sel to_right", act_to_right);
        else
            $display("FAIL | %-20s | Expected 15, Got %0d", "dst_sel to_right", act_to_right);

        repeat(5) @(posedge clk);

        $display("\n── All Tests Complete ──");
        $finish;
    end

endmodule