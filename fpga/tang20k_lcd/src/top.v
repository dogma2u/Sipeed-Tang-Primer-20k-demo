// Tang Primer 20K Dock + 5" LCD -- Space Wars-style (sun + gravity + thrust)
//
// DIP switch 1 down. Controls (active-low):
//   S1 left | S2 right | S3 thrust | S4 fire | S0 hyperspace
//   Diamond = you; wedge = AI
//   Reset = PLL lock only (S0 is NOT board reset)

module top (
    input  wire       sys_clk,
    input  wire       btn_hyper_n,
    input  wire       btn_left_n,
    input  wire       btn_right_n,
    input  wire       btn_thrust_n,
    input  wire       btn_fire_n,
    output wire       lcd_clk,
    output wire       lcd_hsync,
    output wire       lcd_vsync,
    output wire       lcd_de,
    output wire [4:0] lcd_r,
    output wire [5:0] lcd_g,
    output wire [4:0] lcd_b,
    output wire       lcd_bl
);

wire clk_pix;
wire pll_lock;
wire rst_n = pll_lock;

wire [4:0] pix_r;
wire [5:0] pix_g;
wire [4:0] pix_b;
wire [9:0] pix_x;
wire [9:0] pix_y;
wire       de_now;
wire       frame_start;
wire       border_red;

assign lcd_bl = 1'b1;

gowin_rpll u_pll (
    .clkout(clk_pix),
    .lock(pll_lock),
    .clkin(sys_clk)
);

lcd_timing u_lcd (
    .clk(clk_pix),
    .rst_n(rst_n),
    .pix_r_i(pix_r),
    .pix_g_i(pix_g),
    .pix_b_i(pix_b),
    .border_red(border_red),
    .lcd_clk(lcd_clk),
    .lcd_hsync(lcd_hsync),
    .lcd_vsync(lcd_vsync),
    .lcd_de(lcd_de),
    .lcd_r(lcd_r),
    .lcd_g(lcd_g),
    .lcd_b(lcd_b),
    .pix_x(pix_x),
    .pix_y(pix_y),
    .de_now(de_now),
    .frame_start(frame_start)
);

space_wars u_game (
    .clk(clk_pix),
    .rst_n(rst_n),
    .frame_start(frame_start),
    .btn_left_n(btn_left_n),
    .btn_right_n(btn_right_n),
    .btn_thrust_n(btn_thrust_n),
    .btn_fire_n(btn_fire_n),
    .btn_hyper_n(btn_hyper_n),
    .pix_x(pix_x),
    .pix_y(pix_y),
    .de_now(de_now),
    .pix_r(pix_r),
    .pix_g(pix_g),
    .pix_b(pix_b),
    .border_red(border_red)
);

endmodule
