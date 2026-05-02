module tb_top();

reg [4:0] x0, x1, x2, x3;
reg [4:0] w04, w14, w24, w34;
reg [4:0] w05, w15, w25, w35;
reg [4:0] w06, w16, w26, w36;
reg [4:0] w07, w17, w27, w37;
reg [4:0] w48, w58, w68, w78;
reg [4:0] w49, w59, w69, w79;

reg clk;

wire [16:0] out0, out1;
wire out10_ready, out11_ready;

reg in_ready;
// Top module
// Instantiation of top module
// Please replace the instantiation with the top module of your gate level model
// Look for 'test failed' in the message. If there is no such message then your output matches the golden outputs. 


top top(.x0(x0), .x1(x1), .x2(x2), .x3(x3), 
        .w04(w04), .w14(w14), .w24(w24), .w34(w34), 
        .w05(w05), .w15(w15), .w25(w25), .w35(w35),
        .w06(w06), .w16(w16), .w26(w26), .w36(w36),
        .w07(w07), .w17(w17), .w27(w27), .w37(w37),
        .w48(w48), .w58(w58), .w68(w68), .w78(w78),
        .w49(w49), .w59(w59), .w69(w69), .w79(w79),
        .out0(out0), .out1(out1),
        .in_ready(in_ready), .out0_ready(out10_ready), .out1_ready(out11_ready),
        .clk(clk));

initial begin

    clk = 0;
    in_ready = 1; 
    
    x0 = 5'b10000; //4
    x1 = 5'b10000; //2
    x2 = 5'b10000; //4
    x3 = 5'b10000; //1
    
    w04 = 5'b10000; //15
    w14 = 5'b10000; //15
    w24 = 5'b10000; //15
    w34 = 5'b10000; //15
    w05 = 5'b10000; //15
    w15 = 5'b10000; //15
    w25 = 5'b10000; //0
    w35 = 5'b10000; //14
    w06 = 5'b10000; //3
    w16 = 5'b10000; //6
    w26 = 5'b10000; //0
    w36 = 5'b10000; //15
    w07 = 5'b10000; //9
    w17 = 5'b10000; //0
    w27 = 5'b10000; //15
    w37 = 5'b10000; //0
    w48 = 5'b10000; //0
    w58 = 5'b10000; //0
    w68 = 5'b10000; //3
    w78 = 5'b10000; //11
    w49 = 5'b10000; //12
    w59 = 5'b10000; //-16
    w69 = 5'b10000; //-16
    w79 = 5'b10000; //-16


    #40
    if (out0 == -17'd65536)
        $display("-----------out0 is correct-----------------");
    else
        $display("-----------out0 is incorrect-----------");

    if (out1 == -17'd65536)
        $display("-----------out1 is correct-----------");
    else
        $display("-----------out1 is incorrect-----------");


    if (out0 == -17'd65536 && out1 == -17'd65536)
        $display("*********** ALL TESTS PASSED *********");
    else
        $display("*********** SOME TEST(S) FAILED *********");


end


always
    #1 clk = !clk;


initial
    #100 $finish;


endmodule
