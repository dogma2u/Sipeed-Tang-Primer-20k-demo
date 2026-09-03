// S1 left | S2 right | S3 thrust | S4 fire | S0 reset
// Enterprise = you; wedge = AI (sloppy chase + inaccurate shots). Bounce walls.
// Shoot the sun 10× → black hole (gravity on, border red).

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
    output reg  [4:0] pix_b,
    output wire       border_red
);

localparam integer FB_W   = 800;
localparam integer FB_H   = 480;
localparam integer FB_SZ  = FB_W * FB_H;
localparam integer SUN_X  = 400;
localparam integer SUN_Y  = 240;
localparam integer SUN_R  = 18;
localparam integer SUN_HITS_BH = 10; // shots to collapse sun → black hole
localparam integer MARGIN   = 20;
localparam integer NSTARS   = 28;
localparam integer MAXV     = 21;
localparam integer BUL_LIFE = 28;
localparam integer BOOM_N   = 16;
localparam integer DIG_W    = 32;
localparam integer DIG_H    = 56;
localparam integer DIG_T    = 8;
localparam integer DIG_G    = 8;
localparam integer SC_Y     = 18;
localparam integer SC0_MX   = 52;
localparam integer SC0_TX   = 92;
localparam integer SC0_OX   = 132;
localparam integer SC1_MX   = 616;
localparam integer SC1_TX   = 656;
localparam integer SC1_OX   = 696;
localparam integer FRAMES_PER_SEC = 50;
localparam integer TIMER_START    = 90;   // 1:30
localparam integer TIMER_BONUS    = 5;
localparam integer TIMER_MAX      = 599;  // 9:59
localparam integer TM_MX          = 336;  // center timer minutes digit
localparam integer TM_SX0         = 384;  // seconds tens
localparam integer TM_SX1         = 424;  // seconds ones
localparam integer LIFE_Y         = 82;
localparam integer LIFE_W         = 12;
localparam integer LIFE_H         = 10;
localparam integer LIFE_G         = 6;
localparam integer LIFE_MAX       = 5;
localparam integer KILL_FOR_LIFE  = 5;
localparam integer FUEL_MAX_MS    = 15000; // 15 s of thrust
localparam integer FUEL_FRAME_MS  = 20;    // ~1 frame at 50 Hz
localparam integer FUEL_YEL_MS    = 1500;  // 10% of tank
localparam integer FUEL_RED_MS    = 750;   // 5% of tank
localparam integer FUEL_X         = 176;  // right of player ones digit
localparam integer FUEL_Y         = 18;   // align with score top
localparam integer FUEL_W         = 14;
localparam integer FUEL_H         = 56;   // same height as score digits
localparam integer FUEL_T         = 2;
localparam integer FUEL_INNER_H   = 52;   // FUEL_H - 2*FUEL_T
localparam integer FUEL_MS_PER_PX = 288;  // ~15000/52
localparam integer BH_HITS_SUN    = 5;    // player shots into BH → sun returns
localparam integer GO_X           = 241;
localparam integer GO_Y           = 219;  // 7*6=42 tall; center at screen mid (240)
localparam integer GO_SCALE       = 6;
localparam integer GO_GAP         = 6;

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
reg               ebul_on [0:2];
reg               ebul_have_prev [0:2];
reg signed [23:0] ebul_x [0:2];
reg signed [23:0] ebul_y [0:2];
reg signed [15:0] ebul_vx [0:2];
reg signed [15:0] ebul_vy [0:2];
reg [9:0]         ebul_ox [0:2];
reg [9:0]         ebul_ox2 [0:2];
reg [8:0]         ebul_oy [0:2];
reg [8:0]         ebul_oy2 [0:2];
reg [5:0]         ebul_life [0:2];
reg [5:0]         ai_cd;
reg [7:0]         lfsr;
reg [4:0]         ai_pulse;
reg [8:0]         play_sec; // elapsed play, cap 300s
reg [4:0]         boom0, boom1;
reg signed [15:0] boom0_x, boom0_y, boom_x, boom_y;
reg [4:0]         boom0_len_prev, boom_len_prev;
reg               boom0_dirty, boom_dirty;
reg               boom_sel;
reg signed [7:0]  score0, score1;
reg               ship_lock;
reg               game_over;
reg [9:0]         timer_sec;
reg [5:0]         frame_cnt;
reg [2:0]         lives0;
reg [2:0]         ai_streak;
reg [14:0]        fuel_ms;
reg [3:0]         sun_hits;
reg [2:0]         bh_hits;
reg               black_hole;
reg               anti_grav; // sun restored; repulsion from center

assign border_red = black_hole;

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

function [6:0] seg7;
    input [3:0] d;
    begin
        case (d)
            4'd0: seg7 = 7'b0111111;
            4'd1: seg7 = 7'b0000110;
            4'd2: seg7 = 7'b1011011;
            4'd3: seg7 = 7'b1001111;
            4'd4: seg7 = 7'b1100110;
            4'd5: seg7 = 7'b1101101;
            4'd6: seg7 = 7'b1111101;
            4'd7: seg7 = 7'b0000111;
            4'd8: seg7 = 7'b1111111;
            4'd9: seg7 = 7'b1101111;
            default: seg7 = 7'b0000000;
        endcase
    end
endfunction

