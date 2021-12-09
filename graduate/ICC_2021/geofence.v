module geofence ( clk,reset,X,Y,R,valid,is_inside);
input clk;
input reset;
input [9:0] X;
input [9:0] Y;
input [10:0] R;
output valid;
output is_inside;

parameter S_IDLE = 0;
parameter S_COLLECT = 1;
parameter S_SORT = 2;
parameter S_COORD = 3;
parameter S_FINAL = 4;
parameter S_WAIT = 5;
parameter S_DIVX = 6;
parameter S_DIVY = 7;

reg signed [10:0] X_r;
reg signed [10:0] Y_r;
reg signed [11:0] R_r;

reg signed [10:0] X_ary [0:5], X_ary_r [0:5];
reg signed [10:0] Y_ary [0:5], Y_ary_r [0:5];
reg signed [11:0] R_ary [0:5], R_ary_r [0:5];

reg [2:0] state, state_r;
reg [5:0] counter, counter_r;
reg [2:0] counter2, counter2_r;

reg signed [11:0] a, b, c, d;
wire signed [21:0] o_data;
reg signed [21:0] DET, DET_r;

reg signed [21:0] B4, B4_r, DIF_r, DIF;
reg signed [32:0] B2, B2_r;
reg signed [32:0] X_ref, Y_ref, X_ref_r, Y_ref_r;
reg signed [11:0] X_ref_norm, Y_ref_norm, X_ref_norm_r, Y_ref_norm_r;


reg valid_r, valid_w;
reg is_inside_r, is_inside_w;

reg [21:0] top;
reg [11:0] down;
wire [11:0] div_data;

assign div_data = (top / down);

integer i;

op_unit u_op_unit(
	.a(a),
	.b(b),
	.c(c),
	.d(d),
	.o_data(o_data)
);

// debug mode
// task cal_R;
// 	input signed [21:0] X_0;
// 	input signed [21:0] Y_0;
// 	input signed [21:0] X_ref;
// 	input signed [21:0] Y_ref;
// 	input signed [21:0] R_0;
// 	begin
// 		$display("R is %d for (%d,%d) %d", $sqrt((X_0-X_ref)*(X_0-X_ref)+(Y_0-Y_ref)*(Y_0-Y_ref)), X_0, Y_0, R_0);	
// 	end
// endtask

// always @(negedge clk) begin
// 	case(state_r)
// 		S_IDLE: begin
// 		end
// 		S_COLLECT: begin
// 			if(state == S_SORT) begin
// 				$display("Values in X_ary");
// 				$display("%d %d %d %d %d %d", X_ary[0], X_ary[1], X_ary[2], X_ary[3], X_ary[4], X_ary[5]);	
// 				$display("--------------------");
// 			end
// 		end
// 		S_SORT: begin
// 			// $display("Check (%d,%d) & (%d,%d) op %d SWAP? %d",a,b,c,d,o_data,o_data>0);
// 			// $display("Get (%d,%d) & (%d,%d) with ref (%d,%d)",X_ary_r[counter_r],Y_ary_r[counter_r],X_ary_r[counter_r+1],Y_ary_r[counter_r+1],X_ary_r[0],Y_ary_r[0]);
// 			// $display("%d %d %d %d %d %d", X_ary[0], X_ary[1], X_ary[2], X_ary[3], X_ary[4], X_ary[5]);	
// 			if(state == S_COORD) begin
// 				$display("Values in X_ary after sort");
// 				$display("%d %d %d %d %d %d", X_ary[0], X_ary[1], X_ary[2], X_ary[3], X_ary[4], X_ary[5]);	
// 				$display("--------------------");
// 			end
// 		end
// 		S_COORD: begin
// 			if(state == S_FINAL) begin
// 				$display("Getting (%d,%d) %d", X_ary_r[0], Y_ary_r[0], R_ary_r[0]);
// 				$display("Getting (%d,%d) %d", X_ary_r[2], Y_ary_r[2], R_ary_r[2]);
// 				$display("Getting (%d,%d) %d", X_ary_r[4], Y_ary_r[4], R_ary_r[4]);
// 				$display("The reference point is at (%d,%d)", X_ref, Y_ref);
// 				cal_R(X_ary_r[0],Y_ary_r[0],X_ref,Y_ref,R_ary_r[0]);
// 				cal_R(X_ary_r[1],Y_ary_r[1],X_ref,Y_ref,R_ary_r[1]);
// 				cal_R(X_ary_r[2],Y_ary_r[2],X_ref,Y_ref,R_ary_r[2]);
// 				cal_R(X_ary_r[3],Y_ary_r[3],X_ref,Y_ref,R_ary_r[3]);
// 				cal_R(X_ary_r[4],Y_ary_r[4],X_ref,Y_ref,R_ary_r[4]);
// 				cal_R(X_ary_r[5],Y_ary_r[5],X_ref,Y_ref,R_ary_r[5]);
// 				$display("X,Y ref are (%d,%d)", X_ref_r, Y_ref_r);
// 			end
// 		end
// 		S_FINAL: begin
// 			$display("o_data:%d B2_r:%d", o_data, B2_r);
// 		end
// 	endcase
	
