module control_tb;

    logic clk;
    logic rst_n;
    logic start;
    logic done;

    // Instantiate the control module
    zigzag_fsm u_control (
        .clk   (clk),
        .rst_n (rst_n),
        .start (start),
        .done  (done)
    );

    // Clock generation
    always 
        #5 clk = ~clk; // 100MHz clock
    

    initial begin
        // Initialize signals
        clk = 0;
        rst_n = 0;
        start = 0;

        // Reset the system
        @(negedge clk);
        rst_n = 1;
        start = 1;

        @(negedge clk);
        start = 0;
        
        //generate posedges until done is high
        repeat (100) begin
            @(posedge clk);
            if (done) begin
                $display("Test passed: done signal is high.");
                $stop();
            end
        end
    end

endmodule