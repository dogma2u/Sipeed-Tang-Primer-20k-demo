// 1-bit block RAM for full-res vector lines (800x480).
module fb_ram #(
    parameter integer DEPTH = 384000,
    parameter integer AW    = 19
) (
    input  wire             clk,
    input  wire             we,
    input  wire [AW-1:0]    waddr,
    input  wire             wdata,
    input  wire [AW-1:0]    raddr,
    output reg              rdata
);

(* syn_ramstyle = "block_ram" *) reg mem [0:DEPTH-1];

always @(posedge clk) begin
    if (we)
        mem[waddr] <= wdata;
    rdata <= mem[raddr];
end

endmodule
