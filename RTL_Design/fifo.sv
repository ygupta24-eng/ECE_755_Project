module fifo4 #(
    parameter int DATA_W = 8
)(
    input  logic              clk,
    input  logic              rst_n,

    // Write side
    input  logic              wr_en,
    input  logic [DATA_W-1:0] wr_data,
    output logic              full,

    // Read side
    input  logic              rd_en,
    output logic [DATA_W-1:0] rd_data,
    output logic              empty
);

    // ------------------------------------------------------------
    // Storage
    // ------------------------------------------------------------
    logic [DATA_W-1:0] buffer [0:3];   // depth = 4

    // Pointers and count
    logic [1:0] wr_ptr;
    logic [1:0] rd_ptr;
    logic [2:0] count;              // can count 0..4

    // ------------------------------------------------------------
    // Status flags
    // ------------------------------------------------------------
    assign full  = (count == 4);
    assign empty = (count == 0);

    // Read data is always the current head
    assign rd_data = buffer[rd_ptr];

    // ------------------------------------------------------------
    // FIFO logic
    // ------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            count  <= 0;
        end else begin

            // WRITE
            if (wr_en && !full) begin
                buffer[wr_ptr] <= wr_data;
                wr_ptr      <= wr_ptr + 1;
            end

            // READ
            if (rd_en && !empty) begin
                rd_ptr <= rd_ptr + 1;
            end

            // COUNT update
            case ({wr_en && !full, rd_en && !empty})
                2'b10: count <= count + 1; // write only
                2'b01: count <= count - 1; // read only
                default: /* no change */ ;
            endcase
        end
    end

endmodule