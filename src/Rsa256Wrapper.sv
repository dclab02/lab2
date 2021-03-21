module Rsa256Wrapper (
    input         avm_rst,
    input         avm_clk,
    output  [4:0] avm_address, // 32-bit addr
    output        avm_read,
    input  [31:0] avm_readdata,
    output        avm_write,
    output [31:0] avm_writedata,
    input         avm_waitrequest
);

localparam RX_BASE     = 0*4;
localparam TX_BASE     = 1*4;
localparam STATUS_BASE = 2*4;
localparam TX_OK_BIT   = 6;
localparam RX_OK_BIT   = 7;

localparam RSA_DATA_LEN = 32; // bytes == 256-bits

// Feel free to design your own FSM!
localparam S_RX_IDLE        = 0;
localparam S_TX_IDLE        = 1;
localparam S_GET_KEY        = 2;
localparam S_GET_DATA       = 3;
localparam S_WAIT_CALCULATE = 4;
localparam S_SEND_DATA      = 5;

localparam T_KEY  = 1'b0;
localparam T_DATA = 1'b1;

//                             ,  cipher,       plain text
logic [255:0] n_r, n_w, d_r, d_w, enc_r, enc_w, dec_r, dec_w; // store RSA data
logic [2:0] state_r, state_w;
logic [6:0] bytes_counter_r, bytes_counter_w;
logic [4:0] avm_address_r, avm_address_w;
logic avm_read_r, avm_read_w, avm_write_r, avm_write_w;
logic rx_type_r, rx_type_w;

logic rsa_start_r, rsa_start_w;
logic rsa_finished;
logic [255:0] rsa_dec;

assign avm_address = avm_address_r;
assign avm_read = avm_read_r;
assign avm_write = avm_write_r;
assign avm_writedata = dec_r[247-:8];

Rsa256Core rsa256_core(
    .i_clk(avm_clk),
    .i_rst(avm_rst),
    .i_start(rsa_start_r),
    .i_a(enc_r),
    .i_d(d_r),
    .i_n(n_r),
    .o_a_pow_d(rsa_dec),
    .o_finished(rsa_finished)
);

task StartRead;
    input [4:0] addr;
    begin
        avm_read_w = 1;
        avm_write_w = 0;
        avm_address_w = addr;
    end
endtask
task StartWrite;
    input [4:0] addr;
    begin
        avm_read_w = 0;
        avm_write_w = 1;
        avm_address_w = addr;
    end
endtask

always_comb begin
    n_w = n_r;
    d_w = d_r;
    enc_w = enc_r;
    dec_w = dec_r;
    avm_address_w = avm_address_r;
    avm_read_w = avm_read_r;
	avm_write_w = avm_write_r;
    state_w = state_r;
    rsa_start_w = rsa_start_r;
    bytes_counter_w = bytes_counter_r;
    rx_type_w = rx_type_r;

     case (state_r)
        // Wait for Rx signal
        S_RX_IDLE : begin
            StartRead(STATUS_BASE);
            if (!avm_waitrequest) begin
                if (avm_readdata[RX_OK_BIT]) begin
                    StartRead(RX_BASE);
                    if (rx_type_r == T_KEY)
                        state_w = S_GET_KEY;
                    else
                        state_w = S_GET_DATA;
                end
                else begin
                    state_w = S_RX_IDLE;
                end
            end
            else begin
                state_w = S_RX_IDLE;
            end
        end
        // Get key (N, d) from UART
        S_GET_KEY: begin
            if (!avm_waitrequest) begin
                    avm_read_w = 0; // what??
                    if (bytes_counter_r < RSA_DATA_LEN) begin
                        n_w = n_r << 8;
                        n_w[7:0] = avm_readdata[7:0];
                        bytes_counter_w = bytes_counter_r + 1;
                        state_w = S_RX_IDLE;
                    end
                    else if (bytes_counter_r < 2 * RSA_DATA_LEN) begin // 33 ~ 64-bit
                        d_w = d_r << 8;
                        d_w[7:0] = avm_readdata[7:0];
                        bytes_counter_w = bytes_counter_r + 1;
                        state_w = S_RX_IDLE;
                    end
                    if (bytes_counter_r == (2 * RSA_DATA_LEN - 1)) begin
                        rx_type_w = T_DATA;
                        state_w = S_RX_IDLE;
                        bytes_counter_w = 0;
                    end
            end
            else begin
                state_w = S_GET_KEY;
            end
        end

        // Get encrypted data from UART
        S_GET_DATA: begin
            if (!avm_waitrequest && avm_read_r) begin
                avm_read_w = 0;
                // read from rxdata
                if (bytes_counter_r < RSA_DATA_LEN) begin
                    enc_w = enc_r << 8;
                    enc_w[7:0] = avm_readdata[7:0];
                    bytes_counter_w = bytes_counter_r + 1;
                    state_w = S_RX_IDLE;
                end
                if (bytes_counter_r == RSA_DATA_LEN - 1) begin
                    bytes_counter_w = 0;
                    rsa_start_w = 1'b1; // start calculate
                    state_w = S_WAIT_CALCULATE;
                end
            end
        end

        S_WAIT_CALCULATE : begin
            rsa_start_w = 1'b0; // end calculation
            if (rsa_finished) begin
                // rsa_start_w = 1'b0; // end calculation
                dec_w = rsa_dec;
                state_w = S_TX_IDLE;
            end
            else begin
                state_w = S_WAIT_CALCULATE;
            end
        end

        // send decrypted data
        S_TX_IDLE: begin
            StartRead(STATUS_BASE);
            if (!avm_waitrequest) begin
                if (avm_readdata[TX_OK_BIT]) begin
                    StartWrite(TX_BASE);
                    state_w = S_SEND_DATA;
                end
            end
            else begin
                state_w = S_TX_IDLE;
            end
        end

        S_SEND_DATA : begin
            if (!avm_waitrequest) begin
                avm_write_w = 0;
                if (bytes_counter_r < RSA_DATA_LEN - 2) begin
                    bytes_counter_w = bytes_counter_r + 1;
                    dec_w = dec_r << 8;
                    state_w = S_TX_IDLE;
                end
                else if (bytes_counter_r == RSA_DATA_LEN - 2) begin // 31-byte
                    bytes_counter_w = 0;
                    state_w = S_RX_IDLE;
                end
            end
            else begin
                state_w = S_SEND_DATA;
            end
        end

    endcase
end

always_ff @(posedge avm_clk or posedge avm_rst) begin
    if (avm_rst) begin
        n_r <= 0;
        d_r <= 0;
        enc_r <= 0;
        dec_r <= 0;
        avm_address_r <= STATUS_BASE;
        avm_read_r <= 1;
        avm_write_r <= 0;
        state_r <= S_RX_IDLE;
        bytes_counter_r <= 0;
        rsa_start_r <= 0;
        rx_type_r <= T_KEY;
    end else begin
        n_r <= n_w;
        d_r <= d_w;
        enc_r <= enc_w;
        dec_r <= dec_w;
        avm_address_r <= avm_address_w;
        avm_read_r <= avm_read_w;
        avm_write_r <= avm_write_w;
        state_r <= state_w;
        bytes_counter_r <= bytes_counter_w;
        rsa_start_r <= rsa_start_w;
        rx_type_r <= rx_type_w;
    end
end

endmodule
