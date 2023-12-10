`default_nettype none

module IR_math 
    #(parameter NOM_IR = 12'h900)
(
    input wire lft_opn, 
    input wire rght_opn,
    input wire [11:0] lft_IR,
    input wire [11:0] rght_IR,
    input wire signed [8:0] IR_Dtrm,
    input wire en_fusion,
    input wire signed [11:0] dsrd_hdng,
    output wire signed [11:0] dsrd_hdng_adj
);

wire signed [11:0] l_r_diff, l_n_diff, n_r_diff;
assign l_r_diff = (lft_IR - rght_IR) >> 1;
assign l_n_diff = lft_IR - NOM_IR;
assign n_r_diff = NOM_IR - rght_IR;

wire signed [11:0] mux_out_1, mux_out_2, mux_out_3;
assign mux_out_1 = rght_opn ? l_n_diff : l_r_diff;
assign mux_out_2 = lft_opn ? n_r_diff : mux_out_1;
assign mux_out_3 = (lft_opn && rght_opn) ? 12'h000 : mux_out_2;

wire signed [12:0] div32_ext13_out;
assign div32_ext13_out = {{6{mux_out_3[11]}}, mux_out_3[11:5]};

wire signed [12:0] x4_ext13_out;
assign x4_ext13_out = {{2{IR_Dtrm[8]}}, IR_Dtrm, 2'b0};

wire signed [12:0] last_sum_in_1;
assign last_sum_in_1 = (div32_ext13_out + x4_ext13_out) >> 1;

assign dsrd_hdng_adj = en_fusion ? last_sum_in_1 + dsrd_hdng : dsrd_hdng;

endmodule

`default_nettype wire