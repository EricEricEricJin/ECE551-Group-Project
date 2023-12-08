module MtrDrv(
input logic signed [11:0]lft_spd,
input logic [11:0]vbatt,
input logic signed [11:0]rght_spd,
input logic clk,
input logic rst_n,
output logic lftPWM1,
output logic lftPWM2,
output logic rghtPWM1,
output logic rghtPWM2);

logic signed [11:0] lft_scaled, rght_scaled, rightDuty, leftDuty;
logic signed [12:0] scale_factor;
logic signed [23:0] lft_div, rght_div;


DutyScaleROM iROM(.clk(clk), .batt_level(vbatt[9:4]), .scale(scale_factor));
PWM12 PWMRight(.clk(clk), .rst_n(rst_n), .duty(rightDuty), .PWM1(rghtPWM1), .PWM2(rghtPWM2));
PWM12 PWMLeft(.clk(clk), .rst_n(rst_n), .duty(leftDuty), .PWM1(lftPWM1), .PWM2(lftPWM2));

assign lft_div = (lft_spd * scale_factor) / 2048;
assign rght_div = (rght_spd * scale_factor) / 2048;

assign lft_scaled = lft_div[23] ? (&lft_div[21:11] ? lft_div[11:0] : 12'h800) :
				  (~|lft_div[21:11] ? lft_div[11:0] : 12'h7FF);
assign rght_scaled = rght_div[23] ? (&rght_div[21:11] ? rght_div[11:0] : 12'h800) :
				    (~|rght_div[21:11] ? rght_div[11:0] : 12'h7FF);

assign rightDuty = 12'h800 - rght_scaled;
assign leftDuty = lft_scaled + 12'h800;

endmodule
