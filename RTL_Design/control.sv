module zigzag_fsm (
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    output logic done,

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
        CLEAR      = 3'd1,
        FILL       = 3'd2,   // 8 cycles, w_ld_en=1 for last 4
        W_LOAD     = 3'd3,   // 3 cycles only (4th cycle overlaps with COMPUTE)
        COMPUTE    = 3'd4,   // 1 cycle, w_ld_en=1 (loads next weight simultaneously)
        H_SHIFT    = 3'd5,   // 4 cycles, w_ld_en=1 for last 3 cycles (cnt 1,2,3)
        V_SHIFT    = 3'd6,   // 4 cycles, w_ld_en=1 for last 3 cycles (cnt 1,2,3)
        PSUM_SHIFT = 3'd7    // 8 cycles
    } state_t;

    state_t state, next_state;

    // ----------------------------------------------------------------
    // Counters
    // ----------------------------------------------------------------
    logic [3:0] cnt;      // cycle counter within state
    logic [1:0] ch_cnt;   // channel counter 0..3 (per pixel)
    logic [1:0] h_cnt;    // h-shift counter 0..1 (row 0 only)
    logic [2:0] v_cnt;    // v-shift counter 0..5 (6 vertical pixels)

    // ----------------------------------------------------------------
    // State register
    // ----------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else        state <= next_state;
    end

    // ----------------------------------------------------------------
    // Cycle counter — resets on state transition
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
    // ch_cnt — increments each COMPUTE→W_LOAD or COMPUTE→next_pixel
    // resets when new pixel arrives
    // ----------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ch_cnt <= '0;
        end else begin
            case (state)
                IDLE,
                CLEAR,
                FILL,
                H_SHIFT,
                V_SHIFT:  ch_cnt <= '0;    // reset for new pixel

                COMPUTE: begin
                    // increment after every compute cycle
                    ch_cnt <= ch_cnt + 1;
                end

                default: ;
            endcase
        end
    end

    // ----------------------------------------------------------------
    // h_cnt — increments each H_SHIFT completes
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
                    if (next_state == COMPUTE)
                        h_cnt <= h_cnt + 1;
                end

                default: ;
            endcase
        end
    end

    // ----------------------------------------------------------------
    // v_cnt — increments each V_SHIFT completes
    // ----------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v_cnt <= '0;
        end else begin
            case (state)
                IDLE,
                CLEAR:   v_cnt <= '0;

                V_SHIFT: begin
                    if (next_state == COMPUTE)
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
                    next_state = FILL;
            end

            FILL: begin
                // 8 cycles total
                // last 4 cycles: w_ld_en=1 (first weight loading)
                if (cnt == 4'd7)
                    next_state = CLEAR;
            end

            CLEAR: begin
                // 1 cycle only
                next_state = COMPUTE;
            end

            COMPUTE: begin
                // 1 cycle: en=1, move_en=1, w_ld_en=1, direction=circular
                if (ch_cnt == 2'd3) begin
                    // all 4 channels done for this pixel
                    if (v_cnt == 3'd6)
                        next_state = PSUM_SHIFT;
                    else if (v_cnt == 3'd0 && h_cnt < 2'd2)
                        next_state = H_SHIFT;
                    else
                        next_state = V_SHIFT;
                end else begin
                    // more channels — 3 more weight load cycles needed
                    next_state = W_LOAD;
                end
            end

            W_LOAD: begin
                // 3 cycles only (4th cycle is COMPUTE itself)
                if (cnt == 4'd2)
                    next_state = COMPUTE;
            end

            H_SHIFT: begin
                // 4 cycles total
                // cnt=0: move activation, fifo_en=1, w_ld_en=0
                // cnt=1,2,3: move activation + w_ld_en=1 (overlap next weight)
                // after 4 cycles → directly to COMPUTE
                if (cnt == 4'd3)
                    next_state = COMPUTE;
            end

            V_SHIFT: begin
                // 4 cycles total
                // cnt=0: move activation, fifo_en=1, w_ld_en=0
                // cnt=1,2,3: move activation + w_ld_en=1 (overlap next weight)
                // after 4 cycles → directly to COMPUTE
                if (cnt == 4'd3)
                    next_state = COMPUTE;
            end

            PSUM_SHIFT: begin
                if (cnt == 4'd7 && start == 1'b1)
                    next_state = IDLE;
                else if (cnt == 4'd7)
                    next_state = CLEAR; // if start is low, stay active and immediately start next round
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
                // all inactive
            end

            CLEAR: begin
                // 1 cycle: clear all psums
                en       = 1'b1;
                psum_clr = 1'b1;
                w_ld_en  = 1'b1;
            end

            FILL: begin
                // 8 cycles of h-zigzag fill
                // last 4 cycles (cnt 4,5,6,7): w_ld_en=1 to pre-load first weight
                move_en   = 1'b1;
                direction = 2'b10;              // h-zigzag
                w_ld_en   = (cnt >= 4'd4);      // overlap: last 3 fill cycles
            end

            W_LOAD: begin
                // 3 cycles: load weight rows 1,2,3
                // (row 0 was loaded during COMPUTE's w_ld_en pulse)
                w_ld_en   = 1'b1;
                direction = 2'b11;              // circular (ready for compute)
            end

            COMPUTE: begin
                // 1 cycle: circular shift + MAC + start loading next weight (row 0)
                en        = 1'b1;
                move_en   = 1'b1;
                w_ld_en   = 1'b1;              // row 0 of next weight loads now
                direction = 2'b11;             // circular shift
            end

            H_SHIFT: begin
                // 4 cycles: shift new horizontal pixel in
                // cnt=0: pure shift (first activation cycle, no weight yet)
                // cnt=1,2,3: shift + weight loading (rows 1,2,3 of first weight)
                move_en   = 1'b1;
                fifo_en   = 1'b1;
                direction = 2'b10;             // h-zigzag
                w_ld_en   = 1'b1;     // overlap: cycles 0,1,2
            end

            V_SHIFT: begin
                // 4 cycles: shift new vertical pixel in via FIFO
                // cnt=0: pure shift (fifo_en=1, no weight yet)
                // cnt=1,2,3: shift + weight loading (rows 1,2,3)
                move_en   = 1'b1;
                fifo_en   = 1'b1;
                direction = 2'b01;             // v-zigzag
                w_ld_en   = 1'b1;     // overlap: cycles 0,1,2
            end

            PSUM_SHIFT: begin
                move_en       = 1'b1;
                psum_shift_en = 1'b1;
                direction     = 2'b10;
                done          = (cnt == 4'd7);
                w_ld_en   = (cnt >= 4'd4);      // overlap: last 3 fill cycles
            end

            default: ;
        endcase
    end

endmodule