// end



wire signed [11:0] cur_X, cur_Y, cur_R;
wire signed [11:0] next_X, next_Y, next_R;

assign valid = valid_r;
assign is_inside = is_inside_r;
assign cur_X = X_ary_r[counter_r];
assign cur_Y = Y_ary_r[counter_r];
assign cur_R = R_ary_r[counter_r];
assign next_X = X_ary_r[counter_r+1];
assign next_Y = Y_ary_r[counter_r+1];
assign next_R = R_ary_r[counter_r+1];

always @(*) begin
	state = state_r;
	counter = counter_r;
	counter2 = counter2_r;
	for(i=0;i<6;i=i+1) begin
		X_ary[i] = X_ary_r[i];
		Y_ary[i] = Y_ary_r[i];
		R_ary[i] = R_ary_r[i];
	end
	a = 11'sbx;
	b = 11'sbx;
	c = 11'sbx;
	d = 11'sbx;
	B4 = B4_r;
	B2 = B2_r;
	X_ref = X_ref_r;
	Y_ref = Y_ref_r;
	X_ref_norm = X_ref_norm_r;
	Y_ref_norm = Y_ref_norm_r;
	DIF = DIF_r;
	valid_w = 0;
	is_inside_w = 1'bx;
	DET = DET_r;
	top = 11'bx;
	down = 11'bx;
	case(state_r)
		S_IDLE: begin
			state = S_COLLECT;
			X_ref_norm = 0;
			Y_ref_norm = 0;
		end
		S_COLLECT: begin
			counter = counter_r + 1;
			X_ary[counter_r] = X_r;
			Y_ary[counter_r] = Y_r;
			R_ary[counter_r] = R_r; 
			if(counter_r == 5) state = S_SORT;
			if(counter_r == 5) counter = 1;
		end
		S_SORT: begin
			a = X_ary_r[counter_r] - X_ary_r[0];
			b = Y_ary_r[counter_r] - Y_ary_r[0];
			c = X_ary_r[counter_r+1] - X_ary_r[0];
			d = Y_ary_r[counter_r+1] - Y_ary_r[0];
			// swap if +
			X_ary[counter_r] = (o_data > 0) ? next_X : cur_X;
			Y_ary[counter_r] = (o_data > 0) ? next_Y : cur_Y;
			R_ary[counter_r] = (o_data > 0) ? next_R : cur_R;
			X_ary[counter_r+1] = (o_data > 0) ? cur_X : next_X;
			Y_ary[counter_r+1] = (o_data > 0) ? cur_Y : next_Y;
			R_ary[counter_r+1] = (o_data > 0) ? cur_R : next_R;
			// counter update 
			counter = (counter2_r == 4) ? 0 : (counter_r == 4) ? 1 : counter_r + 1;
			counter2 = (counter2_r == 4) ? 0 : (counter_r == 4) ? counter2_r + 1 : counter2_r;
			if(counter2_r == 4) state = S_COORD;
		end
		S_COORD: begin
			counter = counter_r + 1;
			case(counter_r) 
				0: begin // P0^2
					a = X_ary_r[0];
					b = Y_ary_r[0];
					c = -Y_ary_r[0];
					d = X_ary_r[0];
					B2 = o_data;
					B4 = o_data;
				end
				1: begin // P2^2
					a = X_ary_r[2];
					b = Y_ary_r[2];
					c = -Y_ary_r[2];
					d = X_ary_r[2];
					B2 = B2_r - o_data;
				end
				2: begin // R2^2-R0^2
					a = R_ary_r[2];
					b = R_ary_r[0];
					c = R_ary_r[0];
					d = R_ary_r[2];
					B2 = (B2_r + o_data) >>> 1;
				end
				3: begin // P2^2
					a = X_ary_r[4];
					b = Y_ary_r[4];
					c = -Y_ary_r[4];
					d = X_ary_r[4];
					B4 = B4_r - o_data;
				end
				4: begin // R2^2-R0^2
					a = R_ary_r[4];
					b = R_ary_r[0];
					c = R_ary_r[0];
					d = R_ary_r[4];
					B4 = (B4_r + o_data) >>> 1;
				end
				5: begin
					a = Y_ary_r[0] - Y_ary_r[4];
					b = Y_ary_r[0] - Y_ary_r[2];
					c = B4_r >>> 11;
					d = B2_r >>> 11;
					X_ref = o_data <<< 11;
				end
				6: begin
					a = Y_ary_r[0] - Y_ary_r[4];
					b = Y_ary_r[0] - Y_ary_r[2];
					c = B4_r - ((B4_r >>> 11) <<< 11);
					d = B2_r - ((B2_r >>> 11) <<< 11);
					X_ref = X_ref_r + o_data;
				end
				7: begin
					a = X_ary_r[4] - X_ary_r[0];
					b = X_ary_r[2] - X_ary_r[0];
					c = (B4_r >>> 11);
					d = (B2_r >>> 11);
					Y_ref = o_data <<< 11;
				end
				8: begin
					a = X_ary_r[4] - X_ary_r[0];
					b = X_ary_r[2] - X_ary_r[0];
					c = B4_r - ((B4_r >>> 11) <<< 11);
					d = B2_r - ((B2_r >>> 11) <<< 11);
					Y_ref = Y_ref_r + o_data;
					B2 = 0;
				end
				9: begin
					a = X_ary_r[0] - X_ary_r[2];
					b = Y_ary_r[0] - Y_ary_r[2];
					c = X_ary_r[0] - X_ary_r[4];
					d = Y_ary_r[0] - Y_ary_r[4];
					DET = o_data;
				end
				10: begin
					X_ref = (X_ref_r > 0) ? X_ref_r : -X_ref;
					Y_ref = (Y_ref_r > 0) ? Y_ref_r : -Y_ref;
					DET = (DET_r > 0) ? DET_r : -DET_r;
				end
				11: begin
					top = X_ref_r[32-:22];
					down = DET[21-:11];
					X_ref = div_data;
				end
				12: begin
					top = Y_ref_r[32-:22];
					down = DET[21-:11];
					Y_ref = div_data;
				end
			endcase
			if(counter_r == 12) state = S_FINAL;
			if(counter_r == 12) counter = 0;
		end
		// S_DIVX: begin
		// 	// (33b/22b)
		// 	counter = counter_r + 1;
		// 	if(X_ref_r > (DET_r <<< 1) ) begin
		// 		X_ref = (X_ref_r >>> 1); 
		// 		counter2 = counter_r + 1;
		// 	end
		// 	else if(X_ref_r > DET_r ) begin
		// 		X_ref = X_ref_r - DET_r; 
		// 		X_ref_norm = (X_ref_norm_r <<< 1) + 1;
		// 		DET = (DET_r >>> 1);
		// 	end
		// 	else begin
		// 		state = S_DIVY;
		// 		counter = 0;
		// 		counter2 = 0;
		// 		X_ref_norm = (X_ref_norm_r <<< counter2_r);
		// 	end
		// 	$display("%d %d %d",X_ref_norm, X_ref_r, counter2_r);
		// end
		// S_DIVY: begin
		// 	counter = counter_r + 1;
		// 	if(Y_ref_r > (DET_r <<< 1) ) begin
		// 		Y_ref = (Y_ref_r >>> 1); 
		// 		counter2 = counter_r + 1;
		// 	end
		// 	else if(Y_ref_r > DET_r ) begin
		// 		Y_ref = Y_ref_r - DET_r; 
		// 		Y_ref_norm = (Y_ref_norm_r <<< 1) + 1;
		// 		DET = (DET_r >>> 1);
		// 	end
		// 	else begin
		// 		Y_ref_norm = (Y_ref_norm_r <<< 1);
		// 		DET = (DET_r >>> 1);
		// 	end
		// 	if(counter_r == 10) state = S_FINAL;
		// 	if(counter_r == 10) counter = 0;
		// 	if(counter_r == 10) counter2 = 0;
		// 	if(counter_r == 10) Y_ref_norm = (Y_ref_norm_r <<< counter2_r);
		// end
		S_FINAL: begin
			counter = (counter2_r == 1) ? counter_r + 1 : counter_r;
			counter2 = (counter2_r == 1) ? 0 : 1;
			if(counter2_r == 0) begin
				a = X_ary_r[counter_r] - X_ref;
				b = Y_ary_r[counter_r] - Y_ref;
				c = (counter_r == 5) ? (X_ary_r[0] - X_ref) : (X_ary_r[counter_r+1] - X_ref);
				d = (counter_r == 5) ? (Y_ary_r[0] - Y_ref) : (Y_ary_r[counter_r+1] - Y_ref);
				B2 = (o_data > 0) ? B2_r + o_data : B2_r - o_data;
			end
			else begin
				a = X_ary_r[counter_r];
				b = Y_ary_r[counter_r];
				c = (counter_r == 5) ? X_ary_r[0] : X_ary_r[counter_r+1];
				d = (counter_r == 5) ? Y_ary_r[0] : Y_ary_r[counter_r+1];
				B2 = B2_r + o_data;
			end
			if(counter_r == 6 && counter2_r == 0) begin
				is_inside_w = (B2_r > 0) ? 0 : 1;
				valid_w = 1;
				state = S_WAIT;
				counter = 0;
				counter2 = 0;
			end
		end
		S_WAIT: begin
			state = S_IDLE;
		end
	endcase
