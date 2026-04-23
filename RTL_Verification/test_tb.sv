// ============================================================================
//  diag_tb.sv — Diagnostic testbench v2: reveal output pixel spatial mapping
//
//  HOW IT WORKS:
//    1. Image pixels encode their (row, col) position: val = (row<<3) | col
//    2. All weights = +1, all 4 channels identical
//    3. Each PE's psum = 4 × sum(3x3 window of encoded pixels)
//    4. Each output pixel position has a UNIQUE expected sum:
//        out(0,0)=324  out(0,1)=360  out(0,2)=396
//        out(1,0)=612  out(1,1)=648  out(1,2)=684
//        out(2,0)=900  out(2,1)=936  out(2,2)=972
//    5. Match drain values to expected sums → know the drain order.
// ============================================================================
`timescale 1ns/1ps

module diag_tb #(
    parameter int DATA_W   = 6,
    parameter int WEIGHT_W = 2,
    parameter int ACC_W    = 13,
    parameter int ROWS     = 4,
    parameter int COLS     = 4,
    parameter int UNQ_DIR  = 4,
    parameter int IMG_H    = 5,
    parameter int IMG_W    = 5,
    parameter int IN_CH    = 4,
    parameter int K        = 3
)();

logic clk, rst_n;
initial clk = 0;
always #5 clk = ~clk;

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

logic [DATA_W-1:0]          image [0:IMG_H-1][0:IMG_W-1][0:IN_CH-1];
logic signed [WEIGHT_W-1:0] kern  [0:K-1][0:K-1][0:IN_CH-1];

int log_fd;

task automatic zero_inputs;
    int ci;
    h_in0='0; h_in1='0; v_in0='0; v_in1='0;
    for (ci=0; ci<COLS; ci++) w_in[ci]='0;
endtask

task automatic do_compute_round(input int kr, input int kc);
    int ch, i, ci;
    logic signed [WEIGHT_W-1:0] wv;
    for (ch=0; ch<IN_CH; ch++) begin
        wv = kern[kr][kc][ch];
        for (i=0; i<4; i++) begin
            h_in0='0; h_in1='0; v_in0='0; v_in1='0;
            for (ci=0; ci<COLS; ci++) w_in[ci] = wv;
            @(posedge clk);
        end
        zero_inputs();
        @(posedge clk);
    end
endtask

task automatic snapshot_all_pes;
    int r, c;
    logic signed [ACC_W-1:0] v;
    $fdisplay(log_fd, "");
    $fdisplay(log_fd, "=== PE psum_out snapshot ===");
    $fdisplay(log_fd, "Row\\Col :        0         1         2         3");
    for (r=0; r<ROWS; r++) begin
        $fwrite(log_fd, "PE row %0d :", r);
        for (c=0; c<COLS; c++) begin
            case ({r[1:0], c[1:0]})
                {2'd0, 2'd0}: v = $signed(iDUT.u_pe_array.g_pe_row[0].g_pe_col[0].u_pe.psum_out);
                {2'd0, 2'd1}: v = $signed(iDUT.u_pe_array.g_pe_row[0].g_pe_col[1].u_pe.psum_out);
                {2'd0, 2'd2}: v = $signed(iDUT.u_pe_array.g_pe_row[0].g_pe_col[2].u_pe.psum_out);
                {2'd0, 2'd3}: v = $signed(iDUT.u_pe_array.g_pe_row[0].g_pe_col[3].u_pe.psum_out);
                {2'd1, 2'd0}: v = $signed(iDUT.u_pe_array.g_pe_row[1].g_pe_col[0].u_pe.psum_out);
                {2'd1, 2'd1}: v = $signed(iDUT.u_pe_array.g_pe_row[1].g_pe_col[1].u_pe.psum_out);
                {2'd1, 2'd2}: v = $signed(iDUT.u_pe_array.g_pe_row[1].g_pe_col[2].u_pe.psum_out);
                {2'd1, 2'd3}: v = $signed(iDUT.u_pe_array.g_pe_row[1].g_pe_col[3].u_pe.psum_out);
                {2'd2, 2'd0}: v = $signed(iDUT.u_pe_array.g_pe_row[2].g_pe_col[0].u_pe.psum_out);
                {2'd2, 2'd1}: v = $signed(iDUT.u_pe_array.g_pe_row[2].g_pe_col[1].u_pe.psum_out);
                {2'd2, 2'd2}: v = $signed(iDUT.u_pe_array.g_pe_row[2].g_pe_col[2].u_pe.psum_out);
                {2'd2, 2'd3}: v = $signed(iDUT.u_pe_array.g_pe_row[2].g_pe_col[3].u_pe.psum_out);
                {2'd3, 2'd0}: v = $signed(iDUT.u_pe_array.g_pe_row[3].g_pe_col[0].u_pe.psum_out);
                {2'd3, 2'd1}: v = $signed(iDUT.u_pe_array.g_pe_row[3].g_pe_col[1].u_pe.psum_out);
                {2'd3, 2'd2}: v = $signed(iDUT.u_pe_array.g_pe_row[3].g_pe_col[2].u_pe.psum_out);
                {2'd3, 2'd3}: v = $signed(iDUT.u_pe_array.g_pe_row[3].g_pe_col[3].u_pe.psum_out);
                default:      v = '0;
            endcase
            $fwrite(log_fd, "%10d", v);
        end
        $fdisplay(log_fd, "");
    end
    $fdisplay(log_fd, "");
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
        ret = $fscanf(fd, " %d %d %d\n", c, ch, val);
        if (ret == 3 && r < IMG_H && c < IMG_W && ch < IN_CH)
            image[r][c][ch] = val[DATA_W-1:0];
    end
    $fclose(fd);
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
        ret = $fscanf(fd, " %d %d %d\n", kc, ch, val);
        if (ret == 3 && kr < K && kc < K && ch < IN_CH)
            kern[kr][kc][ch] = val[WEIGHT_W-1:0];
    end
    $fclose(fd);
endtask

initial begin
    int i, s, ci;
    int row_base, col;
    int kc_f, ch_f;
    int shift_cycle;
    logic signed [ACC_W-1:0] pshift_p0 [0:9];
    logic signed [ACC_W-1:0] pshift_p1 [0:9];

    logic [DATA_W-1:0] h0f [0:7];
    logic [DATA_W-1:0] h1f [0:7];
    logic [DATA_W-1:0] h0h1 [0:3];
    logic [DATA_W-1:0] h1h1 [0:3];
    int vsh_kr [0:5];
    int vsh_kc [0:5];

    rst_n=0; start=0;
    h_in0='0; h_in1='0; v_in0='0; v_in1='0;
    for (ci=0; ci<COLS; ci++) w_in[ci]='0;

    load_image();
    load_kernel();

    log_fd = $fopen("diag_log.txt", "w");
    $fdisplay(log_fd, "============================================");
    $fdisplay(log_fd, "  Zig-zag diagnostic v2");
    $fdisplay(log_fd, "  Image: pixels encoded as (row<<3) | col");
    $fdisplay(log_fd, "  Kernel: all +1");
    $fdisplay(log_fd, "  Expected output pixel values:");
    $fdisplay(log_fd, "    out(0,0)=324  out(0,1)=360  out(0,2)=396");
    $fdisplay(log_fd, "    out(1,0)=612  out(1,1)=648  out(1,2)=684");
    $fdisplay(log_fd, "    out(2,0)=900  out(2,1)=936  out(2,2)=972");
    $fdisplay(log_fd, "============================================");

    @(negedge clk); rst_n = 1;
    repeat(5) @(posedge clk);

    row_base = 0;
    col = 0;

    vsh_kr[0]=1; vsh_kc[0]=0;
    vsh_kr[1]=1; vsh_kc[1]=1;
    vsh_kr[2]=1; vsh_kc[2]=2;
    vsh_kr[3]=2; vsh_kc[3]=0;
    vsh_kr[4]=2; vsh_kc[4]=1;
    vsh_kr[5]=2; vsh_kc[5]=2;

    for (i=0; i<8; i++) begin
        kc_f = (i<4) ? 0 : 1;
        ch_f = i % IN_CH;
        h0f[i] = image[row_base  ][col+kc_f][ch_f];
        h1f[i] = image[row_base+1][col+kc_f][ch_f];
    end
    for (i=0; i<4; i++) begin
        h0h1[i] = image[row_base  ][col+2][i];
        h1h1[i] = image[row_base+1][col+2][i];
    end

    zero_inputs();
    start = 1;
    @(posedge clk);
    start = 0;

    zero_inputs();
    @(posedge clk);

    for (i=0; i<8; i++) begin
        h_in0 = h0f[i]; h_in1 = h1f[i];
        v_in0='0; v_in1='0;
        for (ci=0; ci<COLS; ci++) w_in[ci]='0;
        @(posedge clk);
    end

    do_compute_round(0, 0);

    for (i=0; i<4; i++) begin
        h_in0 = h0h1[i]; h_in1 = h1h1[i];
        v_in0='0; v_in1='0;
        for (ci=0; ci<COLS; ci++) w_in[ci]='0;
        @(posedge clk);
    end

    do_compute_round(0, 1);

    for (i=0; i<4; i++) begin zero_inputs(); @(posedge clk); end

    do_compute_round(0, 2);

    for (s=0; s<6; s++) begin
        for (i=0; i<4; i++) begin
            h_in0='0; h_in1='0;
            v_in0 = image[row_base + vsh_kr[s]][col + vsh_kc[s]][i];
            v_in1 = image[row_base + vsh_kr[s]][col + vsh_kc[s]][i];
            for (ci=0; ci<COLS; ci++) w_in[ci]='0;
            @(posedge clk);
        end
        do_compute_round(vsh_kr[s], vsh_kc[s]);
    end

    $fdisplay(log_fd, ">>> SNAPSHOT: PE state at start of PSUM_SHIFT");
    snapshot_all_pes();

    $fdisplay(log_fd, "=== psum_out during PSUM_SHIFT ===");
    $fdisplay(log_fd, "cycle  psum_out0   psum_out1   done");
    zero_inputs();
    for (shift_cycle=0; shift_cycle<10; shift_cycle++) begin
        pshift_p0[shift_cycle] = $signed(psum_out0);
        pshift_p1[shift_cycle] = $signed(psum_out1);
        $fdisplay(log_fd, "  %0d    %8d    %8d     %b",
                  shift_cycle, pshift_p0[shift_cycle], pshift_p1[shift_cycle], done);
        @(posedge clk);
        zero_inputs();
    end

    $fdisplay(log_fd, "");
    $fdisplay(log_fd, "=== Analysis key ===");
    $fdisplay(log_fd, "  324 = out(0,0)   360 = out(0,1)   396 = out(0,2)");
    $fdisplay(log_fd, "  612 = out(1,0)   648 = out(1,1)   684 = out(1,2)");
    $fdisplay(log_fd, "  900 = out(2,0)   936 = out(2,1)   972 = out(2,2)");

    $fclose(log_fd);
    $display("Diagnostic complete. See diag_log.txt");
    $finish;
end

endmodule