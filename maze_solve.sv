/*
    Version. 12/06
    Can pass compile in modelsim,
    Not tested yet. 
*/

`default_nettype none

module maze_solve (
    input wire clk, rst_n,
    input wire cmd_md,  // start solving
    input wire cmd0,    // LSB of cmd
    input wire lft_opn, rght_opn,
    input wire mv_cmplt, // from navigate
    input wire sol_cmplt, // found target, stop solving
    output logic strt_hdng,
    output logic [11:0] dsrd_hdng,
    output logic strt_mv, stp_lft, stp_rght
);

parameter PARAM_STARTUP_HDG = 12'h0;

// << Connect stp_lft / rght >>
assign stp_lft = cmd0;
assign stp_rght = !cmd0;

// << Turn direction commands >>
logic turn_left, turn_right, turn_around;

always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
        dsrd_hdng <= PARAM_STARTUP_HDG;
    else if (turn_left)
        dsrd_hdng <= dsrd_hdng + 12'h400;
    else if (turn_right)
        dsrd_hdng <= dsrd_hdng - 12'h400;
    // Assume 3FF and 400 have no difference
end

// << State machine >>
typedef enum logic[1:0] { IDLE, FWD, STRT_HDG, WAIT_HDG } state_t;
state_t state, nxt_state;

always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else state <= nxt_state;
end

always_comb begin
    strt_mv = 0;
    strt_hdng = 0;

    turn_left = 0;
    turn_right = 0;
    turn_around = 0;

    nxt_state = state;
    case (state)
        IDLE: begin
            if (cmd_md) begin
                nxt_state = FWD;
                strt_mv = 1;
            end
        end
        FWD: begin
            if (sol_cmplt) begin
                nxt_state = IDLE;
            end
            else if (mv_cmplt) begin
                nxt_state = STRT_HDG;
            end
        end
        STRT_HDG: begin
            strt_hdng = 1;
            if (stp_lft) begin
                if (lft_opn) turn_left = 1;       // turn left
                else if (rght_opn) turn_right = 1; // set turn right
                else turn_around = 1;               // set turn around
            end
            else begin
                if (rght_opn) turn_left = 1;
                else if (lft_opn) turn_right = 1;
                else turn_around = 1;
            end
            nxt_state = WAIT_HDG;
        end
        default: begin // WAIT_HDG
            if (mv_cmplt) begin
                nxt_state = FWD;
            end
        end
    endcase
end

endmodule

`default_nettype wire