// S1 left | S2 right | S3 thrust | S4 fire | S0 reset
// Enterprise = you; wedge = AI (sloppy chase + inaccurate shots). Bounce walls. No gravity.

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
    output reg  [4:0] pix_r,
    output reg  [5:0] pix_g,
    output reg  [4:0] pix_b
);

localparam integer FB_W   = 800;
localparam integer FB_H   = 480;
localparam integer FB_SZ  = FB_W * FB_H;
localparam integer SUN_X  = 400;
localparam integer SUN_Y  = 240;
localparam integer SUN_R  = 18;
localparam integer MARGIN   = 20;
localparam integer NSTARS   = 28;
localparam integer MAXV     = 21;
localparam integer BUL_LIFE = 28;
localparam integer BOOM_N   = 16;

localparam [3:0] ST_IDLE   = 4'd0;
localparam [3:0] ST_PHYS   = 4'd1;
localparam [3:0] ST_CLEAR  = 4'd2;
localparam [3:0] ST_ERASE  = 4'd3;
localparam [3:0] ST_STARS  = 4'd4;
localparam [3:0] ST_XFORM  = 4'd5;
localparam [3:0] ST_SHIP   = 4'd6;
localparam [3:0] ST_FLAME  = 4'd7;
localparam [3:0] ST_DONE   = 4'd8;
localparam [3:0] ST_NEXT   = 4'd9;
localparam [3:0] ST_SHOT   = 4'd10;
localparam [3:0] ST_BOOM   = 4'd11;

reg [3:0]  state;
reg [18:0] clear_addr;
reg [2:0]  phys_phase;
reg [4:0]  si;
reg        ship_sel; // 0=needle(human), 1=wedge(AI)
reg        have_prev0, have_prev1;
reg        thrusting0, thrusting1;
reg        prev_thrust0, prev_thrust1;

reg [7:0]  ang0, ang1;
reg signed [23:0] pos0_x, pos0_y, pos1_x, pos1_y;
reg signed [15:0] vel0_x, vel0_y, vel1_x, vel1_y;
reg signed [15:0] dx, dy, fx, fy;
reg signed [31:0] r2;
reg signed [31:0] cross, dotp;

reg signed [15:0] sxv [0:MAXV-1];
reg signed [15:0] syv [0:MAXV-1];
reg signed [15:0] pxv0 [0:MAXV-1];
reg signed [15:0] pyv0 [0:MAXV-1];
reg signed [15:0] pxv1 [0:MAXV-1];
reg signed [15:0] pyv1 [0:MAXV-1];
reg signed [15:0] pflame0_x, pflame0_y, pflame1_x, pflame1_y;

// Player torpedo
reg               bullet_on;
reg               bul_have_prev;
reg               fire_hold;
reg signed [23:0] bul_x, bul_y;
reg signed [15:0] bul_vx, bul_vy;
reg [9:0]         bul_ox, bul_ox2;
reg [8:0]         bul_oy, bul_oy2;
reg [4:0]         fire_cd;
reg [5:0]         bul_life;
// AI torpedo (separate streak)
reg               ebul_on;
reg               ebul_have_prev;
reg signed [23:0] ebul_x, ebul_y;
reg signed [15:0] ebul_vx, ebul_vy;
reg [9:0]         ebul_ox, ebul_ox2;
reg [8:0]         ebul_oy, ebul_oy2;
reg [5:0]         ebul_life;
reg [5:0]         ai_cd;
reg [7:0]         lfsr;
reg [4:0]         ai_pulse;
reg [4:0]         boom0, boom1;
reg signed [15:0] boom0_x, boom0_y, boom_x, boom_y;
reg [4:0]         boom0_len_prev, boom_len_prev;
reg               boom0_dirty, boom_dirty;
reg               boom_sel;

reg [4:0]  vi;
reg [4:0]  ei;
reg [4:0]  nvert;
reg [4:0]  nedge;
reg [4:0]  hitch;

reg signed [15:0] b_x, b_y, b_dx, b_dy, b_sx, b_sy, b_err, end_x, end_y;
reg               line_active;
reg               plot_en;
reg [9:0]         plot_x;
reg [8:0]         plot_y;
reg               plot_bit;

wire [7:0] ang_now = ship_sel ? ang1 : ang0;
wire signed [15:0] sin_a, cos_a;
sin_cos u_sc (.angle(ang_now), .sin_val(sin_a), .cos_val(cos_a));

wire left_p   = ~btn_left_n;
wire right_p  = ~btn_right_n;
wire thrust_p = ~btn_thrust_n;
wire fire_p   = ~btn_fire_n;

function signed [15:0] mul_q88;
    input signed [15:0] a, b;
    reg signed [31:0] p;
    begin
        p = a * b;
        mul_q88 = $signed(p[23:8]);
    end
endfunction

function signed [15:0] abs16;
    input signed [15:0] v;
    begin abs16 = v[15] ? -v : v; end
endfunction

// Player: clean top-down TOS (saucer, neck, hull, two nacelles). Nose = +X.
// Wedge: JS 4-point. kind 0=player, 1=AI
function signed [7:0] shp_x;
    input        kind;
    input [4:0]  i;
    begin
        if (!kind) begin
            case (i)
                5'd0:  shp_x =  8'sd16; // saucer nose
                5'd1:  shp_x =  8'sd10;
                5'd2:  shp_x =  8'sd3;
                5'd3:  shp_x =  8'sd0;  // saucer aft / neck
                5'd4:  shp_x =  8'sd3;
                5'd5:  shp_x =  8'sd10;
                5'd6:  shp_x = -8'sd4;  // neck
                5'd7:  shp_x = -8'sd4;
                5'd8:  shp_x = -8'sd12; // hull aft
                5'd9:  shp_x = -8'sd12;
                5'd10: shp_x = -8'sd3;  // port strut
                5'd11: shp_x = -8'sd15; // port nacelle aft
                5'd12: shp_x = -8'sd15;
                5'd13: shp_x =  8'sd2;  // port nacelle nose
                5'd14: shp_x = -8'sd3;  // stbd strut
                5'd15: shp_x = -8'sd15; // stbd nacelle aft
                5'd16: shp_x = -8'sd15;
                5'd17: shp_x =  8'sd2;  // stbd nacelle nose
                default: shp_x = 8'sd0;
            endcase
        end else begin
            case (i)
                5'd0: shp_x =  8'sd14;
                5'd1: shp_x = -8'sd11;
                5'd2: shp_x = -8'sd3;
                5'd3: shp_x = -8'sd11;
                default: shp_x = 8'sd0;
            endcase
        end
    end
