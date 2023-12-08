`default_nettype none

module SRFF (
    input wire clk,
    input wire rst_n,
    input wire s,
    input wire r,
    output reg q
);
    always_ff @(posedge clk or negedge rst_n) begin
        // NOTE: R must be prior to S
        // because when R = cnt>=duty, S = cnt>=nov is also HI. 
        if (!rst_n)
            q <= 0;
        else if (r)
            q <= 0;
        else if (s)
            q <= 1;
    end
endmodule

module counter (
    input wire clk, rst_n,
    output reg [11:0] cnt
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cnt <= 0;
        else
            cnt <= &cnt ? 0 : cnt + 1; 
end
endmodule

module SR_comb (
    input wire [11:0] NONOVERLAP,
    input wire [11:0] duty,
    input wire [11:0] cnt,
    output wire s2, r2, s1, r1
);
    assign s2 = {1'b0, cnt} >= {1'b0, duty} + {1'b0, NONOVERLAP};
    assign r2 = &cnt;
    assign s1 = cnt >= NONOVERLAP;
    assign r1 = cnt >= duty;
endmodule

module PWM12 (
    input wire clk,
    input wire rst_n,
    input wire [11:0] duty,
    output wire PWM1,
    output wire PWM2
);

localparam NONOVERLAP = 12'h02C;

wire [11:0] cnt;
counter i_counter(.clk(clk), .rst_n(rst_n), .cnt(cnt));

wire s2, r2, s1, r1; // PWM2 and PWM1's SRFFs' Set / Reset
SR_comb i_SR_comb(.NONOVERLAP(NONOVERLAP), .duty(duty), .cnt(cnt), 
                  .s2(s2), .r2(r2), .s1(s1), .r1(r1));

SRFF i_SRFF_2(.clk(clk), .rst_n(rst_n), .s(s2), .r(r2), .q(PWM2));
SRFF i_SRFF_1(.clk(clk), .rst_n(rst_n), .s(s1), .r(r1), .q(PWM1));

endmodule

`default_nettype wire 