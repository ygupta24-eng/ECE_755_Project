module top_tb #(
    parameter int DATA_W   = 6,
    parameter int WEIGHT_W = 2,
    parameter int ACC_W    = 13,
    parameter int ROWS     = 4,
    parameter int COLS     = 4,
    parameter int UNQ_DIR  = 4
)();

logic clk, rst_n;
logic start, done;

// Horizontal boundary inputs
logic [DATA_W-1:0]   h_in0;
logic [DATA_W-1:0]   h_in1;

// Vertical boundary inputs
logic [DATA_W-1:0]   v_in0;
logic [DATA_W-1:0]   v_in1;

// Weight inputs — one per column, chains down rows
logic [WEIGHT_W-1:0] w_in [0:COLS-1];

// psum drain outputs
logic [ACC_W-1:0]    psum_out0;  // PE10
logic [ACC_W-1:0]    psum_out1;  // PE30


top #(
    .DATA_W   (DATA_W),
    .WEIGHT_W (WEIGHT_W),
    .ACC_W    (ACC_W),
    .ROWS     (ROWS),
    .COLS     (COLS),
    .UNQ_DIR  (UNQ_DIR)
) iDUT (
    .clk(clk), .rst_n(rst_n), .start(start), .done(done),
    .h_in0(h_in0), .h_in1(h_in1),
    .v_in0(v_in0), .v_in1(v_in1),
    .w_in(w_in),
    .psum_out0(psum_out0), .psum_out1(psum_out1)
);

logic [DATA_W-1:0] v1_store [0:4];

