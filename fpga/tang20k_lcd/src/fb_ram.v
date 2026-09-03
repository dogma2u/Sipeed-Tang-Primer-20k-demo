// 2-bit block RAM for vector ink (color at draw).
// 00 empty | 01 player (green) | 10 AI (white) | 11 shots/boom (white)
// Depth is 800*470: full 800*480 x2 overflows GW2A-18's 46 BSRAM (bit-sliced → 48).
module fb_ram #(
    parameter integer DEPTH = 376000,
    parameter integer AW    = 19
) (
    input  wire             clk,
    input  wire             we,
    input  wire [AW-1:0]    waddr,
    input  wire [1:0]       wdata,
    input  wire [AW-1:0]    raddr,
    output reg  [1:0]       rdata
);

(* syn_ramstyle = "block_ram" *) reg [1:0] mem [0:DEPTH-1];

always @(posedge clk) begin
    if (we)
        mem[waddr] <= wdata;
    rdata <= mem[raddr];
end

endmodule
