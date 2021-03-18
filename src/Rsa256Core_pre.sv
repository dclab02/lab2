module Montgomery(
	input		   i_clk,
	input		   i_rst,
	input 		   i_start,
	input  [255:0] i_a, 
	input  [255:0] i_b,
	input  [255:0] i_n,
	output [255:0] o_res,
	output 		   done
);

localparam S_IDLE = 0;
localparam S_COMPUTE = 1;
logic [256:0] res_r, res_w;
logic state_r, state_w;
logic done_flag_r, done_flag_w;
logic multiplyer_r, multiplyer_w;
logic [256:0] w1, w2, w3, w4;
logic [7:0] count_r, count_w;

assign o_res = res_r[255:0];
assign done = done_flag_r;
always_comb begin
	res_w = res_r;
	state_w = state_r;
	done_flag_w = done_flag_r;
	multiplyer_w = multiplyer_r; 
	count_w = count_r;
	
	case (state_r)
        S_IDLE : begin
            if (i_start) begin
				state_w = S_COMPUTE;
				res_w = 257'b0;
				done_flag_w = 1'b0;
				multiplyer_w = i_a[0];
				count_w = 0;
			end
        end 
        S_COMPUTE: begin
			multiplyer_w = i_a[count_r];
			w1 = multiplyer_w ? {1'b0, i_b} : 257'b0;
			w2 = w1 + res_r;
			w3 = w2[0] ? (w2 + {1'b0, i_n}) : w2;
			w4 = w3 >> 1;
			if (count_r == 8'd255) begin
				if (w4 >= {1'b0, i_n}) begin
					res_w = w4 - {1'b0, i_n};
				end
				else begin
					res_w = w4;
				end
				state_w = S_IDLE;
				done_flag_w = 1'b1;
			end
			else begin
				res_w = w4;
				count_w = count_r + 1;
			end
        end
	endcase
end

always_ff @(posedge i_clk or posedge i_rst) begin
	if (i_rst) begin
		state_r <= S_IDLE;
		res_r <= 257'b0;
		done_flag_r <= 1'b0;
		multiplyer_r <= 1'b0;
		count_r <= 8'b0;
	end
	else begin
		state_r <= state_w;
		res_r <= res_w;
		done_flag_r <= done_flag_w;
		multiplyer_r <= multiplyer_w;
		count_r = count_w;
	end
end
endmodule

module ModuloProduct(
	input          i_clk,
	input          i_rst,
	input          i_start,
	input  [255:0] i_a, 
	input  [255:0] i_n,
	output         o_finished,
	output [255:0] o_result
);

logic state_r, state_w;
logic [7:0] count_r, count_w;
logic [256:0] res_r, res_w;
logic done_r, done_w;
logic [256:0] w1;

localparam S_IDLE = 0;
localparam S_CALC = 1;

assign o_result = res_r[255:0];
assign o_finished = done_r;
always_comb begin
	state_w = state_r;
	count_w = count_r;
	done_w = done_r;
	res_w = res_r;
	w1 = res_r << 1;
	case(state_r)
		S_IDLE: begin
			if (i_start) begin
				state_w = S_CALC;
				res_w = {1'b0,i_a};
				count_w <= 8'b0;
				done_w <= 1'b0;
			end
		end
		S_CALC: begin
			res_w = (w1 > i_n) ? (w1 - i_n) : w1;
			if (count_r == 8'd255) begin
				state_w = S_IDLE;
				done_w = 1'b1;
			end
			else begin
				count_w = count_r + 1;
			end
		end
	endcase
end

always_ff @(posedge i_clk or posedge i_rst) begin
	if (i_rst) begin
		state_r <= S_IDLE;
		res_r <= 257'b0;
		count_r <= 8'b0;
		done_r <= 1'b0;
	end
	else begin
		res_r <= res_w;
		state_r <= state_w;
		count_r <= count_w;
		done_r <= done_w;
	end
end
endmodule

// module ModuloProduct_Inv(
// 	input          i_clk,
// 	input          i_rst,
// 	input          i_start,
// 	input  [255:0] i_a,
// 	input  [255:0] i_n,
// 	output         o_finished,
// 	output [255:0] o_result
// );

// logic state_r, state_w;
// logic [7:0] count_r, count_w;
// logic [256:0] res_r, res_w;
// logic done_r, done_w;
// logic [256:0] w1, w2;

// localparam S_IDLE = 0;
// localparam S_CALC = 1;

// assign o_result = res_r[255:0];
// assign o_finished = done_r;
// always_comb begin
// 	state_w = state_r;
// 	count_w = count_r;
// 	done_w = done_r;
// 	res_w = res_r;	
// 	case(state_r)
// 		S_IDLE: begin
// 			if (i_start) begin
// 				state_w = S_CALC;
// 				res_w = {1'b0,i_a};
// 				count_w <= 8'b0;
// 				done_w <= 1'b0;
// 			end
// 		end
// 		S_CALC: begin
// 			w1 = res_r[0] ? res_r + i_n : res_r;
// 			w2 = w1 >> 1;
// 			res_w = (w2 >= i_n) ? w2 - i_n : w2;
// 			if (count_r == 8'd255) begin
// 				state_w = S_IDLE;
// 				done_w = 1'b1;
// 			end
// 			else begin
// 				count_w = count_r + 1;
// 			end
// 		end
// 	endcase
// end

// always_ff @(posedge i_clk or posedge i_rst) begin
// 	if (i_rst) begin
// 		state_r <= S_IDLE;
// 		res_r <= 257'b0;
// 		count_r <= 8'b0;
// 		done_r <= 1'b0;
// 	end
// 	else begin
// 		res_r <= res_w;
// 		state_r <= state_w;
// 		count_r <= count_w;
// 		done_r <= done_w;
// 	end
// end
// endmodule
 

module Rsa256Core (
	input          i_clk,
	input          i_rst,
	input          i_start,
	input  [255:0] i_a, // cipher text y
	input  [255:0] i_d, // private key
	input  [255:0] i_n,
	output [255:0] o_a_pow_d, // plain text x
	output         o_finished
);

logic calc_product_r, calc_product_w;
logic [255:0] multiplyer_r, multiplyer_w;
logic [255:0] multiply_result_w, result_w, result_r;
logic MT1_done, MT2_done;
logic [1:0] state_r, state_w;
logic [8:0] count_r, count_w;
logic shift_finish;
logic [255:0] shift_res;
logic done_flag_r, done_flag_w;
logic one_loop_flag_r, one_loop_flag_w;
logic calc_mont1_r, calc_mont1_w, calc_mont2_r, calc_mont2_w;
logic no_multipy_r, no_multipy_w;
logic [255:0] square_result_w;
logic [255:0] init_a_w, init_a_r;
logic calc_product_inv_r, calc_product_inv_w;
logic  shift_inv_res;

localparam S_IDLE = 0;
localparam S_PREP = 1;
localparam S_CALC = 2;
localparam S_WAIT = 3;
localparam S_INV = 4;

// operations for RSA256 decryption
// namely, the Montgomery algorithm
Montgomery mont1( .i_clk(i_clk), .i_rst(i_rst), .i_start(calc_mont1_w), .i_a(multiplyer_r), .i_b(result_r), .i_n(i_n), .o_res(multiply_result_w), .done(MT1_done));
Montgomery mont2( .i_clk(i_clk), .i_rst(i_rst), .i_start(calc_mont2_w), .i_a(result_r), .i_b(result_r), .i_n(i_n), .o_res(square_result_w), .done(MT2_done));
ModuloProduct MP(.i_clk(i_clk), .i_rst(i_rst), .i_start(calc_product_w),  .i_a(init_a_w), .i_n(i_n), .o_finished(shift_finish), .o_result(shift_res));
// ModuloProduct_Inv MP_INV(.i_clk(i_clk), .i_rst(i_rst), .i_start(calc_product_inv_w),  .i_a(result_r), .i_n(i_n), .o_finished(shift_inv_finish), .o_result(shift_inv_res));

assign o_a_pow_d = result_r;
assign o_finished = done_flag_r;
always_comb begin
	state_w = state_r;
	calc_product_w = calc_product_r;
	calc_product_inv_w = calc_product_inv_r;
	count_w = count_r;
	no_multipy_w = no_multipy_r;
	multiplyer_w = multiplyer_r;
	one_loop_flag_w = one_loop_flag_r;
	calc_mont1_w = calc_mont1_r;
	calc_mont2_w = calc_mont2_r;
	result_w = result_r;
	init_a_w = init_a_r;
	case(state_r)
		S_IDLE : begin
			if (i_start) begin
				calc_product_w = 1'b1;
				state_w = S_PREP;
				done_flag_w = 1'b0;
				count_w <= 8'd0;;
				calc_mont1_w = 1'b0;
				calc_mont2_w = 1'b0;
				no_multipy_w = 1'b0;
				multiplyer_w = 256'd1;
				init_a_w = i_a;
				result_w <= 257'b0;
				one_loop_flag_w <= 1'b0;
			end
		end	
		S_PREP : begin
			if (shift_finish) begin
				result_w = shift_res;
				state_w = S_CALC;
				calc_product_w = 1'b0;
			end
		end	
		S_CALC : begin
			if (~calc_mont1_r & ~no_multipy_r & ~one_loop_flag_r & ~calc_mont2_r ) begin
				
				state_w = S_WAIT;
				if (i_d[count_r]) begin
					calc_mont1_w = 1'b1;					
				end
				else begin
					no_multipy_w = 1'b1;
				end
			end
			else if (~one_loop_flag_r & ( (MT1_done & calc_mont2_r) | no_multipy_r)) begin
				one_loop_flag_w = 1'b1;
				no_multipy_w = 1'b0;
				state_w = S_WAIT;
			end
			else if (MT2_done) begin
				one_loop_flag_w = 1'b0;
				count_w = count_r + 1;
				if (count_r == 9'd255) begin // done
					result_w = multiplyer_r;
					done_flag_w = 1'b1;
					state_w = S_IDLE;
				end
				
			end
		end
		S_WAIT : begin
			if ((MT1_done & ~calc_mont2_r ) | no_multipy_r) begin
				calc_mont1_w = 1'b0;
				calc_mont2_w = 1'b1;
				if (~no_multipy_r) begin
					multiplyer_w = multiply_result_w;
				end
				state_w = S_CALC;
			end
			else if (MT2_done & calc_mont2_r) begin
				calc_mont2_w = 1'b0;
				state_w = S_CALC;
				result_w = square_result_w;
			end			
		end
		// S_INV : begin
		// 	if (shift_inv_finish) begin
		// 		result_w = shift_inv_res;
		// 		state_w = S_IDLE;
		// 		calc_product_inv_w = 1'b0;
		// 	end		
		// end
	endcase
end

always_ff @(posedge i_clk or posedge i_rst) begin
	
	if (i_rst) begin
		state_r <= S_IDLE;
		result_r <= 257'b0;
		done_flag_r <= 1'b0;
		multiplyer_r <= 256'd1;
		calc_mont1_r <= 1'b0;
		calc_mont2_r <= 1'b0;
		calc_product_r <= 1'b0;
		count_r <= 9'd0;
		no_multipy_r <= 1'b0;
		one_loop_flag_r <= 1'b0;
		init_a_r <= 256'b0;
		// calc_product_inv_r <= 1'b0;
	end
	else begin
		state_r <= state_w;
		result_r <= result_w;
		done_flag_r <= done_flag_w;
		multiplyer_r <= multiplyer_w;
		calc_mont1_r <= calc_mont1_w;
		calc_mont2_r <= calc_mont2_w;
		calc_product_r <= calc_product_w;
		count_r <= count_w;
		no_multipy_r <= no_multipy_w;
		one_loop_flag_r <= one_loop_flag_w ;
		init_a_r <= init_a_w;
		// calc_product_inv_r <= calc_product_inv_w;
	end
end
endmodule