function [3:0] dec_tens;
    input [6:0] v;
    begin
        if (v >= 7'd90)      dec_tens = 4'd9;
        else if (v >= 7'd80) dec_tens = 4'd8;
        else if (v >= 7'd70) dec_tens = 4'd7;
        else if (v >= 7'd60) dec_tens = 4'd6;
        else if (v >= 7'd50) dec_tens = 4'd5;
        else if (v >= 7'd40) dec_tens = 4'd4;
        else if (v >= 7'd30) dec_tens = 4'd3;
        else if (v >= 7'd20) dec_tens = 4'd2;
        else if (v >= 7'd10) dec_tens = 4'd1;
        else                 dec_tens = 4'd0;
    end
endfunction

function pong_digit;
    input [9:0] px;
    input [9:0] py;
    input [9:0] ox;
    input [9:0] oy;
    input [3:0] d;
    reg [9:0] rx;
    reg [9:0] ry;
    reg [6:0] s;
    begin
        pong_digit = 1'b0;
        if ((px >= ox) && (px < (ox + DIG_W)) &&
            (py >= oy) && (py < (oy + DIG_H))) begin
            rx = px - ox;
            ry = py - oy;
            s  = seg7(d);
            if (s[0] && (ry < DIG_T))
                pong_digit = 1'b1;
            if (s[3] && (ry >= (DIG_H - DIG_T)))
                pong_digit = 1'b1;
            if (s[6] && (ry >= ((DIG_H - DIG_T) / 2)) &&
                (ry < ((DIG_H - DIG_T) / 2) + DIG_T))
                pong_digit = 1'b1;
            if (s[5] && (rx < DIG_T) && (ry < (DIG_H / 2)))
                pong_digit = 1'b1;
            if (s[4] && (rx < DIG_T) && (ry >= (DIG_H / 2)))
                pong_digit = 1'b1;
            if (s[1] && (rx >= (DIG_W - DIG_T)) && (ry < (DIG_H / 2)))
                pong_digit = 1'b1;
            if (s[2] && (rx >= (DIG_W - DIG_T)) && (ry >= (DIG_H / 2)))
                pong_digit = 1'b1;
        end
    end
endfunction

function pong_minus;
    input [9:0] px;
    input [9:0] py;
    input [9:0] ox;
    input [9:0] oy;
    begin
        pong_minus = (px >= ox) && (px < (ox + DIG_W)) &&
                     (py >= (oy + ((DIG_H - DIG_T) / 2))) &&
                     (py <  (oy + ((DIG_H - DIG_T) / 2) + DIG_T));
    end
endfunction

function pong_colon;
    input [9:0] px;
    input [9:0] py;
    input [9:0] ox;
    input [9:0] oy;
    begin
        pong_colon =
            ((px >= ox) && (px < (ox + DIG_T)) &&
             (py >= (oy + DIG_H/4 - DIG_T/2)) &&
             (py <  (oy + DIG_H/4 - DIG_T/2 + DIG_T))) ||
            ((px >= ox) && (px < (ox + DIG_T)) &&
             (py >= (oy + (3*DIG_H)/4 - DIG_T/2)) &&
             (py <  (oy + (3*DIG_H)/4 - DIG_T/2 + DIG_T)));
    end
endfunction

// Small upright triangle life icon (AI wedge style)
function life_icon;
    input [9:0] px;
    input [9:0] py;
    input [9:0] ox;
    input [9:0] oy;
    reg [9:0] rx;
    reg [9:0] ry;
    reg [9:0] half;
    begin
        life_icon = 1'b0;
        if ((px >= ox) && (px < (ox + LIFE_W)) &&
            (py >= oy) && (py < (oy + LIFE_H))) begin
            rx = px - ox;
            ry = py - oy;
            half = (ry + 10'd1) >>> 1;
            if ((rx + half >= (LIFE_W / 2)) &&
                (rx <= (LIFE_W / 2) + half))
                life_icon = 1'b1;
        end
    end
endfunction

// Vertical hollow border + bottom-up fill for thrust fuel
function fuel_gauge;
    input [9:0] px;
    input [9:0] py;
    input [9:0] fill_h;
    reg         in_box;
    reg         on_border;
    reg         in_fill;
    begin
        in_box = (px >= FUEL_X) && (px < (FUEL_X + FUEL_W)) &&
                 (py >= FUEL_Y) && (py < (FUEL_Y + FUEL_H));
        on_border = in_box &&
                    ((px < (FUEL_X + FUEL_T)) ||
                     (px >= (FUEL_X + FUEL_W - FUEL_T)) ||
                     (py < (FUEL_Y + FUEL_T)) ||
                     (py >= (FUEL_Y + FUEL_H - FUEL_T)));
        // fill grows upward from the bottom of the inner bar
        in_fill = (fill_h != 10'd0) &&
                  (px >= (FUEL_X + FUEL_T)) &&
                  (px < (FUEL_X + FUEL_W - FUEL_T)) &&
                  (py >= (FUEL_Y + FUEL_H - FUEL_T - fill_h)) &&
                  (py < (FUEL_Y + FUEL_H - FUEL_T));
        fuel_gauge = on_border || in_fill;
    end
endfunction

// 5x7 block glyphs: 0=G 1=A 2=M 3=E 4=O 5=V 6=R 7=space
function [4:0] glyph_row;
    input [2:0] ch;
    input [2:0] row;
    begin
        case (ch)
            3'd0: case (row) // G
                3'd0: glyph_row=5'b01110; 3'd1: glyph_row=5'b10001;
                3'd2: glyph_row=5'b10000; 3'd3: glyph_row=5'b10111;
                3'd4: glyph_row=5'b10001; 3'd5: glyph_row=5'b10001;
                default: glyph_row=5'b01110;
            endcase
            3'd1: case (row) // A
                3'd0: glyph_row=5'b01110; 3'd1: glyph_row=5'b10001;
                3'd2: glyph_row=5'b10001; 3'd3: glyph_row=5'b11111;
                3'd4: glyph_row=5'b10001; 3'd5: glyph_row=5'b10001;
                default: glyph_row=5'b10001;
            endcase
            3'd2: case (row) // M
                3'd0: glyph_row=5'b10001; 3'd1: glyph_row=5'b11011;
                3'd2: glyph_row=5'b10101; 3'd3: glyph_row=5'b10001;
                3'd4: glyph_row=5'b10001; 3'd5: glyph_row=5'b10001;
                default: glyph_row=5'b10001;
            endcase
            3'd3: case (row) // E
                3'd0: glyph_row=5'b11111; 3'd1: glyph_row=5'b10000;
                3'd2: glyph_row=5'b10000; 3'd3: glyph_row=5'b11110;
                3'd4: glyph_row=5'b10000; 3'd5: glyph_row=5'b10000;
                default: glyph_row=5'b11111;
            endcase
            3'd4: case (row) // O
                3'd0: glyph_row=5'b01110; 3'd1: glyph_row=5'b10001;
                3'd2: glyph_row=5'b10001; 3'd3: glyph_row=5'b10001;
                3'd4: glyph_row=5'b10001; 3'd5: glyph_row=5'b10001;
                default: glyph_row=5'b01110;
            endcase
            3'd5: case (row) // V
                3'd0: glyph_row=5'b10001; 3'd1: glyph_row=5'b10001;
                3'd2: glyph_row=5'b10001; 3'd3: glyph_row=5'b10001;
                3'd4: glyph_row=5'b10001; 3'd5: glyph_row=5'b01010;
                default: glyph_row=5'b00100;
            endcase
            3'd6: case (row) // R
                3'd0: glyph_row=5'b11110; 3'd1: glyph_row=5'b10001;
                3'd2: glyph_row=5'b10001; 3'd3: glyph_row=5'b11110;
                3'd4: glyph_row=5'b10100; 3'd5: glyph_row=5'b10010;
                default: glyph_row=5'b10001;
            endcase
            default: glyph_row = 5'b00000; // space
        endcase
    end
endfunction

function block_letter;
    input [9:0] px;
    input [9:0] py;
    input [9:0] ox;
    input [9:0] oy;
    input [2:0] ch;
    reg [9:0] rx;
    reg [9:0] ry;
    reg [9:0] qcol;
    reg [9:0] qrow;
    reg [2:0] col;
    reg [2:0] row;
    reg [4:0] bits;
    begin
        block_letter = 1'b0;
        if ((ch != 3'd7) &&
            (px >= ox) && (px < (ox + 5*GO_SCALE)) &&
            (py >= oy) && (py < (oy + 7*GO_SCALE))) begin
            rx   = px - ox;
            ry   = py - oy;
            qcol = rx / GO_SCALE;
            qrow = ry / GO_SCALE;
            col  = qcol[2:0];
            row  = qrow[2:0];
            bits = glyph_row(ch, row);
            case (col)
                3'd0: if (bits[4]) block_letter = 1'b1;
                3'd1: if (bits[3]) block_letter = 1'b1;
                3'd2: if (bits[2]) block_letter = 1'b1;
                3'd3: if (bits[1]) block_letter = 1'b1;
                3'd4: if (bits[0]) block_letter = 1'b1;
                default: block_letter = 1'b0;
            endcase
        end
    end
endfunction

function game_over_text;
    input [9:0] px;
    input [9:0] py;
    begin
        // pitch = 5*GO_SCALE + GO_GAP = 36; GO_Y=219 centers 42px tall text on 480
        game_over_text =
            block_letter(px, py, 10'd241, 10'd219, 3'd0) || // G
            block_letter(px, py, 10'd277, 10'd219, 3'd1) || // A
            block_letter(px, py, 10'd313, 10'd219, 3'd2) || // M
            block_letter(px, py, 10'd349, 10'd219, 3'd3) || // E
            block_letter(px, py, 10'd421, 10'd219, 3'd4) || // O
            block_letter(px, py, 10'd457, 10'd219, 3'd5) || // V
            block_letter(px, py, 10'd493, 10'd219, 3'd3) || // E
            block_letter(px, py, 10'd529, 10'd219, 3'd6);   // R
    end
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
                5'd18: shp_x = -8'sd12; // hull center aft (flame)
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
                5'd18: shp_y =  8'sd0;
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

function star_at;
    input [9:0] px;
    input [9:0] py;
    input [4:0] i;
    begin
        star_at = (px == star_x(i)) && (py == {1'b0, star_y(i)});
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
        if (!kind) begin nvert = 5'd19; nedge = 5'd22; hitch = 5'd18; end
        else       begin nvert = 5'd4;  nedge = 5'd4;  hitch = 5'd2; end
    end
endtask

task respawn0;
    begin
        pos0_x  <= 24'sd140 <<< 8;
        pos0_y  <= 24'sd240 <<< 8;
        vel0_x  <= 16'sd0;
        vel0_y  <= -16'sd40;
        ang0    <= 8'd192;
        fuel_ms <= FUEL_MAX_MS[14:0];
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
wire in_sun = in_fb_d && !black_hole && (srr_d <= (SUN_R * SUN_R));
wire in_bh  = in_fb_d && black_hole && (srr_d <= (SUN_R * SUN_R));
wire [8:0] play_cap = (play_sec > 9'd300) ? 9'd300 : play_sec;
wire [4:0] ai_dec   = play_cap / 9'd10; // 0..30 every 10s
wire signed [15:0] ai_thrust = 16'sd20 + {7'b0, (play_cap / 9'd15)};
wire star_hit =
    star_at(pix_x_d, pix_y_d, 5'd0)  || star_at(pix_x_d, pix_y_d, 5'd1)  ||
    star_at(pix_x_d, pix_y_d, 5'd2)  || star_at(pix_x_d, pix_y_d, 5'd3)  ||
    star_at(pix_x_d, pix_y_d, 5'd4)  || star_at(pix_x_d, pix_y_d, 5'd5)  ||
    star_at(pix_x_d, pix_y_d, 5'd6)  || star_at(pix_x_d, pix_y_d, 5'd7)  ||
    star_at(pix_x_d, pix_y_d, 5'd8)  || star_at(pix_x_d, pix_y_d, 5'd9)  ||
    star_at(pix_x_d, pix_y_d, 5'd10) || star_at(pix_x_d, pix_y_d, 5'd11) ||
    star_at(pix_x_d, pix_y_d, 5'd12) || star_at(pix_x_d, pix_y_d, 5'd13) ||
    star_at(pix_x_d, pix_y_d, 5'd14) || star_at(pix_x_d, pix_y_d, 5'd15) ||
    star_at(pix_x_d, pix_y_d, 5'd16) || star_at(pix_x_d, pix_y_d, 5'd17) ||
    star_at(pix_x_d, pix_y_d, 5'd18) || star_at(pix_x_d, pix_y_d, 5'd19) ||
    star_at(pix_x_d, pix_y_d, 5'd20) || star_at(pix_x_d, pix_y_d, 5'd21) ||
    star_at(pix_x_d, pix_y_d, 5'd22) || star_at(pix_x_d, pix_y_d, 5'd23) ||
    star_at(pix_x_d, pix_y_d, 5'd24) || star_at(pix_x_d, pix_y_d, 5'd25) ||
    star_at(pix_x_d, pix_y_d, 5'd26) || star_at(pix_x_d, pix_y_d, 5'd27);
wire signed [15:0] ink_dx0 = abs16($signed({6'b0, pix_x_d}) - $signed(pos0_x[23:8]));
wire signed [15:0] ink_dy0 = abs16($signed({6'b0, pix_y_d}) - $signed(pos0_y[23:8]));
wire signed [15:0] ink_dx1 = abs16($signed({6'b0, pix_x_d}) - $signed(pos1_x[23:8]));
wire signed [15:0] ink_dy1 = abs16($signed({6'b0, pix_y_d}) - $signed(pos1_y[23:8]));
wire near_pl = (ink_dx0 < 16'sd30) && (ink_dy0 < 16'sd24);
wire near_ai = (ink_dx1 < 16'sd22) && (ink_dy1 < 16'sd20);

wire [7:0] score0_abs = score0[7] ? (~score0 + 8'd1) : score0;
wire [7:0] score1_abs = score1[7] ? (~score1 + 8'd1) : score1;
wire [3:0] s0_tens = dec_tens(score0_abs[6:0]);
wire [3:0] s1_tens = dec_tens(score1_abs[6:0]);
wire [6:0] s0_ten10 = {s0_tens, 3'b0} + {2'b0, s0_tens, 1'b0};
wire [6:0] s1_ten10 = {s1_tens, 3'b0} + {2'b0, s1_tens, 1'b0};
wire [6:0] s0_ones7 = score0_abs[6:0] - s0_ten10;
wire [6:0] s1_ones7 = score1_abs[6:0] - s1_ten10;
wire [3:0] s0_ones = s0_ones7[3:0];
wire [3:0] s1_ones = s1_ones7[3:0];
wire [3:0] tm_min  = (timer_sec >= 10'd540) ? 4'd9 :
                     (timer_sec >= 10'd480) ? 4'd8 :
                     (timer_sec >= 10'd420) ? 4'd7 :
                     (timer_sec >= 10'd360) ? 4'd6 :
                     (timer_sec >= 10'd300) ? 4'd5 :
                     (timer_sec >= 10'd240) ? 4'd4 :
                     (timer_sec >= 10'd180) ? 4'd3 :
                     (timer_sec >= 10'd120) ? 4'd2 :
                     (timer_sec >= 10'd60)  ? 4'd1 : 4'd0;
wire [9:0] tm_rem  = timer_sec - ({6'b0, tm_min} * 10'd60);
wire [3:0] tm_stens = dec_tens(tm_rem[6:0]);
wire [6:0] tm_sten10 = {tm_stens, 3'b0} + {2'b0, tm_stens, 1'b0};
wire [6:0] tm_sones7 = tm_rem[6:0] - tm_sten10;
wire [3:0] tm_sones = tm_sones7[3:0];
wire       timer_hit =
    pong_digit(pix_x_d, pix_y_d, 10'd336, 10'd18, tm_min) ||
    pong_colon(pix_x_d, pix_y_d, 10'd372, 10'd18) ||
    pong_digit(pix_x_d, pix_y_d, 10'd384, 10'd18, tm_stens) ||
    pong_digit(pix_x_d, pix_y_d, 10'd424, 10'd18, tm_sones);
wire       score_hit =
    (score0[7] && pong_minus(pix_x_d, pix_y_d, 10'd52,  10'd18)) ||
    pong_digit(pix_x_d, pix_y_d, 10'd92,  10'd18, s0_tens) ||
    pong_digit(pix_x_d, pix_y_d, 10'd132, 10'd18, s0_ones) ||
    (score1[7] && pong_minus(pix_x_d, pix_y_d, 10'd616, 10'd18)) ||
    pong_digit(pix_x_d, pix_y_d, 10'd656, 10'd18, s1_tens) ||
    pong_digit(pix_x_d, pix_y_d, 10'd696, 10'd18, s1_ones);
wire       lives0_hit =
    ((lives0 > 3'd0) && life_icon(pix_x_d, pix_y_d, 10'd92,  10'd82)) ||
    ((lives0 > 3'd1) && life_icon(pix_x_d, pix_y_d, 10'd110, 10'd82)) ||
    ((lives0 > 3'd2) && life_icon(pix_x_d, pix_y_d, 10'd128, 10'd82)) ||
    ((lives0 > 3'd3) && life_icon(pix_x_d, pix_y_d, 10'd146, 10'd82)) ||
    ((lives0 > 3'd4) && life_icon(pix_x_d, pix_y_d, 10'd164, 10'd82));
wire [14:0] fuel_px =
    (fuel_ms >= FUEL_MAX_MS[14:0]) ? FUEL_INNER_H[14:0] :
    (fuel_ms / FUEL_MS_PER_PX[14:0]);
wire [9:0] fuel_fill_h =
    (fuel_px > FUEL_INNER_H[14:0]) ? FUEL_INNER_H[9:0] : fuel_px[9:0];
wire       fuel_hit = fuel_gauge(pix_x_d, pix_y_d, fuel_fill_h);
// 2 flashes/sec @ ~50% duty while frame_cnt runs 0..49
wire       go_flash = (frame_cnt < 6'd13) ||
                      ((frame_cnt >= 6'd25) && (frame_cnt < 6'd38));
wire       go_hit   = game_over && go_flash && game_over_text(pix_x_d, pix_y_d);

wire signed [15:0] boom_cx   = boom_sel ? boom_x : boom0_x;
wire signed [15:0] boom_cy   = boom_sel ? boom_y : boom0_y;
wire [4:0]         boom_clen = boom_sel ? boom_len_prev : boom0_len_prev;
wire [4:0]         boom_cnt  = boom_sel ? boom1 : boom0;

always @(posedge clk) begin
    if (in_fb_d && go_hit) begin
        pix_r <= 5'h1F; pix_g <= 6'h00; pix_b <= 5'h00; // bright red
    end else if (in_sun) begin
        if (srr_d < 32'sd80) begin
            pix_r <= 5'h1F; pix_g <= 6'h30; pix_b <= 5'h04;
        end else if (srr_d < 32'sd200) begin
            pix_r <= 5'h1E; pix_g <= 6'h24; pix_b <= 5'h02;
        end else begin
            pix_r <= 5'h18; pix_g <= 6'h14; pix_b <= 5'h00;
        end
    end else if (in_bh) begin
        pix_r <= 5'h02; pix_g <= 6'h00; pix_b <= 5'h02;
    end else if (in_fb_d && star_hit) begin
        pix_r <= 5'h1F; pix_g <= 6'h3F; pix_b <= 5'h1F;
    end else if (in_fb_d && rdata) begin
        if (near_pl) begin
            pix_r <= 5'h00; pix_g <= 6'h3F; pix_b <= 5'h00; // Enterprise green
        end else if (near_ai) begin
            pix_r <= 5'h1F; pix_g <= 6'h3F; pix_b <= 5'h1F; // AI max white
        end else begin
            pix_r <= 5'h1F; pix_g <= 6'h3F; pix_b <= 5'h1F; // shots
        end
    end else if (in_fb_d && timer_hit) begin
        if (timer_sec < 10'd10) begin
            pix_r <= 5'h19; pix_g <= 6'h00; pix_b <= 5'h00;
        end else if (timer_sec < 10'd30) begin
            pix_r <= 5'h19; pix_g <= 6'h32; pix_b <= 5'h00;
        end else begin
            pix_r <= 5'h19; pix_g <= 6'h32; pix_b <= 5'h19;
        end
    end else if (in_fb_d && fuel_hit) begin
        if (fuel_ms <= FUEL_RED_MS[14:0]) begin
            pix_r <= 5'h1F; pix_g <= 6'h00; pix_b <= 5'h00;
        end else if (fuel_ms <= FUEL_YEL_MS[14:0]) begin
            pix_r <= 5'h1F; pix_g <= 6'h3F; pix_b <= 5'h00;
        end else begin
            pix_r <= 5'h00; pix_g <= 6'h3F; pix_b <= 5'h00;
        end
    end else if (in_fb_d && score_hit) begin
        pix_r <= 5'h0C; pix_g <= 6'h3C; pix_b <= 5'h1F;
    end else if (in_fb_d && lives0_hit) begin
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
        nvert <= 5'd19; nedge <= 5'd22; hitch <= 5'd18;
        boom0_dirty    <= 1'b0;
        boom_dirty     <= 1'b0;
        bullet_on      <= 1'b0;
        bul_have_prev  <= 1'b0;
        ebul_on[0]        <= 1'b0;
        ebul_on[1]        <= 1'b0;
        ebul_on[2]        <= 1'b0;
        ebul_have_prev[0] <= 1'b0;
        ebul_have_prev[1] <= 1'b0;
        ebul_have_prev[2] <= 1'b0;
        fire_hold      <= 1'b0;
        fire_cd        <= 5'd0;
        ai_cd          <= 6'd20;
        lfsr           <= 8'hA5;
        ai_pulse       <= 5'd0;
        play_sec       <= 9'd0;
        bul_life       <= 6'd0;
        ebul_life[0]   <= 6'd0;
        ebul_life[1]   <= 6'd0;
        ebul_life[2]   <= 6'd0;
        boom0          <= 5'd0;
        boom1          <= 5'd0;
        boom0_len_prev <= 5'd0;
        boom_len_prev  <= 5'd0;
        boom_sel       <= 1'b0;
        score0         <= 8'sd0;
        score1         <= 8'sd0;
        ship_lock      <= 1'b0;
        game_over      <= 1'b0;
        timer_sec      <= TIMER_START[9:0];
        frame_cnt      <= 6'd0;
        lives0         <= 3'd3;
        ai_streak      <= 3'd0;
        fuel_ms        <= FUEL_MAX_MS[14:0];
        sun_hits       <= 4'd0;
        bh_hits        <= 3'd0;
        black_hole     <= 1'b0;
        anti_grav      <= 1'b0;
        respawn0;
        respawn1;
    end else begin
        plot_en <= 1'b0;
        if (fire_p && !game_over)
            fire_hold <= 1'b1;

        case (state)
            ST_IDLE: if (frame_start) begin
                // Always tick frame_cnt (timer + GAME OVER 2 Hz blink)
                if (frame_cnt == (FRAMES_PER_SEC[5:0] - 6'd1)) begin
                    frame_cnt <= 6'd0;
                    if (!game_over) begin
                        if (timer_sec == 10'd0)
                            game_over <= 1'b1;
                        else
                            timer_sec <= timer_sec - 10'd1;
                        if (play_sec < 9'd300)
                            play_sec <= play_sec + 9'd1;
                    end
                end else
                    frame_cnt <= frame_cnt + 6'd1;
                phys_phase <= 3'd0;
                state <= ST_PHYS;
            end

            // ---- physics: human needle + AI wedge ----
            ST_PHYS: begin
                if (game_over) begin
                    thrusting0  <= 1'b0;
                    thrusting1  <= 1'b0;
                    fire_hold   <= 1'b0;
                    bullet_on   <= 1'b0;
                    ebul_on[0]  <= 1'b0;
                    ebul_on[1]  <= 1'b0;
                    ebul_on[2]  <= 1'b0;
                    if (boom0 == 5'd1) begin
                        pos0_x <= -(24'sd80 <<< 8);
                        pos0_y <= -(24'sd80 <<< 8);
                        vel0_x <= 16'sd0;
                        vel0_y <= 16'sd0;
                    end
                    if (boom1 == 5'd1) begin
                        pos1_x <= ((FB_W + 80) <<< 8);
                        pos1_y <= ((FB_H + 80) <<< 8);
                        vel1_x <= 16'sd0;
                        vel1_y <= 16'sd0;
                    end
                    if (boom0 != 5'd0)
                        boom0 <= boom0 - 5'd1;
                    if (boom1 != 5'd0)
                        boom1 <= boom1 - 5'd1;
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
                end else case (phys_phase)
                    3'd0: begin
                        if (left_p)  ang0 <= ang0 - 8'd4;
                        if (right_p) ang0 <= ang0 + 8'd4;
                        if (thrust_p && (fuel_ms != 15'd0) && (boom0 == 5'd0)) begin
                            thrusting0 <= 1'b1;
                            if (fuel_ms > FUEL_FRAME_MS[14:0])
                                fuel_ms <= fuel_ms - FUEL_FRAME_MS[14:0];
                            else
                                fuel_ms <= 15'd0;
                        end else
                            thrusting0 <= 1'b0;
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
                            // Track harder as time goes on (skip less, turn faster)
                            if ((ai_dec >= 5'd15) || (lfsr[1:0] != 2'b00)) begin
                                if (dotp[31])
                                    ang1 <= ang1 + (8'd2 + {3'b0, ai_dec[4:2]});
                                else if (cross[31])
                                    ang1 <= ang1 + (8'd2 + {3'b0, ai_dec[4:2]});
                                else
                                    ang1 <= ang1 - (8'd2 + {3'b0, ai_dec[4:2]});
                            end
                            thrusting1 <= ~dotp[31] &&
                                          ((ai_dec >= 5'd18) ||
                                           ((dotp > 32'sd1500) &&
                                            ((adx + ady) > 16'sd70) &&
                                            (ai_pulse[4:3] != 2'b11)));
                        end else
                            thrusting1 <= 1'b0;
                        phys_phase <= 3'd4;
                    end
                    3'd4: begin
                        ship_sel <= 1'b0; // cos/sin -> ang0 next cycle
                        phys_phase <= 3'd5;
                    end
                    3'd5: begin
                        begin : grav0
                            reg signed [15:0] gdx, gdy, gx, gy;
                            gdx = 16'sd400 - $signed(pos0_x[23:8]);
                            gdy = 16'sd240 - $signed(pos0_y[23:8]);
                            // BH: soft pull; anti_grav: soft push; thrust (~40) can overcome
                            if (black_hole) begin
                                gx = gdx >>> 5;
                                gy = gdy >>> 5;
                            end else if (anti_grav) begin
                                gx = -(gdx >>> 5);
                                gy = -(gdy >>> 5);
                            end else begin
                                gx = 16'sd0;
                                gy = 16'sd0;
                            end
                            vel0_x <= vel0_x + mul_q88(cos_a, thrusting0 ? 16'sd40 : 16'sd0)
                                      + gx - (vel0_x >>> 8);
                            vel0_y <= vel0_y + mul_q88(sin_a, thrusting0 ? 16'sd40 : 16'sd0)
                                      + gy - (vel0_y >>> 8);
                        end
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
                        begin : grav1
                            reg signed [15:0] gdx, gdy, gx, gy;
                            gdx = 16'sd400 - $signed(pos1_x[23:8]);
                            gdy = 16'sd240 - $signed(pos1_y[23:8]);
                            if (black_hole) begin
                                gx = gdx >>> 5;
                                gy = gdy >>> 5;
                            end else if (anti_grav) begin
                                gx = -(gdx >>> 5);
                                gy = -(gdy >>> 5);
                            end else begin
                                gx = 16'sd0;
                                gy = 16'sd0;
                            end
                            vel1_x <= vel1_x + mul_q88(cos_a, thrusting1 ? ai_thrust : 16'sd0)
                                      + gx - (vel1_x >>> 8);
                            vel1_y <= vel1_y + mul_q88(sin_a, thrusting1 ? ai_thrust : 16'sd0)
                                      + gy - (vel1_y >>> 8);
                        end
                        // Left / center / right shots; later all three
                        if (ai_cd != 6'd0)
                            ai_cd <= ai_cd - 6'd1;
                        else if ((boom0 == 5'd0) && (boom1 == 5'd0) &&
                                 ((ai_dec >= 5'd20) || (~dotp[31] && (dotp > 32'sd2500)))) begin
                            begin : spawn_eshot
                                reg signed [15:0] ox, oy, spr;
                                reg [2:0] mask;
                                ox = mul_q88(cos_a, 16'sd16);
                                oy = mul_q88(sin_a, 16'sd16);
                                spr = 16'sd6 <<< 8;
                                if (ai_dec >= 5'd24)
                                    mask = 3'b111;
                                else if (ai_dec >= 5'd12)
                                    mask = 3'b010 | {lfsr[1], 1'b0, lfsr[0]};
                                else begin
                                    case (lfsr[1:0])
                                        2'b00: mask = 3'b001;
                                        2'b01: mask = 3'b010;
                                        2'b10: mask = 3'b100;
                                        default: mask = 3'b010;
                                    endcase
                                end
                                if (mask[0] && !ebul_on[0]) begin
                                    ebul_x[0]  <= pos1_x + {{8{ox[15]}}, ox};
                                    ebul_y[0]  <= pos1_y + {{8{oy[15]}}, oy};
                                    ebul_vx[0] <= mul_q88(cos_a, 16'sd10 <<< 8)
                                                + mul_q88(-sin_a, spr) + (vel1_x >>> 1);
                                    ebul_vy[0] <= mul_q88(sin_a, 16'sd10 <<< 8)
                                                + mul_q88( cos_a, spr) + (vel1_y >>> 1);
                                    ebul_on[0]   <= 1'b1;
                                    ebul_life[0] <= BUL_LIFE[5:0];
                                end
                                if (mask[1] && !ebul_on[1]) begin
                                    ebul_x[1]  <= pos1_x + {{8{ox[15]}}, ox};
                                    ebul_y[1]  <= pos1_y + {{8{oy[15]}}, oy};
                                    ebul_vx[1] <= mul_q88(cos_a, 16'sd10 <<< 8) + (vel1_x >>> 1);
                                    ebul_vy[1] <= mul_q88(sin_a, 16'sd10 <<< 8) + (vel1_y >>> 1);
                                    ebul_on[1]   <= 1'b1;
                                    ebul_life[1] <= BUL_LIFE[5:0];
                                end
                                if (mask[2] && !ebul_on[2]) begin
                                    ebul_x[2]  <= pos1_x + {{8{ox[15]}}, ox};
                                    ebul_y[2]  <= pos1_y + {{8{oy[15]}}, oy};
                                    ebul_vx[2] <= mul_q88(cos_a, 16'sd10 <<< 8)
                                                + mul_q88(-sin_a, -spr) + (vel1_x >>> 1);
                                    ebul_vy[2] <= mul_q88(sin_a, 16'sd10 <<< 8)
                                                + mul_q88( cos_a, -spr) + (vel1_y >>> 1);
                                    ebul_on[2]   <= 1'b1;
                                    ebul_life[2] <= BUL_LIFE[5:0];
                                end
                            end
                            if ((6'd42 - {1'b0, ai_dec}) < 6'd8)
                                ai_cd <= 6'd8;
                            else
                                ai_cd <= 6'd42 - {1'b0, ai_dec};
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
                    // Player into sun / black-hole core: boom + lose a life
                    if ((r2 < 32'sd400) && (boom0 == 5'd0)) begin
                        boom0       <= BOOM_N[4:0];
                        boom0_dirty <= 1'b1;
                        boom0_x     <= $signed(pos0_x[23:8]);
                        boom0_y     <= $signed(pos0_y[23:8]);
                        if (lives0 != 3'd0) begin
                            if (lives0 == 3'd1)
                                game_over <= 1'b1;
                            lives0 <= lives0 - 3'd1;
                        end
                    end
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
                    if (ebul_on[0]) begin
                        ebul_x[0] <= ebul_x[0] + {{8{ebul_vx[0][15]}}, ebul_vx[0]};
                        ebul_y[0] <= ebul_y[0] + {{8{ebul_vy[0][15]}}, ebul_vy[0]};
                        if (ebul_life[0] != 6'd0) ebul_life[0] <= ebul_life[0] - 6'd1;
                    end
                    if (ebul_on[1]) begin
                        ebul_x[1] <= ebul_x[1] + {{8{ebul_vx[1][15]}}, ebul_vx[1]};
                        ebul_y[1] <= ebul_y[1] + {{8{ebul_vy[1][15]}}, ebul_vy[1]};
                        if (ebul_life[1] != 6'd0) ebul_life[1] <= ebul_life[1] - 6'd1;
                    end
                    if (ebul_on[2]) begin
                        ebul_x[2] <= ebul_x[2] + {{8{ebul_vx[2][15]}}, ebul_vx[2]};
                        ebul_y[2] <= ebul_y[2] + {{8{ebul_vy[2][15]}}, ebul_vy[2]};
                        if (ebul_life[2] != 6'd0) ebul_life[2] <= ebul_life[2] - 6'd1;
                    end
                    if (boom0 == 5'd1) begin
                        if (lives0 != 3'd0)
                            respawn0;
                        else begin
                            pos0_x <= -(24'sd80 <<< 8);
                            pos0_y <= -(24'sd80 <<< 8);
                            vel0_x <= 16'sd0;
                            vel0_y <= 16'sd0;
                        end
                    end
                    if (boom1 == 5'd1)
                        respawn1;
                    if (boom0 != 5'd0)
                        boom0 <= boom0 - 5'd1;
                    if (boom1 != 5'd0)
                        boom1 <= boom1 - 5'd1;
                    ei <= 4'd4;
                end else begin : hits
                    reg signed [15:0] bdx, bdy, adx, ady;
                    reg signed [7:0]  n0, n1;
                    reg [2:0]         nl0, nst;
                    reg [9:0]         nt;
                    reg [3:0]         nsh;
                    reg [2:0]         nbh;
                    reg               hit_ai, hit_pl, ram;
                    reg               sun_p, sun_e;
                    n0 = score0; n1 = score1;
                    nl0 = lives0;
                    nst = ai_streak;
                    nt  = timer_sec;
                    nsh = sun_hits;
                    nbh = bh_hits;
                    hit_ai = 1'b0; hit_pl = 1'b0; ram = 1'b0;
                    sun_p = 1'b0; sun_e = 1'b0;
                    if (bullet_on) begin
                        if ((bul_life == 6'd0) ||
                            (bul_x < (MARGIN <<< 8)) ||
                            (bul_x > ((FB_W - MARGIN) <<< 8)) ||
                            (bul_y < (MARGIN <<< 8)) ||
                            (bul_y > ((FB_H - MARGIN) <<< 8)))
                            bullet_on <= 1'b0;
                        else begin
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
                                hit_ai     = 1'b1;
                            end else begin
                                bdx = $signed(bul_x[23:8]) - 16'sd400;
                                bdy = $signed(bul_y[23:8]) - 16'sd240;
                                if ((bdx * bdx + bdy * bdy) < 32'sd400) begin
                                    bullet_on <= 1'b0;
                                    sun_p = 1'b1;
                                end
                            end
                        end
                    end
                    if (ebul_on[0]) begin
                        if ((ebul_life[0] == 6'd0) ||
                            (ebul_x[0] < (MARGIN <<< 8)) ||
                            (ebul_x[0] > ((FB_W - MARGIN) <<< 8)) ||
                            (ebul_y[0] < (MARGIN <<< 8)) ||
                            (ebul_y[0] > ((FB_H - MARGIN) <<< 8)))
                            ebul_on[0] <= 1'b0;
                        else begin
                            bdx = $signed(ebul_x[0][23:8]) - $signed(pos0_x[23:8]);
                            bdy = $signed(ebul_y[0][23:8]) - $signed(pos0_y[23:8]);
                            adx = bdx[15] ? -bdx : bdx;
                            ady = bdy[15] ? -bdy : bdy;
                            if ((boom0 == 5'd0) && (adx < 16'sd20) && (ady < 16'sd20)) begin
                                ebul_on[0]  <= 1'b0;
                                boom0       <= BOOM_N[4:0];
                                boom0_dirty <= 1'b1;
                                boom0_x     <= $signed(pos0_x[23:8]);
                                boom0_y     <= $signed(pos0_y[23:8]);
                                hit_pl      = 1'b1;
                            end else begin
                                bdx = $signed(ebul_x[0][23:8]) - 16'sd400;
                                bdy = $signed(ebul_y[0][23:8]) - 16'sd240;
                                if ((bdx * bdx + bdy * bdy) < 32'sd400) begin
                                    ebul_on[0] <= 1'b0;
                                    sun_e = 1'b1;
                                end
                            end
                        end
                    end
                    if (ebul_on[1]) begin
                        if ((ebul_life[1] == 6'd0) ||
                            (ebul_x[1] < (MARGIN <<< 8)) ||
                            (ebul_x[1] > ((FB_W - MARGIN) <<< 8)) ||
                            (ebul_y[1] < (MARGIN <<< 8)) ||
                            (ebul_y[1] > ((FB_H - MARGIN) <<< 8)))
                            ebul_on[1] <= 1'b0;
                        else begin
                            bdx = $signed(ebul_x[1][23:8]) - $signed(pos0_x[23:8]);
                            bdy = $signed(ebul_y[1][23:8]) - $signed(pos0_y[23:8]);
                            adx = bdx[15] ? -bdx : bdx;
                            ady = bdy[15] ? -bdy : bdy;
                            if ((boom0 == 5'd0) && !hit_pl && (adx < 16'sd20) && (ady < 16'sd20)) begin
                                ebul_on[1]  <= 1'b0;
                                boom0       <= BOOM_N[4:0];
                                boom0_dirty <= 1'b1;
                                boom0_x     <= $signed(pos0_x[23:8]);
                                boom0_y     <= $signed(pos0_y[23:8]);
                                hit_pl      = 1'b1;
                            end else begin
                                bdx = $signed(ebul_x[1][23:8]) - 16'sd400;
                                bdy = $signed(ebul_y[1][23:8]) - 16'sd240;
                                if ((bdx * bdx + bdy * bdy) < 32'sd400) begin
                                    ebul_on[1] <= 1'b0;
                                    sun_e = 1'b1;
                                end
                            end
                        end
                    end
                    if (ebul_on[2]) begin
                        if ((ebul_life[2] == 6'd0) ||
                            (ebul_x[2] < (MARGIN <<< 8)) ||
                            (ebul_x[2] > ((FB_W - MARGIN) <<< 8)) ||
                            (ebul_y[2] < (MARGIN <<< 8)) ||
                            (ebul_y[2] > ((FB_H - MARGIN) <<< 8)))
                            ebul_on[2] <= 1'b0;
                        else begin
                            bdx = $signed(ebul_x[2][23:8]) - $signed(pos0_x[23:8]);
                            bdy = $signed(ebul_y[2][23:8]) - $signed(pos0_y[23:8]);
                            adx = bdx[15] ? -bdx : bdx;
                            ady = bdy[15] ? -bdy : bdy;
                            if ((boom0 == 5'd0) && !hit_pl && (adx < 16'sd20) && (ady < 16'sd20)) begin
                                ebul_on[2]  <= 1'b0;
                                boom0       <= BOOM_N[4:0];
                                boom0_dirty <= 1'b1;
                                boom0_x     <= $signed(pos0_x[23:8]);
                                boom0_y     <= $signed(pos0_y[23:8]);
                                hit_pl      = 1'b1;
                            end else begin
                                bdx = $signed(ebul_x[2][23:8]) - 16'sd400;
                                bdy = $signed(ebul_y[2][23:8]) - 16'sd240;
                                if ((bdx * bdx + bdy * bdy) < 32'sd400) begin
                                    ebul_on[2] <= 1'b0;
                                    sun_e = 1'b1;
                                end
                            end
                        end
                    end
                    if (black_hole) begin
                        // Player shots into BH restore the sun (anti-gravity)
                        if (sun_p) begin
                            if (nbh == (BH_HITS_SUN[2:0] - 3'd1)) begin
                                black_hole <= 1'b0;
                                anti_grav  <= 1'b1;
                                bh_hits    <= 3'd0;
                            end else
                                bh_hits <= nbh + 3'd1;
                        end
                    end else if (!anti_grav) begin
                        // Normal sun: 10 hits → black hole
                        if (sun_p && (nsh < 4'd15)) nsh = nsh + 4'd1;
                        if (sun_e && (nsh < 4'd15)) nsh = nsh + 4'd1;
                        sun_hits <= nsh;
                        if (nsh >= SUN_HITS_BH[3:0])
                            black_hole <= 1'b1;
                    end
                    // anti_grav: sun is back; core still lethal; no further mode change
                    bdx = $signed(pos0_x[23:8]) - $signed(pos1_x[23:8]);
                    bdy = $signed(pos0_y[23:8]) - $signed(pos1_y[23:8]);
                    adx = bdx[15] ? -bdx : bdx;
                    ady = bdy[15] ? -bdy : bdy;
                    if ((boom0 == 5'd0) && (boom1 == 5'd0) &&
                        (adx < 16'sd20) && (ady < 16'sd18)) begin
                        if (!ship_lock) begin
                            ram = 1'b1;
                            vel0_x <= -vel0_x;
                            vel0_y <= -vel0_y;
                            vel1_x <= -vel1_x;
                            vel1_y <= -vel1_y;
                            if (!bdx[15]) begin
                                pos0_x <= pos0_x + (24'sd8 <<< 8);
                                pos1_x <= pos1_x - (24'sd8 <<< 8);
                            end else begin
                                pos0_x <= pos0_x - (24'sd8 <<< 8);
                                pos1_x <= pos1_x + (24'sd8 <<< 8);
                            end
                        end
                        ship_lock <= 1'b1;
                    end else if ((adx >= 16'sd26) || (ady >= 16'sd24))
                        ship_lock <= 1'b0;
                    if (hit_ai && (n0 < 8'sd99)) n0 = n0 + 8'sd1;
                    if (hit_pl && (n1 < 8'sd99)) n1 = n1 + 8'sd1;
                    if (ram) begin
                        if (n0 > -8'sd99) n0 = n0 - 8'sd1;
                        if (n1 > -8'sd99) n1 = n1 - 8'sd1;
                    end
                    if (hit_pl && (nl0 != 3'd0))
                        nl0 = nl0 - 3'd1;
                    if (hit_ai) begin
                        if (nst == (KILL_FOR_LIFE[2:0] - 3'd1)) begin
                            nst = 3'd0;
                            if (nl0 < LIFE_MAX[2:0])
                                nl0 = nl0 + 3'd1;
                        end else
                            nst = nst + 3'd1;
                    end
                    if (hit_ai || hit_pl) begin
                        if (nt > (TIMER_MAX[9:0] - TIMER_BONUS[9:0]))
                            nt = TIMER_MAX[9:0];
                        else
                            nt = nt + TIMER_BONUS[9:0];
                    end
                    score0    <= n0;
                    score1    <= n1;
                    lives0    <= nl0;
                    ai_streak <= nst;
                    timer_sec <= nt;
                    if (nl0 == 3'd0)
                        game_over <= 1'b1;
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
                        nvert <= (!ship_sel) ? 5'd19 : 5'd4;
                        nedge <= (!ship_sel) ? 5'd22 : 5'd4;
                        hitch <= (!ship_sel) ? 5'd18 : 5'd2;
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
                // Erase leftover FB stars; stars are composited at scanout (in front of ships)
                plot_en <= 1'b1; plot_bit <= 1'b0;
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
                        nvert    <= 5'd19;
                        nedge    <= 5'd22;
                        hitch    <= 5'd18;
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
                        if (ebul_have_prev[0]) begin
                            start_line($signed({6'b0, ebul_ox[0]}), $signed({7'b0, ebul_oy[0]}),
                                       $signed({6'b0, ebul_ox2[0]}), $signed({7'b0, ebul_oy2[0]}));
                            line_active <= 1'b1;
                            plot_bit    <= 1'b0;
                            ei <= 4'd3;
                        end else
                            ei <= 4'd3;
                    end else if (ei == 4'd3) begin
                        if (ebul_on[0]) begin
                            begin : edir0
                                reg signed [15:0] sx, sy, x0, y0, x1, y1;
                                x0 = $signed(ebul_x[0][23:8]);
                                y0 = $signed(ebul_y[0][23:8]);
                                sx = ebul_vx[0] >>> 9;
                                sy = ebul_vy[0] >>> 9;
                                if (sx == 0 && sy == 0) sx = 16'sd5;
                                x1 = x0 + sx; y1 = y0 + sy;
                                start_line(x0, y0, x1, y1);
                                ebul_ox[0]  <= x0[9:0];
                                ebul_oy[0]  <= y0[8:0];
                                ebul_ox2[0] <= x1[9:0];
                                ebul_oy2[0] <= y1[8:0];
                            end
                            line_active <= 1'b1; plot_bit <= 1'b1;
                            ebul_have_prev[0] <= 1'b1;
                            ei <= 4'd4;
                        end else begin
                            ebul_have_prev[0] <= 1'b0;
                            ei <= 4'd4;
                        end
                    end else if (ei == 4'd4) begin
                        if (ebul_have_prev[1]) begin
                            start_line($signed({6'b0, ebul_ox[1]}), $signed({7'b0, ebul_oy[1]}),
                                       $signed({6'b0, ebul_ox2[1]}), $signed({7'b0, ebul_oy2[1]}));
                            line_active <= 1'b1; plot_bit <= 1'b0;
                            ei <= 4'd5;
                        end else
                            ei <= 4'd5;
                    end else if (ei == 4'd5) begin
                        if (ebul_on[1]) begin
                            begin : edir1
                                reg signed [15:0] sx, sy, x0, y0, x1, y1;
                                x0 = $signed(ebul_x[1][23:8]);
                                y0 = $signed(ebul_y[1][23:8]);
                                sx = ebul_vx[1] >>> 9;
                                sy = ebul_vy[1] >>> 9;
                                if (sx == 0 && sy == 0) sx = 16'sd5;
                                x1 = x0 + sx; y1 = y0 + sy;
                                start_line(x0, y0, x1, y1);
                                ebul_ox[1]  <= x0[9:0];
                                ebul_oy[1]  <= y0[8:0];
                                ebul_ox2[1] <= x1[9:0];
                                ebul_oy2[1] <= y1[8:0];
                            end
                            line_active <= 1'b1; plot_bit <= 1'b1;
                            ebul_have_prev[1] <= 1'b1;
                            ei <= 4'd6;
                        end else begin
                            ebul_have_prev[1] <= 1'b0;
                            ei <= 4'd6;
                        end
                    end else if (ei == 4'd6) begin
                        if (ebul_have_prev[2]) begin
                            start_line($signed({6'b0, ebul_ox[2]}), $signed({7'b0, ebul_oy[2]}),
                                       $signed({6'b0, ebul_ox2[2]}), $signed({7'b0, ebul_oy2[2]}));
                            line_active <= 1'b1; plot_bit <= 1'b0;
                            ei <= 4'd7;
                        end else
                            ei <= 4'd7;
                    end else if (ei == 4'd7) begin
                        if (ebul_on[2]) begin
                            begin : edir2
                                reg signed [15:0] sx, sy, x0, y0, x1, y1;
                                x0 = $signed(ebul_x[2][23:8]);
                                y0 = $signed(ebul_y[2][23:8]);
                                sx = ebul_vx[2] >>> 9;
                                sy = ebul_vy[2] >>> 9;
                                if (sx == 0 && sy == 0) sx = 16'sd5;
                                x1 = x0 + sx; y1 = y0 + sy;
                                start_line(x0, y0, x1, y1);
                                ebul_ox[2]  <= x0[9:0];
                                ebul_oy[2]  <= y0[8:0];
                                ebul_ox2[2] <= x1[9:0];
                                ebul_oy2[2] <= y1[8:0];
                            end
                            line_active <= 1'b1; plot_bit <= 1'b1;
                            ebul_have_prev[2] <= 1'b1;
                            ei <= 4'd8;
                        end else begin
                            ebul_have_prev[2] <= 1'b0;
                            ei <= 4'd8;
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
