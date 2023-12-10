module RemoteComm(clk, rst_n, RX, TX, cmd, send_cmd, cmd_sent, resp_rdy, resp);

input clk, rst_n;		// clock and active low reset
input RX;			// serial data input
input send_cmd;			// indicates to tranmit 24-bit command (cmd)
input [15:0] cmd;		// 16-bit command

output logic TX;		// serial data output
output logic cmd_sent;		// indicates transmission of command complete
output logic resp_rdy;		// indicates 8-bit response has been received
output logic [7:0] resp;	// 8-bit response from DUT

typedef enum logic [1:0] {IDLE, BYTE_ONE, BYTE_TWO} state_t;

logic sel_high, trmt, set_cmd_snt, tx_done;
logic[7:0] low_byte, tx_data;

///////////////////////////////////////////////
// Instantiate basic 8-bit UART transceiver //
/////////////////////////////////////////////
UART iUART(.clk(clk), .rst_n(rst_n), .RX(RX), .TX(TX), .tx_data(tx_data), .trmt(trmt),
           .tx_done(tx_done), .rx_data(resp), .rx_rdy(resp_rdy), .clr_rx_rdy(resp_rdy));

// keep low byte perseved
always_ff@(posedge clk) begin
	if(send_cmd) low_byte <= cmd[7:0];
end

// select weither we transmit the high or the low byte
assign tx_data = sel_high ? cmd[15:8] : low_byte;

state_t state, nxt_state;

// state machine flip flop
always_ff@(posedge clk, negedge rst_n) begin
	if(!rst_n) state <= IDLE;
	else state <= nxt_state;
end

always_comb begin
	trmt = 0;
	set_cmd_snt = 0;
	sel_high = 1'b1;
	nxt_state = state;
	case(state)
		// wait for the signal to send the command
		IDLE: if(send_cmd) begin
		      	trmt = 1;
			nxt_state = BYTE_ONE;
		end
		// ensure that the lwo byte is now being selected to be transmitted and wait until the high byte finsihes transmitting
		BYTE_ONE: begin
			sel_high = 0;
			if(tx_done) begin
				nxt_state = BYTE_TWO;
				sel_high = 0;
				trmt = 1;
			end
		end
		// wait for the second byte to transmit and when finsished return the idle state
		BYTE_TWO:
			if(tx_done) begin
			    set_cmd_snt = 1;
			    nxt_state = IDLE;
			end
	endcase
end

// set reset output flop
always_ff@(posedge clk, negedge rst_n) begin
	if(send_cmd) cmd_sent <= 0;
	else if(set_cmd_snt) cmd_sent <= 1'b1;
end

endmodule	