endfunction

function signed [7:0] shp_y;
    input        kind;
    input [4:0]  i;
    begin
        if (!kind) begin
            case (i)
                5'd0:  shp_y =  8'sd0;
                5'd1:  shp_y =  8'sd8;
                5'd2:  shp_y =  8'sd8;
                5'd3:  shp_y =  8'sd0;
                5'd4:  shp_y = -8'sd8;
                5'd5:  shp_y = -8'sd8;
                5'd6:  shp_y =  8'sd2;
                5'd7:  shp_y = -8'sd2;
                5'd8:  shp_y =  8'sd3;
                5'd9:  shp_y = -8'sd3;
                5'd10: shp_y =  8'sd6;
                5'd11: shp_y =  8'sd6;
                5'd12: shp_y =  8'sd8;
                5'd13: shp_y =  8'sd8;
                5'd14: shp_y = -8'sd6;
                5'd15: shp_y = -8'sd6;
                5'd16: shp_y = -8'sd8;
                5'd17: shp_y = -8'sd8;
                default: shp_y = 8'sd0;
            endcase
        end else begin
            case (i)
                5'd0: shp_y =  8'sd0;
                5'd1: shp_y = -8'sd9;
                5'd2: shp_y =  8'sd0;
                5'd3: shp_y =  8'sd9;
                default: shp_y = 8'sd0;
            endcase
        end
    end
endfunction

function [4:0] edge_a;
    input       kind;
    input [4:0] e;
    begin
        if (!kind) begin
            case (e)
                // saucer hex
                5'd0:  edge_a=5'd0;  5'd1:  edge_a=5'd1;  5'd2:  edge_a=5'd2;
                5'd3:  edge_a=5'd3;  5'd4:  edge_a=5'd4;  5'd5:  edge_a=5'd5;
                // neck + hull
                5'd6:  edge_a=5'd3;  5'd7:  edge_a=5'd3;  5'd8:  edge_a=5'd6;
                5'd9:  edge_a=5'd6;  5'd10: edge_a=5'd7;  5'd11: edge_a=5'd8;
                // port nacelle
                5'd12: edge_a=5'd8;  5'd13: edge_a=5'd10; 5'd14: edge_a=5'd11;
                5'd15: edge_a=5'd12; 5'd16: edge_a=5'd13;
                // starboard nacelle
                5'd17: edge_a=5'd9;  5'd18: edge_a=5'd14; 5'd19: edge_a=5'd15;
                5'd20: edge_a=5'd16; 5'd21: edge_a=5'd17;
                default: edge_a=5'd0;
            endcase
        end else begin
            case (e)
                5'd0: edge_a=5'd0; 5'd1: edge_a=5'd1;
                5'd2: edge_a=5'd2; 5'd3: edge_a=5'd3;
                default: edge_a=5'd0;
            endcase
        end
    end
endfunction

function [4:0] edge_b;
    input       kind;
    input [4:0] e;
    begin
        if (!kind) begin
            case (e)
                5'd0:  edge_b=5'd1;  5'd1:  edge_b=5'd2;  5'd2:  edge_b=5'd3;
                5'd3:  edge_b=5'd4;  5'd4:  edge_b=5'd5;  5'd5:  edge_b=5'd0;
                5'd6:  edge_b=5'd6;  5'd7:  edge_b=5'd7;  5'd8:  edge_b=5'd7;
                5'd9:  edge_b=5'd8;  5'd10: edge_b=5'd9;  5'd11: edge_b=5'd9;
                5'd12: edge_b=5'd10; 5'd13: edge_b=5'd11; 5'd14: edge_b=5'd12;
                5'd15: edge_b=5'd13; 5'd16: edge_b=5'd10;
                5'd17: edge_b=5'd14; 5'd18: edge_b=5'd15; 5'd19: edge_b=5'd16;
                5'd20: edge_b=5'd17; 5'd21: edge_b=5'd14;
                default: edge_b=5'd0;
            endcase
        end else begin
            case (e)
                5'd0: edge_b=5'd1; 5'd1: edge_b=5'd2;
                5'd2: edge_b=5'd3; 5'd3: edge_b=5'd0;
                default: edge_b=5'd0;
            endcase
        end
    end
endfunction

function [9:0] star_x;
    input [4:0] i;
    begin
        case (i)
            5'd0: star_x=10'd90;  5'd1: star_x=10'd130; 5'd2: star_x=10'd170;
            5'd3: star_x=10'd210; 5'd4: star_x=10'd230; 5'd5: star_x=10'd270;
            5'd6: star_x=10'd300; 5'd7: star_x=10'd520; 5'd8: star_x=10'd560;
            5'd9: star_x=10'd600; 5'd10:star_x=10'd640; 5'd11:star_x=10'd680;
            5'd12:star_x=10'd100; 5'd13:star_x=10'd180; 5'd14:star_x=10'd130;
            5'd15:star_x=10'd150; 5'd16:star_x=10'd170; 5'd17:star_x=10'd110;
            5'd18:star_x=10'd190; 5'd19:star_x=10'd650; 5'd20:star_x=10'd680;
            5'd21:star_x=10'd710; 5'd22:star_x=10'd690; 5'd23:star_x=10'd720;
            5'd24:star_x=10'd720; 5'd25:star_x=10'd700; 5'd26:star_x=10'd740;
            5'd27:star_x=10'd760; default: star_x=10'd0;
        endcase
    end
endfunction

