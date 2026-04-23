module top_tb_1 #(
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

logic [DATA_W-1:0] v1_store [0:3];

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
    @(posedge clk);
    start = 0;

    // -----------------------------
    // FILL STAGE: drive activations
    // -----------------------------
    repeat(8) begin
        @(posedge clk);
        h_in0 = $urandom_range(1, 255);
        h_in1 = $urandom_range(1, 255);
    end

    // Stop driving activations after FILL
    @(posedge clk);
    h_in0 = '0;
    h_in1 = '0;

    ////////////////////////////////////////////////////////////////////////
    /////////////////////////// 1st pixel /////////////////////////////////
    ///////////////////////////////////////////////////////////////////////

    // -----------------------------
    // 1st compute
    // -----------------------------
    repeat(4) begin     
        w_in[0] = -1;
        w_in[1] = -1;
        w_in[2] = -1;
        w_in[3] = -1;
        @(posedge clk);
    end
    repeat(1) @(posedge clk); //computation

    // -----------------------------
    // 2nd compute
    // -----------------------------
    repeat(4) begin     
        w_in[0] = 1;
        w_in[1] = 1;
        w_in[2] = 1;
        w_in[3] = 1;
        @(posedge clk);
    end
    repeat(1) @(posedge clk); //computation

    // -----------------------------
    // 3rd compute
    // -----------------------------
    repeat(4) begin     
        w_in[0] = -1;
        w_in[1] = -1;
        w_in[2] = -1;
        w_in[3] = -1;
        @(posedge clk);
    end
    repeat(1) @(posedge clk); //computation

    // -----------------------------
    // 4th compute
    // -----------------------------
    repeat(4) begin     
        w_in[0] = 1;
        w_in[1] = 1;
        w_in[2] = 1;
        w_in[3] = 1;
        @(posedge clk);
    end
    repeat(1) @(posedge clk); //computation

    ////////////////////////////////////////////////////////////////////////
    /////////////////////////// 2nd pixel /////////////////////////////////
    ///////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////
    /////// Horizontal shift //////////////
    //////////////////////////////////////
    repeat(4) begin
        h_in0 = $urandom_range(1, 255);
        h_in1 = $urandom_range(1, 255);
        @(posedge clk);
    end

    // Stop driving activations after FILL
    h_in0 = '0;
    h_in1 = '0;

    // -----------------------------
    // 1st compute
    // -----------------------------
    repeat(4) begin     
        w_in[0] = -1;
        w_in[1] = -1;
        w_in[2] = -1;
        w_in[3] = -1;
        @(posedge clk);
    end
    repeat(1) @(posedge clk); //computation

    // -----------------------------
    // 2nd compute
    // -----------------------------
    repeat(4) begin     
        w_in[0] = 1;
        w_in[1] = 1;
        w_in[2] = 1;
        w_in[3] = 1;
        @(posedge clk);
    end
    repeat(1) @(posedge clk); //computation

    // -----------------------------
    // 3rd compute
    // -----------------------------
    repeat(4) begin     
        w_in[0] = -1;
        w_in[1] = -1;
        w_in[2] = -1;
        w_in[3] = -1;
        @(posedge clk);
    end
    repeat(1) @(posedge clk); //computation

    // -----------------------------
    // 4th compute
    // -----------------------------
    repeat(4) begin     
        w_in[0] = 1;
        w_in[1] = 1;
        w_in[2] = 1;
        w_in[3] = 1;
        @(posedge clk);
    end
    repeat(1) @(posedge clk); //computation


    ////////////////////////////////////////////////////////////////////////
    /////////////////////////// 3rd pixel /////////////////////////////////
    ///////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////
    /////// Horizontal shift //////////////
    //////////////////////////////////////
    repeat(4) begin
        h_in0 = $urandom_range(1, 255);
        h_in1 = $urandom_range(1, 255);
        @(posedge clk);
    end

    // Stop driving activations after FILL
    h_in0 = '0;
    h_in1 = '0;

    // -----------------------------
    // 1st compute
    // -----------------------------
    repeat(4) begin     
        w_in[0] = -1;
        w_in[1] = -1;
        w_in[2] = -1;
        w_in[3] = -1;
        @(posedge clk);
    end
    repeat(1) @(posedge clk); //computation

    // -----------------------------
    // 2nd compute
    // -----------------------------
    repeat(4) begin     
        w_in[0] = 1;
        w_in[1] = 1;
        w_in[2] = 1;
        w_in[3] = 1;
        @(posedge clk);
    end
    repeat(1) @(posedge clk); //computation

    // -----------------------------
    // 3rd compute
    // -----------------------------
    repeat(4) begin     
        w_in[0] = -1;
        w_in[1] = -1;
        w_in[2] = -1;
        w_in[3] = -1;
        @(posedge clk);
    end
    repeat(1) @(posedge clk); //computation

    // -----------------------------
    // 4th compute
    // -----------------------------
    repeat(4) begin     
        w_in[0] = 1;
        w_in[1] = 1;
        w_in[2] = 1;
        w_in[3] = 1;
        @(posedge clk);
    end
    repeat(1) @(posedge clk); //computation

    ////////////////////////////////////////////////////////////////////////
    /////////////////////////// 4th pixel /////////////////////////////////
    ///////////////////////////////////////////////////////////////////////
    
    ///////////////////////////////////////
    /////// Vertical shift //////////////
    //////////////////////////////////////
    for (int i = 0; i < 4; i++) begin
        v_in0 = $urandom_range(1, 255);
        v_in1 = $urandom_range(1, 255);

        v1_store[i] = v_in1;   // store the value for reuse

        @(posedge clk);
    end


    // Stop driving activations after FILL
    v_in0 = '0;
    v_in1 = '0;

    // -----------------------------
    // 1st compute
    // -----------------------------
    repeat(4) begin     
        w_in[0] = -1;
        w_in[1] = -1;
        w_in[2] = -1;
        w_in[3] = -1;
        @(posedge clk);
    end
    repeat(1) @(posedge clk); //computation

    // -----------------------------
    // 2nd compute
    // -----------------------------
    repeat(4) begin     
        w_in[0] = 1;
        w_in[1] = 1;
        w_in[2] = 1;
        w_in[3] = 1;
        @(posedge clk);
    end
    repeat(1) @(posedge clk); //computation

    // -----------------------------
    // 3rd compute
    // -----------------------------
    repeat(4) begin     
        w_in[0] = -1;
        w_in[1] = -1;
        w_in[2] = -1;
        w_in[3] = -1;
        @(posedge clk);
    end
    repeat(1) @(posedge clk); //computation

    // -----------------------------
    // 4th compute
    // -----------------------------
    repeat(4) begin     
        w_in[0] = 1;
        w_in[1] = 1;
        w_in[2] = 1;
        w_in[3] = 1;
        @(posedge clk);
    end
    repeat(1) @(posedge clk); //computation

    ////////////////////////////////////////////////////////////////////////
    /////////////////////////// 5th pixel /////////////////////////////////
    ///////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////
    /////// Vertical shift //////////////
    //////////////////////////////////////
    for (int i = 0; i < 4; i++) begin
        v_in0 = v1_store[i];   // reuse 4th pixel’s v_in1
        v_in1 = $urandom_range(1, 255); // or 0, or anything else
        v1_store[i] = v_in1;   // store the value for reuse
        @(posedge clk);
    end


    // Stop driving activations after FILL
    v_in0 = '0;
    v_in1 = '0;

    // -----------------------------
    // 1st compute
    // -----------------------------
    repeat(4) begin     
        w_in[0] = -1;
        w_in[1] = -1;
        w_in[2] = -1;
        w_in[3] = -1;
        @(posedge clk);
    end
    repeat(1) @(posedge clk); //computation

    // -----------------------------
    // 2nd compute
    // -----------------------------
    repeat(4) begin     
        w_in[0] = 1;
        w_in[1] = 1;
        w_in[2] = 1;
        w_in[3] = 1;
        @(posedge clk);
    end
    repeat(1) @(posedge clk); //computation

    // -----------------------------
    // 3rd compute
    // -----------------------------
    repeat(4) begin     
        w_in[0] = -1;
        w_in[1] = -1;
        w_in[2] = -1;
        w_in[3] = -1;
        @(posedge clk);
    end
    repeat(1) @(posedge clk); //computation

    // -----------------------------
    // 4th compute
    // -----------------------------
    repeat(4) begin     
        w_in[0] = 1;
        w_in[1] = 1;
        w_in[2] = 1;
        w_in[3] = 1;
        @(posedge clk);
    end
    repeat(1) @(posedge clk); //computation

    ////////////////////////////////////////////////////////////////////////
    /////////////////////////// 6th pixel /////////////////////////////////
    ///////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////
    /////// Vertical shift //////////////
    //////////////////////////////////////
    for (int i = 0; i < 4; i++) begin
        v_in0 = v1_store[i];   // reuse 4th pixel’s v_in1
        v_in1 = $urandom_range(1, 255); // or 0, or anything else
        v1_store[i] = v_in1;   // store the value for reuse
        @(posedge clk);
    end


    // Stop driving activations after FILL
    v_in0 = '0;
    v_in1 = '0;

    // -----------------------------
    // 1st compute
    // -----------------------------
    repeat(4) begin     
        w_in[0] = -1;
        w_in[1] = -1;
        w_in[2] = -1;
        w_in[3] = -1;
        @(posedge clk);
    end
    repeat(1) @(posedge clk); //computation

    // -----------------------------
    // 2nd compute
    // -----------------------------
    repeat(4) begin     
        w_in[0] = 1;
        w_in[1] = 1;
        w_in[2] = 1;
        w_in[3] = 1;
        @(posedge clk);
    end
    repeat(1) @(posedge clk); //computation

    // -----------------------------
    // 3rd compute
    // -----------------------------
    repeat(4) begin     
        w_in[0] = -1;
        w_in[1] = -1;
        w_in[2] = -1;
        w_in[3] = -1;
        @(posedge clk);
    end
    repeat(1) @(posedge clk); //computation

    // -----------------------------
    // 4th compute
    // -----------------------------
    repeat(4) begin     
        w_in[0] = 1;
        w_in[1] = 1;
        w_in[2] = 1;
        w_in[3] = 1;
        @(posedge clk);
    end
    repeat(1) @(posedge clk); //computation

    ////////////////////////////////////////////////////////////////////////
    /////////////////////////// 7th pixel /////////////////////////////////
    ///////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////
    /////// Vertical shift //////////////
    //////////////////////////////////////
    for (int i = 0; i < 4; i++) begin
        v_in0 = $urandom_range(1, 255);
        v_in1 = $urandom_range(1, 255); // or 0, or anything else
        v1_store[i] = v_in1;   // store the value for reuse
        @(posedge clk);
    end


    // Stop driving activations after FILL
    v_in0 = '0;
    v_in1 = '0;

    // -----------------------------
    // 1st compute
    // -----------------------------
    repeat(4) begin     
        w_in[0] = -1;
        w_in[1] = -1;
        w_in[2] = -1;
        w_in[3] = -1;
        @(posedge clk);
    end
    repeat(1) @(posedge clk); //computation

    // -----------------------------
    // 2nd compute
    // -----------------------------
    repeat(4) begin     
        w_in[0] = 1;
        w_in[1] = 1;
        w_in[2] = 1;
        w_in[3] = 1;
        @(posedge clk);
    end
    repeat(1) @(posedge clk); //computation

    // -----------------------------
    // 3rd compute
    // -----------------------------
    repeat(4) begin     
        w_in[0] = -1;
        w_in[1] = -1;
        w_in[2] = -1;
        w_in[3] = -1;
        @(posedge clk);
    end
    repeat(1) @(posedge clk); //computation

    // -----------------------------
    // 4th compute
    // -----------------------------
    repeat(4) begin     
        w_in[0] = 1;
        w_in[1] = 1;
        w_in[2] = 1;
        w_in[3] = 1;
        @(posedge clk);
    end
    repeat(1) @(posedge clk); //computation

    ////////////////////////////////////////////////////////////////////////
    /////////////////////////// 8th pixel /////////////////////////////////
    ///////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////
    /////// Vertical shift //////////////
    //////////////////////////////////////
    for (int i = 0; i < 4; i++) begin
        v_in0 = v1_store[i];   // reuse 4th pixel’s v_in1
        v_in1 = $urandom_range(1, 255); // or 0, or anything else
        v1_store[i] = v_in1;   // store the value for reuse
        @(posedge clk);
    end


    // Stop driving activations after FILL
    v_in0 = '0;
    v_in1 = '0;

    // -----------------------------
    // 1st compute
    // -----------------------------
    repeat(4) begin     
        w_in[0] = -1;
        w_in[1] = -1;
        w_in[2] = -1;
        w_in[3] = -1;
        @(posedge clk);
    end
    repeat(1) @(posedge clk); //computation

    // -----------------------------
    // 2nd compute
    // -----------------------------
    repeat(4) begin     
        w_in[0] = 1;
        w_in[1] = 1;
        w_in[2] = 1;
        w_in[3] = 1;
        @(posedge clk);
    end
    repeat(1) @(posedge clk); //computation

    // -----------------------------
    // 3rd compute
    // -----------------------------
    repeat(4) begin     
        w_in[0] = -1;
        w_in[1] = -1;
        w_in[2] = -1;
        w_in[3] = -1;
        @(posedge clk);
    end
    repeat(1) @(posedge clk); //computation

    // -----------------------------
    // 4th compute
    // -----------------------------
    repeat(4) begin     
        w_in[0] = 1;
        w_in[1] = 1;
        w_in[2] = 1;
        w_in[3] = 1;
        @(posedge clk);
    end
    repeat(1) @(posedge clk); //computation

    ////////////////////////////////////////////////////////////////////////
    /////////////////////////// 9th pixel /////////////////////////////////
    ///////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////
    /////// Vertical shift //////////////
    //////////////////////////////////////
    for (int i = 0; i < 4; i++) begin
        v_in0 = v1_store[i];   // reuse 4th pixel’s v_in1
        v_in1 = $urandom_range(1, 255); // or 0, or anything else
        v1_store[i] = v_in1;   // store the value for reuse
        @(posedge clk);
    end


    // Stop driving activations after FILL
    v_in0 = '0;
    v_in1 = '0;

    // -----------------------------
    // 1st compute
    // -----------------------------
    repeat(4) begin     
        w_in[0] = -1;
        w_in[1] = -1;
        w_in[2] = -1;
        w_in[3] = -1;
        @(posedge clk);
    end
    repeat(1) @(posedge clk); //computation

    // -----------------------------
    // 2nd compute
    // -----------------------------
    repeat(4) begin     
        w_in[0] = 1;
        w_in[1] = 1;
        w_in[2] = 1;
        w_in[3] = 1;
        @(posedge clk);
    end
    repeat(1) @(posedge clk); //computation

    // -----------------------------
    // 3rd compute
    // -----------------------------
    repeat(4) begin     
        w_in[0] = -1;
        w_in[1] = -1;
        w_in[2] = -1;
        w_in[3] = -1;
        @(posedge clk);
    end
    repeat(1) @(posedge clk); //computation

    // -----------------------------
    // 4th compute
    // -----------------------------
    repeat(4) begin     
        w_in[0] = 1;
        w_in[1] = 1;
        w_in[2] = 1;
        w_in[3] = 1;
        @(posedge clk);
    end
    repeat(1) @(posedge clk); //computation


    //PSUM_SHIFT OUT
    repeat(9) @(posedge clk); 


    $stop();
end



always #10 clk = ~clk;


endmodule