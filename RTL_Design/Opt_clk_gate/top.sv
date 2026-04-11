module top #(
    parameter int DATA_W   = 6,
    parameter int WEIGHT_W = 2,
    parameter int ACC_W    = 13,
    parameter int ROWS     = 4,
    parameter int COLS     = 4,
    parameter int UNQ_DIR  = 4
)(
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    output logic done,

    // Horizontal boundary inputs
    input  logic [DATA_W-1:0]   h_in0,
    input  logic [DATA_W-1:0]   h_in1,

    // Vertical boundary inputs
    input  logic [DATA_W-1:0]   v_in0,
    input  logic [DATA_W-1:0]   v_in1,

    // Weight inputs — one per column, chains down rows
    input  logic [WEIGHT_W-1:0] w_in [0:COLS-1],

    // psum drain outputs
    output logic [ACC_W-1:0]    psum_out0,  // PE10
    output logic [ACC_W-1:0]    psum_out1   // PE30
);

    // ----------------------------------------------------------------
    // Internal control wires — FSM → PE array
    // ----------------------------------------------------------------
    logic       en;
    logic       move_en;
    logic       w_ld_en;
    logic       fifo_en;
    logic       psum_shift_en;
    logic       psum_clr;
    logic [1:0] direction;

    // ----------------------------------------------------------------
    // FSM — generates all control signals
    // ----------------------------------------------------------------
    zigzag_fsm u_fsm (
        .clk          (clk),
        .rst_n        (rst_n),
        .start        (start),
        .done         (done),
        .en           (en),
        .move_en      (move_en),
        .w_ld_en      (w_ld_en),
        .fifo_en      (fifo_en),
        .psum_shift_en(psum_shift_en),
        .psum_clr     (psum_clr),
        .direction    (direction)
    );

    // ----------------------------------------------------------------
    // PE array — zigzag dataflow accelerator
    // ----------------------------------------------------------------
    pe_array #(
        .DATA_W   (DATA_W),
        .WEIGHT_W (WEIGHT_W),
        .ACC_W    (ACC_W),
        .ROWS     (ROWS),
        .COLS     (COLS),
        .UNQ_DIR  (UNQ_DIR)
    ) u_pe_array (
        .clk          (clk),
        .rst_n        (rst_n),
        .h_in0        (h_in0),
        .h_in1        (h_in1),
        .v_in0        (v_in0),
        .v_in1        (v_in1),
        .en           (en),
        .move_en      (move_en),
        .psum_shift_en(psum_shift_en),
        .psum_clr     (psum_clr),
        .w_ld_en      (w_ld_en),
        .w_in         (w_in),
        .direction    (direction),
        .fifo_en      (fifo_en),
        .psum_out0    (psum_out0),
        .psum_out1    (psum_out1)
    );

endmodule