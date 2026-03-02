package tb_tasks;

    localparam PWR_ON = 8'h47; // ASCII 'G'
    localparam PWR_OFF = 8'h53; // ASCII 'S'
    localparam FULL_BATT = 12'hFFF;
    localparam PTCH_TOLERANCE = 3;
    localparam STEER_CENTER = 12'h7FF;


    ////////////////////////////////////////////////
    //             Initialization Tasks           //
    ////////////////////////////////////////////////

    task automatic initialize_signals(ref logic clk, ref logic RST_n, ref logic [7:0] cmd, ref logic send_cmd,
                                    ref logic signed [15:0] rider_lean, ref logic [11:0] ld_cell_lft, ref logic [11:0] ld_cell_rght,
                                    ref logic [11:0] steerPot, ref logic [11:0] batt, ref logic OVR_I_lft, ref logic OVR_I_rght);
        begin
            clk = 1'b0;
            RST_n = 1'b1;
            cmd = 8'h00;
            send_cmd = 1'b0;
            rider_lean = 16'sd0;
            ld_cell_lft = 12'h000;
            ld_cell_rght = 12'h000;
            steerPot = STEER_CENTER;
            batt = FULL_BATT;
            OVR_I_lft = 1'b0;
            OVR_I_rght = 1'b0;
            $display("Signals initialized to default values.");
        end
    endtask

    task automatic reset_dut(ref logic clk, ref logic RST_n);
        begin
            RST_n = 1'b0;
            repeat(10) @(posedge clk);
            RST_n = 1'b1;
            $display("Global reset applied.");
        end
    endtask

    task automatic pwr_on(ref logic clk, ref logic [7:0] cmd, ref logic send_cmd, ref logic cmd_sent);
        begin
            @(posedge clk);
            cmd = PWR_ON;
            send_cmd = 1'b1;
            @(posedge clk);
            send_cmd = 1'b0;
            @(posedge cmd_sent);
            repeat(100) @(posedge clk); 
            $display("Power ON command sent to Segway.");
        end
    endtask

    task automatic pwr_off(ref logic clk, ref logic [7:0] cmd, ref logic send_cmd, ref logic cmd_sent);
        begin
            @(posedge clk);
            cmd = PWR_OFF;
            send_cmd = 1'b1;
            @(posedge clk);
            send_cmd = 1'b0;
            @(posedge cmd_sent);
            repeat(100) @(posedge clk); 
            $display("Power OFF command sent to Segway.");
        end
    endtask


    ////////////////////////////////////////////////
    //             Simulation Tasks               //
    ////////////////////////////////////////////////

    task automatic step_on_platform(ref logic clk, ref logic [11:0] ld_cell_lft, ref logic [11:0] ld_cell_rght, input [11:0] weight_lft, input [11:0] weight_right);
        begin
            ld_cell_lft = weight_lft;
            ld_cell_rght = weight_right;
            $display("Rider stepped onto platform with weight left: %0d, right: %0d", weight_lft, weight_right);
            repeat(10) @(posedge clk);
        end
    endtask

    task automatic step_off_platform(ref logic clk, ref logic [11:0] ld_cell_lft, ref logic [11:0] ld_cell_rght);
        begin
            ld_cell_lft = 12'h000;
            ld_cell_rght = 12'h000;
            $display("Rider stepped off the platform.");
            repeat(10) @(posedge clk);
        end
    endtask

    task automatic apply_lean(ref logic clk, ref logic signed [15:0] rider_lean, input logic signed [15:0] lean_value);
        begin
            @(posedge clk);
            rider_lean = lean_value;
            $display("Applied rider lean value: %0d", lean_value);
        end
    endtask

    task automatic gradually_increase_lean(ref logic clk, ref logic signed [15:0] rider_lean, input logic signed [15:0] target_lean_value);
        begin
            @(posedge clk);
            for (int i = 0; i < 100; i++) begin
                rider_lean = rider_lean + ((target_lean_value - rider_lean) >>> 4); 
                repeat(10000) @(posedge clk);
            end
            $display("Rider lean gradually changed to value: %0d", target_lean_value);
        end
    endtask

    task automatic gradually_decrease_lean(ref logic clk, ref logic signed [15:0] rider_lean, input logic signed [15:0] target_lean_value);
        begin
            @(posedge clk);
            for (int i = 0; i < 100; i++) begin
                rider_lean = rider_lean - ((rider_lean - target_lean_value) >>> 4); 
                repeat(10000) @(posedge clk);
            end
            $display("Rider lean gradually changed to value: %0d", target_lean_value);
        end
    endtask

    task automatic gradually_increase_steer(ref logic clk, ref logic [11:0] steerPot, input logic [11:0] target_pot_value);
        begin
            @(posedge clk);
            for (int i = 0; i < 100; i++) begin
                steerPot = steerPot + ((target_pot_value - steerPot) >>> 4); 
                repeat(10000) @(posedge clk);
            end
            $display("Steering potentiometer gradually changed to value: %0d", target_pot_value);
        end
    endtask

    task automatic gradually_decrease_steer(ref logic clk, ref logic [11:0] steerPot, input logic [11:0] target_pot_value);
        begin
            @(posedge clk);
            for (int i = 0; i < 100; i++) begin
                steerPot = steerPot - ((steerPot - target_pot_value) >>> 4); 
                repeat(10000) @(posedge clk);
            end
            $display("Steering potentiometer gradually changed to value: %0d", target_pot_value);
        end
    endtask

    task automatic set_batt(ref reg [11:0] batt, input logic [11:0] batt_value);
        begin
            batt = batt_value;
            $display("Battery level set to: %0d", batt_value);
        end
    endtask
 
    task automatic set_OVR_I(ref reg OVR_I_lft, ref reg OVR_I_rght, input reg OVR_I_lft_value, input reg OVR_I_rght_value);
        begin
            OVR_I_lft = OVR_I_lft_value;
            OVR_I_rght = OVR_I_rght_value;
            $display("Overcurrent signals set to: OVR_I_lft=%0b, OVR_I_rght=%0b", OVR_I_lft_value, OVR_I_rght_value);
        end
    endtask

    ////////////////////////////////////////////////
    //             Simulation Tests               //
    ////////////////////////////////////////////////

    task automatic check_pwr_state(input logic pwr_up, input logic expected_state);
        begin
            if (pwr_up !== expected_state) begin
                $display("ERROR: pwr_up signal = %0b, expected = %0b", pwr_up, expected_state);
                $stop();
            end 
        end
    endtask

    task automatic check_rider_state(input logic rider_off, input logic expected_state);
        begin
            if (rider_off !== expected_state) begin
                $display("ERROR: rider_off signal = %0b, expected = %0b", rider_off, expected_state);
                $stop();
            end 
        end
    endtask

    task automatic check_steer_en(input logic en_steer, input logic expected_state);
        begin
            if (en_steer !== expected_state) begin
                $display("ERROR: en_steer signal = %0b, expected = %0b", en_steer, expected_state);
                $stop();
            end 
        end
    endtask

    task automatic check_ptch(input logic signed [15:0] ptch, input logic signed [15:0] expected_value);
        begin
            if ((ptch < (expected_value - PTCH_TOLERANCE)) || (ptch > (expected_value + PTCH_TOLERANCE))) begin
                $display("ERROR: theta_platform = %0d out of expected range [%0d, %0d]", ptch, expected_value - PTCH_TOLERANCE, expected_value + PTCH_TOLERANCE);
                $stop();
            end 
        end
    endtask

    task automatic check_too_fast(ref logic clk, ref logic too_fast);
        fork
            begin: timeout_check
                repeat(100000) @(posedge clk);
                $display("Error: Test 11 timed out - too_fast signal not asserted.");
                $stop();
            end
            begin
                @(posedge too_fast);
                disable timeout_check;
            end
        join
    endtask

    task automatic check_motor_speeds(input logic signed [11:0] lft_spd, input logic signed [11:0] rght_spd, input logic left_gt_right);
        begin
            if (left_gt_right) begin
                if (lft_spd <= rght_spd) begin
                    $display("ERROR: Left motor speed (%0d) is not greater than right motor speed (%0d) as expected for right turn.", lft_spd, rght_spd);
                    $stop();
                end
            end else begin
                if (rght_spd <= lft_spd) begin
                    $display("ERROR: Right motor speed (%0d) is not greater than left motor speed (%0d) as expected for left turn.", rght_spd, lft_spd);
                    $stop();
                end
            end
        end
    endtask

    task automatic check_batt_low(input logic batt_low, input logic expected_state);
        begin
            if (batt_low !== expected_state) begin
                $display("ERROR: batt_low signal = %0b, expected = %0b", batt_low, expected_state);
                $stop();
            end
        end
    endtask
 
    task automatic check_overcurrent(input logic OVR_I_shtdwn, input logic expected_state);
        begin
            if (OVR_I_shtdwn !== expected_state) begin
                $display("ERROR: OVR_I_shtdwn = %0b, expected = %0b", OVR_I_shtdwn, expected_state);
                $stop();
            end
        end
    endtask

    ////////////////////////////////////////////////
    //             Miscellaneous                  //
    ////////////////////////////////////////////////

    task automatic wait_cycles(ref logic clk, input int num_cycles);
        begin
            repeat(num_cycles) @(posedge clk);
        end
    endtask

    task automatic increase_test_case(ref int test_case);
        begin
            test_case = test_case + 1;
        end
    endtask

endpackage