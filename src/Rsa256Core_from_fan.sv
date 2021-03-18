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

localparam IDLE = 2'b00 ;
localparam PREP = 2'b01 ;
localparam MONT = 2'b10 ;
localparam CALC = 2'b11 ;

logic [1:0] state_r, state_w ; 
logic [255:0] m_r, m_w ; 
logic [255:0] t_r, t_w ; 
logic [8:0] counter_r, counter_w ;
logic prepReady;
logic prepValid;
logic [255:0] prepTmp;
logic mont1Ready;
logic mont1Valid;
logic [255:0] mont1Tmp;
logic mont2Ready;
logic mont2Valid;
logic [255:0] mont2Tmp;
logic o_finished_tmp ;
assign o_a_pow_d = m_r ;
assign o_finished = o_finished_tmp ;

// operations for RSA256 decryption
// namely, the Montgomery algorithm
RSAMont MONT1(.i_clk(i_clk), .i_rst(i_rst), .i_ready(mont1Ready), .a(m_r), .b(t_r), .N(i_n), .m(mont1Tmp), .o_valid(mont1Valid) );
RSAMont MONT2(.i_clk(i_clk), .i_rst(i_rst), .i_ready(mont2Ready), .a(t_r), .b(t_r), .N(i_n), .m(mont2Tmp), .o_valid(mont2Valid) );
RSAPrep PREP_Func(.i_clk(i_clk) , .i_rst(i_rst), .i_ready(prepReady), .b({1'b0, i_a}), .a({1'b1, 256'b0}), .N({1'b0, i_n}), .m(prepTmp), .o_valid(prepValid) ); 


