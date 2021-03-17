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
logic [256:0] res_r, res_w, res_n_w;
logic state_r, state_w;
logic done_flag_r, done_flag_w;
logic multipyer_r, multipyer_w;
logic [256:0] w1, w2;
logic [7:0] count_r;

assign o_res = res_r[255:0];
assign done = done_flag_r;
always_comb begin
	res_w = res_r;
	state_w = state_r;
	done_flag_w = done_flag_r;
	multipyer_w = multipyer_r; 

	case (state_r)
        S_IDLE : begin
            
        end 
        S_COMPUTE: begin
			w1 = multipyer_w ? {1'b0, i_a} : 257'b0;
			w2 = w1 + res_w;
			w3 = (w2[0] & 1'b1) ? (w2 + {1'b0, i_n}) : w2;
			w4 = w3 >> 1;
			if (count_r == 8'd255) begin
				if w4 > {1'b0, i_n} begin
					res_n_w = w4 - {1'b0, i_n};
				end
				else begin
					res_n_w = w4;
				end
				state_w = S_IDLE;
				done_flag_w = 1'b1;
			end
			else begin
				res_n_w = w4;
				state_w = S_SHIFT;
			end
        end
		S_SHIFT: begin
            count_n = count_r + 1;
			multipyer_w = i_b[count_r];
			state_w = S_COMPUTE;
        end
	endcase
end

always_ff @(posedge i_clk or posedge i_rst or posedge i_start) begin
	if (i_rst) begin
		state_r <= S_IDLE;
		res_r <= 257'b0;
		done_flag_r <= 1'b0;
		multipyer_r <= 1'b0;
		count_r <= 8'b0;
	end
	else if (i_start) begin
		state_r <= S_COMPUTE;
		res_r <= 257'b0;
		done_flag_r <= 1'b0;
		multipyer_r <= i_b[0];
		count_r <= 8'b0;
	end
	else begin
		state_r <= state_w;
		res_r <= res_n_w;
		done_flag_r <= done_flag_w;
		multipyer_r <= multipyer_w;
		count_r = count_n;
	end
end
endmodule

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

logic calc_product;
logic [256:0] Multiplicand;
logic [256:0] Multiplyer;
logic [256:0] result;
logic MP_done;
logic state_r, state_w;
localparam S_IDLE = 0;
localparam S_PREP = 1;
localparam S_CALC = 2;
localparam S_WAIT = 3;
localparam S_SHIFT = 4;
// operations for RSA256 decryption
// namely, the Montgomery algorithm
Montgomery mont( .i_clk(i_clk), .i_rst(i_rst), .i_start(calc_product), .i_a(Multiplicand), .i_b(Multiplyer), .i_n(i_n), .o_res(result), .done(MP_done));

always_comb begin
case(state_r)
	S_IDLE : begin
		
	end	
	S_PREP : begin
		A_K = 
	end	
	S_CALC : begin
		calc_product = 1'b1;
		state_w = S_WAIT
	end
	S_WAIT : begin
		calc_product = 1'b0;
	end
	S_SHIFT : begin

	end
end
always_ff @(posedge i_clk or posedge i_rst or posedge i_start) begin
	if (i_rst) begin
		state_r <= S_IDLE;
		res_r <= 257'b0;
		done_flag_r <= 1'b0;
		multipyer_r <= 1'b0;
		count_r <= 8'b0;
	end
	else if (i_start) begin
		state_r <= S_CALC;
		res_r <= 257'b0;
		done_flag_r <= 1'b0;
		multipyer_r <= i_b[0];
		count_r <= 8'b0;
	end
	else begin
		state_r <= state_w;
		res_r <= res_n_w;
		done_flag_r <= done_flag_w;
		multipyer_r <= multipyer_w;
		count_r = count_n;
	end
end
endmodule
