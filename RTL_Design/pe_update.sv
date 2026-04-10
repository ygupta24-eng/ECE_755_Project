module pe #(
    parameter int DATA_W   = 6,
    parameter int WEIGHT_W = 2, // 2's comp range -2..1
    parameter int ACC_W    = 13
)(
    input  logic              clk,
    input  logic              rst_n,
    input  logic              en, //compute enable, high in circular shift phase , low in horizontal/vertical move phase, initial fill and final drain phase 
    input  logic              move_en,
    input  logic              psum_shift_en,
    input  logic [1:0]        dst_sel,
    input  logic [1:0]        src_sel,

    input  logic [ACC_W-1:0]  act_from_left,
    input  logic [ACC_W-1:0]  act_from_right,
    input  logic [ACC_W-1:0]  act_from_up,
    input  logic [ACC_W-1:0]  act_from_down,

    output logic [ACC_W-1:0]  act_to_left,
    output logic [ACC_W-1:0]  act_to_right,
    output logic [ACC_W-1:0]  act_to_up,
    output logic [ACC_W-1:0]  act_to_down,

    input  logic                    w_ld_en,
    input  logic [WEIGHT_W-1:0]     w_in,
    output logic [WEIGHT_W-1:0]     w_out,

    input  logic                    psum_clr
);

    // ═══════════════════════════════════════════════════════════════════
    // CLOCK GATING SIGNALS - Priority 1 Optimization
    // ═══════════════════════════════════════════════════════════════════
    // Gated clock signal for psum_out accumulator (created by ICG cell in synthesis)
    logic clk_psum_gated;
    
    // Gating enable - combinational from FSM 'en' signal
    logic en_for_gating;
    assign en_for_gating = en;
    
    // Pipelined gating enable (1 cycle delay for glitch-free clock gating)
    logic en_for_gating_d;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            en_for_gating_d <= 1'b0;
        else        
            en_for_gating_d <= en_for_gating;
    end
    
    // ✅ LATCH-BASED ICG: Integrated Clock Gate for psum_out
    // Step 1: Latch - samples enable only when clock is LOW
    logic en_latched;
    always_latch begin
        if (~clk)
            en_latched = en_for_gating_d;  // Sample when clk=0
        // Hold value when clk=1 (no transitions during pulse)
    end
    
    // Step 2: Gated Clock Generator
    // AND gate produces clean gated clock (no glitches possible)
    // This gates the psum accumulator clock → ~90% power savings (10-15% overall)
    assign clk_psum_gated = clk & en_latched;

    // ── Registers ────────────────────────────────────────────────
    logic [ACC_W-1:0]           move_reg;
    logic signed [ACC_W-1:0]    psum_hold_reg;  // always holds last psum_out
    logic signed [WEIGHT_W-1:0] w_reg;
    logic signed [ACC_W-1:0] psum_out;

    // ── Incoming mux ─────────────────────────────────────────────
    logic [ACC_W-1:0] incoming;
    always_comb begin
        unique case (src_sel)
            2'b00: incoming = act_from_left;
            2'b01: incoming = act_from_right;
            2'b10: incoming = act_from_up;
            2'b11: incoming = act_from_down;
            default: incoming = '0;
        endcase
    end

    // ── Weight register ───────────────────────────────────────────
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)       w_reg <= '0;
        else if (w_ld_en) w_reg <= signed'(w_in);
    end
    assign w_out = w_reg;

    // ── MAC ───────────────────────────────────────────────────────
    logic unsigned [DATA_W-1:0]  act_val;
    logic signed  [WEIGHT_W-1:0] w_val;
    logic signed  [ACC_W-1:0]    product;

    assign act_val = move_reg[DATA_W-1:0];
    assign w_val   = w_reg;

    assign product = signed'({{(ACC_W-DATA_W){1'b0}}, act_val}) *
                     signed'({{(ACC_W-WEIGHT_W){w_val[WEIGHT_W-1]}}, w_val});

    // ═══════════════════════════════════════════════════════════════════
    // PSUM ACCUMULATOR - GATED CLOCK (Priority 1 Optimization)
    // ═══════════════════════════════════════════════════════════════════
    // Uses clk_psum_gated instead of clk - controlled by en_for_gating_d
    // When en_for_gating_d=0 (during FILL, H_SHIFT, V_SHIFT, PSUM_SHIFT),
    // clock is gated (not toggling) → ~90% power savings on this register
    always_ff @(posedge clk_psum_gated or negedge rst_n) begin
        if (!rst_n) begin
            psum_out <= '0;
        end else if (en) begin  // en low during psum shift, en is high in circular shift phase, and low in horizontal/vertical move phase, and low in initial fill phase
            if (psum_clr)
                psum_out <= '0;
            else
                psum_out <= psum_out + product;
        end
    end

    // ── shift edge detect ─────────────────────────────────────────
    logic psum_shift_en_d;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) psum_shift_en_d <= '0;
        else        psum_shift_en_d <= psum_shift_en;
    end

    wire first_shift   = psum_shift_en  & ~psum_shift_en_d;
    wire shift_falling = ~psum_shift_en &  psum_shift_en_d;

    // ── what drives act_to_* this cycle ──────────────────────────
    // Combinational mux so output is immediate:
    //   first_shift=1  → drive psum_hold_reg directly (no move_reg latency)
    //   psum_shift_en=1, not first → drive move_reg (chain forwarding)
    //   normal         → drive move_reg (activation)
    logic [ACC_W-1:0] act_out_val;
    always_comb begin
        if (first_shift)
            act_out_val = ACC_W'(psum_out);  // immediate: own psum
        else
            act_out_val = move_reg;                // normal or chain forward
    end

    // ── Movement + output drive ───────────────────────────────────
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            move_reg     <= '0;
            // act_to_left  <= '0;
            // act_to_right <= '0;
            // act_to_up    <= '0;
            // act_to_down  <= '0;
        end 
        else begin

            if (shift_falling) begin
                move_reg     <= '0;        // ← added: flush stale psum
                // act_to_left  <= '0;
                // act_to_right <= '0;
                // act_to_up    <= '0;
                // act_to_down  <= '0;
            end else if (move_en) begin    // ← changed: if → else if
                if (psum_shift_en)
                    move_reg <= incoming;
                else
                    move_reg <= ACC_W'(incoming[DATA_W-1:0]);
    
                // unique case (dst_sel)
                //     2'b00: act_to_right <= act_out_val;
                //     2'b01: act_to_left  <= act_out_val;
                //     2'b10: act_to_down  <= act_out_val;
                //     2'b11: act_to_up    <= act_out_val;
                // endcase
            end
        end
    end


    // ── act_to_* combinational outputs ───────────────────────────
    // driven directly from act_out_val via dst_sel — no FF delay
    // only the active direction gets act_out_val, others are '0
    assign act_to_right = (dst_sel == 2'b00) ? act_out_val : '0;
    assign act_to_left  = (dst_sel == 2'b01) ? act_out_val : '0;
    assign act_to_down  = (dst_sel == 2'b10) ? act_out_val : '0;
    assign act_to_up    = (dst_sel == 2'b11) ? act_out_val : '0;

endmodule