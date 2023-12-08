`default_nettype none

module SPI_mnrch (
    input wire clk, rst_n,
    
    input wire [15:0] wrt_data,
    input wire wrt,

    output wire [15:0] rd_data,
    output reg done,

    output reg SS_n,
    output wire SCLK,
    output wire MOSI,
    input wire MISO
);


    // << Commands given by SM >>
    reg smpl, shft, init;
    reg ld_SCLK, set_done;

    // << done SRFF >>
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            done <= 0;
        else if (init)
            done <= 0;
        else if (set_done)
            done <= 1;
    end

    // << SS_n SRFF >>
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            SS_n <= 1;
        else if (set_done)
            SS_n <= 1;
        else if (init)
            SS_n <= 0;
    end

    // << MISO sampling >>
    reg MISO_smpl;
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            MISO_smpl <= 0;
        else if (smpl)
            MISO_smpl <= MISO;
    end

    // << Shift register >>
    reg [15:0] shft_reg;
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            shft_reg <= 16'b0;
        else if (init)
            shft_reg <= wrt_data;
        else if (shft)
            shft_reg <= {shft_reg[14:0], MISO_smpl};
    end

    assign rd_data = shft_reg;

    assign MOSI = shft_reg[15];

    // << Bit counter >>
    reg [3:0] bit_cntr;
    
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            bit_cntr <= 4'b0;
        else if (init)
            bit_cntr <= 4'b0;
        else if (shft)
            bit_cntr <= bit_cntr + 1;
    end

    // << Clock counter >>
    // Use count up
    reg [4:0] SCLK_div;
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            SCLK_div <= 0;
        else if (ld_SCLK)
            SCLK_div <= 5'b10111; // to make first change at middle 
        else
            SCLK_div <= SCLK_div + 1;
    end
    assign SCLK = SCLK_div[4];


    // << SM >>
    typedef enum reg[1:0] { IDLE, SMPL, SHFT } state_t;
    state_t state, nxt_state;

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else 
            state <= nxt_state;
    end

    always_comb begin
        ld_SCLK = 0;
        init = 0;
        smpl = 0;
        shft = 0;
        set_done = 0;

        nxt_state = state;

        case (state)
            IDLE: begin
				    ld_SCLK = 1;
                if (wrt) begin
                    init = 1;
                    nxt_state = SMPL;
                end
            end 

            SMPL: begin
                if (SCLK_div == 5'b01111) begin
                    smpl = 1;
                    nxt_state = SHFT;
                end
            end

            default: begin // SHFT
                if (bit_cntr == 4'b1111) begin
                    shft = 1;
                    set_done = 1;
                    nxt_state = IDLE;
                end
                else if (SCLK_div == 5'b11111) begin
                    shft = 1;
                    nxt_state = SMPL;
                end
            end
        endcase
    end

endmodule

`default_nettype wire