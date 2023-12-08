`default_nettype none

module UART_rx (
    input wire clk,
    input wire rst_n,
    input wire RX,
    input wire clr_rdy,
    output wire [7:0] rx_data,
    output reg rdy
);

    reg start, receiving, set_rdy;

    //////////////
    // rdy SRFF //
    //////////////
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) rdy <= 0;
   	    else if (clr_rdy) rdy <= 0;
        else if (start) rdy <= 0;
        else if (set_rdy) rdy <= 1;
    end
  
    //////////////////
    // baud counter //
    //////////////////
    wire shift;
    reg [11:0] baud_cnt;
    
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            baud_cnt <= 0;
        else if (start)
	        baud_cnt <= 0;
        else if (receiving) begin
            baud_cnt <= baud_cnt >= 2604 ? 0 : baud_cnt + 1;
        end
    end
    assign shift = receiving ? baud_cnt == 1302 : 0;

    /////////////////
    // Bit counter //
    /////////////////
    reg [3:0] bit_cnt;
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) bit_cnt <= 4'b0;
        else if (start) bit_cnt <= 4'b0;
        else if (shift) bit_cnt <= bit_cnt + 1;
    end

    ///////////////////////////////
    // RX falling edge detection //
    ///////////////////////////////
    reg RX_ff;
    wire RX_fall;
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) RX_ff <= 0;
        else RX_ff <= RX;
    end
    assign RX_fall = RX_ff && !RX;

    ///////////////////
    // State Machine //
    ///////////////////
    typedef enum reg { IDLE, RECV } state_t;
    state_t state, nxt_state;

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else 
            state <= nxt_state;
    end

    always_comb begin
        start = 0;
        set_rdy = 0;
        receiving = 0;
        nxt_state = state;
        
        case (state)
            IDLE: begin
                if (RX_fall) begin
                    start = 1;
                    nxt_state = RECV;
                end
            end
            default: begin // RECV
                receiving = 1;
                if (bit_cnt == 9) begin
                    set_rdy = 1;
                    nxt_state = IDLE;
                end
            end 
        endcase
    end

    ///////////////
    // Data flow //
    ///////////////
    reg [8:0] shift_reg;
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) shift_reg <= 0;
        else if (shift) shift_reg <= {RX, shift_reg[8:1]};
    end
    assign rx_data = shift_reg[8:1];

endmodule

`default_nettype wire 
