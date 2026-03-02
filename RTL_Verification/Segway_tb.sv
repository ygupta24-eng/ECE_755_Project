module Segway_tb();

    import tb_tasks::*; // import tasks package

    //// Interconnects to DUT/support defined as type wire /////
    wire SS_n,SCLK,MOSI,MISO,INT;				// to inertial sensor
    wire A2D_SS_n,A2D_SCLK,A2D_MOSI,A2D_MISO;	// to A2D converter
    wire RX_TX;
    wire PWM1_rght, PWM2_rght, PWM1_lft, PWM2_lft;
    wire piezo,piezo_n;
    logic cmd_sent;
    wire rst_n;					// synchronized global reset

    ////// Stimulus is declared as type reg ///////
    reg clk, RST_n;
    reg [7:0] cmd;				// command host is sending to DUT
    reg send_cmd;				// asserted to initiate sending of command
    reg signed [15:0] rider_lean;
    reg [11:0] ld_cell_lft, ld_cell_rght, steerPot, batt;	// A2D values
    reg OVR_I_lft, OVR_I_rght;

    // internal signals
    int test_case; // to track current test case number for debugging

    ////////////////////////////////////////////////////////////////
    // Instantiate Physical Model of Segway with Inertial sensor //
    //////////////////////////////////////////////////////////////	
    SegwayModel iPHYS(.clk(clk),.RST_n(RST_n),.SS_n(SS_n),.SCLK(SCLK),
                    .MISO(MISO),.MOSI(MOSI),.INT(INT),.PWM1_lft(PWM1_lft),
                    .PWM2_lft(PWM2_lft),.PWM1_rght(PWM1_rght),
                    .PWM2_rght(PWM2_rght),.rider_lean(rider_lean));				  

    /////////////////////////////////////////////////////////
    // Instantiate Model of A2D for load cell and battery //
    ///////////////////////////////////////////////////////
    ADC128S_FC iA2D(.clk(clk),.rst_n(RST_n),.SS_n(A2D_SS_n),.SCLK(A2D_SCLK),
                .MISO(A2D_MISO),.MOSI(A2D_MOSI),.ld_cell_lft(ld_cell_lft),.ld_cell_rght(ld_cell_rght),
                .steerPot(steerPot),.batt(batt));			
        
    ////// Instantiate DUT ////////
    Segway iDUT(.clk(clk),.RST_n(RST_n),.INERT_SS_n(SS_n),.INERT_MOSI(MOSI),
                .INERT_SCLK(SCLK),.INERT_MISO(MISO),.INERT_INT(INT),.A2D_SS_n(A2D_SS_n),
                .A2D_MOSI(A2D_MOSI),.A2D_SCLK(A2D_SCLK),.A2D_MISO(A2D_MISO),
                .PWM1_lft(PWM1_lft),.PWM2_lft(PWM2_lft),.PWM1_rght(PWM1_rght),
                .PWM2_rght(PWM2_rght),.OVR_I_lft(OVR_I_lft),.OVR_I_rght(OVR_I_rght),
                .piezo_n(piezo_n),.piezo(piezo),.RX(RX_TX));

    //// Instantiate UART_tx (mimics command from BLE module) //////
    UART_tx iTX(.clk(clk),.rst_n(rst_n),.TX(RX_TX),.trmt(send_cmd),.tx_data(cmd),.tx_done(cmd_sent));

    /////////////////////////////////////
    // Instantiate reset synchronizer //
    ///////////////////////////////////
    rst_synch iRST(.clk(clk),.RST_n(RST_n),.rst_n(rst_n));


    initial begin

        ///////////////////////////////////////////////////
        //      Test Sequence 1: Powering On and Off     //
        ///////////////////////////////////////////////////

        $display("Starting Powering On and Off Tests...\n");

        test_case = 0;

        // initialize signals for new test sequence
        initialize_signals(clk, RST_n, cmd, send_cmd,
                            rider_lean, ld_cell_lft, ld_cell_rght,
                            steerPot, batt, OVR_I_lft, OVR_I_rght);
        reset_dut(clk, RST_n);
        $display("\n"); // spacing

        ///////////////////////////////////////////////////
        //         Test 1: Power ON                      //
        ///////////////////////////////////////////////////

        increase_test_case(test_case);
        $display("Test 1: Power ON without rider");
        wait_cycles(clk, 100000);
        pwr_on(clk, cmd, send_cmd, cmd_sent);
        wait_cycles(clk, 100000);
        check_pwr_state(iDUT.iAuth.pwr_up, 1'b1);
        $display("Test 1 completed.\n");

        ///////////////////////////////////////////////////
        //         Test 2: Rider steps on platform       //
        ///////////////////////////////////////////////////

        increase_test_case(test_case);
        $display("Test 2: Power ON with rider");
        wait_cycles(clk, 100000);
        step_on_platform(clk, ld_cell_lft, ld_cell_rght, 12'd1000, 12'd1000);
        wait_cycles(clk, 100000);
        check_rider_state(iDUT.iSTR.rider_off, 1'b0);
        wait_cycles(clk, 100000);
        // steering should be enabled now
        check_steer_en(iDUT.iSTR.en_steer, 1'b1);
        $display("Test 2 completed.\n");

        ///////////////////////////////////////////////////
        //         Test 3: Power OFF with rider ON       //
        ///////////////////////////////////////////////////

        increase_test_case(test_case);
        $display("Test 3: Power OFF with rider ON");
        wait_cycles(clk, 100000);
        pwr_off(clk, cmd, send_cmd, cmd_sent);
        wait_cycles(clk, 100000);
        // power should remain on since rider is still on
        check_pwr_state(iDUT.iAuth.pwr_up, 1'b1);
        $display("Test 3 completed.\n");

        ///////////////////////////////////////////////////
        //      Test 4: Power ON after powering OFF      //
        ///////////////////////////////////////////////////

        increase_test_case(test_case);
        $display("Test 4: Power ON after powering OFF");
        wait_cycles(clk, 100000);
        pwr_on(clk, cmd, send_cmd, cmd_sent);
        wait_cycles(clk, 100000);
        check_pwr_state(iDUT.iAuth.pwr_up, 1'b1);
        $display("Test 4 completed.\n");

        ///////////////////////////////////////////////////
        //       Test 5: Power OFF with rider OFF        //
        ///////////////////////////////////////////////////

        increase_test_case(test_case);
        $display("Test 5: Power OFF with rider OFF");
        wait_cycles(clk, 100000);
        step_off_platform(clk, ld_cell_lft, ld_cell_rght);
        wait_cycles(clk, 100000);
        check_rider_state(iDUT.iSTR.rider_off, 1'b1);
        pwr_off(clk, cmd, send_cmd, cmd_sent);
        wait_cycles(clk, 100000);
        check_pwr_state(iDUT.iAuth.pwr_up, 1'b0);
        $display("Test 5 completed.\n");


        ///////////////////////////////////////////////////
        //         Test Sequence 2: Driving              //
        ///////////////////////////////////////////////////

        $display("Starting Driving Tests...\n");

        // Power ON segway
        wait_cycles(clk, 100000);
        pwr_on(clk, cmd, send_cmd, cmd_sent);
        step_on_platform(clk, ld_cell_lft, ld_cell_rght, 12'd1000, 12'd1000);
        wait_cycles(clk, 100000);
        $display("\n"); // spacing

        ///////////////////////////////////////////////////
        //        Test 6: Leaning forward                //
        ///////////////////////////////////////////////////

        increase_test_case(test_case);
        $display("Test 6: Leaning forward");
        wait_cycles(clk, 350000);
        apply_lean(clk, rider_lean, 16'sh0FFF);
        wait_cycles(clk, 1000000);
        check_ptch(iDUT.iBAL.ptch, 16'sh0000);
        apply_lean(clk, rider_lean, 16'sh0000);
        wait_cycles(clk, 1000000);
        check_ptch(iDUT.iBAL.ptch, 16'sh0000);
        $display("Test 6 completed.\n");

        /////////////////////////////////////////////////
        //         Test 7: Leaning back                //
        /////////////////////////////////////////////////

        increase_test_case(test_case);
        $display("Test 7: Leaning back");
        wait_cycles(clk, 350000);
        gradually_decrease_lean(clk, rider_lean, 16'shF000);
        wait_cycles(clk, 1000000);
        check_ptch(iDUT.iBAL.ptch, 16'sh0000);
        $display("Test 7 completed.\n");

        ///////////////////////////////////////////////////
        //         Test Sequence 3: Steering             //
        ///////////////////////////////////////////////////

        $display("Starting Steering Tests...\n");

        ///////////////////////////////////////////////////
        //           Test 8: Steering Left               //
        ///////////////////////////////////////////////////

        increase_test_case(test_case);
        $display("Test 8: Steering Left");
        wait_cycles(clk, 350000);
        apply_lean(clk, rider_lean, 16'sh0FFF);
        wait_cycles(clk, 1000000);
        gradually_decrease_steer(clk, steerPot, 12'h000); // turn left
        wait_cycles(clk, 1000000);
        // verify right motor speed is higher than left motor speed
        check_motor_speeds(iDUT.iBAL.lft_spd, iDUT.iBAL.rght_spd, 1'b0);
        $display("Test 8 completed.\n");

        ///////////////////////////////////////////////////
        //           Test 9: Steering Right             //
        ///////////////////////////////////////////////////

        increase_test_case(test_case);
        $display("Test 9: Steering Right");
        wait_cycles(clk, 350000);
        apply_lean(clk, rider_lean, 16'sh0FFF);
        wait_cycles(clk, 1000000);
        gradually_increase_steer(clk, steerPot, 12'hFFF); // turn right
        wait_cycles(clk, 1000000);
        // verify left motor speed is higher than right motor speed
        check_motor_speeds(iDUT.iBAL.lft_spd, iDUT.iBAL.rght_spd, 1'b1);
        $display("Test 9 completed.\n");

        ///////////////////////////////////////////////////
        //                Test 10: Too fast              //
        ///////////////////////////////////////////////////

        increase_test_case(test_case);
        $display("Test 10: Too fast condition");
        wait_cycles(clk, 350000);
        gradually_increase_lean(clk, rider_lean, 16'sh4FFF);
        wait_cycles(clk, 10000);
        gradually_decrease_steer(clk, steerPot, 12'h000); 
        wait_cycles(clk, 10000);
        apply_lean(clk, rider_lean, 16'sh7FFF);
        check_too_fast(clk, iDUT.iBAL.too_fast);
        $display("Test 10 completed.\n");

        ///////////////////////////////////////////////////
        //       Test Sequence 4: Corner Cases           //
        ///////////////////////////////////////////////////

        $display("Starting Corner Cases Tests...\n");

        reset_dut(clk, RST_n);

        // Power ON segway
        wait_cycles(clk, 100000);
        pwr_on(clk, cmd, send_cmd, cmd_sent);
        wait_cycles(clk, 100000);
        step_on_platform(clk, ld_cell_lft, ld_cell_rght, 12'd1000, 12'd1000);
        $display("\n"); // spacing

        ///////////////////////////////////////////////////
        //        Test 11: Overcurrent Condition         //
        ///////////////////////////////////////////////////

        increase_test_case(test_case);
        $display("Test 11: Overcurrent Condition");
        wait_cycles(clk, 200000);
        set_OVR_I(OVR_I_lft, OVR_I_rght, 1'b1, 1'b1);
        wait_cycles(clk, 200000);
        check_overcurrent(iDUT.iDRV.OVR_I_shtdwn, 1'b1);
        set_OVR_I(OVR_I_lft, OVR_I_rght, 1'b0, 1'b0);
        $display("Test 11 completed.\n");
 
        ///////////////////////////////////////////////////
        //        Test 12: Low Battery Condition         //
        ///////////////////////////////////////////////////
       
        increase_test_case(test_case);
        $display("Test 12: Low Battery Condition");
        set_batt(batt, 12'h710);
        wait_cycles(clk, 200000);
        check_batt_low(iDUT.batt_low, 1'b1);
        set_batt(batt, 12'h810);
        $display("Test 12 completed.\n");

        //////////////////////////////////////////////////
        //           Test 13: Rider falling off         //
        //////////////////////////////////////////////////

        increase_test_case(test_case);
        $display("Test 13: Rider falling off");
        wait_cycles(clk, 1000000);
        step_off_platform(clk, ld_cell_lft, ld_cell_rght);
        wait_cycles(clk, 100000);
        check_rider_state(iDUT.iSTR.rider_off, 1'b1); // rider off should be asserted
        check_steer_en(iDUT.iSTR.en_steer, 1'b0); // steering should be disabled
        check_pwr_state(iDUT.iAuth.pwr_up, 1'b1); // power should still be on
        wait_cycles(clk, 100000);
        $display("Test 13 completed.\n");

        ///////////////////////////////////////////////////
        //           Test 14: Unbalanced rider           //
        ///////////////////////////////////////////////////

        increase_test_case(test_case);
        $display("Test 14: Unbalanced rider");
        wait_cycles(clk, 1000000);
        step_on_platform(clk, ld_cell_lft, ld_cell_rght, 12'd0000, 12'd1000); // unbalanced
        wait_cycles(clk, 100000);
        check_rider_state(iDUT.iSTR.rider_off, 1'b0); // min weight for rider, so rider_off should be deasserted
        check_steer_en(iDUT.iSTR.en_steer, 1'b0); // steering should be disabled due to unbalanced rider
        check_pwr_state(iDUT.iAuth.pwr_up, 1'b1); // power should still be on
        wait_cycles(clk, 100000);
        step_on_platform(clk, ld_cell_lft, ld_cell_rght, 12'd937, 12'd1000); // less than 15/16 difference
        wait_cycles(clk, 1500000); // wait for steering enable timer to expire
        check_steer_en(iDUT.iSTR.en_steer, 1'b1); // steering should now be enabled
        $display("Test 14 completed.\n");


        $display("All tests completed successfully.");
        $stop();
    end

    always
        #10 clk = ~clk;
endmodule	