function [8:0] star_y;
    input [4:0] i;
    begin
        case (i)
            5'd0: star_y=9'd50;  5'd1: star_y=9'd60;  5'd2: star_y=9'd55;
            5'd3: star_y=9'd70;  5'd4: star_y=9'd100; 5'd5: star_y=9'd110;
            5'd6: star_y=9'd95;  5'd7: star_y=9'd40;  5'd8: star_y=9'd70;
            5'd9: star_y=9'd45;  5'd10:star_y=9'd75;  5'd11:star_y=9'd50;
            5'd12:star_y=9'd360; 5'd13:star_y=9'd350; 5'd14:star_y=9'd390;
            5'd15:star_y=9'd395; 5'd16:star_y=9'd400; 5'd17:star_y=9'd440;
            5'd18:star_y=9'd445; 5'd19:star_y=9'd400; 5'd20:star_y=9'd420;
            5'd21:star_y=9'd400; 5'd22:star_y=9'd440; 5'd23:star_y=9'd380;
            5'd24:star_y=9'd160; 5'd25:star_y=9'd130; 5'd26:star_y=9'd130;
            5'd27:star_y=9'd100; default: star_y=9'd0;
        endcase
    end
endfunction

task start_line;
    input signed [15:0] x0, y0, x1i, y1i;
    begin
        end_x <= x1i; end_y <= y1i;
        b_dx  <= abs16(x1i - x0);
        b_dy  <= abs16(y1i - y0);
        b_sx  <= (x0 < x1i) ? 16'sd1 : -16'sd1;
        b_sy  <= (y0 < y1i) ? 16'sd1 : -16'sd1;
        b_err <= abs16(x1i - x0) - abs16(y1i - y0);
        b_x   <= x0; b_y <= y0;
    end
endtask

task step_bresenham;
    begin
        if ((b_x == end_x) && (b_y == end_y))
            line_active <= 1'b0;
        else begin : bstep
            reg signed [15:0] e2, nerr, nx, ny;
            e2 = b_err <<< 1; nerr = b_err; nx = b_x; ny = b_y;
            if (e2 > -b_dy) begin nerr = nerr - b_dy; nx = nx + b_sx; end
            if (e2 <  b_dx) begin nerr = nerr + b_dx; ny = ny + b_sy; end
            b_err <= nerr; b_x <= nx; b_y <= ny;
        end
    end
endtask

task bounce_ship;
    inout signed [23:0] px, py;
    inout signed [15:0] vx, vy;
    begin
        if (px < (MARGIN <<< 8)) begin
            px = MARGIN <<< 8;
            vx = -vx;
        end else if (px > ((FB_W - MARGIN) <<< 8)) begin
            px = (FB_W - MARGIN) <<< 8;
            vx = -vx;
        end
        if (py < (MARGIN <<< 8)) begin
            py = MARGIN <<< 8;
            vy = -vy;
        end else if (py > ((FB_H - MARGIN) <<< 8)) begin
            py = (FB_H - MARGIN) <<< 8;
            vy = -vy;
        end
    end
endtask

task load_ship_geom;
    input kind;
    begin
        if (!kind) begin nvert = 5'd18; nedge = 5'd22; hitch = 5'd11; end
        else       begin nvert = 5'd4;  nedge = 5'd4;  hitch = 5'd2; end
    end
endtask

task respawn0;
    begin
        pos0_x <= 24'sd140 <<< 8;
        pos0_y <= 24'sd240 <<< 8;
        vel0_x <= 16'sd0;
        vel0_y <= -16'sd40;
        ang0   <= 8'd192;
    end
endtask

task respawn1;
    begin
        pos1_x <= 24'sd660 <<< 8;
        pos1_y <= 24'sd240 <<< 8;
        vel1_x <= 16'sd0;
        vel1_y <= 16'sd40;
        ang1   <= 8'd64;
    end
endtask

wire [18:0] raddr = (pix_y * 19'd800) + {9'd0, pix_x};
wire        in_fb = de_now && (pix_x < FB_W) && (pix_y < FB_H);
wire [18:0] waddr = (plot_y * 19'd800) + {9'd0, plot_x};
wire        w_ok  = plot_en && (plot_x < FB_W) && (plot_y < FB_H);
wire        wr_en = (state == ST_CLEAR) || w_ok;
wire [18:0] wr_addr = (state == ST_CLEAR) ? clear_addr : waddr;
wire        wr_data = (state == ST_CLEAR) ? 1'b0 : plot_bit;
wire        rdata;

fb_ram u_fb (
    .clk(clk), .we(wr_en), .waddr(wr_addr), .wdata(wr_data),
    .raddr(raddr), .rdata(rdata)
);

reg in_fb_d;
reg [9:0] pix_x_d, pix_y_d;

always @(posedge clk) begin
    in_fb_d <= in_fb;
    pix_x_d <= pix_x;
    pix_y_d <= pix_y;
end

