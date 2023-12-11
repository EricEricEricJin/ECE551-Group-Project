module MtrDrv(
input logic signed [11:0]lft_spd,
input logic [11:0]vbatt,
input logic signed [11:0]rght_spd,
input logic clk,
input logic rst_n,
output logic lftPWM1,
output logic lftPWM2,
output logic rghtPWM1,
output logic rghtPWM2
);

// logic lftPWM1_nf, lftPWM2_nf, rghtPWM1_nf, rghtPWM2_nf;

logic signed [11:0] lft_spd_ff, rght_spd_ff;
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n) begin
		lft_spd_ff <= 0;
		rght_spd_ff <= 0;
	end
	else begin
		lft_spd_ff <= lft_spd;
		rght_spd_ff <= rght_spd;
	end
end

logic signed [11:0] lft_scaled, rght_scaled, rightDuty, leftDuty;
logic signed [12:0] scale_factor;
logic signed [23:0] lft_div, rght_div;


DutyScaleROM iROM(.clk(clk), .batt_level(vbatt[9:4]), .scale(scale_factor));
// PWM12 PWMRight(.clk(clk), .rst_n(rst_n), .duty(rightDuty), .PWM1(rghtPWM1_nf), .PWM2(rghtPWM2_nf));
// PWM12 PWMLeft(.clk(clk), .rst_n(rst_n), .duty(leftDuty), .PWM1(lftPWM1_nf), .PWM2(lftPWM2_nf));

PWM12 PWMRight(.clk(clk), .rst_n(rst_n), .duty(rightDuty), .PWM1(rghtPWM1), .PWM2(rghtPWM2));
PWM12 PWMLeft(.clk(clk), .rst_n(rst_n), .duty(leftDuty), .PWM1(lftPWM1), .PWM2(lftPWM2));

assign lft_div = (lft_spd_ff * scale_factor) / 2048;
assign rght_div = (rght_spd_ff * scale_factor) / 2048;

assign lft_scaled = lft_div[23] ? (&lft_div[21:11] ? lft_div[11:0] : 12'h800) :
				  (~|lft_div[21:11] ? lft_div[11:0] : 12'h7FF);
assign rght_scaled = rght_div[23] ? (&rght_div[21:11] ? rght_div[11:0] : 12'h800) :
				    (~|rght_div[21:11] ? rght_div[11:0] : 12'h7FF);

assign rightDuty = 12'h800 - rght_scaled;
assign leftDuty = lft_scaled + 12'h800;

// always_ff @( posedge clk, negedge rst_n ) begin
// 	if (!rst_n) begin
// 		lftPWM1 <= 0;
// 		lftPWM2 <= 0;
// 		rghtPWM1 <= 0;
// 		rghtPWM2 <= 0;
// 	end
// 	else begin
// 		lftPWM1 <= lftPWM1_nf;
// 		lftPWM2 <= lftPWM2_nf;
// 		rghtPWM1 <= rghtPWM1_nf;
// 		rghtPWM2 <= rghtPWM2_nf;
// 	end
// end

endmodule
