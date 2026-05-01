module fifo9_tb();

    logic              clk;
    logic              rst_n;
    logic              wr_en;
    logic [12:0]       wr_data;
    logic              full;
    logic              rd_en;
    logic [12:0]       rd_data;
    logic              empty;
 
    fifo9 dut (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .wr_data(wr_data),
        .full(full),
        .rd_en(rd_en),
        .rd_data(rd_data),
        .empty(empty)
    );
    //tasks
    task Initialize();
        begin
            clk = 0;
            rst_n = 0;
            wr_en = 0;
            wr_data = 0;
            rd_en = 0;
            repeat(10) @(negedge clk);
            rst_n = 1;  
            repeat(10) @(negedge clk);
        end
    endtask
    task WriteData(input logic [12:0] data);
        begin
            wr_en = 1;
            wr_data = data;
            @(negedge clk);
            wr_en = 0;
        end
    endtask
    task ReadData();
        begin
            rd_en = 1;
            @(negedge clk);
            rd_en = 0;
        end
    endtask
    task ReadWriteData(input logic [12:0] data);
        begin
            wr_en = 1;
            wr_data = data;
            rd_en = 1;
            @(negedge clk);
            wr_en = 0;
            rd_en = 0;
        end
    endtask
    //end tasks

    //Main Testing
    initial begin
        Initialize();
        if (full === 0 && empty === 1)
            $display("Test 1 passed: FIFO should be empty after reset");
        else
            $error("Test 1 failed: FIFO should be empty after reset");
        repeat(2) @(negedge clk);
        if (rd_data === 'x)
            $display("Test 2 passed: Read data should be unknown when write is not happened");
        else
            $error("Test 2 failed: Read data should be unknown when write is not happened");
        /*/ Write 9 values to fill the FIFO
        for (int i = 0; i < 5; i++) begin
            WriteData(.data(i+11));  // Write values 11 to 15
        end
        if (full === 0 && empty === 0)
            $display("Test 3 passed: FIFO should not be full or empty after 5 writes");
        else
            $error("Test 3 failed: FIFO should not be full or empty after 5 writes");
        repeat(2) @(negedge clk);
        for (int i = 0; i < 5; i++) begin
            ReadData();  // Read values 11 to 15
            if (rd_data === i + 11)
                $display("Test 4.%0d passed: Read data should be %0d", i, i + 11);
            else
                $error("Test 4.%0d failed: Read data should be %0d", i, i + 11);
        end
        repeat(2) @(negedge clk);
        ReadData();  
        if (rd_data === 'x)
            $display("Test 4.5 passed: Read data should be unknown when trying to read from the non written location");
        else
            $error("Test 4.5 failed: attempt to read from non written location should yield unknown data");
        repeat(2) @(negedge clk);
        if (full === 0 && empty === 1)
            $display("Test 5 passed: empty should be asserted after reading all written data");
        else
            $error("Test 5 failed: empty should be asserted after reading all written data");*/
        repeat(2) @(negedge clk);
        for (int i = 0; i < 9; i++) begin
            WriteData(.data(i)); // Write values 0 to 8
        end
        repeat(2) @(negedge clk);
        if (full === 1 && empty === 0)
            $display("Test 6 passed: FIFO should be full after writing 9 values");
        else
            $error("Test 6 failed: FIFO should be full after writing 9 values");
        repeat(2) @(negedge clk);
        for (int i = 0; i < 9; i++) begin
            ReadData();  // Read values 0 to 8
            if (rd_data === i)
                $display("Test 7.%0d passed: Read data should be %0d", i, i);
            else
                $error("Test 7.%0d failed: Read data should be %0d", i, i);
        end
        repeat(2) @(negedge clk);
        if (full === 0 && empty === 1)
            $display("Test 8 passed: FIFO should be empty after reading all data");
        else
            $error("Test 8 failed: FIFO should be empty after reading all data");
        repeat(2) @(negedge clk);
        WriteData(.data(11));
        for (int i = 1; i < 9; i++) begin
            ReadWriteData(.data(i + 11));
            if (rd_data === i + 10)
                $display("Test 9.%0d passed: Read data should be %0d", i, i + 10);
            else
                $error("Test 9.%0d failed: Read data should be %0d", i, i + 10);
        end
        @(negedge clk);
        ReadData();
        if (rd_data === 19)
            $display("Test 9.9 passed: Read data should be 19");
        else
            $error("Test 9.9 failed: Read data should be 19");
        repeat(2) @(negedge clk);
        for (int i = 0; i < 9; i++) begin
            ReadWriteData(.data(i + 30));  // Write values 30 to 38
            if (rd_data === i + 30)
                $display("Test 11.%0d passed: Read data should be %0d", i, i + 30);
            else
                $error("Test 11.%0d failed: Read data should be %0d", i, i + 30);
        end
        repeat(2) @(negedge clk);
        if (full === 0 && empty === 1)
            $display("Test 12 passed: FIFO should be empty after reading all data");
        else
            $error("Test 12 failed: FIFO should be empty after reading all data");
        $display("All tests completed");
        repeat(10) @(negedge clk);
        $stop;
    end

    // Clock generation
    always #5 clk = ~clk; 
endmodule