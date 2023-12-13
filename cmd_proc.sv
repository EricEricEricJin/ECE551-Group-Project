module cmd_proc(
input logic clk,
input logic rst_n,
input logic[15:0] cmd,
input logic cmd_rdy,
input logic cal_done,
input logic sol_cmplt,
input logic mv_cmplt,
output logic clr_cmd_rdy,
output logic send_resp,
output logic strt_cal,
output logic in_cal,
output logic strt_hdng,
output logic strt_mv,
output logic stp_lft,
output logic stp_rght,
output logic[11:0] dsrd_hdng,
output logic cmd_md);

typedef enum logic[2:0] { IDLE, READ_CMD, CAL, HEAD, MOVE, SOLVE} state_t;

// holding register for dsrd_hdng
logic capture_hdng;
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n) dsrd_hdng <= 0;
	else if(capture_hdng) dsrd_hdng <= cmd[11:0];
end

// holding register for both stp_lft, stp_rght
logic capture_stp;
always_ff@(posedge clk, negedge rst_n) begin
	if(!rst_n) begin
		stp_lft <= 0;
		stp_rght <= 0;
	end else if(capture_stp) begin
		stp_lft <= cmd[1];
		stp_rght <= cmd[0];
	end
end

// state ff
state_t state, nxt_state;

always_ff@(posedge clk, negedge rst_n) begin
	if(!rst_n)
		state <= IDLE;
	else
		state <= nxt_state;
end

always_comb begin
	clr_cmd_rdy = 0;
	strt_cal = 0;
	send_resp = 0;
	strt_hdng = 0;
	strt_mv = 0;
	capture_hdng = 0;
	capture_stp = 0;
	cmd_md = 1;
	nxt_state = state;
	case(state)
		// IDLE state wait for a cmd to be ready, and then decodes the command and in turn goes to the correct state
		IDLE: if(cmd_rdy) begin
			clr_cmd_rdy = 1;
			if(cmd[15:13] == 3'b000) begin
				strt_cal = 1;
				nxt_state = CAL;
			  end else if(cmd[15:13] == 3'b001) begin
				strt_hdng = 1;
				capture_hdng = 1;
				nxt_state = HEAD;
			  end else if(cmd[15:13] == 3'b010) begin
				strt_mv = 1;
				capture_stp = 1;
				nxt_state = MOVE;
			  end else if(cmd[15:13] == 3'b011) begin
				cmd_md = 0;
				nxt_state = SOLVE;
			end
		end
		// wait for calabration to end and return to the idle state
		CAL: begin
			in_cal = 1;
			if(cal_done) begin
				send_resp = 1;
				nxt_state = IDLE;
			end
		end
		// once we have moved to the new heading ack and return to idle state
		HEAD: if(mv_cmplt) begin
			send_resp = 1;
			nxt_state = IDLE;
		end
		// once we have moved to the new position ack and return to idle state
		MOVE: if(mv_cmplt) begin
			send_resp = 1;
			nxt_state = IDLE;
		end
		// kick off the solving algo, and do not stop until we have found the magnet
		SOLVE: begin
			cmd_md = 0;
			if(sol_cmplt) begin
				nxt_state = IDLE;
			end
		end
	endcase
end
endmodule
