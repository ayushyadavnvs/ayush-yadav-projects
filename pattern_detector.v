// // pattern is 0110 with overlap
// module pd(clk , x , y);
// output reg y ;
// input clk , x;
// reg [1:0] state;
// parameter s0 = 2'b00 , s1 = 2'b01 , s2 = 2'b10 , s3 = 2'b11;
// always @(posedge clk)
// begin 
//     case(state)
//     s0: begin 
//         state <= x? s0 : s1;
//     end 
//     s1: begin 
//         state <= x? s2 : s1;

//     end
//     s2: begin 
//         state <= x? s3 : s1;

//     end
//     s3: begin 
//         state <= x? s0 : s1;

//     end
//     default : state <= s0;
//     endcase
// end
// always @(state)
// begin 
//     case(state)
//     s0: y = 0;
//     s1: y = 0;
//     s2: y = 0;
//     s3: y = x?0:1;
//     endcase
// end
// endmodule 


module pd(clk, x, y);
    output reg y;
    input clk, x;
    reg [1:0] state;

    // State encoding
    parameter s0 = 2'b00, s1 = 2'b01, s2 = 2'b10, s3 = 2'b11;

    // Initialize state
    initial state = s0;

    // State transition logic
    always @(posedge clk) begin
        case (state)
            s0: state <= x ? s0 : s1;
            s1: state <= x ? s2 : s1;
            s2: state <= x ? s3 : s1;
            s3: state <= x ? s2 : s1;  // Key fix: Overlapping transition
            default: state <= s0;
        endcase
    end

    // Output logic (moved inside clocked always block)
    always @(posedge clk) begin
        case (state)
            s3: y <= (x == 0) ? 1 : 0;  // y=1 when pattern 0110 is detected
            default: y <= 0;
        endcase
    end
endmodule