module UART_rx(
input logic clk,
input logic rst_n,
input logic RX,
input logic clr_rdy,
output logic[7:0] rx_data,
output logic rdy);

logic start, recieving, shift, set_rdy;
logic[3:0] bit_cnt;
logic[11:0] baud_cnt;
logic[8:0] rx_shft_reg;

typedef enum logic {idle, receive} state_t;

// shift register
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n) rx_shft_reg <= 0;
	else if(shift) rx_shft_reg <= {RX, rx_shft_reg[8:1]};
	
end

assign rx_data = rx_shft_reg[7:0];

// baud cnt register
always_ff @(posedge clk) begin
	if(start) baud_cnt <= 12'h516;
	else if(shift) baud_cnt <= 12'hA2C;
	else if(recieving) baud_cnt <= baud_cnt - 1;   
end

assign shift = baud_cnt == 0;

// bit count
always_ff @(posedge clk) begin
	if(start) bit_cnt <= 0;
	else if(shift) bit_cnt <= bit_cnt + 1;
end

state_t state, nxt_state;

always_ff@(posedge clk, negedge rst_n) begin
	if(!rst_n) state <= idle;
	else state <= nxt_state;
end

always_comb begin
	nxt_state = state;
	start = 1'b0;
	set_rdy = 1'b0;
	recieving = 1'b0;
	case(state)
		idle: if(!RX) begin
			nxt_state = receive;
			start = 1'b1;
		end
		receive: begin
			recieving = 1'b1;
			if(bit_cnt == 4'hA) begin
				nxt_state = idle;
				recieving = 1'b0;
				set_rdy = 1'b1;
			end
		end
	endcase
end

// set reset flop to tell if tx is done
always_ff@(posedge clk, negedge rst_n) begin
	if(!rst_n) rdy <= 0;
	else if(clr_rdy | start) rdy <= 0;
	else if(set_rdy) rdy <= 1'b1;	
end

endmodule
