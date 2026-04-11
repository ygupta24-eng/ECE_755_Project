module zigzag_fsm (
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    output logic done,

    // ----------------------------------------------------------------
    // Internal control signals → PE array
    // ----------------------------------------------------------------
    output logic       en,
    output logic       move_en,
    output logic       w_ld_en,
    output logic       fifo_en,
    output logic       psum_shift_en,
    output logic       psum_clr,
    output logic [1:0] direction
);

    // ----------------------------------------------------------------
    // State encoding
    // ----------------------------------------------------------------
    typedef enum logic [2:0] {
        IDLE       = 3'd0,
        CLEAR      = 3'd1,   // 1 cycle: en=1, psum_clr=1
        FILL       = 3'd2,
        W_LOAD     = 3'd3,
        COMPUTE    = 3'd4,
        H_SHIFT    = 3'd5,
        V_SHIFT    = 3'd6,
        PSUM_SHIFT = 3'd7
    } state_t;

    state_t state, next_state;

    // ----------------------------------------------------------------
    // Counters
    // ----------------------------------------------------------------
    logic [3:0] cnt;      // cycle counter within state (max 8)
    logic [1:0] ch_cnt;   // channel counter     0..3
    logic [1:0] h_cnt;    // h-shift counter     0..1
    logic [2:0] v_cnt;    // v-shift counter     0..6

    // ----------------------------------------------------------------
    // State register
    // ----------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else        state <= next_state;
    end

    // ----------------------------------------------------------------
    // Cycle counter — resets on every state transition
    // ----------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= '0;
        end else begin
            if (state != next_state)
                cnt <= '0;
            else
                cnt <= cnt + 1;
        end
    end

    // ----------------------------------------------------------------
    // ch_cnt — channel counter
    // ----------------------------------------------------------------
    // ICG removed: ch_cnt is a 2-bit counter that increments only ~4
    // times per full inference. The latch+FF+AND overhead of an ICG
    // cell costs more area and routing than a 2-bit counter saves in
    // power. More critically, the gating enable required a 1-cycle
    // delay (en_d) that caused the increment to fire one cycle after
    // the COMPUTE→* transition — at which point state had already
    // changed, so the increment condition was never true, leaving
    // ch_cnt permanently stuck at 0 and the FSM unable to progress.
    // Plain clk is correct and costs negligibly more power here.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ch_cnt <= '0;
        end else begin
            case (state)
                IDLE,
                CLEAR,
                FILL,
                H_SHIFT,
                V_SHIFT:  ch_cnt <= '0;

                COMPUTE: begin
                    if (next_state == W_LOAD     ||
                        next_state == H_SHIFT    ||
                        next_state == V_SHIFT    ||
                        next_state == PSUM_SHIFT)
                        ch_cnt <= ch_cnt + 1;
                end

                default: ;
            endcase
        end
    end

    // ----------------------------------------------------------------
    // h_cnt — horizontal shift counter (row 0 only)
    // ----------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h_cnt <= '0;
        end else begin
            case (state)
                IDLE,
                CLEAR,
                FILL:    h_cnt <= '0;

                H_SHIFT: begin
                    if (next_state == W_LOAD)
                        h_cnt <= h_cnt + 1;
                end

                default: ;
            endcase
        end
    end

    // ----------------------------------------------------------------
    // v_cnt — vertical shift counter
    // ----------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v_cnt <= '0;
        end else begin
            case (state)
                IDLE,
                CLEAR:   v_cnt <= '0;

                V_SHIFT: begin
                    if (next_state == W_LOAD)
                        v_cnt <= v_cnt + 1;
                end

                default: ;
            endcase
        end
    end

    // ----------------------------------------------------------------
    // Next state logic
    // ----------------------------------------------------------------
    always_comb begin
        next_state = state;

        case (state)
            IDLE: begin
                if (start)
                    next_state = CLEAR;
            end

            CLEAR: begin
                // 1 cycle only — immediately move to FILL
                next_state = FILL;
            end

            FILL: begin
                if (cnt == 4'd7)
                    next_state = W_LOAD;
            end

            W_LOAD: begin
                if (cnt == 4'd3)
                    next_state = COMPUTE;
            end

            COMPUTE: begin
                if (ch_cnt == 2'd3) begin
                    if (v_cnt == 3'd6)
                        next_state = PSUM_SHIFT;
                    else if (v_cnt == 3'd0 && h_cnt < 2'd2)
                        next_state = H_SHIFT;
                    else
                        next_state = V_SHIFT;
                end else begin
                    next_state = W_LOAD;
                end
            end

            H_SHIFT: begin
                if (cnt == 4'd3)
                    next_state = W_LOAD;
            end

            V_SHIFT: begin
                if (cnt == 4'd3)
                    next_state = W_LOAD;
            end

            PSUM_SHIFT: begin
                if (cnt == 4'd7)
                    next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // ----------------------------------------------------------------
    // Output logic (combinational)
    // ----------------------------------------------------------------
    always_comb begin
        en            = 1'b0;
        move_en       = 1'b0;
        w_ld_en       = 1'b0;
        fifo_en       = 1'b0;
        psum_shift_en = 1'b0;
        psum_clr      = 1'b0;
        done          = 1'b0;
        direction     = 2'b11;

        case (state)
            IDLE: begin
                // all outputs inactive
            end

            CLEAR: begin
                // 1 cycle: en=1 opens psum_gated clock, psum_clr=1 zeros all psums
                // move_en=0: activations do not move this cycle
                en       = 1'b1;
                psum_clr = 1'b1;
            end

            FILL: begin
                move_en   = 1'b1;
                direction = 2'b10;   // h-zigzag: load activations into array
            end

            W_LOAD: begin
                w_ld_en   = 1'b1;
                direction = 2'b11;   // circular — weights shift, activations idle
            end

            COMPUTE: begin
                en        = 1'b1;
                move_en   = 1'b1;
                direction = 2'b11;   // circular shift: MAC active each cycle
            end

            H_SHIFT: begin
                move_en   = 1'b1;
                fifo_en   = 1'b1;
                direction = 2'b10;   // horizontal zigzag wrap via FIFO
            end

            V_SHIFT: begin
                move_en   = 1'b1;
                fifo_en   = 1'b1;
                direction = 2'b01;   // vertical zigzag wrap via FIFO
            end

            PSUM_SHIFT: begin
                move_en       = 1'b1;
                psum_shift_en = 1'b1;
                direction     = 2'b10;               // reuse h-zigzag: drain leftward
                done          = (cnt == 4'd7);        // pulse on last drain cycle
            end

            default: ;
        endcase
    end

endmodule

/*
State sequence per inference:
  IDLE       → start asserted
  CLEAR      → 1 cycle:  en=1, psum_clr=1 — all 16 psums zeroed
  FILL       → 8 cycles: activations loaded into PE array
  [W_LOAD(4) + COMPUTE(1)] × 4 channels, repeated per pixel position:
    H_SHIFT  → 4 cycles: horizontal wrap (h_cnt: 0→1→2)
    V_SHIFT  → 4 cycles: vertical wrap   (v_cnt: 0→1→...→6)
  PSUM_SHIFT → 8 cycles: psums drained out, done pulses on cycle 7
  IDLE       → ready for next start
*/