wire signed [15:0] sdx_d = $signed({6'b0, pix_x_d}) - 16'sd400;
wire signed [15:0] sdy_d = $signed({6'b0, pix_y_d}) - 16'sd240;
wire signed [31:0] srr_d = sdx_d * sdx_d + sdy_d * sdy_d;
wire in_sun = in_fb_d && (srr_d <= (SUN_R * SUN_R));

wire signed [15:0] boom_cx   = boom_sel ? boom_x : boom0_x;
wire signed [15:0] boom_cy   = boom_sel ? boom_y : boom0_y;
wire [4:0]         boom_clen = boom_sel ? boom_len_prev : boom0_len_prev;
wire [4:0]         boom_cnt  = boom_sel ? boom1 : boom0;

always @(posedge clk) begin
    if (in_sun) begin
        if (srr_d < 32'sd80) begin
            pix_r <= 5'h1F; pix_g <= 6'h30; pix_b <= 5'h04;
        end else if (srr_d < 32'sd200) begin
            pix_r <= 5'h1E; pix_g <= 6'h24; pix_b <= 5'h02;
        end else begin
            pix_r <= 5'h18; pix_g <= 6'h14; pix_b <= 5'h00;
        end
    end else if (in_fb_d && rdata) begin
        pix_r <= 5'h1F; pix_g <= 6'h3F; pix_b <= 5'h1F;
    end else begin
        pix_r <= 5'd0; pix_g <= 6'd0; pix_b <= 5'd0;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state        <= ST_CLEAR;
        clear_addr   <= 19'd0;
        plot_en      <= 1'b0;
        line_active  <= 1'b0;
        have_prev0   <= 1'b0;
        have_prev1   <= 1'b0;
        thrusting0   <= 1'b0;
        thrusting1   <= 1'b0;
        prev_thrust0 <= 1'b0;
        prev_thrust1 <= 1'b0;
        phys_phase   <= 3'd0;
        ship_sel     <= 1'b0;
        vi <= 5'd0; ei <= 4'd0; si <= 5'd0;
        nvert <= 5'd18; nedge <= 5'd22; hitch <= 5'd11;
        boom0_dirty    <= 1'b0;
        boom_dirty     <= 1'b0;
        bullet_on      <= 1'b0;
        bul_have_prev  <= 1'b0;
        ebul_on        <= 1'b0;
        ebul_have_prev <= 1'b0;
        fire_hold      <= 1'b0;
        fire_cd        <= 5'd0;
        ai_cd          <= 6'd20;
        lfsr           <= 8'hA5;
        ai_pulse       <= 5'd0;
        bul_life       <= 6'd0;
        ebul_life      <= 6'd0;
        boom0          <= 5'd0;
        boom1          <= 5'd0;
        boom0_len_prev <= 5'd0;
        boom_len_prev  <= 5'd0;
        boom_sel       <= 1'b0;
        respawn0;
        respawn1;
    end else begin
        plot_en <= 1'b0;
        if (fire_p)
            fire_hold <= 1'b1;

        case (state)
            ST_IDLE: if (frame_start) begin
                phys_phase <= 3'd0;
                state <= ST_PHYS;
            end

            // ---- physics: human needle + AI wedge ----
            ST_PHYS: begin
                case (phys_phase)
                    3'd0: begin
                        if (left_p)  ang0 <= ang0 - 8'd4;
                        if (right_p) ang0 <= ang0 + 8'd4;
                        thrusting0 <= thrust_p;
                        dx <= $signed(pos0_x[23:8]) - $signed(pos1_x[23:8]);
                        dy <= $signed(pos0_y[23:8]) - $signed(pos1_y[23:8]);
                        lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
                        ai_pulse <= ai_pulse + 5'd1;
                        phys_phase <= 3'd1;
                    end
                    3'd1: begin
                        // Need cos/sin of ang1 — temporarily use ship_sel=1 path:
                        // Approximate with stored sin_cos of ang_now; force ship_sel
                        ship_sel <= 1'b1;
                        phys_phase <= 3'd2;
                    end
                    3'd2: begin
                        // cross = cos*dy - sin*dx ; rotate AI toward player
                        cross <= cos_a * dy - sin_a * dx;
                        dotp  <= cos_a * dx + sin_a * dy;
                        phys_phase <= 3'd3;
                    end
                    3'd3: begin
                        if (boom1 == 5'd0) begin : ai_steer
                            reg signed [15:0] adx, ady;
                            adx = dx[15] ? -dx : dx;
                            ady = dy[15] ? -dy : dy;
                            // Sluggish track: skip some frames, slow turn, always yaw if target is behind
                            if (lfsr[1:0] != 2'b00) begin
                                if (dotp[31])
                                    ang1 <= ang1 + 8'd2;
                                else if (cross[31])
                                    ang1 <= ang1 + 8'd2;
                                else
                                    ang1 <= ang1 - 8'd2;
                            end
                            // Coast when close; pulse thrust so it overshoots
                            thrusting1 <= ~dotp[31] && (dotp > 32'sd1500) &&
                                          ((adx + ady) > 16'sd70) &&
                                          (ai_pulse[4:3] != 2'b11);
                        end else
                            thrusting1 <= 1'b0;
                        phys_phase <= 3'd4;
                    end
                    3'd4: begin
                        ship_sel <= 1'b0; // cos/sin -> ang0 next cycle
                        phys_phase <= 3'd5;
                    end
                    3'd5: begin
                        vel0_x <= vel0_x + mul_q88(cos_a, thrusting0 ? 16'sd40 : 16'sd0)
                                  - (vel0_x >>> 8);
                        vel0_y <= vel0_y + mul_q88(sin_a, thrusting0 ? 16'sd40 : 16'sd0)
                                  - (vel0_y >>> 8);
                        // Fire while cos/sin = player heading
                        if (fire_cd != 5'd0)
                            fire_cd <= fire_cd - 5'd1;
                        else if (fire_hold && !bullet_on && (boom0 == 5'd0) && (boom1 == 5'd0)) begin
                            begin : spawn_shot
                                reg signed [15:0] ox, oy;
                                ox = mul_q88(cos_a, 16'sd18);
                                oy = mul_q88(sin_a, 16'sd18);
                                bul_x  <= pos0_x + {{8{ox[15]}}, ox};
                                bul_y  <= pos0_y + {{8{oy[15]}}, oy};
                                // ~10 px/frame in Q8.8
                                bul_vx <= mul_q88(cos_a, 16'sd10 <<< 8) + (vel0_x >>> 1);
                                bul_vy <= mul_q88(sin_a, 16'sd10 <<< 8) + (vel0_y >>> 1);
                            end
                            bullet_on <= 1'b1;
                            bul_life  <= BUL_LIFE[5:0];
                            fire_cd   <= 5'd12;
                            fire_hold <= 1'b0;
                        end
                        ship_sel <= 1'b1;
                        phys_phase <= 3'd6;
                    end
                    3'd6: begin
                        vel1_x <= vel1_x + mul_q88(cos_a, thrusting1 ? 16'sd32 : 16'sd0)
                                  - (vel1_x >>> 8);
                        vel1_y <= vel1_y + mul_q88(sin_a, thrusting1 ? 16'sd32 : 16'sd0)
                                  - (vel1_y >>> 8);
                        // Wide cone + side miss; long irregular cooldown
                        if (ai_cd != 6'd0)
                            ai_cd <= ai_cd - 6'd1;
                        else if (!ebul_on && (boom0 == 5'd0) && (boom1 == 5'd0) &&
                                 ~dotp[31] && (dotp > 32'sd4000)) begin
                            begin : spawn_eshot
                                reg signed [15:0] ox, oy, miss;
                                ox = mul_q88(cos_a, 16'sd16);
                                oy = mul_q88(sin_a, 16'sd16);
                                miss = $signed({12'b0, lfsr[3:0]}) - 16'sd8; // -8..7
                                ebul_x  <= pos1_x + {{8{ox[15]}}, ox};
                                ebul_y  <= pos1_y + {{8{oy[15]}}, oy};
                                ebul_vx <= mul_q88(cos_a, 16'sd10 <<< 8)
                                         + mul_q88(-sin_a, miss <<< 7)
                                         + (vel1_x >>> 1);
                                ebul_vy <= mul_q88(sin_a, 16'sd10 <<< 8)
                                         + mul_q88( cos_a, miss <<< 7)
                                         + (vel1_y >>> 1);
                            end
                            ebul_on   <= 1'b1;
                            ebul_life <= BUL_LIFE[5:0];
                            ai_cd     <= 6'd42 + {2'b0, lfsr[3:0]};
                        end
                        phys_phase <= 3'd7;
                    end
                    3'd7: begin
                        pos0_x <= pos0_x + {{8{vel0_x[15]}}, vel0_x};
                        pos0_y <= pos0_y + {{8{vel0_y[15]}}, vel0_y};
                        pos1_x <= pos1_x + {{8{vel1_x[15]}}, vel1_x};
                        pos1_y <= pos1_y + {{8{vel1_y[15]}}, vel1_y};
                        phys_phase <= 3'd0;
                        // bounce + sun in dedicated substeps via flags
                        state <= ST_NEXT; // reuse: bounce/sun check
                        ei <= 4'd0; // mark bounce stage via ei
                    end
                    default: phys_phase <= 3'd0;
                endcase
            end

            // Bounce walls + sun hit (ei=0 bounce, ei=1 sun)
            ST_NEXT: begin
                if (ei == 4'd0) begin
                    begin : bnc
                        reg signed [23:0] t0x, t0y, t1x, t1y;
                        reg signed [15:0] v0x, v0y, v1x, v1y;
                        t0x = pos0_x; t0y = pos0_y; v0x = vel0_x; v0y = vel0_y;
                        t1x = pos1_x; t1y = pos1_y; v1x = vel1_x; v1y = vel1_y;
                        if (t0x < (MARGIN <<< 8)) begin t0x = MARGIN <<< 8; v0x = -v0x; end
                        else if (t0x > ((FB_W-MARGIN) <<< 8)) begin t0x = (FB_W-MARGIN) <<< 8; v0x = -v0x; end
                        if (t0y < (MARGIN <<< 8)) begin t0y = MARGIN <<< 8; v0y = -v0y; end
                        else if (t0y > ((FB_H-MARGIN) <<< 8)) begin t0y = (FB_H-MARGIN) <<< 8; v0y = -v0y; end
                        if (t1x < (MARGIN <<< 8)) begin t1x = MARGIN <<< 8; v1x = -v1x; end
                        else if (t1x > ((FB_W-MARGIN) <<< 8)) begin t1x = (FB_W-MARGIN) <<< 8; v1x = -v1x; end
                        if (t1y < (MARGIN <<< 8)) begin t1y = MARGIN <<< 8; v1y = -v1y; end
                        else if (t1y > ((FB_H-MARGIN) <<< 8)) begin t1y = (FB_H-MARGIN) <<< 8; v1y = -v1y; end
                        pos0_x <= t0x; pos0_y <= t0y; vel0_x <= v0x; vel0_y <= v0y;
                        pos1_x <= t1x; pos1_y <= t1y; vel1_x <= v1x; vel1_y <= v1y;
                    end
                    dx <= $signed(pos0_x[23:8]) - 16'sd400;
                    dy <= $signed(pos0_y[23:8]) - 16'sd240;
                    ei <= 4'd1;
                end else if (ei == 4'd1) begin
                    r2 <= dx * dx + dy * dy;
                    dx <= $signed(pos1_x[23:8]) - 16'sd400;
                    dy <= $signed(pos1_y[23:8]) - 16'sd240;
                    ei <= 4'd2;
                end else if (ei == 4'd2) begin
                    if (r2 < 32'sd400) respawn0;
                    r2 <= dx * dx + dy * dy;
                    ei <= 4'd3;
                end else if (ei == 4'd3) begin
                    if (r2 < 32'sd400) respawn1;
                    if (bullet_on) begin
                        bul_x <= bul_x + {{8{bul_vx[15]}}, bul_vx};
                        bul_y <= bul_y + {{8{bul_vy[15]}}, bul_vy};
                        if (bul_life != 6'd0)
                            bul_life <= bul_life - 6'd1;
                    end
                    if (ebul_on) begin
                        ebul_x <= ebul_x + {{8{ebul_vx[15]}}, ebul_vx};
                        ebul_y <= ebul_y + {{8{ebul_vy[15]}}, ebul_vy};
                        if (ebul_life != 6'd0)
                            ebul_life <= ebul_life - 6'd1;
                    end
                    if (boom0 == 5'd1)
                        respawn0;
                    if (boom1 == 5'd1)
                        respawn1;
                    if (boom0 != 5'd0)
                        boom0 <= boom0 - 5'd1;
                    if (boom1 != 5'd0)
                        boom1 <= boom1 - 5'd1;
                    ei <= 4'd4;
                end else begin
                    if (bullet_on) begin
                        if ((bul_life == 6'd0) ||
                            (bul_x < (MARGIN <<< 8)) ||
                            (bul_x > ((FB_W - MARGIN) <<< 8)) ||
                            (bul_y < (MARGIN <<< 8)) ||
                            (bul_y > ((FB_H - MARGIN) <<< 8)))
                            bullet_on <= 1'b0;
                        else begin : hitchk
                            reg signed [15:0] bdx, bdy, adx, ady;
                            bdx = $signed(bul_x[23:8]) - $signed(pos1_x[23:8]);
                            bdy = $signed(bul_y[23:8]) - $signed(pos1_y[23:8]);
                            adx = bdx[15] ? -bdx : bdx;
                            ady = bdy[15] ? -bdy : bdy;
                            if ((boom1 == 5'd0) && (adx < 16'sd16) && (ady < 16'sd16)) begin
                                bullet_on <= 1'b0;
                                boom1      <= BOOM_N[4:0];
                                boom_dirty <= 1'b1;
                                boom_x     <= $signed(pos1_x[23:8]);
                                boom_y     <= $signed(pos1_y[23:8]);
                            end else begin
                                bdx = $signed(bul_x[23:8]) - 16'sd400;
                                bdy = $signed(bul_y[23:8]) - 16'sd240;
                                if ((bdx * bdx + bdy * bdy) < 32'sd400)
                                    bullet_on <= 1'b0;
                            end
                        end
                    end
                    if (ebul_on) begin
                        if ((ebul_life == 6'd0) ||
                            (ebul_x < (MARGIN <<< 8)) ||
                            (ebul_x > ((FB_W - MARGIN) <<< 8)) ||
                            (ebul_y < (MARGIN <<< 8)) ||
                            (ebul_y > ((FB_H - MARGIN) <<< 8)))
                            ebul_on <= 1'b0;
                        else begin : ehitchk
                            reg signed [15:0] bdx, bdy, adx, ady;
                            bdx = $signed(ebul_x[23:8]) - $signed(pos0_x[23:8]);
                            bdy = $signed(ebul_y[23:8]) - $signed(pos0_y[23:8]);
                            adx = bdx[15] ? -bdx : bdx;
                            ady = bdy[15] ? -bdy : bdy;
                            if ((boom0 == 5'd0) && (adx < 16'sd20) && (ady < 16'sd20)) begin
                                ebul_on     <= 1'b0;
                                boom0       <= BOOM_N[4:0];
                                boom0_dirty <= 1'b1;
                                boom0_x     <= $signed(pos0_x[23:8]);
                                boom0_y     <= $signed(pos0_y[23:8]);
                            end else begin
                                bdx = $signed(ebul_x[23:8]) - 16'sd400;
                                bdy = $signed(ebul_y[23:8]) - 16'sd240;
                                if ((bdx * bdx + bdy * bdy) < 32'sd400)
                                    ebul_on <= 1'b0;
                            end
                        end
                    end
                    ship_sel    <= 1'b0;
                    line_active <= 1'b0;
                    plot_bit    <= 1'b0;
                    ei          <= 4'd0;
                    if (have_prev0 || have_prev1)
                        state <= ST_ERASE;
                    else begin
                        si <= 5'd0;
                        state <= ST_STARS;
                    end
                end
            end

            ST_CLEAR: begin
                if (clear_addr == FB_SZ - 1) begin
                    si <= 5'd0;
                    state <= ST_STARS;
                end else
                    clear_addr <= clear_addr + 19'd1;
            end

            ST_ERASE: begin
                if (!line_active) begin
                    if (ei == 4'd0) begin
                        load_ship_geom(ship_sel);
                        nvert <= (!ship_sel) ? 5'd18 : 5'd4;
                        nedge <= (!ship_sel) ? 5'd22 : 5'd4;
                        hitch <= (!ship_sel) ? 5'd11 : 5'd2;
                        ei <= 5'd1;
                    end else if ((ei - 5'd1) >= nedge) begin
                        if ((ship_sel ? prev_thrust1 : prev_thrust0)) begin
                            if (!ship_sel)
                                start_line(pxv0[hitch], pyv0[hitch], pflame0_x, pflame0_y);
                            else
                                start_line(pxv1[hitch], pyv1[hitch], pflame1_x, pflame1_y);
                            line_active <= 1'b1;
                            if (!ship_sel) prev_thrust0 <= 1'b0;
                            else           prev_thrust1 <= 1'b0;
                            ei <= 5'd31;
                        end else if (!ship_sel && have_prev1) begin
                            ship_sel <= 1'b1;
                            ei <= 5'd0;
                        end else begin
                            si <= 5'd0;
                            state <= ST_STARS;
                        end
                    end else begin
                        if (!ship_sel)
                            start_line(pxv0[edge_a(1'b0, ei - 5'd1)],
                                       pyv0[edge_a(1'b0, ei - 5'd1)],
                                       pxv0[edge_b(1'b0, ei - 5'd1)],
                                       pyv0[edge_b(1'b0, ei - 5'd1)]);
                        else
                            start_line(pxv1[edge_a(1'b1, ei - 5'd1)],
                                       pyv1[edge_a(1'b1, ei - 5'd1)],
                                       pxv1[edge_b(1'b1, ei - 5'd1)],
                                       pyv1[edge_b(1'b1, ei - 5'd1)]);
                        line_active <= 1'b1;
                        plot_bit <= 1'b0;
                        ei <= ei + 5'd1;
                    end
                end else begin
                    plot_bit <= 1'b0;
                    if ((b_x >= 0) && (b_x < FB_W) && (b_y >= 0) && (b_y < FB_H)) begin
                        plot_en <= 1'b1;
                        plot_x <= b_x[9:0];
                        plot_y <= b_y[8:0];
                    end
                    step_bresenham;
                end
            end

            ST_STARS: begin
                plot_en <= 1'b1; plot_bit <= 1'b1;
                plot_x <= star_x(si); plot_y <= star_y(si);
                if (si == NSTARS - 1) begin
                    vi <= 5'd0;
                    if ((boom0 != 5'd0) || boom0_dirty) begin
                        if ((boom1 != 5'd0) || boom_dirty)
                            state <= ST_SHOT;
                        else begin
                            ship_sel <= 1'b1;
                            nvert    <= 5'd4;
                            nedge    <= 5'd4;
                            hitch    <= 5'd2;
                            state    <= ST_XFORM;
                        end
                    end else begin
                        ship_sel <= 1'b0;
                        nvert    <= 5'd18;
                        nedge    <= 5'd22;
                        hitch    <= 5'd11;
                        state    <= ST_XFORM;
                    end
                end else
                    si <= si + 5'd1;
            end

            ST_XFORM: begin
                begin : xfv
                    reg signed [7:0] tx, ty;
                    reg signed [15:0] lx, ly;
                    reg signed [23:0] px, py;
                    tx = shp_x(ship_sel, vi);
                    ty = shp_y(ship_sel, vi);
                    lx = {{8{tx[7]}}, tx};
                    ly = {{8{ty[7]}}, ty};
                    px = ship_sel ? pos1_x : pos0_x;
                    py = ship_sel ? pos1_y : pos0_y;
                    sxv[vi] <= $signed(px[23:8]) + mul_q88(lx, cos_a) - mul_q88(ly, sin_a);
                    syv[vi] <= $signed(py[23:8]) + mul_q88(lx, sin_a) + mul_q88(ly, cos_a);
                end
                if (vi == (nvert - 5'd1)) begin
                    ei <= 5'd0;
                    line_active <= 1'b0;
                    state <= ST_SHIP;
                end else
                    vi <= vi + 5'd1;
            end

            ST_SHIP: begin
                if (!line_active) begin
                    if (ei >= nedge) begin
                        if (ship_sel ? thrusting1 : thrusting0) begin
                            line_active <= 1'b0;
                            state <= ST_FLAME;
                        end else begin
                            vi <= 5'd0;
                            state <= ST_DONE;
                        end
                    end else begin
                        start_line(sxv[edge_a(ship_sel, ei)],
                                   syv[edge_a(ship_sel, ei)],
                                   sxv[edge_b(ship_sel, ei)],
                                   syv[edge_b(ship_sel, ei)]);
                        line_active <= 1'b1;
                        plot_bit <= 1'b1;
                        ei <= ei + 5'd1;
                    end
                end else begin
                    plot_bit <= 1'b1;
                    if ((b_x >= 0) && (b_x < FB_W) && (b_y >= 0) && (b_y < FB_H)) begin
                        plot_en <= 1'b1;
                        plot_x <= b_x[9:0];
                        plot_y <= b_y[8:0];
                    end
                    step_bresenham;
                end
            end

            ST_FLAME: begin
                if (!line_active) begin
                    if (!ship_sel) begin
                        start_line(sxv[hitch], syv[hitch],
                            sxv[hitch] - mul_q88(cos_a, 16'sd10),
                            syv[hitch] - mul_q88(sin_a, 16'sd10));
                        pflame0_x <= sxv[hitch] - mul_q88(cos_a, 16'sd10);
                        pflame0_y <= syv[hitch] - mul_q88(sin_a, 16'sd10);
                    end else begin
                        start_line(sxv[hitch], syv[hitch],
                            sxv[hitch] - mul_q88(cos_a, 16'sd10),
                            syv[hitch] - mul_q88(sin_a, 16'sd10));
                        pflame1_x <= sxv[hitch] - mul_q88(cos_a, 16'sd10);
                        pflame1_y <= syv[hitch] - mul_q88(sin_a, 16'sd10);
                    end
                    line_active <= 1'b1;
                    plot_bit <= 1'b1;
                end else begin
                    plot_bit <= 1'b1;
                    if ((b_x >= 0) && (b_x < FB_W) && (b_y >= 0) && (b_y < FB_H)) begin
                        plot_en <= 1'b1;
                        plot_x <= b_x[9:0];
                        plot_y <= b_y[8:0];
                    end
                    if ((b_x == end_x) && (b_y == end_y)) begin
                        line_active <= 1'b0;
                        vi <= 5'd0;
                        state <= ST_DONE;
                    end else
                        step_bresenham;
                end
            end

            ST_DONE: begin
                if (vi < nvert) begin
                    if (!ship_sel) begin
                        pxv0[vi] <= sxv[vi];
                        pyv0[vi] <= syv[vi];
                    end else begin
                        pxv1[vi] <= sxv[vi];
                        pyv1[vi] <= syv[vi];
                    end
                    vi <= vi + 5'd1;
                end else if (!ship_sel) begin
                    have_prev0   <= 1'b1;
                    prev_thrust0 <= thrusting0;
                    vi           <= 5'd0;
                    ei           <= 5'd0;
                    if ((boom1 != 5'd0) || boom_dirty)
                        state <= ST_SHOT;
                    else begin
                        ship_sel <= 1'b1;
                        nvert    <= 5'd4;
                        nedge    <= 5'd4;
                        hitch    <= 5'd2;
                        state    <= ST_XFORM;
                    end
                end else begin
                    have_prev1   <= 1'b1;
                    prev_thrust1 <= thrusting1;
                    ship_sel     <= 1'b0;
                    vi           <= 5'd0;
                    ei           <= 5'd0;
                    state        <= ST_SHOT;
                end
            end

            // Short visible streak (~6px), then boom if needed
            ST_SHOT: begin
                if (!line_active) begin
                    if (ei == 4'd0) begin
                        if (bul_have_prev) begin
                            start_line($signed({6'b0, bul_ox}), $signed({7'b0, bul_oy}),
                                       $signed({6'b0, bul_ox2}), $signed({7'b0, bul_oy2}));
                            line_active <= 1'b1;
                            plot_bit    <= 1'b0;
                            ei <= 4'd1;
                        end else
                            ei <= 4'd1;
                    end else if (ei == 4'd1) begin
                        if (bullet_on) begin
                            begin : bdir
                                reg signed [15:0] sx, sy, x0, y0, x1, y1;
                                x0 = $signed(bul_x[23:8]);
                                y0 = $signed(bul_y[23:8]);
                                sx = bul_vx >>> 9; // ~5px
                                sy = bul_vy >>> 9;
                                if (sx == 0 && sy == 0) sx = 16'sd5;
                                x1 = x0 + sx;
                                y1 = y0 + sy;
                                start_line(x0, y0, x1, y1);
                                bul_ox  <= x0[9:0];
                                bul_oy  <= y0[8:0];
                                bul_ox2 <= x1[9:0];
                                bul_oy2 <= y1[8:0];
                            end
                            line_active   <= 1'b1;
                            plot_bit      <= 1'b1;
                            bul_have_prev <= 1'b1;
                            ei <= 4'd2;
                        end else begin
                            bul_have_prev <= 1'b0;
                            ei <= 4'd2;
                        end
                    end else if (ei == 4'd2) begin
                        if (ebul_have_prev) begin
                            start_line($signed({6'b0, ebul_ox}), $signed({7'b0, ebul_oy}),
                                       $signed({6'b0, ebul_ox2}), $signed({7'b0, ebul_oy2}));
                            line_active <= 1'b1;
                            plot_bit    <= 1'b0;
                            ei <= 4'd3;
                        end else
                            ei <= 4'd3;
                    end else if (ei == 4'd3) begin
                        if (ebul_on) begin
                            begin : edir
                                reg signed [15:0] sx, sy, x0, y0, x1, y1;
                                x0 = $signed(ebul_x[23:8]);
                                y0 = $signed(ebul_y[23:8]);
                                sx = ebul_vx >>> 9;
                                sy = ebul_vy >>> 9;
                                if (sx == 0 && sy == 0) sx = 16'sd5;
                                x1 = x0 + sx;
                                y1 = y0 + sy;
                                start_line(x0, y0, x1, y1);
                                ebul_ox  <= x0[9:0];
                                ebul_oy  <= y0[8:0];
                                ebul_ox2 <= x1[9:0];
                                ebul_oy2 <= y1[8:0];
                            end
                            line_active    <= 1'b1;
                            plot_bit       <= 1'b1;
                            ebul_have_prev <= 1'b1;
                            ei <= 4'd4;
                        end else begin
                            ebul_have_prev <= 1'b0;
                            ei <= 4'd4;
                        end
                    end else begin
                        ei <= 5'd0;
                        if ((boom0 != 5'd0) || boom0_dirty || (boom1 != 5'd0) || boom_dirty) begin
                            boom_sel <= ((boom0 != 5'd0) || boom0_dirty) ? 1'b0 : 1'b1;
                            state    <= ST_BOOM;
                        end else
                            state <= ST_IDLE;
                    end
                end else begin
                    if ((b_x >= 0) && (b_x < FB_W) && (b_y >= 0) && (b_y < FB_H)) begin
                        plot_en <= 1'b1;
                        plot_x  <= b_x[9:0];
                        plot_y  <= b_y[8:0];
                    end
                    step_bresenham;
                end
            end

            // Expanding X burst (boom_sel 0=player, 1=AI)
            ST_BOOM: begin
                if (!line_active) begin
                    if (ei == 4'd0) begin
                        if (boom_clen != 5'd0) begin
                            start_line(boom_cx - {11'b0, boom_clen},
                                       boom_cy - {11'b0, boom_clen},
                                       boom_cx + {11'b0, boom_clen},
                                       boom_cy + {11'b0, boom_clen});
                            line_active <= 1'b1;
                            plot_bit    <= 1'b0;
                            ei <= 4'd1;
                        end else
                            ei <= 4'd2;
                    end else if (ei == 4'd1) begin
                        start_line(boom_cx - {11'b0, boom_clen},
                                   boom_cy + {11'b0, boom_clen},
                                   boom_cx + {11'b0, boom_clen},
                                   boom_cy - {11'b0, boom_clen});
                        line_active <= 1'b1;
                        plot_bit    <= 1'b0;
                        ei <= 4'd2;
                    end else if (ei == 4'd2) begin
                        if (boom_cnt == 5'd0) begin
                            ei <= 4'd4;
                        end else begin
                            begin : boomdraw
                                reg [4:0] L;
                                L = 5'd19 - boom_cnt;
                                if (boom_sel)
                                    boom_len_prev <= L;
                                else
                                    boom0_len_prev <= L;
                                start_line(boom_cx - {11'b0, L},
                                           boom_cy - {11'b0, L},
                                           boom_cx + {11'b0, L},
                                           boom_cy + {11'b0, L});
                            end
                            line_active <= 1'b1;
                            plot_bit    <= 1'b1;
                            ei <= 4'd3;
                        end
                    end else if (ei == 4'd3) begin
                        start_line(boom_cx - {11'b0, boom_clen},
                                   boom_cy + {11'b0, boom_clen},
                                   boom_cx + {11'b0, boom_clen},
                                   boom_cy - {11'b0, boom_clen});
                        line_active <= 1'b1;
                        plot_bit    <= 1'b1;
                        ei <= 4'd4;
                    end else begin
                        if (boom_cnt == 5'd0) begin
                            if (boom_sel) begin
                                boom_len_prev <= 5'd0;
                                boom_dirty    <= 1'b0;
                            end else begin
                                boom0_len_prev <= 5'd0;
                                boom0_dirty    <= 1'b0;
                            end
                        end
                        if (!boom_sel && ((boom1 != 5'd0) || boom_dirty)) begin
                            boom_sel <= 1'b1;
                            ei       <= 5'd0;
                        end else begin
                            ei    <= 5'd0;
                            state <= ST_IDLE;
                        end
                    end
                end else begin
                    if ((b_x >= 0) && (b_x < FB_W) && (b_y >= 0) && (b_y < FB_H)) begin
                        plot_en <= 1'b1;
                        plot_x  <= b_x[9:0];
                        plot_y  <= b_y[8:0];
                    end
                    step_bresenham;
                end
            end

            default: state <= ST_IDLE;
        endcase
    end
end

endmodule