always_comb 
begin
	o_finished_tmp = 0 ;
	prepReady = 0 ;
	mont1Ready = 0 ;
 	mont2Ready = 0;
	state_w = state_r ;
	m_w = m_r ;
	t_w = t_r ;
	counter_w = counter_r ;

	if (state_r == IDLE)
	begin
		if (i_start)
		begin 
			m_w = 1 ;
			t_w = 0 ;
			counter_w = 0 ;
			prepReady = 1 ;
			state_w = PREP ;
		end 
		else
		begin 
			m_w = 0 ;
			t_w = 0 ;
			counter_w = 0 ;
			prepReady = 0 ;
			state_w = IDLE ;
		end 
	end
	else if (state_r == PREP)
	begin
		if (prepValid)
		begin 
			m_w = 1 ;
			t_w = prepTmp ;
			counter_w = 0 ;
			prepReady = 0 ;
			state_w = MONT ;
		end 
		else
		begin
			m_w = 1 ;
			t_w = t_r ;
			counter_w = 0 ;
			prepReady = 1 ;
			state_w = PREP ;
		end
	end 
	/*
	else if (state_r == CALC)
	begin
		if (counter_r != 9'd256)
		begin
			mont2Ready = 1;
			if (mont2Valid)
			begin 
				m_w = m_r ;
				t_w = mont2Tmp ;
				counter_w = counter_r + 1'd1 ;
				mont2Ready = 0 ;
				state_w = MONT ;
			end 
			else
			begin
				m_w = m_r ;
				t_w = t_r ;
				counter_w = counter_r ;
				mont2Ready = 1 ;
				state_w = CALC ;
			end
		end
		else
		begin
			m_w = m_r ;
			t_w = t_r ;
			counter_w = 0 ;
			o_finished_tmp = 1 ;
			state_w = IDLE ;
		end
	end
	*/
	else if (state_r == MONT)
	begin
		if(counter_r != 9'd256)
		begin
			if (i_d[counter_r])
			begin
				mont1Ready = 1 ;
				mont2Ready = 1;
				if (mont1Valid && mont2Valid)
				begin 
					m_w = mont1Tmp ;
					t_w = mont2Tmp ;
					counter_w = counter_r + 9'd1;
					mont1Ready = 0 ;
					mont2Ready = 0 ;
					state_w = MONT ;
				end 
				else
				begin
					m_w = m_r ;
					t_w = t_r ;
					counter_w = counter_r ;
					mont1Ready = 1 ;
					mont2Ready = 1;
					state_w = MONT ;
				end
			end
			else
			begin
				mont2Ready = 1;
				if(mont2Valid)
				begin
					m_w = m_r ;
					t_w = mont2Tmp ;
					counter_w = counter_r + 1'd1 ;
					mont2Ready = 0 ;
					state_w = MONT ;
				end
				else
				begin
					m_w = m_r ;
					t_w = t_r ;
					counter_w = counter_r ;
					mont2Ready = 1 ;
					state_w = MONT ;
				end
			end
		end
		else
		begin
			m_w = m_r ;
			t_w = t_r ;
			counter_w = counter_r ;
			o_finished_tmp = 1 ;
			state_w = IDLE ;
		end			
	end
end

always_ff  @(posedge i_clk or posedge i_rst) 
begin
	if(i_rst)
	begin
		m_r <= 0 ;
		t_r <= 0 ;
		counter_r <= 0 ;
		state_r <= IDLE ; 
	end
	else
	begin 
		state_r <= state_w ;
		t_r <= t_w ;
		m_r <= m_w ;
		counter_r <= counter_w ;
	end
end


endmodule

module RSAMont (
	input          i_clk,
	input          i_rst,
	input          i_ready,
	input  [255:0] a,
	input  [255:0] b,
	input  [255:0] N,
	output [255:0] m,
	output         o_valid
);

localparam IDLE = 1'b0 ;
localparam START = 1'b1 ;

logic [257:0] m_r, m_w ; 
logic state_r, state_w ; 
logic [8:0] counter_r, counter_w ;
logic [257:0] tmp , tmp2;
logic o_valid_tmp ;

assign m = m_r[255:0] ;
assign o_valid = o_valid_tmp ;
always_comb 
begin
	o_valid_tmp = 0 ;
	state_w = state_r ;
	m_w = m_r ;
	counter_w = counter_r ;
	tmp = 0 ;
	tmp2 = 0 ;

	if (state_r == IDLE)
	begin
		if (i_ready)
		begin 
			m_w = 0 ;
			counter_w = 0 ;
			state_w = START ;
		end 
		else
		begin 
			m_w = m_r ;
			counter_w = counter_r ;
			state_w = IDLE ;
		end 
	end
	else if (state_r == START)
	begin
		if (counter_r != 9'd256)
		begin 
			state_w = START ;
			counter_w = counter_r + 9'd1 ; 
			if (a[counter_r])
			begin 
				tmp = m_r + {2'b0, b} ; 
			end 
			else
			begin 
				tmp = m_r ;
			end 

			if (tmp[0])
			begin
				tmp2 = (tmp + {2'b0, N}) >> 1 ;
			end
			else
			begin
				tmp2 = tmp >> 1 ; 
			end

			if (counter_r == 255)
			begin
				if (tmp2 >= {2'b0, N})
				begin
					m_w = tmp2 - {2'b0,N} ;
				end
				else
				begin
					m_w = tmp2 ;
				end
			end
			else
			begin
				m_w = tmp2 ;
			end
		end 
		else
		begin 
			counter_w = 0 ; 
			state_w = IDLE; 
			o_valid_tmp = 1 ; 
		end 
	end 
end

always_ff  @(posedge i_clk or posedge i_rst) 
begin
	if(i_rst)
	begin
		m_r <= 0 ;
		counter_r <= 0 ;
		state_r <= IDLE ; 
	end
	else
	begin 
		state_r <= state_w ;
		m_r <= m_w ;
		counter_r <= counter_w ;
	end
end

endmodule


module RSAPrep (
	input          i_clk,
	input          i_rst,
	input          i_ready,
	input  [256:0] b,
	input  [256:0] a,
	input  [256:0] N,
	output [255:0] m,
	output         o_valid 
);

localparam IDLE = 1'b0 ;
localparam START = 1'b1 ;

logic [256:0] m_r, m_w, t_r, t_w ; 
logic state_r, state_w ; 
logic [8:0] counter_r, counter_w ; 
logic o_valid_tmp ;

assign m = m_r[255:0] ; 
assign o_valid = o_valid_tmp ;
always_comb 
begin 
	o_valid_tmp = 0 ;
	state_w = state_r ;
	m_w = 0 ;
	t_w = t_r ;
	counter_w = counter_r ;
	
	if (state_r == IDLE)
	begin
		if (i_ready)
		begin 
			m_w = 0 ;
			t_w = b ;
			counter_w = 0 ;
			state_w = START ;
		end 
		else
		begin 
			m_w = 0 ;
			t_w = 0 ;
			counter_w = 0 ;
			state_w = IDLE ;
		end 
	end
	else if (state_r == START)
	begin
		if (counter_r != 9'd257)
		begin 
			state_w = START ;
			counter_w = counter_r + 1'd1 ; 
			if ( a[counter_r])
			begin 
				m_w = (m_r + t_r >= N ) ? m_r + t_r - N : m_r + t_r ; 
				t_w = (t_r + t_r > N) ? t_r + t_r - N : t_r + t_r ; 
			end 
			else
			begin 
				m_w = m_r ;
				t_w = (t_r + t_r > N) ? t_r + t_r - N : t_r + t_r ;
			end 
		end 
		else
		begin 
			counter_w = 0 ; 
			state_w = IDLE; 
			m_w = m_r ;
			t_w = t_r ;
			o_valid_tmp = 1 ; 
		end 
	end 
end 

always_ff  @(posedge i_clk or posedge i_rst)
begin 
	if(i_rst)
	begin
		m_r <= 0 ;
		t_r <= 0 ;
		counter_r <= 0 ;
		state_r <= IDLE ; 
	end
	else
	begin 
		state_r <= state_w ;
		m_r <= m_w ;
		t_r <= t_w ;
		counter_r <= counter_w  ;
	end
end 

endmodule 