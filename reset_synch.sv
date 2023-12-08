`default_nettype none
module reset_synch (
    input wire clk, RST_n,
    output reg rst_n 
);

reg ff1;

always_ff @(posedge clk, negedge RST_n) begin
    if (!RST_n) begin
        ff1 <= 0;
        rst_n <= 0;
    end
    else begin
        ff1 <= 1;
        rst_n <= ff1;
    end
end
    
endmodule

`default_nettype wire