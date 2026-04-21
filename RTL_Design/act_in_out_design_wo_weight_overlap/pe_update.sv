module pe #(
    parameter int DATA_W   = 6,
    parameter int WEIGHT_W = 2, // 2's comp range -2..1
    parameter int ACC_W    = 13
)(
    input  logic              clk,
    input  logic              rst_n,
    input  logic              move_en,
    input  logic              psum_shift_en,
    // dst_sel removed — routing now handled by PE array
    input  logic [1:0]        src_sel,

    // Single activation input (selected by array based on src_sel)
    input  logic [ACC_W-1:0]  act_in,

    // Single activation output (routed by array based on dst_sel)
    output logic [ACC_W-1:0]  act_out,

    input  logic                    w_ld_en,
    input  logic [WEIGHT_W-1:0]     w_in,
    output logic [WEIGHT_W-1:0]     w_out,

    input  logic                    psum_clr,
    input  logic                    en_latched  // gated clock enable for psum_out
);

    logic clk_psum_gated;
    assign clk_psum_gated = clk & en_latched;

    // ── Registers ────────────────────────────────────────────────
    logic [ACC_W-1:0]           move_reg;
    logic signed [WEIGHT_W-1:0] w_reg;
    logic signed [ACC_W-1:0]    psum_out;

    // ── Weight buffering ──────────────────────────────────────────
    //logic signed [WEIGHT_W-1:0] w_buffer;

    // always_ff @(posedge clk or negedge rst_n) begin
    //     if (!rst_n)        w_buffer <= '0;
    //     else if (w_ld_en)  w_buffer <= signed'(w_in);
    // end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)      w_reg <= '0;
        else if(w_ld_en) w_reg <= signed'(w_in); 
    end

    assign w_out = w_reg;;

    // ── MAC ───────────────────────────────────────────────────────
    logic unsigned [DATA_W-1:0]   act_val;
    logic signed   [WEIGHT_W-1:0] w_val;
    logic signed   [ACC_W-1:0]    product;

    assign act_val = move_reg[DATA_W-1:0];
    assign w_val   = w_reg;

    assign product = signed'({{(ACC_W-DATA_W){1'b0}}, act_val}) *
                     signed'({{(ACC_W-WEIGHT_W){w_val[WEIGHT_W-1]}}, w_val});

    // ── Psum accumulator — gated clock ───────────────────────────
    always_ff @(posedge clk_psum_gated or negedge rst_n) begin
        if (!rst_n)
            psum_out <= '0;
        if (psum_clr)
            psum_out <= '0;
        else
            psum_out <= psum_out + product;
    end

    // ── Psum shift edge detect ────────────────────────────────────
    logic psum_shift_en_d;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) psum_shift_en_d <= '0;
        else        psum_shift_en_d <= psum_shift_en;
    end

    wire first_shift   = psum_shift_en  & ~psum_shift_en_d;
    wire shift_falling = ~psum_shift_en &  psum_shift_en_d;

    // ── act_out_val mux ───────────────────────────────────────────
    // first_shift → own psum_out (no move_reg latency)
    // otherwise   → move_reg (activation or psum chain)
    logic [ACC_W-1:0] act_out_val;
    always_comb begin
        if (first_shift)
            act_out_val = ACC_W'(psum_out);
        else
            act_out_val = move_reg;
    end

    // ── Single act_out ───────────────────────────────────────────
    // Routing to correct neighbour is handled by PE array
    // act_out is valid whenever move_en=1 or first_shift=1
    assign act_out = act_out_val;

    // ── Movement register ─────────────────────────────────────────
    // act_in comes from PE array routing mux (already selected by src_sel)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            move_reg <= '0;
        end else begin
            if (shift_falling) begin
                move_reg <= '0;
            end else if (move_en) begin
                if (psum_shift_en)
                    move_reg <= act_in;                       // full ACC_W psum chain
                else
                    move_reg <= ACC_W'(act_in[DATA_W-1:0]);   // zero-extend activation
            end
        end
    end

endmodule
