// TODO: resolve glitch
/*  
    Issue: clr rdy deassert rx_rdy immediately
    so that rx_rdy glitch
    Solution: rewrite UART_rx
*/

`default_nettype none
module UART_Wrapper (
    input wire clk, rst_n,

    input wire clr_cmd_rdy,
    output reg cmd_rdy,
    
    output wire [15:0] cmd,
    input wire trmt,
    input wire [7:0] resp,
    output wire tx_done,

    wire TX, RX
);

//////////////////
// cmd_rdy SRFF //
//////////////////
reg cmd_rdy_s, cmd_rdy_r;
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        cmd_rdy <= 0;
    else if (cmd_rdy_r || clr_cmd_rdy)
        cmd_rdy <= 0;
    else if (cmd_rdy_s)
        cmd_rdy <= 1;
end

////////
// SM //
////////
// WaitByte1st, WaitByte2nd
typedef enum reg { WB1, WB2 } state_t; 

state_t state, nxt_state;
reg clr_rdy; // assert to clear rx rdy state
reg shift;   // when assert fill rx data to low 8bits

//////////////////////
// State maintainer //
//////////////////////
always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
        state <= WB1;
    end
    else begin
        state <= nxt_state;
    end
end

//////////////////////
// Command register //
//////////////////////
wire [7:0] rx_data;
reg [7:0] cmd_low_8;
assign cmd = {rx_data, cmd_low_8};

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cmd_low_8 <= 8'b0;
    end
    else if (shift) begin
        cmd_low_8 <= rx_data;
    end
end

wire rx_rdy;

////////////////////////////
// SM combinational logic //
////////////////////////////
always_comb begin
    cmd_rdy_r = 0;
    cmd_rdy_s = 0;
    clr_rdy = 0;
    shift = 0;

    nxt_state = state;

    case (state)
        WB1: begin
            if (rx_rdy) begin
                cmd_rdy_r = 1;
                clr_rdy = 1;
                shift = 1;
                nxt_state = WB2;
            end
        end
        default: // WB2
            if (rx_rdy) begin
                cmd_rdy_s = 1;
                clr_rdy = 1;
                nxt_state = WB1;
            end 
    endcase
end

/////////////////////
// Initialize UART //
/////////////////////

UART iUART(
    .clk(clk), .rst_n(rst_n), 
    .RX(RX), .trmt(trmt), 
    .clr_rx_rdy(clr_rdy),
    .tx_data(resp),
    .TX(TX), .rx_rdy(rx_rdy), .tx_done(tx_done),
    .rx_data(rx_data)
);

endmodule
`default_nettype wire