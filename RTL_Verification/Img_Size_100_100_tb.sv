// ============================================================================
//  top_tb_golden_1.sv  —  ZigZag Systolic Array Golden Model Testbench
// ============================================================================
`timescale 1ns/1ps

module top_tb_golden_1 #(
    parameter int DATA_W   = 6,
    parameter int WEIGHT_W = 2,
    parameter int ACC_W    = 13,
    parameter int ROWS     = 4,
    parameter int COLS     = 4,
    parameter int UNQ_DIR  = 4,
    parameter int IMG_H    = 100,
    parameter int IMG_W    = 100,
    parameter int IN_CH    = 4,
    parameter int K        = 3,
    parameter int OUT_H    = IMG_H - K + 1,
    parameter int OUT_W    = IMG_W - K + 1,
    parameter int N_PAIRS  = (OUT_H/2) * OUT_W
)();

// ── Clock ─────────────────────────────────────────────────────────────────────
logic clk, rst_n;
initial clk = 0;
always #5 clk = ~clk;

// ── DUT ───────────────────────────────────────────────────────────────────────
logic                start, done;
logic [DATA_W-1:0]   h_in0, h_in1, v_in0, v_in1;
logic [WEIGHT_W-1:0] w_in [0:COLS-1];
logic [ACC_W-1:0]    psum_out0, psum_out1;

top #(
    .DATA_W(DATA_W), .WEIGHT_W(WEIGHT_W), .ACC_W(ACC_W),
    .ROWS(ROWS), .COLS(COLS), .UNQ_DIR(UNQ_DIR)
) iDUT (
    .clk(clk), .rst_n(rst_n), .start(start), .done(done),
    .h_in0(h_in0), .h_in1(h_in1),
    .v_in0(v_in0), .v_in1(v_in1),
    .w_in(w_in),
    .psum_out0(psum_out0), .psum_out1(psum_out1)
);

// ── Data arrays ───────────────────────────────────────────────────────────────
logic [DATA_W-1:0]          image   [0:IMG_H-1][0:IMG_W-1][0:IN_CH-1];
logic signed [WEIGHT_W-1:0] kern    [0:K-1][0:K-1][0:IN_CH-1];
logic signed [ACC_W-1:0]    gold_p0 [0:N_PAIRS-1];
logic signed [ACC_W-1:0]    gold_p1 [0:N_PAIRS-1];

int pass_cnt, fail_cnt;

// ─────────────────────────────────────────────────────────────────────────────
//  Helper Functions & Tasks
// ─────────────────────────────────────────────────────────────────────────────

task automatic zero_inputs;
    int ci;
    h_in0='0; h_in1='0; v_in0='0; v_in1='0;
    for (ci=0; ci<COLS; ci++) w_in[ci]='0;
endtask

// Safely fetches a pixel from the image or returns 0 if out of bounds
function logic [DATA_W-1:0] get_px(int r, int c, int ch);
    if (r >= 0 && r < IMG_H && c >= 0 && c < IMG_W && ch >= 0 && ch < IN_CH)
        return image[r][c][ch];
    return '0;
endfunction

// One compute round = 4 channels × [W_LOAD(4 cy) + COMPUTE(1 cy)]
task automatic do_compute_round(input int kr, input int kc);
    int ch, i, ci;
    logic signed [WEIGHT_W-1:0] wv;
    for (ch=0; ch<IN_CH; ch++) begin
        wv = kern[kr][kc][ch];
        // W_LOAD × 4 cycles
        for (i=0; i<4; i++) begin
            h_in0='0; h_in1='0; v_in0='0; v_in1='0;
            for (ci=0; ci<COLS; ci++) w_in[ci] = wv;
            @(posedge clk);
        end
        // COMPUTE × 1 cycle
        zero_inputs();
        @(posedge clk);
    end
endtask

// ─────────────────────────────────────────────────────────────────────────────
//  One full start→done invocation (Decoupled Weights, Acts, & Phases)
// ─────────────────────────────────────────────────────────────────────────────
task automatic drive_invocation(
    input int inv_idx,
    input int row_base,
    input int col
);
    int i, s, tcnt;
    logic signed [ACC_W-1:0] cap0, cap1;

    // DECOUPLED INDICES
    // act_kr forces the correct image rows into the v_in pins
    int act_kr [0:5] = '{ 2, 2, 2, 3, 3, 3 }; 
    // wt_kr keeps the kernel safely in bounds (Row 1 and Row 2)
    int wt_kr  [0:5] = '{ 1, 1, 1, 2, 2, 2 }; 
    // ZigZag Columns
    int vsh_kc [0:5] = '{ 2, 1, 0, 0, 1, 2 }; 

    // 1. Pulse start
    zero_inputs();
    start = 1;
    @(posedge clk);   // FSM: IDLE → CLEAR
    start = 0;

    // 2. CLEAR (1 cycle)
    zero_inputs();
    @(posedge clk);   // FSM: CLEAR → FILL

    // 3. FILL (8 cycles) - Standard Phase (0, 1, 2, 3)
    for (i=0; i<8; i++) begin
        int kc_f = (i < 4) ? 0 : 1; 
        int ch_f = i % 4; // RESTORED to standard order
        
        h_in0 = get_px(row_base,     col + kc_f, ch_f);
        h_in1 = get_px(row_base + 1, col + kc_f, ch_f);
        v_in0 = '0; 
        v_in1 = '0;
        for (int ci=0; ci<COLS; ci++) w_in[ci]='0;
        @(posedge clk);
    end

    // 4. Round 0 (kr=0, kc=0)
    do_compute_round(0, 0);

    // 5. H_SHIFT 1 (4 cycles) -> Load col+2 - Standard Phase (0, 1, 2, 3)
    for (i=0; i<4; i++) begin
        int ch_f = i % 4; // RESTORED to standard order
        
        h_in0 = get_px(row_base,     col + 2, ch_f);
        h_in1 = get_px(row_base + 1, col + 2, ch_f);
        v_in0 = '0; 
        v_in1 = '0;
        for (int ci=0; ci<COLS; ci++) w_in[ci]='0;
        @(posedge clk);
    end

    // 6. Round 1 (kr=0, kc=1)
    do_compute_round(0, 1);

    // 7. H_SHIFT 2 (4 cycles) -> Bridge pass-through
    for (i=0; i<4; i++) begin
        zero_inputs();
        @(posedge clk);
    end

    // 8. Round 2 (kr=0, kc=2)
    do_compute_round(0, 2);

    // 9. Six V_SHIFT and Compute rounds (Rounds 3..8)
    for (s=0; s<6; s++) begin
        // V_SHIFT (4 cycles) - Compensated Phase (1, 2, 3, 0)
        for (i=0; i<4; i++) begin
            // V_SHIFT uses direct pins, requires phase offset
            int ch_f = (i + 1) % 4; 
            
            h_in0 = '0; 
            h_in1 = '0;
            v_in0 = get_px(row_base + act_kr[s],     col + vsh_kc[s], ch_f);
            v_in1 = get_px(row_base + 1 + act_kr[s], col + vsh_kc[s], ch_f);
            
            for (int ci=0; ci<COLS; ci++) w_in[ci]='0;
            @(posedge clk);
        end

        // Compute round - USE wt_kr for Kernel data!
        do_compute_round(wt_kr[s], vsh_kc[s]);
    end

    // 10. PSUM_SHIFT: Wait for done
    zero_inputs();
    tcnt = 0;
    while (done !== 1'b1 && tcnt < 20) begin
        @(posedge clk);
        zero_inputs();
        tcnt = tcnt + 1;
    end

    if (tcnt >= 20) begin
        $display("WARN: done timeout inv=%0d row=%0d col=%0d (waited %0d cy)",
                 inv_idx, row_base, col, tcnt);
    end

    // Capture and Compare
    cap0 = $signed(psum_out0);
    cap1 = $signed(psum_out1);

    if (cap0 === gold_p0[inv_idx] && cap1 === gold_p1[inv_idx]) begin
        pass_cnt = pass_cnt + 1;
        if (inv_idx < 5 || (inv_idx % 500) == 0)
            $display("PASS [%5d] row=%2d col=%2d | p0=%7d  p1=%7d",
                     inv_idx, row_base, col, cap0, cap1);
    end else begin
        fail_cnt = fail_cnt + 1;
        $display("FAIL [%5d] row=%2d col=%2d | got(%7d,%7d)  exp(%7d,%7d)",
                 inv_idx, row_base, col, cap0, cap1,
                 gold_p0[inv_idx], gold_p1[inv_idx]);
        if (fail_cnt >= 20) begin
            $display("=== 20 failures — stopping early ===");
            $stop();
        end
    end

    // Let FSM return to IDLE before next invocation
    @(posedge clk);
    @(posedge clk);
endtask

// ─────────────────────────────────────────────────────────────────────────────
//  File loaders
// ─────────────────────────────────────────────────────────────────────────────
task automatic load_golden_outputs;
    int    fd, ret, idx_read, p0, p1;
    string tok;
    fd = $fopen("golden_outputs.txt", "r");
    if (fd == 0) begin
        $display("ERROR: golden_outputs.txt not found. Run golden_model.py first.");
        $finish;
    end
    while (!$feof(fd)) begin
        ret = $fscanf(fd, " %s", tok);
        if (ret != 1) continue;
        if (tok.substr(0,0) == "#") begin ret = $fgets(tok, fd); continue; end
        idx_read = tok.atoi();
        ret = $fscanf(fd, " %d %d", p0, p1);
        if (ret == 2 && idx_read >= 0 && idx_read < N_PAIRS) begin
            gold_p0[idx_read] = p0;
            gold_p1[idx_read] = p1;
        end
    end
    $fclose(fd);
    $display("Loaded golden_outputs.txt  (%0d pairs)", N_PAIRS);
endtask

task automatic load_image;
    int    fd, ret, r, c, ch, val;
    string tok;
    fd = $fopen("image_flat.txt", "r");
    if (fd == 0) begin $display("ERROR: image_flat.txt not found."); $finish; end
    while (!$feof(fd)) begin
        ret = $fscanf(fd, " %s", tok);
        if (ret != 1) continue;
        if (tok.substr(0,0) == "#") begin ret = $fgets(tok, fd); continue; end
        r = tok.atoi();
        ret = $fscanf(fd, " %d %d %d", c, ch, val);
        if (ret == 3 && r < IMG_H && c < IMG_W && ch < IN_CH)
            image[r][c][ch] = val[DATA_W-1:0];
    end
    $fclose(fd);
    $display("Loaded image_flat.txt      (%0dx%0dx%0d)", IMG_H, IMG_W, IN_CH);
endtask

task automatic load_kernel;
    int    fd, ret, kr, kc, ch, val;
    string tok;
    fd = $fopen("kernel_flat.txt", "r");
    if (fd == 0) begin $display("ERROR: kernel_flat.txt not found."); $finish; end
    while (!$feof(fd)) begin
        ret = $fscanf(fd, " %s", tok);
        if (ret != 1) continue;
        if (tok.substr(0,0) == "#") begin ret = $fgets(tok, fd); continue; end
        kr = tok.atoi();
        ret = $fscanf(fd, " %d %d %d", kc, ch, val);
        if (ret == 3 && kr < K && kc < K && ch < IN_CH)
            kern[kr][kc][ch] = val[WEIGHT_W-1:0];
    end
    $fclose(fd);
    $display("Loaded kernel_flat.txt     (%0dx%0dx%0d)", K, K, IN_CH);
endtask

// ─────────────────────────────────────────────────────────────────────────────
//  Main
// ─────────────────────────────────────────────────────────────────────────────
initial begin
    int row_base, col, inv_idx;
    int ci;

    rst_n=0; start=0;
    pass_cnt=0; fail_cnt=0;
    h_in0='0; h_in1='0; v_in0='0; v_in1='0;
    for (ci=0; ci<COLS; ci++) w_in[ci]='0;

    load_golden_outputs();
    load_image();
    load_kernel();

    @(negedge clk);
    rst_n = 1;
    repeat(5) @(posedge clk);
    $display("=== Convolution verification: %0d invocations ===", N_PAIRS);

    inv_idx = 0;
    for (row_base=0; row_base<OUT_H; row_base=row_base+2) begin
        for (col=0; col<OUT_W; col=col+1) begin
            drive_invocation(inv_idx, row_base, col);
            inv_idx = inv_idx + 1;
        end
    end

    $display("");
    $display("=======  VERIFICATION COMPLETE  =======");
    $display("  PASS : %0d / %0d", pass_cnt, N_PAIRS);
    $display("  FAIL : %0d / %0d", fail_cnt, N_PAIRS);
    if (fail_cnt == 0)
        $display("  *** ALL %0d TESTS PASSED ***", N_PAIRS);
    else
        $display("  *** %0d FAILURES ***", fail_cnt);
    $display("=======================================");
    $finish;
end

// ─────────────────────────────────────────────────────────────────────────────
//  Optional FSM debug monitor
// ─────────────────────────────────────────────────────────────────────────────
`ifdef DEBUG_FSM
int cycle_cnt;
initial cycle_cnt = 0;
always @(posedge clk) begin
    if (rst_n) begin
        cycle_cnt <= cycle_cnt + 1;
        $display("cy=%0d  state=%0d cnt=%0d ch=%0d h=%0d v=%0d  done=%b  p0=%0d p1=%0d",
                 cycle_cnt,
                 iDUT.u_fsm.state,
                 iDUT.u_fsm.cnt,
                 iDUT.u_fsm.ch_cnt,
                 iDUT.u_fsm.h_cnt,
                 iDUT.u_fsm.v_cnt,
                 done,
                 $signed(psum_out0),
                 $signed(psum_out1));
    end
