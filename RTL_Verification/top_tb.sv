`timescale 1ns/1ps

module top_tb #(
    parameter int DATA_W   = 6,
    parameter int WEIGHT_W = 2,
    parameter int ACC_W    = 13,
    parameter int ROWS     = 4,
    parameter int COLS     = 4,
    parameter int UNQ_DIR  = 4
)();

    // ── Signals ───────────────────────────────────────────────────
    logic clk, rst_n;
    logic start, done;

    logic [DATA_W-1:0]   h_in0, h_in1;
    logic [DATA_W-1:0]   v_in0, v_in1;
    logic [WEIGHT_W-1:0] w_in [0:COLS-1];
    logic [ACC_W-1:0]    psum_out0;
    logic [ACC_W-1:0]    psum_out1;

    // ── Storage for vertical chaining ─────────────────────────────
    logic [DATA_W-1:0] v1_store [0:3];

    // ── DUT Instantiation ─────────────────────────────────────────
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

    // ── Clock ─────────────────────────────────────────────────────
    initial clk = 0;
    always #10 clk = ~clk;

    // ── Cycle counter ─────────────────────────────────────────────
    int cycle_count;
    initial cycle_count = 0;
    always @(posedge clk) cycle_count++;

    // ─────────────────────────────────────────────────────────────
    // TASKS
    // ─────────────────────────────────────────────────────────────

    // ── Initialize and reset ──────────────────────────────────────
    task automatic init_dut();
        rst_n = 0;
        start = 0;
        h_in0 = '0;
        h_in1 = '0;
        v_in0 = '0;
        v_in1 = '0;
        foreach (w_in[i]) w_in[i] = '0;
        @(negedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        $display("[CYC %0d] Reset released, triggering start", cycle_count);
        start = 1;
        @(posedge clk);
        start = 0;
    endtask

    // ── FILL: drive h_in0/h_in1 for 8 cycles ─────────────────────
    // Called once at the start to fill the array horizontally
    task automatic fill_h(
        input logic [DATA_W-1:0] stream0 [0:7],
        input logic [DATA_W-1:0] stream1 [0:7]
    );
        $display("[CYC %0d] >> FILL: loading horizontal activations", cycle_count);
        repeat(8) begin
            @(posedge clk);
            h_in0 = stream0[cycle_count % 8];
            h_in1 = stream1[cycle_count % 8];
            $display("  FILL | h_in0=%0d h_in1=%0d", h_in0, h_in1);
        end
        @(posedge clk);
        h_in0 = '0;
        h_in1 = '0;
    endtask

    // ── W_LOAD + COMPUTE: 4 channels ──────────────────────────────
    // Loads a weight set and computes for 4 channels
    // Alternates weight sign each channel: -1, +1, -1, +1
    task automatic load_and_compute(input string pixel_label);
        logic signed [WEIGHT_W-1:0] w_val;
        $display("[CYC %0d] >> COMPUTE: %s", cycle_count, pixel_label);
        for (int ch = 0; ch < 4; ch++) begin
            // Alternate weights: ch0→-1, ch1→+1, ch2→-1, ch3→+1
            w_val = (ch % 2 == 0) ? -1 : 1;
            repeat(4) begin
                foreach (w_in[i]) w_in[i] = w_val;
                @(posedge clk);
            end
            repeat(1) @(posedge clk);  // computation cycle
            $display("  CH%0d | w=%0d | psum_out0=%0d psum_out1=%0d",
                      ch, w_val, psum_out0, psum_out1);
        end
    endtask

    // ── H_SHIFT: drive new h_in values for 4 cycles ───────────────
    // Shifts activations one position horizontally
    task automatic hshift(input string pixel_label);
        $display("[CYC %0d] >> H_SHIFT: %s", cycle_count, pixel_label);
        repeat(4) begin
            @(posedge clk);
            h_in0 = $urandom_range(1, 63);  // keep within DATA_W=6
            h_in1 = $urandom_range(1, 63);
            $display("  H_SHIFT | h_in0=%0d h_in1=%0d", h_in0, h_in1);
        end
        @(posedge clk);
        h_in0 = '0;
        h_in1 = '0;
    endtask

    // ── V_SHIFT: drive new v_in values for 4 cycles ───────────────
    // Shifts activations one position vertically
    // chain=1 → reuse previous v1_store as v_in0 (chained from above)
    // chain=0 → generate fresh v_in0 randomly
    task automatic vshift(input string pixel_label, input logic chain);
        $display("[CYC %0d] >> V_SHIFT: %s (chain=%0b)", cycle_count, pixel_label, chain);
        for (int i = 0; i < 4; i++) begin
            @(posedge clk);
            v_in0 = chain ? v1_store[i] : $urandom_range(1, 63);
            v_in1 = $urandom_range(1, 63);
            v1_store[i] = v_in1;  // store for next chained V_SHIFT
            $display("  V_SHIFT | v_in0=%0d v_in1=%0d", v_in0, v_in1);
        end
        @(posedge clk);
        v_in0 = '0;
        v_in1 = '0;
    endtask

    // ── PSUM drain: wait 9 cycles and print outputs ───────────────
    task automatic drain_psum();
        $display("[CYC %0d] >> PSUM_SHIFT: draining", cycle_count);
        repeat(9) begin
            @(posedge clk);
            $display("  DRAIN | psum_out0=%0d psum_out1=%0d", psum_out0, psum_out1);
        end
    endtask

    // ── Check done signal ─────────────────────────────────────────
    task automatic wait_done();
        int timeout;
        timeout = 500;
        while (!done && timeout > 0) begin
            @(posedge clk);
            timeout--;
        end
        if (timeout == 0)
            $display("FAIL | done never asserted — timeout at cycle %0d", cycle_count);
        else
            $display("PASS | done asserted at cycle %0d", cycle_count);
    endtask

    // ─────────────────────────────────────────────────────────────
    // STIMULUS
    // ─────────────────────────────────────────────────────────────

    // Activation streams for initial FILL (8 values each)
    logic [DATA_W-1:0] h0_fill [0:7] = '{10, 20, 30, 40, 50, 60, 5,  15};
    logic [DATA_W-1:0] h1_fill [0:7] = '{11, 21, 31, 41, 51, 61, 6,  16};

    initial begin
        $dumpfile("top_tb.vcd");
        $dumpvars(0, top_tb);

        // ── Init + Reset ──────────────────────────────────────────
        init_dut();

        // ── FILL: initial horizontal load ─────────────────────────
        fill_h(h0_fill, h1_fill);

        // ── Pixel 1: first H position (post FILL) ─────────────────
        $display("\n════════ PIXEL 1 ════════");
        load_and_compute("Pixel 1");

        // ── Pixel 2: one H_SHIFT right ────────────────────────────
        $display("\n════════ PIXEL 2 ════════");
        hshift("Pixel 2 H_SHIFT");
        load_and_compute("Pixel 2");

        // ── Pixel 3: second H_SHIFT right ─────────────────────────
        $display("\n════════ PIXEL 3 ════════");
        hshift("Pixel 3 H_SHIFT");
        load_and_compute("Pixel 3");

        // ── Pixel 4: first V_SHIFT down (fresh) ───────────────────
        $display("\n════════ PIXEL 4 ════════");
        vshift("Pixel 4 V_SHIFT", 1'b0);  // fresh v_in0
        load_and_compute("Pixel 4");

        // ── Pixel 5: V_SHIFT chained from pixel 4 ─────────────────
        $display("\n════════ PIXEL 5 ════════");
        vshift("Pixel 5 V_SHIFT", 1'b1);  // chain: v_in0 = pixel4's v_in1
        load_and_compute("Pixel 5");

        // ── Pixel 6: V_SHIFT chained from pixel 5 ─────────────────
        $display("\n════════ PIXEL 6 ════════");
        vshift("Pixel 6 V_SHIFT", 1'b1);
        load_and_compute("Pixel 6");

        // ── Pixel 7: fresh V_SHIFT (new row group) ─────────────────
        $display("\n════════ PIXEL 7 ════════");
        vshift("Pixel 7 V_SHIFT", 1'b0);  // fresh v_in0
        load_and_compute("Pixel 7");

        // ── Pixel 8: V_SHIFT chained from pixel 7 ─────────────────
        $display("\n════════ PIXEL 8 ════════");
        vshift("Pixel 8 V_SHIFT", 1'b1);
        load_and_compute("Pixel 8");

        // ── Pixel 9: V_SHIFT chained from pixel 8 ─────────────────
        $display("\n════════ PIXEL 9 ════════");
        vshift("Pixel 9 V_SHIFT", 1'b1);
        load_and_compute("Pixel 9");

        // ── Wait for done ─────────────────────────────────────────
        wait_done();
        // ── PSUM drain ────────────────────────────────────────────
        drain_psum();

        repeat(5) @(posedge clk);
        $display("\n── Top Level Verification Complete ──");
        $stop();
    end

endmodule