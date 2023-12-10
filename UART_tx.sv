module UART_tx(
input logic clk,
input logic rst_n,
input logic trmt,
input logic[7:0] tx_data,
output logic tx_done,
output logic TX);

logic init;
logic shift;
logic transmitting;
logic set_done;
logic [8:0]tx_shft_reg;
logic [11:0]baud_cnt;
logic [3:0]bit_cnt;

typedef enum logic {idle, transmit} state_t;

// shift register
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n) tx_shft_reg <= 9'h1FF;
	else if(init) tx_shft_reg <= {tx_data,1'b0};	// create the dataframe by having the first bit be low to denote the start of a transaction
	else if(shift) tx_shft_reg <= {1'b1, tx_shft_reg[8:1]}; // otherwise shift out the LSB
end

// LSB of the shift register is what will be read by TX of receiever
assign TX = tx_shft_reg[0];

// baud counter
always_ff @(posedge clk) begin
	if(init | shift) baud_cnt <= 0;
	else if(transmitting) baud_cnt <= baud_cnt + 1;
end

// baud counter hit baud divider therefore we need to shift
assign shift = (baud_cnt == 12'hA2C);

// bit count
always_ff @(posedge clk) begin
	if(init) bit_cnt <= 0;
	else if(shift) bit_cnt <= bit_cnt + 1;
end

state_t state, nxt_state;

// state machine flip flop
always_ff@(posedge clk, negedge rst_n) begin
	if(!rst_n) state <= idle;
	else state <= nxt_state;
end

always_comb begin
	nxt_state = state;
	init = 1'b0;
	set_done = 1'b0;
	transmitting = 1'b0;
	case(state)
		// wait for a transmission to begin
		idle: if(trmt) begin
			nxt_state = transmit;
			init = 1'b1;
		end
		// once we begin to transmit wait until 10 bits have been shifted out to stop
		transmit: begin
		transmitting = 1'b1;
		if(bit_cnt == 4'hA) begin
				nxt_state = idle;
				transmitting = 1'b0;
				set_done = 1'b1;
		end
		end
	endcase
end

// set reset flop to tell if tx is done
always_ff@(posedge clk, negedge rst_n) begin
	if(!rst_n) tx_done <= 0;
	else if(init) tx_done <= 0;
	else if(set_done) tx_done <= 1'b1;	
end
	
endmodule
