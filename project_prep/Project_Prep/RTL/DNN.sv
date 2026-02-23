module DNN(x0,x1,x2,x3,       //Inputs to the DNN
           w04,w05,w06,w07,   //Weights from Input layer to Hidden Layer 1
           w14,w15,w16,w17,   //Weights from Input layer to Hidden Layer 1
           w24,w25,w26,w27,   //Weights from Input layer to Hidden Layer 1
           w34,w35,w36,w37,   //Weights from Input layer to Hidden Layer 1
           w48,w49,           //Weights from Hidden Layer 1 to Output Layer
           w58,w59,           //Weights from Hidden Layer 1 to Output Layer
           w68,w69,            //Weights from Hidden Layer 1 to Output Layer
           w78,w79,            //Weights from Hidden Layer 1 to Output Layer
           in_ready,          //Input ready signal
           out0_ready,        //Output 0 ready signal
           out1_ready,        //Output 1 ready signal
           clk,               //Clock signal
           out0,              //Output 0 of the DNN
           out1);             //Output 1 of the DNN 
    
    //Inputs to the DNN
    input signed [4:0] x0,x1,x2,x3;

    //Weights from Input layer to Hidden Layer 1
    input signed [4:0] w04,w05,w06,w07;
    input signed [4:0] w14,w15,w16,w17;
    input signed [4:0] w24,w25,w26,w27;
    input signed [4:0] w34,w35,w36,w37;

    //Weights from Hidden Layer 1 to Output Layer
    input signed [4:0] w48,w49;
    input signed [4:0] w58,w59;
    input signed [4:0] w68,w69;
    input signed [4:0] w78,w79;

    input in_ready;                 //Input ready signal
    output out0_ready;              //Output 0 ready signal
    output out1_ready;              //Output 1 ready signal

    input clk;                      //Clock signal
    output reg signed [16:0] out0;  //Output 0 of the DNN
    output reg signed [16:0] out1;  //Output 1 of the DNN

    //Internal signals
    wire signed [11:0] y0_pre, y1_pre, y2_pre, y3_pre; //Pre-activation outputs of Hidden Layer 1
    wire signed [11:0] y0_post, y1_post, y2_post, y3_post; //Post-activation outputs of Hidden Layer 1

    //Instantiate Hidden Layer 1
    assign y0_pre = (x0 * w04) + (x1 * w14) + (x2 * w24) + (x3 * w34);
    assign y1_pre = (x0 * w05) + (x1 * w15) + (x2 * w25) + (x3 * w35);
    assign y2_pre = (x0 * w06) + (x1 * w16) + (x2 * w26) + (x3 * w36);
    assign y3_pre = (x0 * w07) + (x1 * w17) + (x2 * w27) + (x3 * w37);

    //ReLU Activation Function
    assign y0_post = (y0_pre > 0) ? y0_pre : 0;
    assign y1_post = (y1_pre > 0) ? y1_pre : 0;
    assign y2_post = (y2_pre > 0) ? y2_pre : 0;
    assign y3_post = (y3_pre > 0) ? y3_pre : 0;

    // Instantiate Output Layer
    always @(posedge clk) begin
        if(in_ready) begin
            out0 <= (y0_post * w48) + (y1_post * w58) + (y2_post * w68) + (y3_post * w78);
            out1 <= (y0_post * w49) + (y1_post * w59) + (y2_post * w69) + (y3_post * w79);
        end
    end
endmodule