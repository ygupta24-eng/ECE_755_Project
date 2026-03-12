`timescale 1ns/1ps

// =============================================================
// ZigZag Testbench v2
// RTL change: sel_src -> src_sel + dst_sel (decoupled)
//
// Sequence:
//   Cycle 1-3 : src_sel=RIGHT, dst_sel=UP  → receive act, pass upward simultaneously
//   Cycle 4   : src_sel=RIGHT, dst_sel=UP  → last activation arrives + en=1 (1 cycle compute)
//   After     : en goes LOW, psum frozen
// =============================================================

module tb_pe_zigzag_v2;

    // -------------------------------------------------------
    // Parameters
    // -------------------------------------------------------
    parameter int DATA_W = 8;
    parameter int ACC_W  = 24;

    // -------------------------------------------------------
    // DUT Signals
    // -------------------------------------------------------
    logic              clk;
    logic              rst_n;
    logic              en;
    logic              move_en;
    logic [1:0]        src_sel;
    logic [1:0]        dst_sel;

    logic [DATA_W-1:0] act_from_left;
    logic [DATA_W-1:0] act_from_right;
    logic [DATA_W-1:0] act_from_up;
    logic [DATA_W-1:0] act_from_down;

    logic [DATA_W-1:0] act_to_left;
    logic [DATA_W-1:0] act_to_right;
    logic [DATA_W-1:0] act_to_up;
    logic [DATA_W-1:0] act_to_down;

    logic              w_ld_en;
    logic [DATA_W-1:0] w_in;
    logic [DATA_W-1:0] w_out;

    logic [ACC_W-1:0]  psum_out;
    logic              psum_clr;

    // -------------------------------------------------------
    // DUT Instantiation
    // -------------------------------------------------------
    pe #(
        .DATA_W(DATA_W),
        .ACC_W (ACC_W)
    ) dut (
        .clk           (clk),
        .rst_n         (rst_n),
        .en            (en),
        .move_en       (move_en),
        .src_sel       (src_sel),
        .dst_sel       (dst_sel),
        .act_from_left (act_from_left),
        .act_from_right(act_from_right),
        .act_from_up   (act_from_up),
        .act_from_down (act_from_down),
        .act_to_left   (act_to_left),
        .act_to_right  (act_to_right),
        .act_to_up     (act_to_up),
        .act_to_down   (act_to_down),
        .w_ld_en       (w_ld_en),
        .w_in          (w_in),
        .w_out         (w_out),
        .psum_out      (psum_out),
        .psum_clr      (psum_clr)
    );

    // -------------------------------------------------------
    // Clock : 10 ns period
    // -------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------------
    // tick task: wait n posedges, then tiny skew for input setup
    // -------------------------------------------------------
    task automatic tick(int n = 1);
        repeat(n) @(posedge clk);
        #1;
    endtask

    // -------------------------------------------------------
    // Golden state
    // -------------------------------------------------------
    logic [ACC_W-1:0]  golden_psum;
    logic [DATA_W-1:0] golden_w;
    logic [DATA_W-1:0] act_pipe [4];   // act_pipe[0..3] = activations fed cycle 1..4

    // -------------------------------------------------------
    // Checker
    // -------------------------------------------------------
    task automatic check_psum(input string tag);
        if (psum_out !== golden_psum)
            $error("[%s] MISMATCH  DUT=%0d  GOLDEN=%0d", tag, psum_out, golden_psum);
        else
            $display("[%s] OK  psum_out=%0d", tag, psum_out);
    endtask

    // =======================================================
    // MAIN TEST
    // =======================================================
    initial begin
        $display("========================================");
        $display("  ZigZag PE Testbench v2");
        $display("  src=RIGHT, dst=UP, compute on cycle 4");
        $display("========================================");

        // ---------------------------------------------------
        // 0. Initialise
        // ---------------------------------------------------
        rst_n          = 0;
        en             = 0;
        move_en        = 0;
        src_sel        = 2'b01;   // RIGHT
        dst_sel        = 2'b11;   // UP  (dst_sel=11 -> act_to_up <= move_reg)
        w_ld_en        = 0;
        w_in           = '0;
        psum_clr       = 0;
        act_from_left  = '0;
        act_from_right = '0;
        act_from_up    = '0;
        act_from_down  = '0;
        golden_psum    = '0;
        golden_w       = '0;

        // Four input activations (arrive one per cycle)
        act_pipe[0] = 8'd10;
        act_pipe[1] = 8'd20;
        act_pipe[2] = 8'd30;
        act_pipe[3] = 8'd40;   // <-- 4th cycle: compute fires on this

        // ---------------------------------------------------
        // 1. Reset
        // ---------------------------------------------------
        tick(3);
        rst_n = 1;
        tick(2);
        $display("[RESET] Done");

        // ---------------------------------------------------
        // 2. Load weight
        //    w_reg = 5 ; also passes down column via w_out
        // ---------------------------------------------------
        golden_w = 8'd5;
        w_in     = golden_w;
        w_ld_en  = 1;
        tick(1);
        w_ld_en  = 0;
        tick(1);
        $display("[WEIGHT] w_reg <= %0d", golden_w);

        // ---------------------------------------------------
        // 3. Cycles 1-3 : receive from RIGHT, pass to UP
        //
        //    src_sel = 01 (RIGHT) -> incoming = act_from_right
        //    dst_sel = 11 (UP)    -> act_to_up <= move_reg
        //
        //    Timeline (what the FF sees at each posedge):
        //      posedge 1: move_reg <= act_pipe[0]  |  act_to_up <= 0        (move_reg was 0)
        //      posedge 2: move_reg <= act_pipe[1]  |  act_to_up <= act_pipe[0]
        //      posedge 3: move_reg <= act_pipe[2]  |  act_to_up <= act_pipe[1]
        //
        //    en=0 so psum stays 0 throughout
        // ---------------------------------------------------
        $display("--- Cycles 1-3 : receive RIGHT + pass UP (en=0) ---");
        move_en = 1;
        en      = 0;

        for (int c = 0; c < 3; c++) begin
            act_from_right = act_pipe[c];
            tick(1);
            $display("  cycle %0d : act_from_right=%0d  act_to_up=%0d  psum_out=%0d",
                      c+1, act_pipe[c], act_to_up, psum_out);
        end

        // ---------------------------------------------------
        // 4. Cycle 4 : last activation + en=1 (single compute)
        //
        //    At this posedge:
        //      move_reg was act_pipe[2] (loaded last cycle)
        //      MAC fires:  psum += act_pipe[2] * w_reg
        //      move_reg <= act_pipe[3]
        //      act_to_up <= act_pipe[2]
        //
        //    Immediately after tick, en goes LOW.
        // ---------------------------------------------------
        $display("--- Cycle 4 : last activation + en=1 for exactly 1 cycle ---");
        act_from_right = act_pipe[3];
        en             = 1;           // RAISE en just before posedge

        // Golden: MAC uses move_reg which currently holds act_pipe[2]
        golden_psum += act_pipe[2] * golden_w;

        tick(1);                      // <-- single posedge fires the MAC
        en = 0;                       // LOWER en immediately after

        $display("  cycle 4 : act_from_right=%0d  act_to_up=%0d  psum_out=%0d  golden=%0d  [en now LOW]",
                  act_pipe[3], act_to_up, psum_out, golden_psum);

        // ---------------------------------------------------
        // 5. Verify psum is frozen for 3 more cycles
        //    move_en still active, en=0 -> MAC must NOT fire
        // ---------------------------------------------------
        $display("--- Post-compute : en=0, psum must stay frozen ---");
        for (int c = 0; c < 3; c++) begin
            act_from_right = act_pipe[c];   // keep feeding (shouldn't matter)
            tick(1);
            $display("  frozen cycle %0d : psum_out=%0d  golden=%0d",
                      c+1, psum_out, golden_psum);
        end

        move_en        = 0;
        act_from_right = '0;
        tick(2);

        // ---------------------------------------------------
        // 6. Final check
        // ---------------------------------------------------
        check_psum("FINAL");

        // ---------------------------------------------------
        // 7. Clear psum
        // ---------------------------------------------------
        psum_clr  = 1;
        en        = 1;        // en must be high for psum_clr to take effect
        tick(1);
        psum_clr    = 0;
        en          = 0;
        golden_psum = '0;
        tick(1);
        check_psum("AFTER_CLR");

        $display("========================================");
        $display("  Testbench DONE");
        $display("========================================");
        $finish;
    end

    // -------------------------------------------------------
    // Waveform dump
    // -------------------------------------------------------
    initial begin
        $dumpfile("tb_pe_zigzag_v2.vcd");
        $dumpvars(0, tb_pe_zigzag_v2);
    end

endmodule