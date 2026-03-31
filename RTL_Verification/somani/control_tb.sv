module control_tb();

logic clk, rst_n;
logic start, done;

zigzag_fsm iDUT(.clk(clk), .rst_n(rst_n), .start(start), .done(done));

initial begin
    clk   = 0;
    rst_n = 0;
    start = 0;

    // Release reset
    @(negedge clk);
    rst_n = 1;

    // Pulse start
    repeat(5) @(posedge clk);
    start = 1;
    @(posedge clk);
    start = 0;


    repeat(230) @(posedge clk);
    $stop();
    // Wait for completion
    //wait(done);
    //$display("DONE at time %0t", $time);
    //$finish;
end

always #10 clk = ~clk;

endmodule