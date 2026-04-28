// ============================================================
//  tb_peg_1x.sv  —  Testbench for peg_1x (single 2×2 PEG)
//
//  Covers:
//    TC1  Weight loading chain (col0, col1, 2-cycle pipeline)
//    TC2  H-zigzag (2'b10): activation flow + psum computation
//    TC3  V-zigzag (2'b01): activation flow + psum computation
//    TC4  Circular shift (2'b11 / 2'b00): internal ring, boundary ignored
//    TC5  Negative weight MAC (w=-1)
//    TC6  psum_clr between back-to-back passes
//    TC7  psum_shift_en drain — checks psum_out0 value
//    TC8  direction must be h-zigzag when draining (psum_shift_en)
//
//  Golden values computed analytically — see verification script.
//
//  Naming matches peg_1x port list exactly.
//  pe_update.sv and peg_1x.sv must be on the include path.
// ============================================================

`timescale 1ns/1ps

module tb_peg_1x;

    // ── Parameters ───────────────────────────────────────────────
    localparam int DATA_W   = 6;
    localparam int WEIGHT_W = 2;
    localparam int ACC_W    = 13;
    localparam int COLS     = 2;

    localparam real CLK_HALF = 5.0; // 100 MHz

    // ── DUT ports ────────────────────────────────────────────────
    logic                    clk;
    logic                    rst_n;

    logic [DATA_W-1:0]       h_in0;
    logic [DATA_W-1:0]       v_in0;

    logic                    en;
    logic                    move_en;
    logic                    psum_shift_en;
    logic                    psum_clr;
    logic                    w_ld_en;

    logic [WEIGHT_W-1:0]     w_in [0:COLS-1];
    logic [1:0]              direction;

    logic [ACC_W-1:0]        psum_out0;

    // ── DUT instantiation ────────────────────────────────────────
    peg_1x #(
        .DATA_W   (DATA_W),
        .WEIGHT_W (WEIGHT_W),
        .ACC_W    (ACC_W),
        .ROWS     (2),
        .COLS     (COLS)
    ) dut (
        .clk           (clk),
        .rst_n         (rst_n),
        .h_in0         (h_in0),
        .v_in0         (v_in0),
        .en            (en),
        .move_en       (move_en),
        .psum_shift_en (psum_shift_en),
        .psum_clr      (psum_clr),
        .w_ld_en       (w_ld_en),
        .w_in          (w_in),
        .direction     (direction),
        .psum_out0     (psum_out0)
    );

    // ── Clock ────────────────────────────────────────────────────
    initial clk = 0;
    always #(CLK_HALF) clk = ~clk;

    // ── Test-result tracking ─────────────────────────────────────
    int pass_count = 0;
    int fail_count = 0;

    task automatic check(
        input string        tag,
        input logic [ACC_W-1:0] got,
        input logic [ACC_W-1:0] exp
    );
        if (got === exp) begin
            $display("  PASS  [%0t] %s  got=%0d (0x%04X)", $time, tag, signed'(got), got);
            pass_count++;
        end else begin
            $display("  FAIL  [%0t] %s  expected=%0d (0x%04X)  got=%0d (0x%04X)",
                     $time, tag, signed'(exp), exp, signed'(got), got);
            fail_count++;
        end
    endtask

    // ── Helpers ──────────────────────────────────────────────────
    task automatic cycle(int n = 1);
        repeat(n) @(posedge clk);
        #1; // tiny settle after posedge
    endtask

    // Drive everything idle between tests
    task automatic idle_all();
        h_in0         = '0;
        v_in0         = '0;
        en            = 0;
        move_en       = 0;
        psum_shift_en = 0;
        psum_clr      = 0;
        w_ld_en       = 0;
        w_in[0]       = '0;
        w_in[1]       = '0;
        direction     = 2'b10;  // h-zigzag default
    endtask

    // Full reset (2 cycles low)
    task automatic do_reset();
        rst_n = 0;
        idle_all();
        cycle(2);
        @(negedge clk); rst_n = 1;  // deassert between clocks to avoid race
        cycle(2);
    endtask

    // Load weights into both columns and wait for w_reg pipeline to settle.
    //   w_in[0] → col0 (feeds PE[0][0], PE[1][0])
    //   w_in[1] → col1 (feeds PE[0][1], PE[1][1])
    // w_buffer registered on posedge(clk) when w_ld_en=1 (1 cycle).
    // w_reg    = w_buffer delayed 1 more cycle.
    // Total: assert w_ld_en for 1 cycle, then wait 2 more for w_reg.
    task automatic load_weights(
        input logic [WEIGHT_W-1:0] w0,
        input logic [WEIGHT_W-1:0] w1
    );
        @(negedge clk);
        w_in[0] = w0;  w_in[1] = w1;
        w_ld_en = 1;
        cycle(1);
        @(negedge clk); w_ld_en = 0;
        cycle(2);   // wait for w_reg to be valid
    endtask

    // Stream activations through h_in0 for N cycles (h-zigzag).
    // en=1 enables the gated clock so psum accumulates.
    task automatic stream_h(
        input logic [DATA_W-1:0] acts [],
        input int                extra_drain = 4  // flush pipeline
    );
        @(negedge clk);
        en      = 1;
        move_en = 1;
        foreach (acts[i]) begin
            h_in0 = acts[i];
            cycle(1);
        end
        h_in0 = '0;
        cycle(extra_drain);  // let last activation propagate through all 4 hops
        @(negedge clk);
        en      = 0;
        move_en = 0;
    endtask

    // Stream activations through v_in0 for N cycles (v-zigzag).
    task automatic stream_v(
        input logic [DATA_W-1:0] acts [],
        input int                extra_drain = 4
    );
        @(negedge clk);
        en      = 1;
        move_en = 1;
        foreach (acts[i]) begin
            v_in0 = acts[i];
            cycle(1);
        end
        v_in0 = '0;
        cycle(extra_drain);
        @(negedge clk);
        en      = 0;
        move_en = 0;
    endtask

    // Assert psum_shift_en with direction=h-zigzag for one cycle
    // to latch psum_out0. Sample one cycle later (move_reg stage).
    //
    // On the rising edge of psum_shift_en:
    //   first_shift=1 → act_out_val = psum_out (accumulator)
    //   PE[1][0] drives act_to_left[1][0] = psum_out0 combinationally.
    //
    // We read psum_out0 AFTER the posedge (combinational, no extra cycle).
    task automatic drain_psum(output logic [ACC_W-1:0] val);
        @(negedge clk);
        direction     = 2'b10;  // h-zigzag required for grp2.dst=to_left
        psum_shift_en = 1;
        move_en       = 1;
        cycle(1);               // posedge: first_shift fires, psum_out0 driven
        val = psum_out0;        // sample after settle
        @(negedge clk);
        psum_shift_en = 0;
        move_en       = 0;
    endtask

    // Clear all accumulators
    task automatic clear_psums();
        @(negedge clk);
        psum_clr = 1;
        en       = 1;           // en_latched must be 1 for gated clk to fire
        cycle(1);
        @(negedge clk);
        psum_clr = 0;
        en       = 0;
        cycle(1);
    endtask

    // ── Main test sequence ───────────────────────────────────────
    initial begin
        $display("\n========================================================");
        $display(" tb_peg_1x  —  peg_1x Verification");
        $display("========================================================\n");

        do_reset();

        // ══════════════════════════════════════════════════════
        // TC1: Weight loading — check pipeline registers settle
        // ══════════════════════════════════════════════════════
        $display("── TC1: Weight loading chain ──────────────────────────");
        // Weights are internal — we verify indirectly via MAC output in TC2.
        // Here we just confirm no X-prop from weight chain after load.
        load_weights(2'b01, 2'b01);  // w=+1 both columns
        // psum should still be 0 (no activations)
        cycle(2);
        check("TC1: psum_out0=0 after weight load only",
              psum_out0, ACC_W'(0));


        // ══════════════════════════════════════════════════════
        // TC2: H-zigzag — activation flow + psum computation
        // ══════════════════════════════════════════════════════
        $display("\n── TC2: H-zigzag computation ──────────────────────────");
        // Analytical path (direction=2'b10):
        //   h_in0 → PE[1][1](col1) → PE[0][1](col1) → PE[0][0](col0) → PE[1][0](col0)
        // Each PE accumulates: psum += act × w
        // w_col0=1, w_col1=1, acts=[5,7]
        // Every PE sees [5,7] (shifted by 1 cycle per hop, same values)
        // Expected psum for PE[1][0] = 5×1 + 7×1 = 12
        do_reset();
        clear_psums();
        direction = 2'b10;
        load_weights(2'b01, 2'b01);  // +1, +1

        begin
            automatic logic [DATA_W-1:0] acts[] = '{6'd5, 6'd7};
            stream_h(acts, 6);
        end

        begin
            automatic logic [ACC_W-1:0] got;
            drain_psum(got);
            check("TC2: PE[1][0] psum (h-zigzag, w=+1, acts=[5,7])", got, ACC_W'(12));
        end


        // ══════════════════════════════════════════════════════
        // TC3: V-zigzag — activation flow + psum computation
        // ══════════════════════════════════════════════════════
        $display("\n── TC3: V-zigzag computation ──────────────────────────");
        // Analytical path (direction=2'b01):
        //   v_in0 → PE[1][0](col0) → PE[1][1](col1) → PE[0][1](col1) → PE[0][0](col0)
        // w_col0=1, w_col1=1, acts=[3,4]
        // PE[1][0] sees [3,4] first (delay 0) → psum = 3+4 = 7
        // psum_shift_en must be combined with direction=h-zigzag to drain
        do_reset();
        clear_psums();
        direction = 2'b01;
        load_weights(2'b01, 2'b01);  // +1, +1

        begin
            automatic logic [DATA_W-1:0] acts[] = '{6'd3, 6'd4};
            stream_v(acts, 6);
        end

        // Switch to h-zigzag for psum drain — same as original 4x4
        begin
            automatic logic [ACC_W-1:0] got;
            direction = 2'b10;  // required for drain
            drain_psum(got);
            check("TC3: PE[1][0] psum (v-zigzag, w=+1, acts=[3,4])", got, ACC_W'(7));
        end


        // ══════════════════════════════════════════════════════
        // TC4: Circular shift (2'b11) — internal ring, verify
        //      h_in0/v_in0 are NOT consumed (PE[1][1] reads from_left)
        // ══════════════════════════════════════════════════════
        $display("\n── TC4: Circular shift — boundary isolation ───────────");
        // direction=2'b11:
        //   PE[1][1] grp3: src=from_left = act_to_right[1][0] (internal)
        //   h_in0 enters act_from_right[1][1] but PE[1][1].src=from_left → IGNORED
        //   PE[1][0] grp2: src=from_up = act_to_down[0][0] (internal)
        //   v_in0 enters act_from_down[1][0] but PE[1][0].src=from_up  → IGNORED
        //
        // Drive h_in0 and v_in0 with non-zero values.
        // All internal wires start at 0 after reset.
        // PE psum should remain 0 after several cycles (no valid activation enters).
        do_reset();
        clear_psums();
        direction = 2'b11;
        load_weights(2'b01, 2'b01);

        @(negedge clk);
        en      = 1;
        move_en = 1;
        h_in0   = 6'd15;  // should be ignored by all PEs in circular mode
        v_in0   = 6'd15;
        cycle(8);         // run several cycles
        @(negedge clk);
        en = 0; move_en = 0;
        h_in0 = '0; v_in0 = '0;

        // Drain: must switch to h-zigzag for PE[1][0] to drive act_to_left
        begin
            automatic logic [ACC_W-1:0] got;
            direction = 2'b10;
            drain_psum(got);
            check("TC4: psum=0 in circular mode (h_in0/v_in0 ignored)", got, ACC_W'(0));
        end


        // ══════════════════════════════════════════════════════
        // TC5: Negative weight — h-zigzag, w=-1 (2'b11)
        // acts=[2,4] → psum = 2×(-1) + 4×(-1) = -6
        // In 13-bit 2's complement: -6 = 13'b1_1111_1111_1010 = 0x1FFA
        // ══════════════════════════════════════════════════════
        $display("\n── TC5: Negative weight MAC ────────────────────────────");
        do_reset();
        clear_psums();
        direction = 2'b10;
        load_weights(2'b11, 2'b11);  // -1, -1 in 2's complement

        begin
            automatic logic [DATA_W-1:0] acts[] = '{6'd2, 6'd4};
            stream_h(acts, 6);
        end

        begin
            automatic logic [ACC_W-1:0] got;
            drain_psum(got);
            // -6 as ACC_W-bit signed
            check("TC5: PE[1][0] psum (w=-1, acts=[2,4])", got,
                  ACC_W'($signed(-6)));
        end


        // ══════════════════════════════════════════════════════
        // TC6: psum_clr between back-to-back passes
        //      First pass: psum=12. Clear. Second pass: psum=12 again.
        // ══════════════════════════════════════════════════════
        $display("\n── TC6: psum_clr between passes ───────────────────────");
        do_reset();
        clear_psums();
        direction = 2'b10;
        load_weights(2'b01, 2'b01);

        // Pass 1
        begin
            automatic logic [DATA_W-1:0] acts[] = '{6'd5, 6'd7};
            stream_h(acts, 6);
        end

        begin
            automatic logic [ACC_W-1:0] got;
            drain_psum(got);
            check("TC6a: psum after pass1 = 12", got, ACC_W'(12));
        end

        // Clear and re-run same pass
        clear_psums();
        direction = 2'b10;

        begin
            automatic logic [DATA_W-1:0] acts[] = '{6'd5, 6'd7};
            stream_h(acts, 6);
        end

        begin
            automatic logic [ACC_W-1:0] got;
            drain_psum(got);
            check("TC6b: psum after clear+pass2 = 12 (not 24)", got, ACC_W'(12));
        end


        // ══════════════════════════════════════════════════════
        // TC7: psum_shift_en drain — verify psum_out0 appears
        //      in the same cycle psum_shift_en goes high (first_shift).
        //      Use $past or direct sample to confirm timing.
        // ══════════════════════════════════════════════════════
        $display("\n── TC7: psum_shift timing (single activation) ─────────");
        // Load w=1, stream single act=10 in h-zigzag.
        // After pipeline settles PE[1][0].psum=10.
        // On first_shift cycle, act_to_left[1][0] = psum_out = 10.
        do_reset();
        clear_psums();
        direction = 2'b10;
        load_weights(2'b01, 2'b01);

        begin
            automatic logic [DATA_W-1:0] acts[] = '{6'd10};
            stream_h(acts, 6);
        end

        begin
            automatic logic [ACC_W-1:0] got;
            // Sample immediately at first_shift (combinational output)
            @(negedge clk);
            direction     = 2'b10;
            psum_shift_en = 1;
            move_en       = 1;
            @(posedge clk);
            #1;  // post-posedge combinational settle
            got = psum_out0;
            @(negedge clk);
            psum_shift_en = 0;
            move_en       = 0;
            check("TC7: psum_out0 at first_shift (act=10, w=1)", got, ACC_W'(10));
        end


        // ══════════════════════════════════════════════════════
        // TC8: Confirm psum_out0 = 0 when draining with wrong
        //      direction (2'b11 circular → PE[1][0] dst=to_right,
        //      not to_left → act_to_left[1][0]=0)
        // ══════════════════════════════════════════════════════
        $display("\n── TC8: psum_out0=0 when direction≠h-zigzag on drain ──");
        do_reset();
        clear_psums();
        direction = 2'b10;
        load_weights(2'b01, 2'b01);

        begin
            automatic logic [DATA_W-1:0] acts[] = '{6'd5, 6'd7};
            stream_h(acts, 6);
        end

        // Drain with circular direction — PE[1][0] dst=to_right, not to_left
        begin
            automatic logic [ACC_W-1:0] got;
            @(negedge clk);
            direction     = 2'b11;  // circular — wrong direction for drain
            psum_shift_en = 1;
            move_en       = 1;
            cycle(1);
            got = psum_out0;
            @(negedge clk);
            psum_shift_en = 0;
            move_en       = 0;
            check("TC8: psum_out0=0 if direction≠h-zigzag during shift", got, ACC_W'(0));
        end


        // ══════════════════════════════════════════════════════
        // TC9: Accumulation across multiple activation vectors
        //      Two separate streams without psum_clr between them.
        //      psum = stream1 + stream2
        // ══════════════════════════════════════════════════════
        $display("\n── TC9: Accumulation across two streams ───────────────");
        // Stream1: acts=[3,3] → each PE contributes 6
        // Stream2: acts=[2,2] → each PE contributes 4
        // Total PE[1][0] psum = 10 (w=+1)
        do_reset();
        clear_psums();
        direction = 2'b10;
        load_weights(2'b01, 2'b01);

        begin
            automatic logic [DATA_W-1:0] acts1[] = '{6'd3, 6'd3};
            automatic logic [DATA_W-1:0] acts2[] = '{6'd2, 6'd2};
            stream_h(acts1, 6);
            direction = 2'b10;
            stream_h(acts2, 6);
        end

        begin
            automatic logic [ACC_W-1:0] got;
            drain_psum(got);
            check("TC9: accumulated psum over 2 streams (3+3+2+2=10)", got, ACC_W'(10));
        end


        // ══════════════════════════════════════════════════════
        // SUMMARY
        // ══════════════════════════════════════════════════════
        $display("\n========================================================");
        $display(" Results: %0d PASS  /  %0d FAIL  /  %0d TOTAL",
                 pass_count, fail_count, pass_count+fail_count);
        $display("========================================================\n");

        if (fail_count == 0)
            $display("  ALL CHECKS PASSED\n");
        else
            $display("  FAILURES DETECTED — check waveform for details\n");

        $finish;
    end

    // ── Waveform dump ────────────────────────────────────────────
    initial begin
        $dumpfile("tb_peg_1x.vcd");
        $dumpvars(0, tb_peg_1x);
    end

    // ── Timeout watchdog ─────────────────────────────────────────
    initial begin
        #50000;
        $display("TIMEOUT: simulation exceeded 50 us");
        $finish;
    end

endmodule
