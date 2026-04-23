// ============================================================================
//  top_tb_golden.sv  —  ZigZag Systolic Array Golden Model Testbench
//
//  CORRECT FSM SCHEDULE (traced by hand from control.sv):
//     CLEAR      = 1 cy
//     FILL       = 8 cy
//     W_LOAD     = 4 cy   (cnt 0→3)
//     COMPUTE    = 1 cy   (exits immediately unless ch_cnt==3)
//     H_SHIFT    = 4 cy
//     V_SHIFT    = 4 cy
//     PSUM_SHIFT = 8 cy
//
//  PER-CHANNEL BLOCK: W_LOAD(4) + COMPUTE(1) = 5 cy
//  PER-ROUND (4 channels): 20 cy
//
//  MACRO SEQUENCE (9 compute rounds, one per kernel position):
//    CLEAR(1) + FILL(8)
//      + Round 0 (20)                             ← v_cnt=0,h_cnt=0 → H_SHIFT
//    + H_SHIFT(4) + Round 1 (20)                  ← v_cnt=0,h_cnt=1 → H_SHIFT
//    + H_SHIFT(4) + Round 2 (20)                  ← v_cnt=0,h_cnt=2 → V_SHIFT
//    + V_SHIFT(4) + Round 3 (20)  ← v_cnt=1 → V_SHIFT
//    + V_SHIFT(4) + Round 4 (20)  ← v_cnt=2 → V_SHIFT
//    + V_SHIFT(4) + Round 5 (20)  ← v_cnt=3 → V_SHIFT
//    + V_SHIFT(4) + Round 6 (20)  ← v_cnt=4 → V_SHIFT
//    + V_SHIFT(4) + Round 7 (20)  ← v_cnt=5 → V_SHIFT
//    + V_SHIFT(4) + Round 8 (20)  ← v_cnt=6 → PSUM_SHIFT
//    + PSUM_SHIFT(8)
//
//  KERNEL POSITION MAP (9 positions for 3×3 kernel):
//    Round 0 (post FILL)    → (kr=0, kc=0)
//    Round 1 (post H_SHIFT) → (kr=0, kc=1)
//    Round 2 (post H_SHIFT) → (kr=0, kc=2)
//    Round 3 (post V_SHIFT) → (kr=1, kc=0)
//    Round 4 (post V_SHIFT) → (kr=1, kc=1)
//    Round 5 (post V_SHIFT) → (kr=1, kc=2)
//    Round 6 (post V_SHIFT) → (kr=2, kc=0)
//    Round 7 (post V_SHIFT) → (kr=2, kc=1)
//    Round 8 (post V_SHIFT) → (kr=2, kc=2)
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
task automatic zero_inputs;
    int ci;
    h_in0='0; h_in1='0; v_in0='0; v_in1='0;
    for (ci=0; ci<COLS; ci++) w_in[ci]='0;
