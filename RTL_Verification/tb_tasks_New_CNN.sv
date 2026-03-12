package tb_tasks;

parameter DATA_W = 8;
parameter ACC_W  = 24;
parameter CH_PAR = 8;


// -------------------------------------------------
// TASK 1 : RESET DUT
// -------------------------------------------------
task automatic reset_dut(

    ref logic clk,
    ref logic rst_n,
    ref logic pe_clk_en,
    ref logic move_en,
    ref logic [1:0] sel_src,
    ref logic w_ld_en,
    ref logic psum_clr,

    ref logic [DATA_W-1:0] act_from_left,
    ref logic [DATA_W-1:0] act_from_right,
    ref logic [DATA_W-1:0] act_from_up,
    ref logic [DATA_W-1:0] act_from_down,

    ref logic [ACC_W-1:0] golden_psum [CH_PAR],
    ref logic [DATA_W-1:0] golden_weights [CH_PAR],
    ref logic [DATA_W-1:0] golden_act

);

begin

    rst_n = 0;
    pe_clk_en = 1;
    move_en = 0;
    sel_src = 0;

    w_ld_en = 0;
    psum_clr = 0;

    act_from_left  = 0;
    act_from_right = 0;
    act_from_up    = 0;
    act_from_down  = 0;

    repeat(2) @(posedge clk);

    rst_n = 1;

    repeat(2) @(posedge clk);

    for(int i=0;i<CH_PAR;i++) begin
        golden_psum[i] = 0;
        golden_weights[i] = 0;
    end

    golden_act = 0;

    $display("RESET DONE");

end
endtask



// -------------------------------------------------
// TASK 2 : LOAD WEIGHTS
// -------------------------------------------------
task automatic load_weights(

    ref logic clk,
    ref logic w_ld_en,

    ref logic [DATA_W-1:0] w_ld_data [CH_PAR],
    ref logic [DATA_W-1:0] w [CH_PAR],
    ref logic [DATA_W-1:0] golden_weights [CH_PAR]

);

begin

    repeat(2) @(posedge clk);

    w_ld_en = 1;

    for(int i=0;i<CH_PAR;i++) begin
        w_ld_data[i] = w[i];
        golden_weights[i] = w[i];
    end

    repeat(2) @(posedge clk);

    w_ld_en = 0;

    $display("WEIGHTS LOADED");

end
endtask



// -------------------------------------------------
// TASK 3 : MOVE ACTIVATION
// -------------------------------------------------
task automatic move_activation(

    ref logic clk,
    ref logic move_en,
    ref logic [1:0] direction,
    ref logic [DATA_W-1:0] data,
    ref logic [1:0] sel_src,

    ref logic [DATA_W-1:0]act_from_left,
    ref logic [DATA_W-1:0]act_from_right,
    ref logic [DATA_W-1:0]act_from_up,
    ref logic [DATA_W-1:0]act_from_down,

    ref logic [DATA_W-1:0] golden_act

);

begin

    repeat(2) @(posedge clk);

    move_en = 1;
    sel_src = direction;

    case(direction)

        2'b00: act_from_left  = data;
        2'b01: act_from_right = data;
        2'b10: act_from_up    = data;
        2'b11: act_from_down  = data;

    endcase

    golden_act = data;

    $display("ACT MOVED dir=%0d data=%0d", direction, data);

end
endtask



// -------------------------------------------------
// TASK 4 : COMPUTE CYCLE
// -------------------------------------------------
task automatic compute_cycle(

    ref logic clk,

    ref logic [ACC_W-1:0] golden_psum [CH_PAR],
    ref logic [DATA_W-1:0] golden_act,
    ref logic [DATA_W-1:0] golden_weights [CH_PAR]

);

begin

    repeat(2) @(posedge clk);

    for(int i=0;i<CH_PAR;i++) begin
        golden_psum[i] += golden_act * golden_weights[i];
    end

end
endtask



// -------------------------------------------------
// TASK 5 : CLEAR PSUM
// -------------------------------------------------
task automatic clear_psum(

    ref logic clk,
    ref logic psum_clr,
    ref logic [ACC_W-1:0] golden_psum [CH_PAR]

);

begin

    repeat(2) @(posedge clk);

    psum_clr = 1;

    repeat(2) @(posedge clk);

    psum_clr = 0;

    for(int i=0;i<CH_PAR;i++)
        golden_psum[i] = 0;

    $display("PSUM CLEARED");

end
endtask



// -------------------------------------------------
// TASK 6 : CHECK PSUM
// -------------------------------------------------
task automatic check_psum(

    ref logic clk,
    ref logic [ACC_W-1:0] psum_out [CH_PAR],
    ref logic [ACC_W-1:0] golden_psum [CH_PAR]

);

begin

    repeat(2) @(posedge clk);

    for(int i=0;i<CH_PAR;i++) begin

        if(psum_out[i] !== golden_psum[i]) begin
            $error("PSUM MISMATCH lane=%0d DUT=%0d GOLD=%0d",
                    i, psum_out[i], golden_psum[i]);
        end

    end

end
endtask



// -------------------------------------------------
// TASK 7 : CLOCK GATING TEST
// -------------------------------------------------
task automatic autotest_clock_gating(

    ref logic clk,
    ref logic pe_clk_en,

    ref logic [ACC_W-1:0] psum_out [CH_PAR],
    ref logic [ACC_W-1:0] golden_psum [CH_PAR]

);

begin

    repeat(2) @(posedge clk);

    pe_clk_en = 0;

    repeat(2) @(posedge clk);

    for(int i=0;i<CH_PAR;i++) begin

        if(psum_out[i] !== golden_psum[i])
            $error("CLOCK GATING FAILED");

    end

    pe_clk_en = 1;

    $display("CLOCK GATING TEST DONE");

end
endtask


endpackage