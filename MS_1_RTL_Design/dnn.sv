module top (x0, x1, x2, x3, w04, w05, w06, w07, w14, w15, w16, w17, w24, w25, w26, w27, w34, w35, w36,
w37, w48, w58, w49, w59, w68, w69, w78, w79, out0, out1, in_ready, out0_ready, out1_ready, clk);
input signed [4:0] x0, x1, x2, x3, w04, w05, w06, w07, w14, w15, w16, w17, w24, w25, w26, w27, w34, w35, w36, w37,
w48, w58, w49, w59, w68, w69, w78, w79;
input in_ready;
input clk;
output reg signed [16:0] out0, out1;
output logic out0_ready, out1_ready;

// Implementation of the neural network
logic signed [9:0] y04, y05, y06, y07;
logic signed [9:0] y14, y15, y16, y17;
logic signed [9:0] y24, y25, y26, y27;
logic signed [9:0] y34, y35, y36, y37;

assign y04 = x0 * w04;
assign y05 = x0 * w05; 
assign y06 = x0 * w06; 
assign y07 = x0 * w07; 
assign y14 = x1 * w14; 
assign y15 = x1 * w15;
assign y16 = x1 * w16; 
assign y17 = x1 * w17; 
assign y24 = x2 * w24; 
assign y25 = x2 * w25; 
assign y26 = x2 * w26; 
assign y27 = x2 * w27; 
assign y34 = x3 * w34; 
assign y35 = x3 * w35; 
assign y36 = x3 * w36; 
assign y37 = x3 * w37; 

logic signed [11:0] y4, y5, y6, y7;

assign y4 = y04 + y14 + y24 + y34;
assign y5 = y05 + y15 + y25 + y35;
assign y6 = y06 + y16 + y26 + y36;
assign y7 = y07 + y17 + y27 + y37;

//pipeline registers
reg signed[11:0] p4, p5, p6, p7;

always_ff @(posedge clk) begin
    if(in_ready) begin
        p4 <= y4;
        p5 <= y5;
        p6 <= y6;
        p7 <= y7;
    end
end

//relu logic for h)idden layer
logic signed [11:0] relu4, relu5, relu6, relu7;

assign relu4 = (p4 < 12'sd0) ? 12'sd0 : p4;
assign relu5 = (p5 < 12'sd0) ? 12'sd0 : p5;
assign relu6 = (p6 < 12'sd0) ? 12'sd0 : p6;
assign relu7 = (p7 < 12'sd0) ? 12'sd0 : p7;

logic signed [16:0] y48, y58, y49, y59, y68, y69, y78, y79;

assign y48 = relu4 * w48;
assign y49 = relu4 * w49;
assign y58 = relu5 * w58;
assign y59 = relu5 * w59;
assign y68 = relu6 * w68;
assign y69 = relu6 * w69;
assign y78 = relu7 * w78;
assign y79 = relu7 * w79;

logic signed [16:0] y8, y9;

assign y8 = y48 + y58 + y68 + y78;
assign y9 = y49 + y59 + y69 + y79;

// Ready signals
// Assuming a simple 2-cycle latency for the pipeline
logic [1:0] ready_pipeline;
always_ff @(posedge clk) begin
    ready_pipeline[0] <= in_ready;
    ready_pipeline[1] <= ready_pipeline[0];
end

assign out0_ready = ready_pipeline[1];
assign out1_ready = ready_pipeline[1];

//pipeline registers
always_ff @(posedge clk) begin
    if(ready_pipeline[0]) begin
        out0 <= y8;
        out1 <= y9;
    end
end

endmodule
