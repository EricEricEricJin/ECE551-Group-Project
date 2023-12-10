module navigate(clk,rst_n,strt_hdng,strt_mv,stp_lft,stp_rght,mv_cmplt,hdng_rdy,moving,
                en_fusion,at_hdng,lft_opn,rght_opn,frwrd_opn,frwrd_spd);
				
    parameter FAST_SIM = 1;		// speeds up incrementing of frwrd register for faster simulation
                    
    input clk,rst_n;					// 50MHz clock and asynch active low reset
    input strt_hdng;					// indicates should start a new heading
    input strt_mv;					// indicates should start a new forward move
    input stp_lft;					// indicates should stop at first left opening
    input stp_rght;					// indicates should stop at first right opening
    input hdng_rdy;					// new heading reading ready....used to pace frwrd_spd increments
    output logic mv_cmplt;			// asserted when heading or forward move complete
    output logic moving;				// enables integration in PID and in inertial_integrator
    output en_fusion;					// Only enable fusion (IR reading affect on nav) when moving forward at decent speed.
    input at_hdng;					// from PID, indicates heading close enough to consider heading complete.
    input lft_opn,rght_opn,frwrd_opn;	// from IR sensors, indicates available direction.  Might stop at rise of lft/rght
    output reg [10:0] frwrd_spd;		// unsigned forward speed setting to PID

    // << Left / right open rising edge detector  >>
    reg lft_opn_ffd, rght_opn_ffd;
    wire lft_opn_rise, rght_opn_rise;
    
    always_ff @(posedge clk) begin
        lft_opn_ffd <= lft_opn;
        rght_opn_ffd <= rght_opn;
    end

    assign lft_opn_rise = lft_opn & ~lft_opn_ffd;
    assign rght_opn_rise = rght_opn & ~rght_opn_ffd;
    
    // << decide frwrd_inc by FAST_SIM >>
    wire [6:0] frwrd_inc;
    assign frwrd_inc = FAST_SIM ? 6'h18 : 6'h02;

    // << SM state maintainer >>
    typedef enum reg[2:0] { IDLE, HEAD, ACCL, DECN, DECF } state_t;
    state_t state, nxt_state;
    always_ff @( posedge clk, negedge rst_n ) begin
        if (!rst_n) begin
            state <= IDLE;
        end
        else begin
            state <= nxt_state;
        end
    end

    reg init_frwrd, inc_frwrd, dec_frwrd, dec_frwrd_fast;

    localparam MAX_FRWRD = 11'h2A0;		// max forward speed
    localparam MIN_FRWRD = 11'h0D0;		// minimum duty at which wheels will turn
    
    // << decide en_fusion by forward speed >>
    assign en_fusion = frwrd_spd > (MAX_FRWRD >> 1);

    ////////////////////////////////
    // Now form forward register //
    //////////////////////////////
    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            frwrd_spd <= 11'h000;
        else if (init_frwrd)		// assert this signal when leaving IDLE due to strt_mv
            frwrd_spd <= MIN_FRWRD;									// min speed to get motors moving
        else if (hdng_rdy && inc_frwrd && (frwrd_spd<MAX_FRWRD))	// max out at 2A0
            frwrd_spd <= frwrd_spd + {5'h00,frwrd_inc};				// always accel at 1x frwrd_inc
        else if (hdng_rdy && (frwrd_spd>11'h000) && (dec_frwrd | dec_frwrd_fast))
            frwrd_spd <= ((dec_frwrd_fast) && (frwrd_spd>{2'h0,frwrd_inc,3'b000})) ? frwrd_spd - {2'h0,frwrd_inc,3'b000} : // 8x accel rate
                        (dec_frwrd_fast) ? 11'h000 :	  // if non zero but smaller than dec amnt set to zero.
                        (frwrd_spd>{4'h0,frwrd_inc,1'b0}) ? frwrd_spd - {4'h0,frwrd_inc,1'b0} : // slow down at 2x accel rate
                        11'h000;

    // << Your implementation of ancillary circuits and SM >>	
	// FF strt_mv and strt_hdg
logic strt_mv_ff, strt_hdng_ff;
always_ff @(posedge clk, negedge rst_n) begin
if (!rst_n) begin
strt_mv_ff <= 0;
strt_hdng_ff <= 0;
end
else begin
	strt_mv_ff <= strt_mv;
strt_hdng_ff <= strt_hdng;
end
end

    always_comb begin

        init_frwrd = 0;
        moving = 0;
        mv_cmplt = 0;
        inc_frwrd = 0;
        dec_frwrd = 0;
        dec_frwrd_fast = 0;

        nxt_state = state;

        case (state)
            IDLE: begin
                // << IDLE -> ACCL >>
                // if (strt_mv_ff) begin
		if (strt_mv) begin
                    init_frwrd = 1;
                    nxt_state = ACCL;
                end
                
                // << IDLE -> HEAD >>
                else if (strt_hdng_ff) begin
		// else if (strt_hdng) begin
                    nxt_state = HEAD;
                end

            end

            HEAD: begin
                moving = 1;

                // << HEAD -> IDLE >>
                if (at_hdng) begin
                    mv_cmplt = 1;
                    nxt_state = IDLE;
                end

            end

            ACCL: begin
                moving = 1;
                inc_frwrd = 1;

                // << ACCL -> DECFast >>
                if (!frwrd_opn) begin
                    nxt_state = DECF;
                end

                // << ACCL -> DECNormal >>
                else if ((lft_opn_rise && stp_lft) || (rght_opn_rise && stp_rght)) begin
                    nxt_state = DECN;
                end
            end
            
            DECN: begin
                moving = 1;
                dec_frwrd = 1;
                // << DECNormal -> IDLE >>
                if (frwrd_spd == 0) begin
                    mv_cmplt = 1;
                    nxt_state = IDLE;
                end
            end
            
            // DECF:
            default: begin
                moving = 1;
                dec_frwrd_fast = 1;
                // << DECFast -> IDLE >>
                if (frwrd_spd == 0) begin
                    mv_cmplt = 1;
                    nxt_state = IDLE;
                end
            end 
        endcase
    end

endmodule
  