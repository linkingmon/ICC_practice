module test(
	clk,
	a,
	b,
	c,
);
input clk;
input [9:0] a;
input [9:0] b;
output reg [19:0] c;

wire [19:0] c_w;

assign c_w = a*b;
always @(posedge clk) c <= c_w;
endmodule
