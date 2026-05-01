module fifo9 #(
    parameter int DATA_W = 13  // default matches ACC_W
)(
    input  logic              clk,
    input  logic              rst_n,
    input  logic              wr_en,
    input  logic [DATA_W-1:0] wr_data,
    output logic              full,
    input  logic              rd_en,
    output logic [DATA_W-1:0] rd_data,
    output logic              empty
);

    localparam int DEPTH   = 9;
    localparam int PTR_W   = $clog2(DEPTH) + 1;  // 4 bits: 0..8
    localparam int COUNT_W = $clog2(DEPTH + 1);   // 4 bits: 0..9

    logic [DATA_W-1:0] buffer [0:DEPTH-1];

    logic [PTR_W-1:0]   wr_ptr;
    logic [PTR_W-1:0]   rd_ptr;
    logic [COUNT_W-1:0] count;

    assign full    = (count == DEPTH);
    assign empty   = (count == 0);
    assign rd_data = buffer[rd_ptr];  // combinational read — valid same cycle as rd_en

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            count  <= '0;
        end else begin
            if (wr_en && !full) begin
                buffer[wr_ptr] <= wr_data;
                wr_ptr         <= (wr_ptr == DEPTH-1) ? '0 : wr_ptr + 1;
            end
            if (rd_en && !empty) begin
                rd_ptr         <= (rd_ptr == DEPTH-1) ? '0 : rd_ptr + 1;
            end
            case ({wr_en && !full, rd_en && !empty})
                2'b10:   count <= count + 1;  // write only
                2'b01:   count <= count - 1;  // read only
                default: ;                     // both or neither — no change
            endcase
        end
    end

endmodule