initial begin
    // Initialize everything
    clk   = 0;
    rst_n = 0;
    start = 0;

    h_in0 = '0;
    h_in1 = '0;
    v_in0 = '0;
    v_in1 = '0;

    // Initialize weights to 0
    foreach (w_in[i]) w_in[i] = '0;

    // Release reset
    @(negedge clk);
    rst_n = 1;

    // Pulse start → enter FILL
    repeat(5) @(posedge clk);
    start = 1;


    // channel in sequence 1,2,3,4
    // pe33 : channel 4, pe32 : channel 1, pe23 : channel 3, pe22 : channel 2

    // -----------------------------
    // FILL STAGE: drive activations
    // -----------------------------
    for (int i = 0; i < 8; i++) begin
        @(posedge clk);
        if(i==0) start = 0;

        // Always drive activations during FILL
        h_in0 = $urandom_range(1, 255);
        h_in1 = $urandom_range(1, 255);

        // During LAST 4 cycles of FILL, also drive weights
        if (i >= 4) begin
            w_in[0] = -1;
            w_in[1] = -1;
            w_in[2] = -1;
            w_in[3] = -1;
        end else begin
            // No weight load in first 4 cycles
            w_in[0] = '0;
            w_in[1] = '0;
            w_in[2] = '0;
            w_in[3] = '0;
        end
    end

    // CLEAR STATE
    // Stop driving activations and weights after FILL
    @(posedge clk);
    h_in0 = '0;
    h_in1 = '0;

    // 2nd W_LOAD , 1st compute overlaps with 2nd weight load
    repeat(4) begin   
        w_in[0] = 1;
        w_in[1] = 1;
        w_in[2] = 1;
        w_in[3] = 1;
        @(posedge clk);
    end

    // 3rd W_LOAD , 2nd compute overlaps with 3rd weight load
    repeat(4) begin         
        w_in[0] = -1;
        w_in[1] = -1;
        w_in[2] = -1;
        w_in[3] = -1;
        @(posedge clk);
    end
    
    // 4th W_LOAD , 3rd compute overlaps with 4th weight load
    repeat(4) begin     
        w_in[0] = 1;
        w_in[1] = 1;
        w_in[2] = 1;
        w_in[3] = 1; 
        @(posedge clk); 
    end

    ////////////////////////////////////////////////////////////////////////
    /////////////////////////// 2nd pixel /////////////////////////////////
    /////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////
    /////// Horizontal shift //////////////
    //////////////////////////////////////

    // channel in sequence 1,2,3,4
    // pe33 : channel 4, pe32 : channel 1, pe23 : channel 3, pe22 : channel 2

    for (int i = 0; i < 5; i++) begin
        //1st is compute with 1 weight load
        // next 4 are horizontal shift with 3 weight loads (overlapping) 
        @(posedge clk);

        // During LAST 4 cycles of FILL, also drive weights
        if (i < 4) begin
            w_in[0] = -1;
            w_in[1] = -1;
            w_in[2] = -1;
            w_in[3] = -1;
        end
        if(i > 0) begin
            h_in0 = $urandom_range(1, 255);
            h_in1 = $urandom_range(1, 255);
        end
    end

    // 2nd W_LOAD , 1st compute overlaps with 2nd weight load
    repeat(4) begin   
        w_in[0] = 1;
        w_in[1] = 1;
        w_in[2] = 1;
        w_in[3] = 1;
        @(posedge clk);
        h_in0 = '0;
        h_in1 = '0;
    end

    // 3rd W_LOAD , 2nd compute overlaps with 3rd weight load
    repeat(4) begin   
        w_in[0] = -1;
        w_in[1] = -1;
        w_in[2] = -1;
        w_in[3] = -1;
        @(posedge clk);
    end

    // 4th W_LOAD , 3rd compute overlaps with 4th weight load
    repeat(4) begin   
        w_in[0] = 1;
        w_in[1] = 1;
        w_in[2] = 1;
        w_in[3] = 1;
        @(posedge clk);
    end

    ////////////////////////////////////////////////////////////////////////
    /////////////////////////// 3rd pixel /////////////////////////////////
    /////////////////////////////////////////////////////////////////////
    
    ///////////////////////////////////////
    /////// Horizontal shift //////////////
    //////////////////////////////////////

    // channel in sequence 1,2,3,4
    // pe33 : channel 4, pe32 : channel 1, pe23 : channel 3, pe22 : channel 2

    for (int i = 0; i < 5; i++) begin
        //1st is compute with 1 weight load
        // next 4 are horizontal shift with 3 weight loads (overlapping) 
        @(posedge clk);

        // During LAST 4 cycles of FILL, also drive weights
        if (i < 4) begin
            w_in[0] = -1;
            w_in[1] = -1;
            w_in[2] = -1;
            w_in[3] = -1;
        end
        if(i > 0) begin
            h_in0 = $urandom_range(1, 255);
            h_in1 = $urandom_range(1, 255);
        end
    end

    // 2nd W_LOAD , 1st compute overlaps with 2nd weight load
    repeat(4) begin   
        w_in[0] = 1;
        w_in[1] = 1;
        w_in[2] = 1;
        w_in[3] = 1;
        @(posedge clk);
        h_in0 = '0;
        h_in1 = '0;
    end

    // 3rd W_LOAD , 2nd compute overlaps with 3rd weight load
    repeat(4) begin   
        w_in[0] = -1;
        w_in[1] = -1;
        w_in[2] = -1;
        w_in[3] = -1;
        @(posedge clk);
    end

    // 4th W_LOAD , 3rd compute overlaps with 4th weight load
    repeat(4) begin   
        w_in[0] = 1;
        w_in[1] = 1;
        w_in[2] = 1;
        w_in[3] = 1;
        @(posedge clk);
    end


    ////////////////////////////////////////////////////////////////////////
    /////////////////////////// 4th pixel /////////////////////////////////
    ///////////////////////////////////////////////////////////////////////
    
    ///////////////////////////////////////
    /////// Vertical shift //////////////
    //////////////////////////////////////

    // channel in sequence 1,2,3,4
    // pe33 : channel 3, pe32 : channel 4, pe23 : channel 2, pe22 : channel 1

    for (int i = 0; i < 5; i++) begin
        //1st is compute with 1 weight load
        // next 4 are horizontal shift with 3 weight loads (overlapping) 
        @(posedge clk);

        // During LAST 4 cycles of FILL, also drive weights
        if (i < 4) begin
            w_in[0] = -1;
            w_in[1] = -1;
            w_in[2] = -1;
            w_in[3] = -1;
        end
        if(i > 0) begin
            v_in0 = $urandom_range(1, 255);
            v_in1 = $urandom_range(1, 255);
            
            v1_store[i] = v_in1;   // store the value for reuse
        end
    end

    // 2nd W_LOAD , 1st compute overlaps with 2nd weight load
    repeat(4) begin   
        w_in[0] = 1;
        w_in[1] = 1;
        w_in[2] = 1;
        w_in[3] = 1;
        @(posedge clk);
        v_in0 = '0;
        v_in1 = '0;
    end

    // 3rd W_LOAD , 2nd compute overlaps with 3rd weight load
    repeat(4) begin   
        w_in[0] = -1;
        w_in[1] = -1;
        w_in[2] = -1;
        w_in[3] = -1;
        @(posedge clk);
    end

    // 4th W_LOAD , 3rd compute overlaps with 4th weight load
    repeat(4) begin   
        w_in[0] = 1;
        w_in[1] = 1;
        w_in[2] = 1;
        w_in[3] = 1;
        @(posedge clk);
    end

    ////////////////////////////////////////////////////////////////////////
    /////////////////////////// 5th pixel /////////////////////////////////
    ///////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////
    /////// Vertical shift //////////////
    //////////////////////////////////////

    // channel in sequence 1,2,3,4
    // pe33 : channel 3, pe32 : channel 4, pe23 : channel 2, pe22 : channel 1

    for (int i = 0; i < 5; i++) begin
        //1st is compute with 1 weight load
        // next 4 are horizontal shift with 3 weight loads (overlapping) 
        @(posedge clk);

        // During LAST 4 cycles of FILL, also drive weights
        if (i < 4) begin
            w_in[0] = -1;
            w_in[1] = -1;
            w_in[2] = -1;
            w_in[3] = -1;
        end
        if(i > 0) begin
            v_in0 = v1_store[i];   // reuse 4th pixel’s v_in1
            v_in1 = $urandom_range(1, 255);
            
            v1_store[i-1] = v_in1;   // store the value for reuse
        end
    end

    // 2nd W_LOAD , 1st compute overlaps with 2nd weight load
    repeat(4) begin   
        w_in[0] = 1;
        w_in[1] = 1;
        w_in[2] = 1;
        w_in[3] = 1;
        @(posedge clk);
        v_in0 = '0;
        v_in1 = '0;
    end

    // 3rd W_LOAD , 2nd compute overlaps with 3rd weight load
    repeat(4) begin   
        w_in[0] = -1;
        w_in[1] = -1;
        w_in[2] = -1;
        w_in[3] = -1;
        @(posedge clk);
    end

    // 4th W_LOAD , 3rd compute overlaps with 4th weight load
    repeat(4) begin   
        w_in[0] = 1;
        w_in[1] = 1;
        w_in[2] = 1;
        w_in[3] = 1;
        @(posedge clk);
    end

    ////////////////////////////////////////////////////////////////////////
    /////////////////////////// 6th pixel /////////////////////////////////
    ///////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////
    /////// Vertical shift //////////////
    //////////////////////////////////////

    // channel in sequence 2,3,4,1
    // pe33 : channel 4, pe32 : channel 1, pe23 : channel 3, pe22 : channel 2

    for (int i = 0; i < 5; i++) begin
        //1st is compute with 1 weight load
        // next 4 are horizontal shift with 3 weight loads (overlapping) 
        @(posedge clk);

        // During LAST 4 cycles of FILL, also drive weights
        if (i < 4) begin
            w_in[0] = -1;
            w_in[1] = -1;
            w_in[2] = -1;
            w_in[3] = -1;
        end
        if(i > 0) begin
            v_in0 = v1_store[(i)%4];   // reuse 4th pixel’s v_in1
            v_in1 = $urandom_range(1, 255);
        end
    end

    // 2nd W_LOAD , 1st compute overlaps with 2nd weight load
    repeat(4) begin   
        w_in[0] = 1;
        w_in[1] = 1;
        w_in[2] = 1;
        w_in[3] = 1;
        @(posedge clk);
        v_in0 = '0;
        v_in1 = '0;
    end

    // 3rd W_LOAD , 2nd compute overlaps with 3rd weight load
    repeat(4) begin   
        w_in[0] = -1;
        w_in[1] = -1;
        w_in[2] = -1;
        w_in[3] = -1;
        @(posedge clk);
    end

    // 4th W_LOAD , 3rd compute overlaps with 4th weight load
    repeat(4) begin   
        w_in[0] = 1;
        w_in[1] = 1;
        w_in[2] = 1;
        w_in[3] = 1;
        @(posedge clk);
    end


    // ////////////////////////////////////////////////////////////////////////
    // /////////////////////////// 7th pixel /////////////////////////////////
    // ///////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////
    /////// Vertical shift //////////////
    //////////////////////////////////////

    // channel in sequence 1,2,3,4
    // pe33 : channel 3, pe32 : channel 4, pe23 : channel 2, pe22 : channel 1

    for (int i = 0; i < 5; i++) begin
        //1st is compute with 1 weight load
        // next 4 are horizontal shift with 3 weight loads (overlapping) 
        @(posedge clk);

        // During LAST 4 cycles of FILL, also drive weights
        if (i < 4) begin
            w_in[0] = -1;
            w_in[1] = -1;
            w_in[2] = -1;
            w_in[3] = -1;
        end
        if(i > 0) begin
            v_in0 = $urandom_range(1, 255);
            v_in1 = $urandom_range(1, 255);
            
            v1_store[i] = v_in1;   // store the value for reuse
        end
    end

    // 2nd W_LOAD , 1st compute overlaps with 2nd weight load
    repeat(4) begin   
        w_in[0] = 1;
        w_in[1] = 1;
        w_in[2] = 1;
        w_in[3] = 1;
        @(posedge clk);
        v_in0 = '0;
        v_in1 = '0;
    end

    // 3rd W_LOAD , 2nd compute overlaps with 3rd weight load
    repeat(4) begin   
        w_in[0] = -1;
        w_in[1] = -1;
        w_in[2] = -1;
        w_in[3] = -1;
        @(posedge clk);
    end

    // 4th W_LOAD , 3rd compute overlaps with 4th weight load
    repeat(4) begin   
        w_in[0] = 1;
        w_in[1] = 1;
        w_in[2] = 1;
        w_in[3] = 1;
        @(posedge clk);
    end

    ////////////////////////////////////////////////////////////////////////
    /////////////////////////// 8th pixel /////////////////////////////////
    ///////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////
    /////// Vertical shift //////////////
    //////////////////////////////////////

    // channel in sequence 1,2,3,4
    // pe33 : channel 3, pe32 : channel 4, pe23 : channel 2, pe22 : channel 1

    for (int i = 0; i < 5; i++) begin
        //1st is compute with 1 weight load
        // next 4 are horizontal shift with 3 weight loads (overlapping) 
        @(posedge clk);

        // During LAST 4 cycles of FILL, also drive weights
        if (i < 4) begin
            w_in[0] = -1;
            w_in[1] = -1;
            w_in[2] = -1;
            w_in[3] = -1;
        end
        if(i > 0) begin
            v_in0 = v1_store[i];   // reuse 4th pixel’s v_in1
            v_in1 = $urandom_range(1, 255);
            
            v1_store[i-1] = v_in1;   // store the value for reuse
        end
    end

    // 2nd W_LOAD , 1st compute overlaps with 2nd weight load
    repeat(4) begin   
        w_in[0] = 1;
        w_in[1] = 1;
        w_in[2] = 1;
        w_in[3] = 1;
        @(posedge clk);
        v_in0 = '0;
        v_in1 = '0;
    end

    // 3rd W_LOAD , 2nd compute overlaps with 3rd weight load
    repeat(4) begin   
        w_in[0] = -1;
        w_in[1] = -1;
        w_in[2] = -1;
        w_in[3] = -1;
        @(posedge clk);
    end

    // 4th W_LOAD , 3rd compute overlaps with 4th weight load
    repeat(4) begin   
        w_in[0] = 1;
        w_in[1] = 1;
        w_in[2] = 1;
        w_in[3] = 1;
        @(posedge clk);
    end

    ////////////////////////////////////////////////////////////////////////
    /////////////////////////// 9th pixel /////////////////////////////////
    ///////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////
    /////// Vertical shift //////////////
    //////////////////////////////////////

    // channel in sequence 2,3,4,1
    // pe33 : channel 4, pe32 : channel 1, pe23 : channel 3, pe22 : channel 2

    for (int i = 0; i < 5; i++) begin
        //1st is compute with 1 weight load
        // next 4 are horizontal shift with 3 weight loads (overlapping) 
        @(posedge clk);

        // During LAST 4 cycles of FILL, also drive weights
        if (i < 4) begin
            w_in[0] = -1;
            w_in[1] = -1;
            w_in[2] = -1;
            w_in[3] = -1;
        end
        if(i > 0) begin
            v_in0 = v1_store[(i)%4];   // reuse 4th pixel’s v_in1
            v_in1 = $urandom_range(1, 255);
        end
    end

    // 2nd W_LOAD , 1st compute overlaps with 2nd weight load
    repeat(4) begin   
        w_in[0] = 1;
        w_in[1] = 1;
        w_in[2] = 1;
        w_in[3] = 1;
        @(posedge clk);
        v_in0 = '0;
        v_in1 = '0;
    end

    // 3rd W_LOAD , 2nd compute overlaps with 3rd weight load
    repeat(4) begin   
        w_in[0] = -1;
        w_in[1] = -1;
        w_in[2] = -1;
        w_in[3] = -1;
        @(posedge clk);
    end

    // 4th W_LOAD , 3rd compute overlaps with 4th weight load
    repeat(4) begin   
        w_in[0] = 1;
        w_in[1] = 1;
        w_in[2] = 1;
        w_in[3] = 1;
        @(posedge clk);
    end

    //PSUM_SHIFT OUT
    repeat(9) @(posedge clk); //overlap second pixel fill stage with first pixel psum shift out

    repeat(3) @(posedge clk); //extra


    $stop();
end



always #10 clk = ~clk;


endmodule
