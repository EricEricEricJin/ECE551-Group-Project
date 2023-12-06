`default_nettype none

module piezo_drv #(parameter FAST_SIM = 0) (
    input wire clk, rst_n,
    input wire batt_low,
    input wire fanfare,
    output wire piezo, piezo_n
);

localparam CLOCK_FREQ = 50_000_000;

// << Duration timer >>
logic clr_dura_cnt;
logic [24:0] dura_cnt;

generate 
    if (FAST_SIM) begin
        always_ff @(posedge clk, negedge rst_n) begin
            if (!rst_n)
                dura_cnt <= 0;
            else if (clr_dura_cnt)
                dura_cnt <= 0;
            else
                dura_cnt <= dura_cnt + 16;
        end    
    end
    else begin
        always_ff @(posedge clk, negedge rst_n) begin
            if (!rst_n)
                dura_cnt <= 0;
            else if (clr_dura_cnt)
                dura_cnt <= 0;
            else
                dura_cnt <= dura_cnt + 1;
        end           
    end 
endgenerate 


// << Tone generator >>
// `define TONE_INC_STEP(f) ((2**20-1) - (CLOCK_FREQ/f))
typedef enum logic[7:0] { // inc. step
    SILENT = 8'd0,
    // G6 = TONE_INC_STEP(1568),
    // C7 = TONE_INC_STEP(2093),
    // E7 = TONE_INC_STEP(2637),
    // G7 = TONE_INC_STEP(3136)   
    G6 = 8'd33,
    C7 = 8'd44,
    E7 = 8'd55,
    G7 = 8'd66
} tone_t;

// typedef enum logic[6:0] { // inc. step
//     SILENT = 0,
//     G6 = 1,
//     C7 = 2,
//     E7 = 3,
//     G7 = 4
// } tone_t;

tone_t tone;
logic[19:0] tone_cnt;

always_ff @( posedge clk, negedge rst_n ) begin
    if (!rst_n)
        tone_cnt <= 0;
    else if (tone == SILENT)
        tone_cnt <= 0;
    else 
        tone_cnt <= tone_cnt + tone;
end
assign piezo = tone_cnt[19];
assign piezo_n = !piezo;

// << State Machine >>
typedef enum logic[2:0] { IDLE, T1, T2, T3, T4, T5, T6 } state_t;
state_t state, nxt_state;

always @(posedge clk, negedge rst_n) begin
    if (!rst_n)
        state = IDLE;
    else
        state = nxt_state;
end

always_comb begin
    tone = SILENT;
    clr_dura_cnt = 0;
    nxt_state = state;
    case (state)
        IDLE: begin
            if (batt_low || fanfare) begin
                clr_dura_cnt = 1;
                nxt_state = T1;
            end
        end 
        T1: begin
            tone = G6;
            if (dura_cnt == 2**23) begin
                clr_dura_cnt = 1;
                nxt_state = T2;
            end
        end
        T2: begin
            tone = C7;
            if (dura_cnt == 2**23) begin
                clr_dura_cnt = 1;;
                nxt_state = T3;
            end
        end
        T3: begin
            tone = E7;
            if (dura_cnt == 2**23) begin
                clr_dura_cnt = 1;
                if (fanfare && !batt_low)
                    nxt_state = T4;
                else
                    nxt_state = IDLE;
            end
        end
        T4: begin
            tone = G7;
            if (dura_cnt == (2**23 + 2**22)) begin
                clr_dura_cnt = 1;
                nxt_state = T5;
            end
        end
        T5: begin
            tone = E7;
            if (dura_cnt == 2**22) begin
                clr_dura_cnt = 1;
                nxt_state = T6;
            end
        end
        default: begin // T6
            tone = G7;
            if (dura_cnt == 2**24) begin
                clr_dura_cnt = 1;
                nxt_state = IDLE;
            end
        end
    endcase
end

endmodule

`default_nettype wire