end
`endif

// =============================================================================
//  PE VISIBILITY — waveform signals for all 16 PEs
// =============================================================================

// ── Per-PE named signals ──────────────────────────────────────────────────────
logic signed [ACC_W-1:0]    pe_move_reg  [0:ROWS-1][0:COLS-1];
logic signed [ACC_W-1:0]    pe_psum      [0:ROWS-1][0:COLS-1];
logic signed [WEIGHT_W-1:0] pe_weight    [0:ROWS-1][0:COLS-1];
logic signed [ACC_W-1:0]    pe_act_out   [0:ROWS-1][0:COLS-1];
logic        [1:0]          pe_dst_sel   [0:ROWS-1][0:COLS-1];
logic        [1:0]          pe_src_sel   [0:ROWS-1][0:COLS-1];
logic signed [ACC_W-1:0]    pe_to_left   [0:ROWS-1][0:COLS-1];
logic signed [ACC_W-1:0]    pe_to_right  [0:ROWS-1][0:COLS-1];
logic signed [ACC_W-1:0]    pe_to_up     [0:ROWS-1][0:COLS-1];
logic signed [ACC_W-1:0]    pe_to_down   [0:ROWS-1][0:COLS-1];
logic signed [ACC_W-1:0]    pe_from_left [0:ROWS-1][0:COLS-1];
logic signed [ACC_W-1:0]    pe_from_right[0:ROWS-1][0:COLS-1];
logic signed [ACC_W-1:0]    pe_from_up   [0:ROWS-1][0:COLS-1];
logic signed [ACC_W-1:0]    pe_from_down [0:ROWS-1][0:COLS-1];

generate
    for (genvar r = 0; r < ROWS; r++) begin : g_vis_r
        for (genvar c = 0; c < COLS; c++) begin : g_vis_c
            assign pe_move_reg  [r][c] = $signed(iDUT.u_pe_array.g_pe_row[r].g_pe_col[c].u_pe.move_reg);
            assign pe_psum      [r][c] = $signed(iDUT.u_pe_array.g_pe_row[r].g_pe_col[c].u_pe.psum_out);
            assign pe_weight    [r][c] = $signed(iDUT.u_pe_array.g_pe_row[r].g_pe_col[c].u_pe.w_reg);
            assign pe_act_out   [r][c] = $signed(iDUT.u_pe_array.g_pe_row[r].g_pe_col[c].u_pe.act_out_val);
            assign pe_dst_sel   [r][c] =         iDUT.u_pe_array.g_pe_row[r].g_pe_col[c].u_pe.dst_sel;
            assign pe_src_sel   [r][c] =         iDUT.u_pe_array.g_pe_row[r].g_pe_col[c].u_pe.src_sel;
            assign pe_to_left   [r][c] = $signed(iDUT.u_pe_array.g_pe_row[r].g_pe_col[c].u_pe.act_to_left);
            assign pe_to_right  [r][c] = $signed(iDUT.u_pe_array.g_pe_row[r].g_pe_col[c].u_pe.act_to_right);
            assign pe_to_up     [r][c] = $signed(iDUT.u_pe_array.g_pe_row[r].g_pe_col[c].u_pe.act_to_up);
            assign pe_to_down   [r][c] = $signed(iDUT.u_pe_array.g_pe_row[r].g_pe_col[c].u_pe.act_to_down);
            assign pe_from_left [r][c] = $signed(iDUT.u_pe_array.act_from_left [r][c]);
            assign pe_from_right[r][c] = $signed(iDUT.u_pe_array.act_from_right[r][c]);
            assign pe_from_up   [r][c] = $signed(iDUT.u_pe_array.act_from_up   [r][c]);
            assign pe_from_down [r][c] = $signed(iDUT.u_pe_array.act_from_down [r][c]);
        end
    end
endgenerate

// ── FSM state as readable string ──────────────────────────────────────────────
string fsm_state_str;
always_comb begin
    case (iDUT.u_fsm.state)
        3'd0: fsm_state_str = "IDLE      ";
        3'd1: fsm_state_str = "CLEAR     ";
        3'd2: fsm_state_str = "FILL      ";
        3'd3: fsm_state_str = "W_LOAD    ";
        3'd4: fsm_state_str = "COMPUTE   ";
        3'd5: fsm_state_str = "H_SHIFT   ";
        3'd6: fsm_state_str = "V_SHIFT   ";
        3'd7: fsm_state_str = "PSUM_SHIFT";
        default: fsm_state_str = "UNKNOWN   ";
    endcase
end

// ── FSM counter aliases ───────────────────────────────────────────────────────
logic [3:0] fsm_cnt;
logic [1:0] fsm_ch_cnt;
logic [1:0] fsm_h_cnt;
logic [2:0] fsm_v_cnt;
assign fsm_cnt    = iDUT.u_fsm.cnt;
assign fsm_ch_cnt = iDUT.u_fsm.ch_cnt;
assign fsm_h_cnt  = iDUT.u_fsm.h_cnt;
assign fsm_v_cnt  = iDUT.u_fsm.v_cnt;

// ── Control signal aliases ────────────────────────────────────────────────────
logic       ctrl_en, ctrl_move_en, ctrl_w_ld_en;
logic       ctrl_fifo_en, ctrl_psum_shift_en, ctrl_psum_clr;
logic [1:0] ctrl_direction;
assign ctrl_en            = iDUT.en;
assign ctrl_move_en       = iDUT.move_en;
assign ctrl_w_ld_en       = iDUT.w_ld_en;
assign ctrl_fifo_en       = iDUT.fifo_en;
assign ctrl_psum_shift_en = iDUT.psum_shift_en;
assign ctrl_psum_clr      = iDUT.psum_clr;
assign ctrl_direction     = iDUT.direction;

endmodule

//TCL Script for adding waves in simulation (e.g. in ModelSim or Questa):

/*
# FSM state and counters
add wave -divider "FSM"
add wave /top_tb_golden_1/fsm_state_str
add wave /top_tb_golden_1/fsm_cnt
add wave /top_tb_golden_1/fsm_ch_cnt
add wave /top_tb_golden_1/fsm_h_cnt
add wave /top_tb_golden_1/fsm_v_cnt

# Control signals
add wave -divider "Control"
add wave /top_tb_golden_1/ctrl_en
add wave /top_tb_golden_1/ctrl_move_en
add wave /top_tb_golden_1/ctrl_w_ld_en
add wave /top_tb_golden_1/ctrl_direction
add wave /top_tb_golden_1/ctrl_fifo_en
add wave /top_tb_golden_1/ctrl_psum_shift_en
add wave /top_tb_golden_1/ctrl_psum_clr

# Boundary inputs and outputs
add wave -divider "Boundary"
add wave /top_tb_golden_1/h_in0
add wave /top_tb_golden_1/h_in1
add wave /top_tb_golden_1/v_in0
add wave /top_tb_golden_1/v_in1
add wave /top_tb_golden_1/done
add wave /top_tb_golden_1/psum_out0
add wave /top_tb_golden_1/psum_out1

# All 16 PEs - State, Routing, and Interconnects
foreach r {0 1 2 3} {
    foreach c {0 1 2 3} {
        add wave -divider "PE\[$r\]\[$c\]"
        
        # 1. Core State
        add wave /top_tb_golden_1/pe_move_reg\[$r\]\[$c\]
        add wave /top_tb_golden_1/pe_psum\[$r\]\[$c\]
        add wave /top_tb_golden_1/pe_weight\[$r\]\[$c\]
        add wave /top_tb_golden_1/pe_act_out\[$r\]\[$c\]
        
        # 2. MUX Controls (Crucial for the V_SHIFT bug)
        add wave /top_tb_golden_1/pe_src_sel\[$r\]\[$c\]
        add wave /top_tb_golden_1/pe_dst_sel\[$r\]\[$c\]
        
        # 3. Physical incoming wires (To trace what the MUX is ignoring)
        add wave /top_tb_golden_1/pe_from_up\[$r\]\[$c\]
        add wave /top_tb_golden_1/pe_from_left\[$r\]\[$c\]
        add wave /top_tb_golden_1/pe_from_right\[$r\]\[$c\]
        add wave /top_tb_golden_1/pe_from_down\[$r\]\[$c\]
    }
}
*/