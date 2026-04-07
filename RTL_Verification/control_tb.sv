`timescale 1ns/1ps

module control_tb();

    logic clk, rst_n, start;
    logic done;

    // ── Observe internal FSM signals via hierarchical reference ──
    logic       en, move_en, w_ld_en;
    logic       fifo_en, psum_shift_en, psum_clr;
    logic [1:0] direction;

    zigzag_fsm dut (
        .clk   (clk),
        .rst_n (rst_n),
        .start (start),
        .done  (done)
    );

    // ── Hierarchical signal probing ───────────────────────────────
    assign en            = dut.en;
    assign move_en       = dut.move_en;
    assign w_ld_en       = dut.w_ld_en;
    assign fifo_en       = dut.fifo_en;
    assign psum_shift_en = dut.psum_shift_en;
    assign psum_clr      = dut.psum_clr;
    assign direction     = dut.direction;

    // ── Clock ─────────────────────────────────────────────────────
    initial clk = 0;
    always #(5) clk = ~clk;

    // ── Tasks ─────────────────────────────────────────────────────
    task init_dut();
        rst_n = 0;
        start = 0;
        repeat(2) @(posedge clk);
        rst_n = 1;
        @(posedge clk);
    endtask

    // Pulse start for 1 cycle to kick off FSM
    task automatic trigger_start();
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
    endtask

    // Wait for FSM to reach a specific state
    task automatic wait_for_state(input logic [2:0] target_state, input string state_name);
        int timeout = 400;
        while (dut.state !== target_state && timeout > 0) begin
            @(posedge clk);
            timeout--;
        end
        if (timeout == 0)
            $display("TIMEOUT | waiting for state %s", state_name);
        else
            $display("REACHED | state = %s", state_name);
    endtask

    // Check a signal value and report pass/fail
    task check_signal(input logic actual, input logic expected, input string sig_name);
        if (actual === expected)
            $display("PASS | %-20s | value = %0b", sig_name, actual);
        else
            $display("FAIL | %-20s | Expected = %0b | Got = %0b", sig_name, expected, actual);
    endtask

    task check_direction(input logic [1:0] expected, input string test_name);
        if (direction === expected)
            $display("PASS | %-20s | direction = %0b", test_name, direction);
        else
            $display("FAIL | %-20s | Expected = %0b | Got = %0b", test_name, expected, direction);
    endtask

    // Wait N clock cycles
    task wait_cycles(input int n);
        repeat(n) @(posedge clk);
    endtask

    // ── Test 1: Reset behavior ────────────────────────────────────
    task test_reset();
        $display("\n── Test 1: Reset Behavior ──");
        init_dut();
        @(negedge clk);
        check_signal(dut.state == 3'd0, 1'b1, "IDLE after reset");
        check_signal(en,            1'b0, "en=0 in IDLE");
        check_signal(move_en,       1'b0, "move_en=0 in IDLE");
        check_signal(w_ld_en,       1'b0, "w_ld_en=0 in IDLE");
        check_signal(psum_shift_en, 1'b0, "psum_shift_en=0 in IDLE");
        check_signal(done,          1'b0, "done=0 in IDLE");
    endtask

    // ── Test 2: CLEAR state ───────────────────────────────────────
    task test_clear();
        $display("\n── Test 2: CLEAR State ──");
        init_dut();
        trigger_start();
        @(negedge clk);  // sample in CLEAR
        check_signal(en,       1'b1, "en=1 in CLEAR");
        check_signal(psum_clr, 1'b1, "psum_clr=1 in CLEAR");
        check_signal(move_en,  1'b0, "move_en=0 in CLEAR");
        // CLEAR lasts only 1 cycle — next cycle should be FILL
        @(posedge clk);
        @(negedge clk);
        check_signal(move_en,  1'b1, "move_en=1 in FILL");
        check_signal(en,       1'b0, "en=0 in FILL");
    endtask

    // ── Test 3: FILL state ────────────────────────────────────────
    task test_fill();
        $display("\n── Test 3: FILL State ──");
        init_dut();
        trigger_start();
        wait_for_state(3'd2, "FILL");
        @(negedge clk);
        check_signal(move_en,  1'b1, "move_en=1 in FILL");
        check_signal(en,       1'b0, "en=0 in FILL");
        check_direction(2'b10, "direction=H_ZigZag in FILL");
        // FILL runs 8 cycles — verify it stays in FILL
        wait_cycles(4);
        @(negedge clk);
        check_signal(move_en,  1'b1, "move_en=1 mid FILL");
        check_direction(2'b10, "direction stable in FILL");
    endtask

    // ── Test 4: W_LOAD state ──────────────────────────────────────
    task test_wload();
        $display("\n── Test 4: W_LOAD State ──");
        init_dut();
        trigger_start();
        wait_for_state(3'd3, "W_LOAD");
        @(negedge clk);
        check_signal(w_ld_en,  1'b1, "w_ld_en=1 in W_LOAD");
        check_signal(en,       1'b0, "en=0 in W_LOAD");
        check_signal(move_en,  1'b0, "move_en=0 in W_LOAD");
        check_direction(2'b11, "direction=Circular in W_LOAD");
    endtask

    // ── Test 5: COMPUTE state ─────────────────────────────────────
    task test_compute();
        $display("\n── Test 5: COMPUTE State ──");
        init_dut();
        trigger_start();
        wait_for_state(3'd4, "COMPUTE");
        @(negedge clk);
        check_signal(en,       1, "en=1 in COMPUTE");
        check_signal(move_en,  1, "move_en=1 in COMPUTE");
        check_signal(w_ld_en,  1, "w_ld_en=1 in COMPUTE");
        check_direction(2'b11, "direction=Circular in COMPUTE");
    endtask

    // ── Test 6: H_SHIFT state ─────────────────────────────────────
    task test_hshift();
        $display("\n── Test 6: H_SHIFT State ──");
        init_dut();
        trigger_start();
        wait_for_state(3'd5, "H_SHIFT");
        @(negedge clk);
        check_signal(move_en,  1'b1, "move_en=1 in H_SHIFT");
        check_signal(fifo_en,  1'b1, "fifo_en=1 in H_SHIFT");
        check_signal(en,       1'b0, "en=0 in H_SHIFT");
        check_direction(2'b10, "direction=H_ZigZag in H_SHIFT");
    endtask

    // ── Test 7: V_SHIFT state ─────────────────────────────────────
    task test_vshift();
        $display("\n── Test 7: V_SHIFT State ──");
        init_dut();
        trigger_start();
        wait_for_state(3'd6, "V_SHIFT");
        @(negedge clk);
        check_signal(move_en,  1'b1, "move_en=1 in V_SHIFT");
        check_signal(fifo_en,  1'b1, "fifo_en=1 in V_SHIFT");
        check_signal(en,       1'b0, "en=0 in V_SHIFT");
        check_direction(2'b01, "direction=V_ZigZag in V_SHIFT");
    endtask

    // ── Test 8: PSUM_SHIFT state and done pulse ───────────────────
    task test_psum_shift();
        $display("\n── Test 8: PSUM_SHIFT and done ──");
        init_dut();
        trigger_start();
        wait_for_state(3'd7, "PSUM_SHIFT");
        @(negedge clk);
        check_signal(move_en,       1'b1, "move_en=1 in PSUM_SHIFT");
        check_signal(psum_shift_en, 1'b1, "psum_shift_en=1 in PSUM_SHIFT");
        check_signal(en,            1'b0, "en=0 in PSUM_SHIFT");
        check_direction(2'b10,           "direction=H_ZigZag in PSUM_SHIFT");
        // Wait for done pulse on last cycle (cnt==7)
        wait_cycles(7);
        @(negedge clk);
        check_signal(done, 1'b1, "done pulses on last cycle");
        // After done FSM should return to IDLE
        @(posedge clk);
        @(negedge clk);
        check_signal(dut.state == 3'd0, 1'b1, "back to IDLE after done");
    endtask

    // ── Test 9: Full run — IDLE to IDLE ───────────────────────────
    task automatic test_full_run();
        int timeout;
        $display("\n── Test 9: Full FSM Run ──");
        init_dut();
        trigger_start();
        // Wait for done to pulse indicating full convolution complete 
        timeout = 500;
        while (!done && timeout > 0) begin
            @(posedge clk);
            timeout = timeout - 1;
        end
        if (timeout == 0)
            $display("FAIL | Full run timed out — done never asserted");
        else
            $display("PASS | Full run completed — done asserted at time %0t", $time);
        // Confirm return to IDLE
        @(posedge clk);
        @(negedge clk);
        check_signal(dut.state == 3'd0, 1'b1, "IDLE after full run");
    endtask

    // ── State name decoder ────────────────────────────────────────
    function automatic string state_name(input logic [2:0] s);
        case (s)
            3'd0: return "IDLE      ";
            3'd1: return "CLEAR     ";
            3'd2: return "FILL      ";
            3'd3: return "W_LOAD    ";
            3'd4: return "COMPUTE   ";
            3'd5: return "H_SHIFT   ";
            3'd6: return "V_SHIFT   ";
            3'd7: return "PSUM_SHIFT";
            default: return "UNKNOWN   ";
        endcase
    endfunction

    // ── Continuous state + signal logger ─────────────────────────
    // Runs every cycle in parallel — shows exactly what state
    // the FSM is in and for how long
    logic [2:0] prev_state;
    int         state_entry_cycle;
    int         log_cycle;

    initial begin
        prev_state        = 3'd0;
        state_entry_cycle = 0;
        log_cycle         = 0;
    end

    always @(posedge clk) begin
        log_cycle++;
        // Print every cycle with all control signals
        $display("CYC %3d | %-10s | en=%0b move_en=%0b w_ld_en=%0b fifo_en=%0b psum_shift_en=%0b psum_clr=%0b | dir=%0b | done=%0b",
            log_cycle,
            state_name(dut.state),
            en, move_en, w_ld_en, fifo_en, psum_shift_en, psum_clr,
            direction,
            done);

        // Print banner on every state transition
        if (dut.state !== prev_state) begin
            $display("--------------------------------------------------------------");
            $display(">>> STATE TRANSITION: %s → %s at cycle %0d (spent %0d cycles in %s)",
                state_name(prev_state),
                state_name(dut.state),
                log_cycle,
                log_cycle - state_entry_cycle,
                state_name(prev_state));
            $display("--------------------------------------------------------------");
            prev_state        = dut.state;
            state_entry_cycle = log_cycle;
        end
    end

    // ── Test 10: Uninterrupted full FSM run ───────────────────────
    task automatic test_uninterrupted_run();
        int timeout;
        $display("\n══════════════════════════════════════════");
        $display("   Test 10: Uninterrupted Full FSM Run    ");
        $display("══════════════════════════════════════════");
        init_dut();
        trigger_start();
        // Let FSM run completely without any intervention
        // Just watch the logger output
        timeout = 1000;
        while (!done && timeout > 0) begin
            @(posedge clk);
            timeout--;
        end
        if (timeout == 0)
            $display("FAIL | Uninterrupted run timed out — done never asserted");
        else begin
            $display("\n══════════════════════════════════════════");
            $display("PASS | FSM completed at cycle %0d", log_cycle);
            $display("══════════════════════════════════════════");
        end
        // Confirm back to IDLE
        @(posedge clk);
        @(negedge clk);
        check_signal(dut.state == 3'd0, 1'b1, "IDLE after uninterrupted run");
    endtask

    // ── Run all tests ─────────────────────────────────────────────
    initial begin
        $dumpfile("control_tb.vcd");
        $dumpvars(0, control_tb);

        // test_reset();
        // test_clear();
        // test_fill();
        // test_wload();
        // test_compute();
        // test_hshift();
        // test_vshift();
        // test_psum_shift();
        // test_full_run();
        test_uninterrupted_run();

        repeat(5) @(posedge clk);
        $display("\n── All Control FSM Tests Complete ──");
        $finish;
    end

endmodule