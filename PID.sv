`default_nettype none

module Pterm (
    input wire signed [9:0] err_sat,
    output wire signed [13:0] P_term
);

    localparam P_coeff = 4'h3;
    assign P_term = $signed(P_coeff) * err_sat;

endmodule

module Iterm (
    input wire clk, 
    input wire rst_n,
    input wire hdng_vld,
    input wire moving,
    input wire [9:0] err_sat,
    output wire [11:0] I_term
);

    wire signed [15:0] err_sat_ext, nxt_integrator, mux_out_1, sum;
    reg signed [15:0] integrator;
    wire ov;

    // Ref to block diagram
    assign err_sat_ext = {{6{err_sat[9]}}, err_sat};
    assign sum = err_sat_ext + integrator;
    assign mux_out_1 = (hdng_vld && (!ov)) ? sum : integrator;
    assign ov = err_sat_ext[15] == integrator[15] && err_sat_ext[15] != sum[15];
    assign nxt_integrator = moving ? mux_out_1 : 16'h0000;

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            integrator <= 16'h0000;
        else
            integrator <= nxt_integrator; 
    end

    assign I_term = integrator[15:4];
    
endmodule

module mux_ff_locker (
    input wire clk,
    input wire rst_n,
    input wire hdng_vld,
    input wire signed [9:0] in,
    output reg signed [9:0] out
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            out <= 0;
        else if (hdng_vld)
            out <= in;
    end
endmodule

module Dterm (
    input wire clk,
    input wire rst_n,
    input wire hdng_vld,
    input wire signed [9:0] err_sat,
    output wire signed [12:0] D_term
);

    localparam D_COEFF = 5'h0e;
    
    wire signed [9:0] locker_1_out, locker_2_out;
    mux_ff_locker i_locker_1(.clk(clk), .rst_n(rst_n), .hdng_vld(hdng_vld), .in(err_sat), .out(locker_1_out));
    mux_ff_locker i_locker_2(.clk(clk), .rst_n(rst_n), .hdng_vld(hdng_vld), .in(locker_1_out), .out(locker_2_out));

    wire signed [10:0] sub_out;
    assign sub_out =  err_sat - locker_2_out;

    wire signed [7:0] sat_out;
    assign sat_out = sub_out[10] && !(&sub_out[10:7]) ? -8'd128 : (!sub_out[10] && |sub_out[10:7] ? 8'd127 : sub_out[7:0]);

    assign D_term = $signed(D_COEFF) * sat_out;
endmodule

module PID(
    input wire clk,
    input wire rst_n,
    input wire moving,
    input wire signed [11:0] dsrd_hdng,
    input wire signed [11:0] actl_hdng,
    input wire hdng_vld,
    input wire signed [10:0] frwrd_spd,
    output logic at_hdng,
    output logic signed [11:0] lft_spd,
    output logic signed [11:0] rght_spd
);

    logic at_hdng_nf;
    logic signed [11:0] lft_spd_nf, rght_spd_nf;

    // Saturate error to 10 bits
    wire signed [11:0] error;

    logic signed [9:0] err_sat;
    wire signed [9:0]  err_sat_nf;
    assign error = actl_hdng - dsrd_hdng;
    assign err_sat_nf = error[11] ? (&(error[10:9]) ? {1'b1, error[8:0]} : 10'b1000000000)  // negative 
                           : (|(error[10:9]) ? 10'b0111111111 : {1'b0, error[8:0]}); // positive
    
    always_ff @( posedge clk, negedge rst_n ) begin
        if (!rst_n) err_sat <= 0;
        else err_sat <= err_sat_nf;
    end

    // assign at_hdng_nf = dsrd_hdng == actl_hdng;
    assign at_hdng_nf = err_sat[9] ? ~err_sat < 10'd29 : err_sat < 10'd30;

    wire signed [13:0] Pterm_out;
    wire signed [11:0] Iterm_out;
    wire signed [12:0] Dterm_out;

    Pterm i_Pterm(.err_sat(err_sat), .P_term(Pterm_out));
    Iterm i_Iterm(.clk(clk), .rst_n(rst_n), .hdng_vld(hdng_vld), .moving(moving), .err_sat(err_sat), .I_term(Iterm_out));
    Dterm i_Dterm(.clk(clk), .rst_n(rst_n), .hdng_vld(hdng_vld), .err_sat(err_sat), .D_term(Dterm_out));

    // Sum up P, I, D terms and div 8
    wire signed [11:0] all_term_out;
    assign all_term_out = ({Pterm_out[13], Pterm_out} + {{3{Iterm_out[11]}}, Iterm_out} + {{2{Dterm_out[12]}}, Dterm_out}) >> 3;

    // left = speed + pid_out
    // right = speed - pid_out
    assign lft_spd_nf = moving ? (all_term_out + frwrd_spd) : 0;
    assign rght_spd_nf = moving ? (frwrd_spd - all_term_out) : 0;

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            lft_spd <= 0;
            rght_spd <= 0;
            at_hdng <= 0;
        end else begin
            lft_spd <= lft_spd_nf;
            rght_spd <= rght_spd_nf;
            at_hdng <= at_hdng_nf;            
        end
    end
endmodule

`default_nettype wire 