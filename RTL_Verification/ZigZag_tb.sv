`timescale 1ns/1ps

module zigzag_tb();

    // ── Parameters ────────────────────────────────────────────────
    parameter int DATA_W   = 6;
    parameter int WEIGHT_W = 2;
    parameter int ACC_W    = 13;

    // ── FSM control signals ───────────────────────────────────────
    logic clk, rst_n, start, done;
    logic       en, move_en, w_ld_en;
    logic       fifo_en, psum_shift_en, psum_clr;
    logic [1:0] direction;

    // ── ZigZag array I/O ──────────────────────────────────────────
    logic [DATA_W-1:0] h_in0, h_in1;
    logic [DATA_W-1:0] v_in0, v_in1;
    logic [WEIGHT_W-1:0] w_in [0:3];
    logic [ACC_W-1:0]  psum_out0, psum_out1;

    // ── FSM Instantiation ─────────────────────────────────────────
    zigzag_fsm u_fsm (
        .clk   (clk),
        .rst_n (rst_n),
        .start (start),
        .done  (done)
    );

    // ── Probe FSM internal signals ────────────────────────────────
    assign en            = u_fsm.en;
    assign move_en       = u_fsm.move_en;
    assign w_ld_en       = u_fsm.w_ld_en;
    assign fifo_en       = u_fsm.fifo_en;
    assign psum_shift_en = u_fsm.psum_shift_en;
    assign psum_clr      = u_fsm.psum_clr;
    assign direction     = u_fsm.direction;

    // ── ZigZag Array Instantiation ────────────────────────────────
    zig_zag_4x4 #(
        .DATA_W  (DATA_W),
        .WEIGHT_W(WEIGHT_W),
        .ACC_W   (ACC_W)
    ) dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .h_in0        (h_in0),
        .h_in1        (h_in1),
        .v_in0        (v_in0),
        .v_in1        (v_in1),
        .en           (en),
        .move_en      (move_en),
        .psum_shift_en(psum_shift_en),
        .psum_clr     (psum_clr),
        .w_ld_en      (w_ld_en),
        .fifo_en      (fifo_en),
        .w_in         (w_in),
        .direction    (direction),
        .psum_out0    (psum_out0),
        .psum_out1    (psum_out1)
    );

    // ── Clock ─────────────────────────────────────────────────────
    initial clk = 0;
    always #(5) clk = ~clk;

    // ── Cycle logger ──────────────────────────────────────────────
    int cycle_count;
    initial cycle_count = 0;
    always @(posedge clk) begin
        cycle_count++;
        $display("CYC %0d | state=%0d dir=%0b en=%0b move_en=%0b w_ld_en=%0b fifo_en=%0b psum_shift_en=%0b | h_in0=%0d h_in1=%0d | psum0=%0d psum1=%0d",
            cycle_count,
            u_fsm.state,
            direction,
            en, move_en, w_ld_en, fifo_en, psum_shift_en,
            h_in0, h_in1,
            psum_out0, psum_out1);
    end

    // ── PE move_reg logger ────────────────────────────────────────
    task automatic log_pe_move_regs(input string label);
        $display("── %s ──", label);
        $display("  Row0 | PE[0][0].move_reg=%0d | PE[0][1].move_reg=%0d | PE[0][2].move_reg=%0d | PE[0][3].move_reg=%0d",
            dut.g_pe_row[0].g_pe_col[0].u_pe.move_reg,
            dut.g_pe_row[0].g_pe_col[1].u_pe.move_reg,
            dut.g_pe_row[0].g_pe_col[2].u_pe.move_reg,
            dut.g_pe_row[0].g_pe_col[3].u_pe.move_reg);
        $display("  Row1 | PE[1][0].move_reg=%0d | PE[1][1].move_reg=%0d | PE[1][2].move_reg=%0d | PE[1][3].move_reg=%0d",
            dut.g_pe_row[1].g_pe_col[0].u_pe.move_reg,
            dut.g_pe_row[1].g_pe_col[1].u_pe.move_reg,
            dut.g_pe_row[1].g_pe_col[2].u_pe.move_reg,
            dut.g_pe_row[1].g_pe_col[3].u_pe.move_reg);
        $display("  Row2 | PE[2][0].move_reg=%0d | PE[2][1].move_reg=%0d | PE[2][2].move_reg=%0d | PE[2][3].move_reg=%0d",
            dut.g_pe_row[2].g_pe_col[0].u_pe.move_reg,
            dut.g_pe_row[2].g_pe_col[1].u_pe.move_reg,
            dut.g_pe_row[2].g_pe_col[2].u_pe.move_reg,
            dut.g_pe_row[2].g_pe_col[3].u_pe.move_reg);
        $display("  Row3 | PE[3][0].move_reg=%0d | PE[3][1].move_reg=%0d | PE[3][2].move_reg=%0d | PE[3][3].move_reg=%0d",
            dut.g_pe_row[3].g_pe_col[0].u_pe.move_reg,
            dut.g_pe_row[3].g_pe_col[1].u_pe.move_reg,
            dut.g_pe_row[3].g_pe_col[2].u_pe.move_reg,
            dut.g_pe_row[3].g_pe_col[3].u_pe.move_reg);
    endtask

    // ── psum logger ───────────────────────────────────────────────
    task automatic log_pe_psums(input string label);
        $display("── %s ──", label);
        $display("  Row0 | PE[0][0].psum=%0d | PE[0][1].psum=%0d | PE[0][2].psum=%0d | PE[0][3].psum=%0d",
            dut.g_pe_row[0].g_pe_col[0].u_pe.psum_out,
            dut.g_pe_row[0].g_pe_col[1].u_pe.psum_out,
            dut.g_pe_row[0].g_pe_col[2].u_pe.psum_out,
            dut.g_pe_row[0].g_pe_col[3].u_pe.psum_out);
        $display("  Row1 | PE[1][0].psum=%0d | PE[1][1].psum=%0d | PE[1][2].psum=%0d | PE[1][3].psum=%0d",
            dut.g_pe_row[1].g_pe_col[0].u_pe.psum_out,
            dut.g_pe_row[1].g_pe_col[1].u_pe.psum_out,
            dut.g_pe_row[1].g_pe_col[2].u_pe.psum_out,
            dut.g_pe_row[1].g_pe_col[3].u_pe.psum_out);
        $display("  Row2 | PE[2][0].psum=%0d | PE[2][1].psum=%0d | PE[2][2].psum=%0d | PE[2][3].psum=%0d",
            dut.g_pe_row[2].g_pe_col[0].u_pe.psum_out,
            dut.g_pe_row[2].g_pe_col[1].u_pe.psum_out,
            dut.g_pe_row[2].g_pe_col[2].u_pe.psum_out,
            dut.g_pe_row[2].g_pe_col[3].u_pe.psum_out);
        $display("  Row3 | PE[3][0].psum=%0d | PE[3][1].psum=%0d | PE[3][2].psum=%0d | PE[3][3].psum=%0d",
            dut.g_pe_row[3].g_pe_col[0].u_pe.psum_out,
            dut.g_pe_row[3].g_pe_col[1].u_pe.psum_out,
            dut.g_pe_row[3].g_pe_col[2].u_pe.psum_out,
            dut.g_pe_row[3].g_pe_col[3].u_pe.psum_out);
    endtask

    // ── weight logger ─────────────────────────────────────────────
    task automatic log_pe_weights(input string label);
        $display("── %s ──", label);
        $display("  Row0 | PE[0][0].w=%0d | PE[0][1].w=%0d | PE[0][2].w=%0d | PE[0][3].w=%0d",
            dut.g_pe_row[0].g_pe_col[0].u_pe.w_reg,
            dut.g_pe_row[0].g_pe_col[1].u_pe.w_reg,
            dut.g_pe_row[0].g_pe_col[2].u_pe.w_reg,
            dut.g_pe_row[0].g_pe_col[3].u_pe.w_reg);
        $display("  Row1 | PE[1][0].w=%0d | PE[1][1].w=%0d | PE[1][2].w=%0d | PE[1][3].w=%0d",
            dut.g_pe_row[1].g_pe_col[0].u_pe.w_reg,
            dut.g_pe_row[1].g_pe_col[1].u_pe.w_reg,
            dut.g_pe_row[1].g_pe_col[2].u_pe.w_reg,
            dut.g_pe_row[1].g_pe_col[3].u_pe.w_reg);
        $display("  Row2 | PE[2][0].w=%0d | PE[2][1].w=%0d | PE[2][2].w=%0d | PE[2][3].w=%0d",
            dut.g_pe_row[2].g_pe_col[0].u_pe.w_reg,
            dut.g_pe_row[2].g_pe_col[1].u_pe.w_reg,
            dut.g_pe_row[2].g_pe_col[2].u_pe.w_reg,
            dut.g_pe_row[2].g_pe_col[3].u_pe.w_reg);
        $display("  Row3 | PE[3][0].w=%0d | PE[3][1].w=%0d | PE[3][2].w=%0d | PE[3][3].w=%0d",
            dut.g_pe_row[3].g_pe_col[0].u_pe.w_reg,
            dut.g_pe_row[3].g_pe_col[1].u_pe.w_reg,
            dut.g_pe_row[3].g_pe_col[2].u_pe.w_reg,
            dut.g_pe_row[3].g_pe_col[3].u_pe.w_reg);
    endtask

    // ── check psum of a specific PE ───────────────────────────────
    // Cannot use variable index — use a case statement instead
    task automatic check_pe_psum(
        input int r, input int c,
        input logic signed [ACC_W-1:0] expected,
        input string test_name
    );
        logic signed [ACC_W-1:0] actual;
        case ({r, c})
            {0,0}: actual = dut.g_pe_row[0].g_pe_col[0].u_pe.psum_out;
            {0,1}: actual = dut.g_pe_row[0].g_pe_col[1].u_pe.psum_out;
            {0,2}: actual = dut.g_pe_row[0].g_pe_col[2].u_pe.psum_out;
            {0,3}: actual = dut.g_pe_row[0].g_pe_col[3].u_pe.psum_out;
            {1,0}: actual = dut.g_pe_row[1].g_pe_col[0].u_pe.psum_out;
            {1,1}: actual = dut.g_pe_row[1].g_pe_col[1].u_pe.psum_out;
            {1,2}: actual = dut.g_pe_row[1].g_pe_col[2].u_pe.psum_out;
            {1,3}: actual = dut.g_pe_row[1].g_pe_col[3].u_pe.psum_out;
            {2,0}: actual = dut.g_pe_row[2].g_pe_col[0].u_pe.psum_out;
            {2,1}: actual = dut.g_pe_row[2].g_pe_col[1].u_pe.psum_out;
            {2,2}: actual = dut.g_pe_row[2].g_pe_col[2].u_pe.psum_out;
            {2,3}: actual = dut.g_pe_row[2].g_pe_col[3].u_pe.psum_out;
            {3,0}: actual = dut.g_pe_row[3].g_pe_col[0].u_pe.psum_out;
            {3,1}: actual = dut.g_pe_row[3].g_pe_col[1].u_pe.psum_out;
            {3,2}: actual = dut.g_pe_row[3].g_pe_col[2].u_pe.psum_out;
            {3,3}: actual = dut.g_pe_row[3].g_pe_col[3].u_pe.psum_out;
            default: actual = '0;
        endcase
        if (actual === expected)
            $display("PASS | %-30s | PE[%0d][%0d].psum = %0d", test_name, r, c, actual);
        else
            $display("FAIL | %-30s | PE[%0d][%0d] Expected=%0d Got=%0d",
                      test_name, r, c, expected, actual);
    endtask

   // ── check move_reg of a specific PE ───────────────────────────
    task automatic check_pe_move_reg(
        input int r, input int c,
        input logic [ACC_W-1:0] expected,
        input string test_name
    );
        logic [ACC_W-1:0] actual;
        case ({r, c})
            {0,0}: actual = dut.g_pe_row[0].g_pe_col[0].u_pe.move_reg;
            {0,1}: actual = dut.g_pe_row[0].g_pe_col[1].u_pe.move_reg;
            {0,2}: actual = dut.g_pe_row[0].g_pe_col[2].u_pe.move_reg;
            {0,3}: actual = dut.g_pe_row[0].g_pe_col[3].u_pe.move_reg;
            {1,0}: actual = dut.g_pe_row[1].g_pe_col[0].u_pe.move_reg;
            {1,1}: actual = dut.g_pe_row[1].g_pe_col[1].u_pe.move_reg;
            {1,2}: actual = dut.g_pe_row[1].g_pe_col[2].u_pe.move_reg;
            {1,3}: actual = dut.g_pe_row[1].g_pe_col[3].u_pe.move_reg;
            {2,0}: actual = dut.g_pe_row[2].g_pe_col[0].u_pe.move_reg;
            {2,1}: actual = dut.g_pe_row[2].g_pe_col[1].u_pe.move_reg;
            {2,2}: actual = dut.g_pe_row[2].g_pe_col[2].u_pe.move_reg;
            {2,3}: actual = dut.g_pe_row[2].g_pe_col[3].u_pe.move_reg;
            {3,0}: actual = dut.g_pe_row[3].g_pe_col[0].u_pe.move_reg;
            {3,1}: actual = dut.g_pe_row[3].g_pe_col[1].u_pe.move_reg;
            {3,2}: actual = dut.g_pe_row[3].g_pe_col[2].u_pe.move_reg;
            {3,3}: actual = dut.g_pe_row[3].g_pe_col[3].u_pe.move_reg;
            default: actual = '0;
        endcase
        if (actual === expected)
            $display("PASS | %-30s | PE[%0d][%0d].move_reg = %0d", test_name, r, c, actual);
        else
            $display("FAIL | %-30s | PE[%0d][%0d] Expected=%0d Got=%0d",
                      test_name, r, c, expected, actual);
    endtask

    // ── check signal ──────────────────────────────────────────────
    task automatic check_signal(
        input logic actual,
        input logic expected,
        input string sig_name
    );
        if (actual === expected)
            $display("PASS | %-30s | value = %0b", sig_name, actual);
        else
            $display("FAIL | %-30s | Expected=%0b Got=%0b", sig_name, expected, actual);
    endtask

    // ── init ──────────────────────────────────────────────────────
    task automatic init_dut();
        rst_n = 0;
        start = 0;
        h_in0 = '0;
        h_in1 = '0;
        v_in0 = '0;
        v_in1 = '0;
        w_in  = '{default: '0};
        repeat(2) @(posedge clk);
        rst_n = 1;
        @(posedge clk);
    endtask

    // ── wait for state ────────────────────────────────────────────
    task automatic wait_for_state(input logic [2:0] target, input string name);
        int timeout;
        timeout = 300;
        while (u_fsm.state !== target && timeout > 0) begin
            @(posedge clk);
            timeout--;
        end
        if (timeout == 0)
            $display("TIMEOUT | %s never reached", name);
        else
            $display("\n>>>>>> ENTERED STATE: %s <<<<<<", name);
    endtask

    // ── wait for H_SHIFT completion ───────────────────────────────
    // Detects H_SHIFT (3'd5) → W_LOAD (3'd3) transition
    // This is the correct signal that one H_SHIFT pass is done
    task automatic wait_for_hshift_done();
        int timeout;
        timeout = 100;
        // First make sure we are IN H_SHIFT
        while (u_fsm.state !== 3'd5 && timeout > 0) begin
            @(posedge clk);
            timeout--;
        end
        // Now wait for it to LEAVE H_SHIFT
        while (u_fsm.state === 3'd5 && timeout > 0) begin
            @(posedge clk);
            timeout--;
        end
        if (timeout == 0)
            $display("TIMEOUT | H_SHIFT never completed");
        else
            $display("\n>>>>>> H_SHIFT COMPLETED — transitioned to state %0d <<<<<<",
                      u_fsm.state);
    endtask

    // ── Activation streams (8 values, one per ZigZag chain PE) ───
    logic [DATA_W-1:0] h0_stream [0:7] = '{10, 20, 30, 40, 50, 60, 5,  15};
    logic [DATA_W-1:0] h1_stream [0:7] = '{11, 21, 31, 41, 51, 61, 6,  16};

    // ── Feed horizontal inputs during FILL ────────────────────────
    task automatic feed_h_inputs();
        for (int i = 0; i < 8; i++) begin
            @(posedge clk);
            h_in0 = h0_stream[i];
            h_in1 = h1_stream[i];
            $display("  FEED cycle%0d | h_in0=%0d h_in1=%0d", i, h_in0, h_in1);
        end
        h_in0 = '0;
        h_in1 = '0;
    endtask

    // ─────────────────────────────────────────────────────────────
    initial begin
        $dumpfile("zigzag_tb.vcd");
        $dumpvars(0, zigzag_tb);

        // ── Initialize ────────────────────────────────────────────
        init_dut();

        // Pre-set weights — FSM picks them up when w_ld_en fires
        w_in[0] = 2'b01;  // +1
        w_in[1] = 2'b01;  // +1
        w_in[2] = 2'b01;  // +1
        w_in[3] = 2'b01;  // +1

        // ── Trigger FSM ───────────────────────────────────────────
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        // ── CLEAR: 1 cycle ────────────────────────────────────────
        wait_for_state(3'd1, "CLEAR");
        @(negedge clk);
        log_pe_psums("After CLEAR — all psums should be 0");

        // ── FILL: 8 cycles ────────────────────────────────────────
        wait_for_state(3'd2, "FILL");
        $display("\n>> Feeding horizontal activations during FILL <<");
        fork
            feed_h_inputs();
            begin
                repeat(8) begin
                    @(negedge clk);
                    log_pe_move_regs("FILL cycle move_regs");
                end
            end
        join

        // After FILL — check each PE got the right activation
        // Row 1 (right to left): PE[1][3] gets last value fed = h0_stream[7]=15
        //                        PE[1][2] gets h0_stream[6]=5
        //                        PE[1][1] gets h0_stream[5]=60
        //                        PE[1][0] gets h0_stream[4]=50
        @(negedge clk);
        $display("\n>> Checking move_regs after FILL <<");
        check_pe_move_reg(1, 3, ACC_W'(h0_stream[7]), "Row1 PE[1][3] after FILL");
        check_pe_move_reg(1, 2, ACC_W'(h0_stream[6]), "Row1 PE[1][2] after FILL");
        check_pe_move_reg(1, 1, ACC_W'(h0_stream[5]), "Row1 PE[1][1] after FILL");
        check_pe_move_reg(1, 0, ACC_W'(h0_stream[4]), "Row1 PE[1][0] after FILL");
        check_pe_move_reg(3, 3, ACC_W'(h1_stream[7]), "Row3 PE[3][3] after FILL");
        check_pe_move_reg(3, 2, ACC_W'(h1_stream[6]), "Row3 PE[3][2] after FILL");
        check_pe_move_reg(3, 1, ACC_W'(h1_stream[5]), "Row3 PE[3][1] after FILL");
        check_pe_move_reg(3, 0, ACC_W'(h1_stream[4]), "Row3 PE[3][0] after FILL");

        // ── W_LOAD: 4 cycles ──────────────────────────────────────
        wait_for_state(3'd3, "W_LOAD");
        repeat(4) @(posedge clk);
        @(negedge clk);
        $display("\n>> Checking weights after W_LOAD <<");
        log_pe_weights("After W_LOAD — all w_reg should be +1");
        // Confirm psums still 0 before compute
        for (int r = 0; r < 4; r++)
            for (int c = 0; c < 4; c++)
                check_pe_psum(r, c, 13'sd0,
                    $sformatf("psum=0 before COMPUTE PE[%0d][%0d]", r, c));

        // ── COMPUTE: 4 channels ───────────────────────────────────
        wait_for_state(3'd4, "COMPUTE");
        $display("\n>> COMPUTE: circular shift + MAC <<");
        repeat(4) begin
            @(negedge clk);
            log_pe_psums("COMPUTE cycle psum snapshot");
            log_pe_move_regs("COMPUTE cycle move_reg snapshot");
        end

        // With weight=1: psum = last activation in move_reg
        @(negedge clk);
        $display("\n>> Checking psums after COMPUTE (ch0) <<");
        check_pe_psum(1, 3, 13'sd15, "PE[1][3] psum after ch0");
        check_pe_psum(1, 2, 13'sd5,  "PE[1][2] psum after ch0");
        check_pe_psum(1, 1, 13'sd60, "PE[1][1] psum after ch0");
        check_pe_psum(1, 0, 13'sd50, "PE[1][0] psum after ch0");

        // ── H_SHIFT: detect completion ────────────────────────────
        wait_for_state(3'd5, "H_SHIFT");
        $display("\n>> H_SHIFT in progress — logging each cycle <<");
        repeat(4) begin
            @(negedge clk);
            log_pe_move_regs("H_SHIFT cycle move_regs");
            log_pe_psums("H_SHIFT cycle psums");
            $display("  H_SHIFT | fifo_en=%0b direction=%0b", fifo_en, direction);
        end

        // Wait for H_SHIFT → W_LOAD transition
        // This is the true end of one horizontal ZigZag pass
        wait_for_hshift_done();
        @(negedge clk);
        $display("\n>> One H_SHIFT complete <<");
        check_signal(u_fsm.state == 3'd3, 1'b1, "FSM in W_LOAD after H_SHIFT");

        // Check move_regs shifted by 1 position
        $display("\n>> move_regs after one H_SHIFT <<");
        log_pe_move_regs("After first H_SHIFT");
        log_pe_psums("Psums after first H_SHIFT");

        // Check FIFO captured correct bottom row values
        $display("\n>> FIFO state after H_SHIFT <<");
        $display("  FIFO1 empty=%0b full=%0b", dut.u_fifo1.empty, dut.u_fifo1.full);
        $display("  FIFO2 empty=%0b full=%0b", dut.u_fifo2.empty, dut.u_fifo2.full);

        // ── Let FSM complete full run ──────────────────────────────
        $display("\n>> Letting FSM complete full run <<");
        begin
            int full_timeout;
            full_timeout = 500;
            while (!done && full_timeout > 0) begin
                @(posedge clk);
                full_timeout--;
            end
            if (full_timeout == 0)
                $display("FAIL | Full run timed out — done never asserted");
            else
                $display("PASS | done asserted at time %0t", $time);
        end

        // ── PSUM_SHIFT drain check ─────────────────────────────────
        $display("\n>> Final psum drain outputs <<");
        repeat(8) begin
            @(negedge clk);
            $display("  DRAIN | psum_out0=%0d psum_out1=%0d", psum_out0, psum_out1);
        end

        repeat(5) @(posedge clk);
        $display("\n── ZigZag Horizontal Verification Complete ──");
        $finish;
    end

endmodule