endtask

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
//  One full start→done invocation
// ─────────────────────────────────────────────────────────────────────────────
task automatic drive_invocation(
    input int inv_idx,
    input int row_base,
    input int col
);
    int i, s, ch, ci;
    int kc_f, ch_f, ir, ic;
    int tcnt;

    logic [DATA_W-1:0] h0f [0:7];
    logic [DATA_W-1:0] h1f [0:7];
    logic [DATA_W-1:0] h0h1 [0:3];
    logic [DATA_W-1:0] h1h1 [0:3];
    logic [DATA_W-1:0] v0v [0:5][0:3];
    logic [DATA_W-1:0] v1v [0:5][0:3];

    int vsh_kr [0:5];
    int vsh_kc [0:5];

    logic signed [ACC_W-1:0] cap0, cap1;

    vsh_kr[0]=1; vsh_kc[0]=0;
    vsh_kr[1]=1; vsh_kc[1]=1;
    vsh_kr[2]=1; vsh_kc[2]=2;
    vsh_kr[3]=2; vsh_kc[3]=0;
    vsh_kr[4]=2; vsh_kc[4]=1;
    vsh_kr[5]=2; vsh_kc[5]=2;

    for (i=0; i<8; i++) begin
        kc_f = (i<4) ? 0 : 1;
        ch_f = i % IN_CH;
        h0f[i] = ((col+kc_f)<IMG_W && row_base   <IMG_H) ? image[row_base  ][col+kc_f][ch_f] : '0;
        h1f[i] = ((col+kc_f)<IMG_W && (row_base+1)<IMG_H) ? image[row_base+1][col+kc_f][ch_f] : '0;
    end

    for (i=0; i<4; i++) begin
        h0h1[i] = ((col+2)<IMG_W && row_base   <IMG_H) ? image[row_base  ][col+2][i] : '0;
        h1h1[i] = ((col+2)<IMG_W && (row_base+1)<IMG_H) ? image[row_base+1][col+2][i] : '0;
    end

    for (s=0; s<6; s++) begin
        for (ch=0; ch<4; ch++) begin
            ir = row_base + vsh_kr[s];
            ic = col      + vsh_kc[s];
            if (ir<IMG_H && ic<IMG_W) begin
                v0v[s][ch] = image[ir][ic][ch];
                v1v[s][ch] = image[ir][ic][ch];
            end else begin
                v0v[s][ch] = '0;
                v1v[s][ch] = '0;
            end
        end
    end

    zero_inputs();
    start = 1;
    @(posedge clk);
    start = 0;

    zero_inputs();
    @(posedge clk);

    for (i=0; i<8; i++) begin
        h_in0 = h0f[i]; h_in1 = h1f[i];
        v_in0 = '0; v_in1 = '0;
        for (ci=0; ci<COLS; ci++) w_in[ci]='0;
        @(posedge clk);
    end

    do_compute_round(0, 0);

    for (i=0; i<4; i++) begin
        h_in0 = h0h1[i]; h_in1 = h1h1[i];
        v_in0 = '0; v_in1 = '0;
        for (ci=0; ci<COLS; ci++) w_in[ci]='0;
        @(posedge clk);
    end

    do_compute_round(0, 1);

    for (i=0; i<4; i++) begin
        zero_inputs();
        @(posedge clk);
    end

    do_compute_round(0, 2);

    for (s=0; s<6; s++) begin
        for (i=0; i<4; i++) begin
            h_in0='0; h_in1='0;
            v_in0 = v0v[s][i];
            v_in1 = v1v[s][i];
            for (ci=0; ci<COLS; ci++) w_in[ci]='0;
            @(posedge clk);
        end
        do_compute_round(vsh_kr[s], vsh_kc[s]);
    end

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
//  Optional FSM debug monitor — compile with +define+DEBUG_FSM
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
//  Add these to your wave window to trace activation and weight movement.
//
//  Signal naming: pe_XXX[row][col]
//    pe_move_reg[r][c]  — activation value currently held in that PE
//    pe_psum    [r][c]  — accumulated partial sum (grows each COMPUTE)
//    pe_weight  [r][c]  — weight loaded into that PE
//    pe_act_out [r][c]  — value the PE is currently driving onto its output bus
//    pe_dst_sel [r][c]  — direction it sends to (00=right,01=left,10=down,11=up)
//    pe_src_sel [r][c]  — direction it receives from
//    pe_to_left / pe_to_right / pe_to_up / pe_to_down [r][c] — output buses
//    pe_from_left / pe_from_right / pe_from_up / pe_from_down [r][c] — input buses
//
//  FSM visibility:
//    fsm_state_str  — readable state name e.g. "FILL", "W_LOAD", "COMPUTE"
//    fsm_cnt / fsm_ch_cnt / fsm_h_cnt / fsm_v_cnt — all FSM counters
//
//  Control signal aliases (convenient for wave window):
//    ctrl_en / ctrl_move_en / ctrl_w_ld_en / ctrl_fifo_en
//    ctrl_psum_shift_en / ctrl_psum_clr / ctrl_direction
// =============================================================================

// ── Per-PE named signals ──────────────────────────────────────────────────────
logic signed [ACC_W-1:0]    pe_move_reg  [0:ROWS-1][0:COLS-1];
logic signed [ACC_W-1:0]    pe_psum      [0:ROWS-1][0:COLS-1];
logic signed [WEIGHT_W-1:0] pe_weight    [0:ROWS-1][0:COLS-1];
logic signed [ACC_W-1:0]    pe_act_out   [0:ROWS-1][0:COLS-1];
logic        [1:0]           pe_dst_sel   [0:ROWS-1][0:COLS-1];
logic        [1:0]           pe_src_sel   [0:ROWS-1][0:COLS-1];
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

/*# FSM state and counters
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
add wave /top_tb_golden_1/ctrl_psum_shift_en

# Boundary inputs and outputs
add wave -divider "Boundary"
add wave /top_tb_golden_1/h_in0
add wave /top_tb_golden_1/h_in1
add wave /top_tb_golden_1/v_in0
add wave /top_tb_golden_1/v_in1
add wave /top_tb_golden_1/psum_out0
add wave /top_tb_golden_1/psum_out1
add wave /top_tb_golden_1/done

# All 16 PEs - move_reg, psum, weight
foreach r {0 1 2 3} {
    foreach c {0 1 2 3} {
        add wave -divider "PE\[$r\]\[$c\]"
        add wave /top_tb_golden_1/pe_move_reg\[$r\]\[$c\]
        add wave /top_tb_golden_1/pe_psum\[$r\]\[$c\]
        add wave /top_tb_golden_1/pe_weight\[$r\]\[$c\]
        add wave /top_tb_golden_1/pe_act_out\[$r\]\[$c\]
    }
} */