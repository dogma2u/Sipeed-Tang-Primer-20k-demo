// Space Wars glue: physics + draw + scanout + FB + shared sin_cos.
// Controls: S1 left | S2 right | S3 thrust | S4 fire | S0 reset

module space_wars (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       frame_start,
    input  wire       btn_left_n,
    input  wire       btn_right_n,
    input  wire       btn_thrust_n,
    input  wire       btn_fire_n,
    input  wire [9:0] pix_x,
    input  wire [9:0] pix_y,
    input  wire       de_now,
    output wire [4:0] pix_r,
    output wire [5:0] pix_g,
    output wire [4:0] pix_b,
    output wire       border_red
);

// Gowin Education often fails `include — keep constants local.
localparam integer FB_W   = 800;
localparam integer FB_H   = 470;
localparam [1:0] COL_OFF  = 2'b00;

wire               phys_busy, draw_busy;
wire               phys_sc_sel, draw_sc_sel;
wire               draw_go, draw_done;
wire signed [23:0] pos0_x, pos0_y, pos1_x, pos1_y;
wire        [7:0]  ang0, ang1;
wire               thrusting0, thrusting1;
wire        [7:0]  shot_on;
wire       [191:0] shot_x, shot_y;
wire       [127:0] shot_vx, shot_vy;
wire        [47:0] shot_life;
wire        [4:0]  boom0, boom1;
wire signed [15:0] boom0_x, boom0_y, boom_x, boom_y;
wire               boom0_dirty, boom_dirty;
wire               clr_boom0_dirty, clr_boom1_dirty;
wire signed [9:0]  score0, score1;
wire               game_over;
wire        [13:0] timer_sec;
wire        [5:0]  frame_cnt;
wire        [2:0]  lives0;
wire        [14:0] fuel_ms;
wire               black_hole;

wire               plot_en, clear_mode;
wire        [9:0]  plot_x;
wire        [8:0]  plot_y;
wire        [1:0]  plot_col;
wire        [18:0] clear_addr;

// Hold physics until boot FB clear (and any in-flight draw) finishes
wire frame_kick = frame_start & ~draw_busy;

wire sc_sel = draw_busy ? draw_sc_sel : phys_sc_sel;
wire [7:0] ang_now = sc_sel ? ang1 : ang0;
wire signed [15:0] sin_a, cos_a;
sin_cos u_sc (.angle(ang_now), .sin_val(sin_a), .cos_val(cos_a));

wire [18:0] raddr = (pix_y * 19'd800) + {9'd0, pix_x};
wire [18:0] waddr = (plot_y * 19'd800) + {9'd0, plot_x};
wire        w_ok  = plot_en && (plot_x < FB_W) && (plot_y < FB_H);
wire        wr_en = clear_mode || w_ok;
wire [18:0] wr_addr = clear_mode ? clear_addr : waddr;
wire [1:0]  wr_data = clear_mode ? COL_OFF : plot_col;
wire [1:0]  rdata;

fb_ram u_fb (
    .clk(clk), .we(wr_en), .waddr(wr_addr), .wdata(wr_data),
    .raddr(raddr), .rdata(rdata)
);

sw_physics u_phys (
    .clk(clk),
    .rst_n(rst_n),
    .frame_start(frame_kick),
    .draw_done(draw_done),
    .btn_left_n(btn_left_n),
    .btn_right_n(btn_right_n),
    .btn_thrust_n(btn_thrust_n),
    .btn_fire_n(btn_fire_n),
    .sin_a(sin_a),
    .cos_a(cos_a),
    .sc_sel(phys_sc_sel),
    .draw_go(draw_go),
    .busy(phys_busy),
    .pos0_x(pos0_x),
    .pos0_y(pos0_y),
    .pos1_x(pos1_x),
    .pos1_y(pos1_y),
    .ang0(ang0),
    .ang1(ang1),
    .thrusting0(thrusting0),
    .thrusting1(thrusting1),
    .shot_on(shot_on),
    .shot_x(shot_x),
    .shot_y(shot_y),
    .shot_vx(shot_vx),
    .shot_vy(shot_vy),
    .shot_life(shot_life),
    .boom0(boom0),
    .boom1(boom1),
    .boom0_x(boom0_x),
    .boom0_y(boom0_y),
    .boom_x(boom_x),
    .boom_y(boom_y),
    .boom0_dirty(boom0_dirty),
    .boom_dirty(boom_dirty),
    .clr_boom0_dirty(clr_boom0_dirty),
    .clr_boom1_dirty(clr_boom1_dirty),
    .score0(score0),
    .score1(score1),
    .game_over(game_over),
    .timer_sec(timer_sec),
    .frame_cnt(frame_cnt),
    .lives0(lives0),
    .fuel_ms(fuel_ms),
    .black_hole(black_hole),
    .border_red(border_red)
);

sw_draw u_draw (
    .clk(clk),
    .rst_n(rst_n),
    .draw_go(draw_go),
    .draw_done(draw_done),
    .busy(draw_busy),
    .sc_sel(draw_sc_sel),
    .pos0_x(pos0_x),
    .pos0_y(pos0_y),
    .pos1_x(pos1_x),
    .pos1_y(pos1_y),
    .ang0(ang0),
    .ang1(ang1),
    .thrusting0(thrusting0),
    .thrusting1(thrusting1),
    .shot_on(shot_on),
    .shot_x(shot_x),
    .shot_y(shot_y),
    .shot_vx(shot_vx),
    .shot_vy(shot_vy),
    .boom0(boom0),
    .boom1(boom1),
    .boom0_x(boom0_x),
    .boom0_y(boom0_y),
    .boom_x(boom_x),
    .boom_y(boom_y),
    .boom0_dirty(boom0_dirty),
    .boom_dirty(boom_dirty),
    .clr_boom0_dirty(clr_boom0_dirty),
    .clr_boom1_dirty(clr_boom1_dirty),
    .sin_a(sin_a),
    .cos_a(cos_a),
    .plot_en(plot_en),
    .plot_x(plot_x),
    .plot_y(plot_y),
    .plot_col(plot_col),
    .clear_mode(clear_mode),
    .clear_addr(clear_addr)
);

sw_scanout u_scan (
    .clk(clk),
    .de_now(de_now),
    .pix_x(pix_x),
    .pix_y(pix_y),
    .rdata(rdata),
    .black_hole(black_hole),
    .game_over(game_over),
    .frame_cnt(frame_cnt),
    .timer_sec(timer_sec),
    .score0(score0),
    .score1(score1),
    .lives0(lives0),
    .fuel_ms(fuel_ms),
    .pix_r(pix_r),
    .pix_g(pix_g),
    .pix_b(pix_b)
);

endmodule