end

always @(posedge clk or posedge reset) begin
	if(reset) begin
		state_r <= S_IDLE;
		counter_r <= 0;
		counter2_r <= 0;
		X_ref_norm_r <= 0;
		Y_ref_norm_r <= 0;
	end
	else begin
		for(i=0;i<6;i=i+1) begin
			X_ary_r[i] <= X_ary[i];
			Y_ary_r[i] <= Y_ary[i];
			R_ary_r[i] <= R_ary[i];
		end
		X_r <= $signed({1'b0,X});
		Y_r <= $signed({1'b0,Y});
		R_r <= $signed({1'b0,R});
		state_r <= state;
		counter_r <= counter;
		counter2_r <= counter2;
		B2_r <= B2;
		B4_r <= B4;
		X_ref_r <= X_ref;
		Y_ref_r <= Y_ref;
		X_ref_norm_r <= X_ref_norm;
		Y_ref_norm_r <= Y_ref_norm;
		valid_r <= valid_w;
		is_inside_r <= is_inside_w;
		DET_r <= DET;
	end
end


endmodule

module op_unit(
	a,
	b,
	c,
	d,
	o_data
);

// | a b |
// | c d |

input signed [11:0] a, b, c, d;
output signed [21:0] o_data;

assign o_data = a*d - b*c;

endmodule