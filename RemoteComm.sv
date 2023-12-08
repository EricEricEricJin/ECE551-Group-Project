`default_nettype none

module RemoteComm(clk, rst_n, RX, TX, cmd, send_cmd, cmd_sent, resp_rdy, resp);

    input wire clk, rst_n;		// clock and active low reset
    input wire RX;				// serial data input
    input wire send_cmd;			// indicates to tranmit 24-bit command (cmd)
    input wire [15:0] cmd;		// 16-bit command

    output wire TX;				// serial data output
    output reg cmd_sent;		// indicates transmission of command complete
    output wire resp_rdy;		// indicates 8-bit response has been received
    output wire [7:0] resp;		// 8-bit response from DUT

    // << SM output commands >>
    reg trmt, sel;

    // << cmd_sent SRFF >>
    reg cmd_sent_set;
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) cmd_sent <= 0;
        else if (cmd_sent_set) cmd_sent <= 1;
        else if (send_cmd) cmd_sent <= 0;
    end

    // << TX data and TX done >>
    wire tx_done;
    wire [7:0] tx_data;
    reg [7:0] cmd_low_8;
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) cmd_low_8 <= 8'b0;
        else if (send_cmd) cmd_low_8 <= cmd[7:0];
    end
    assign tx_data = sel ? cmd[15:8] : cmd_low_8;


    ///////////////////////////////////////////////
    // Instantiate basic 8-bit UART transceiver //
    /////////////////////////////////////////////
    UART iUART(.clk(clk), .rst_n(rst_n), .RX(RX), .TX(TX), .tx_data(tx_data), .trmt(trmt),
            .tx_done(tx_done), .rx_data(resp), .rx_rdy(resp_rdy), .clr_rx_rdy(resp_rdy));

    //////////////////////
    // Implement the SM //
    //////////////////////
    typedef enum reg[1:0] { IDLE, TB1, TB2 } state_t;
    state_t state, nxt_state;

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= nxt_state;
    end

    reg tx_done_delayed;
    wire tx_rise;
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) 
            tx_done_delayed <= 0;
        else
            tx_done_delayed <= tx_done;
    end
    assign tx_rise = (!tx_done_delayed) && tx_done;

    always_comb begin
        trmt = 0;
        sel = 0;
        cmd_sent_set = 0;
        
        nxt_state = state;

        case (state)
            IDLE: begin
                if (send_cmd) begin
                    trmt = 1;
                    sel = 1;
                    nxt_state = TB1;
                end 
            end 
            TB1: begin
                if (tx_rise) begin
                    trmt = 1;
                    nxt_state = TB2;
                end
            end 
            default: begin // TB2
                if (tx_rise) begin
                    cmd_sent_set = 1;
                    nxt_state = IDLE;
                end
            end 
        endcase
    end

endmodule	
