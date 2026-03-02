package tb_tasks;
    
// -------------------------------------------------
// Initialization of TASKS
// -------------------------------------------------
    parameter DATA_W = 8;
    parameter ACC_W  = 24;
    parameter CH_PAR = 8;

//Task 1: Reset DUT
task automatic reset_dut(ref logic clk, ref logic rst_n, ref logic pe_clk_en, ref logic [1:0] mode, ref logic [1:0] sel_src, ref logic w_ld_en, ref logic psum_clr, ref logic [DATA_W-1:0] w_ld_data [CH_PAR-1:0],
                             ref logic [DATA_W-1:0] act_from_left, ref logic [DATA_W-1:0] act_from_right, ref logic [DATA_W-1:0] act_from_up, ref logic [DATA_W-1:0] act_from_down, ref logic [ACC_W-1:0] golden_psum [CH_PAR-1:0],
                             ref logic [DATA_W-1:0] golden_weights [CH_PAR-1:0], ref logic [DATA_W-1:0] golden_act );
  
    begin
        rst_n = 0;
        pe_clk_en = 1;
        mode = 2'b00;
        sel_src = 2'b00;
        w_ld_en = 0;
        psum_clr = 0;
        act_from_left = '0;
        act_from_right = '0;
        act_from_up = '0;
        act_from_down = '0;
        repeat (2) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        for (int i=0; i<CH_PAR; i++) begin
            golden_psum[i] = 0;
            golden_weights[i] = 0;
        end
        golden_act = 0;

        $display("RESET DONE");
    end
endtask

//Task 2: Load weights
task automatic load_weights(ref logic clk,ref logic w_ld_en, ref logic [DATA_W-1:0] w_ld_data [CH_PAR-1:0], ref logic [DATA_W-1:0] w [CH_PAR-1:0], ref logic [DATA_W-1:0] golden_weights [CH_PAR-1:0]);
        
    begin
        repeat (2) @(posedge clk);
        w_ld_en = 1;
        for (int i=0; i<CH_PAR; i++) begin
            w_ld_data[i] = w[i];
            golden_weights[i] = w[i];
        end
        repeat (2) @(posedge clk);
        w_ld_en = 0;

        $display("WEIGHTS LOADED");
    end
endtask

// Task 3: Forward activation
task automatic move_activation(ref logic clk,ref logic [1:0] direction, ref logic [DATA_W-1:0] data, ref logic mode, ref logic sel_src,
                             ref logic act_from_left, ref logic act_from_right, ref logic act_from_up, ref logic act_from_down, ref logic [DATA_W-1:0] golden_act);
                        
    begin
        repeat (2) @(posedge clk);
        mode = 2'b10;
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


//Task 4: Computation 
task automatic compute_cycle(ref logic clk,ref logic mode, ref logic [ACC_W-1:0] golden_psum [CH_PAR-1:0], ref logic [DATA_W-1:0] golden_act, ref logic [DATA_W-1:0] golden_weights [CH_PAR-1:0], ref logic psum_clr, ref logic [ACC_W-1:0] psum_out [CH_PAR-1:0]);
    begin
        repeat (2) @(posedge clk);
        mode = 2'b01;
        for (int i=0; i<CH_PAR; i++) begin
            golden_psum[i] += golden_act * golden_weights[i];
        end

    end
endtask

// Task 5: Clear PSUM
task automatic clear_psum(ref logic clk,ref logic psum_clr, ref logic [ACC_W-1:0] golden_psum [CH_PAR-1:0], ref logic [ACC_W-1:0] psum_out [CH_PAR-1:0]);
    begin
        repeat (2) @(posedge clk);
        psum_clr = 1;
        repeat (2) @(posedge clk);
        psum_clr = 0;

        for (int i=0; i<CH_PAR; i++)
            golden_psum[i] = 0;

        $display("PSUM CLEARED");
    end
endtask

// Task 6: Check PSUM output
task automatic check_psum(ref logic clk, ref logic [ACC_W-1:0] psum_out [CH_PAR-1:0], ref logic [ACC_W-1:0] golden_psum [CH_PAR-1:0]);
    begin
        repeat (2) @(posedge clk);
        for (int i=0; i<CH_PAR; i++) begin
            if (psum_out[i] !== golden_psum[i]) begin
                $error("PSUM MISMATCH lane=%0d DUT=%0d GOLD=%0d",
                        i, psum_out[i], golden_psum[i]);
            end
        end
    end
endtask

// Task 7: Test clock gating (ensure no changes to PSUM when pe_clk_en=0)
task automatic autotest_clock_gating(ref logic clk,ref logic pe_clk_en, ref logic mode, ref logic [ACC_W-1:0] psum_out [CH_PAR-1:0], ref logic [ACC_W-1:0] golden_psum [CH_PAR-1:0] );
    begin
        repeat (2) @(posedge clk);
        pe_clk_en = 0;
        mode = 2'b01;
        repeat (2) @(posedge clk);

        for (int i=0; i<CH_PAR; i++) begin
            if (psum_out[i] !== golden_psum[i])
                $error("Clock gating failed!");
        end

        pe_clk_en = 1;
        mode = 2'b00;
        $display("CLOCK GATING TEST DONE");
    end 
endtask

endpackage