module UART_Wrapper(
input clk,
input rst_n,
input RX,
input trmt,
input[7:0] resp,
input logic clr_cmd_rdy,
output logic cmd_rdy,
output logic tx_done,
output logic TX,
output logic[15:0] cmd
);

logic rx_rdy, clr_rx_rdy, upper_bit, cmd_done, store_byte;
logic[7:0] rx_data;
typedef enum logic {idle, low_byte} state_t;

// instantaite UART to act as out transmitter
UART transmit(.clk(clk),
.rst_n(rst_n),
.RX(RX),
.TX(TX),
.rx_rdy(rx_rdy),
.clr_rx_rdy(clr_rx_rdy),
.rx_data(rx_data),
.trmt(trmt),
.tx_data(resp),
.tx_done(tx_done));

// holding register for the lower upper byte
always_ff @(posedge clk) begin
	if(store_byte) cmd[15:8] <= rx_data; 
end

state_t state, nxt_state;

// state machine flip flop
always_ff@(posedge clk, negedge rst_n) begin
	if(!rst_n) state <= idle;
	else state <= nxt_state;
end

always_comb begin
	nxt_state = state;
	upper_bit = 0;
	clr_rx_rdy = 0;
	cmd_done = 0;
	store_byte = 0;
	case(state)
	// wait for the  first byte to be recieved, and then clear the rx_rdy
	idle: if(rx_rdy) begin
		nxt_state = low_byte;
		store_byte = 1;
		clr_rx_rdy = 1;
	      end
	// change to the upper byte and wait for the tranmission to end, once ended assert that we have receieved a 2 byte command
	low_byte: begin
		upper_bit = 1;
		if(rx_rdy) begin
		     nxt_state = idle;
		     cmd[7:0] = rx_data;
		     clr_rx_rdy = 1;
		     cmd_done = 1;
		   end
		end
	endcase
end

// set reset flop to update the output
always_ff@(posedge clk) begin
	if(!upper_bit | clr_cmd_rdy) cmd_rdy <= 0;
	else if(cmd_done) cmd_rdy <= 1;
end

endmodule
