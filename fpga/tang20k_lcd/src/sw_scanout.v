// Scanout compositing: sun/BH, star ROM, 2-bit FB ink, HUD overlay, GAME OVER.

module sw_scanout (
    input  wire       clk,
    input  wire       de_now,
    input  wire [9:0] pix_x,
    input  wire [9:0] pix_y,
    input  wire [1:0] rdata,
    input  wire       black_hole,
    input  wire       game_over,
    input  wire [5:0] frame_cnt,
    input  wire [13:0] timer_sec,
    input  wire signed [9:0] score0,
    input  wire signed [9:0] score1,
    input  wire [2:0] lives0,
    input  wire [14:0] fuel_ms,
    output reg  [4:0] pix_r,
    output reg  [5:0] pix_g,
    output reg  [4:0] pix_b
);

// Gowin Education often fails `include — keep constants local.
localparam integer FB_W   = 800;
localparam integer FB_H   = 470;
localparam integer SUN_R  = 18;
localparam integer FUEL_MAX_MS    = 15000;
localparam integer FUEL_YEL_MS    = 1500;
localparam integer FUEL_RED_MS    = 750;
localparam integer FUEL_X         = 176;
localparam integer FUEL_Y         = 18;
localparam integer FUEL_W         = 14;
localparam integer FUEL_H         = 56;
localparam integer FUEL_T         = 2;
localparam integer FUEL_INNER_H   = 52;
localparam integer FUEL_MS_PER_PX = 288;
localparam integer DIG_W    = 32;
localparam integer DIG_H    = 56;
localparam integer DIG_T    = 8;
localparam integer LIFE_W   = 12;
localparam integer LIFE_H   = 10;
localparam integer GO_SCALE = 6;

localparam [1:0] COL_OFF  = 2'b00;
localparam [1:0] COL_PL   = 2'b01;
localparam [1:0] COL_AI   = 2'b10;

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

function [3:0] dec_hundreds;
    input [9:0] v;
    begin
        if (v >= 10'd900)      dec_hundreds = 4'd9;
        else if (v >= 10'd800) dec_hundreds = 4'd8;
        else if (v >= 10'd700) dec_hundreds = 4'd7;
        else if (v >= 10'd600) dec_hundreds = 4'd6;
        else if (v >= 10'd500) dec_hundreds = 4'd5;
        else if (v >= 10'd400) dec_hundreds = 4'd4;
        else if (v >= 10'd300) dec_hundreds = 4'd3;
        else if (v >= 10'd200) dec_hundreds = 4'd2;
        else if (v >= 10'd100) dec_hundreds = 4'd1;
        else                   dec_hundreds = 4'd0;
    end
endfunction

// kind: 0=digit, 1=minus bar, 2=colon dots
function hud_mark;
    input [9:0] px, py, ox, oy;
    input [3:0] d;
    input [1:0] kind;
    reg [9:0] rx, ry;
    reg [6:0] s;
    begin
        hud_mark = 1'b0;
        if (kind == 2'd1) begin
            hud_mark = (px >= ox) && (px < (ox + DIG_W)) &&
                       (py >= (oy + ((DIG_H - DIG_T) / 2))) &&
                       (py <  (oy + ((DIG_H - DIG_T) / 2) + DIG_T));
        end else if (kind == 2'd2) begin
            hud_mark =
                ((px >= ox) && (px < (ox + DIG_T)) &&
                 (py >= (oy + DIG_H/4 - DIG_T/2)) &&
                 (py <  (oy + DIG_H/4 - DIG_T/2 + DIG_T))) ||
                ((px >= ox) && (px < (ox + DIG_T)) &&
                 (py >= (oy + (3*DIG_H)/4 - DIG_T/2)) &&
                 (py <  (oy + (3*DIG_H)/4 - DIG_T/2 + DIG_T)));
        end else if ((px >= ox) && (px < (ox + DIG_W)) &&
                     (py >= oy) && (py < (oy + DIG_H))) begin
            rx = px - ox;
            ry = py - oy;
            s  = seg7(d);
            if (s[0] && (ry < DIG_T))
                hud_mark = 1'b1;
            if (s[3] && (ry >= (DIG_H - DIG_T)))
                hud_mark = 1'b1;
            if (s[6] && (ry >= ((DIG_H - DIG_T) / 2)) &&
                (ry < ((DIG_H - DIG_T) / 2) + DIG_T))
                hud_mark = 1'b1;
            if (s[5] && (rx < DIG_T) && (ry < (DIG_H / 2)))
                hud_mark = 1'b1;
            if (s[4] && (rx < DIG_T) && (ry >= (DIG_H / 2)))
                hud_mark = 1'b1;
            if (s[1] && (rx >= (DIG_W - DIG_T)) && (ry < (DIG_H / 2)))
                hud_mark = 1'b1;
            if (s[2] && (rx >= (DIG_W - DIG_T)) && (ry >= (DIG_H / 2)))
                hud_mark = 1'b1;
        end
    end
endfunction

function life_icon;
    input [9:0] px, py, ox, oy;
    reg [9:0] rx, ry, half;
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

function fuel_gauge;
    input [9:0] px, py, fill_h;
    reg in_box, on_border, in_fill;
    begin
        in_box = (px >= FUEL_X) && (px < (FUEL_X + FUEL_W)) &&
                 (py >= FUEL_Y) && (py < (FUEL_Y + FUEL_H));
        on_border = in_box &&
                    ((px < (FUEL_X + FUEL_T)) ||
                     (px >= (FUEL_X + FUEL_W - FUEL_T)) ||
                     (py < (FUEL_Y + FUEL_T)) ||
                     (py >= (FUEL_Y + FUEL_H - FUEL_T)));
        in_fill = (fill_h != 10'd0) &&
                  (px >= (FUEL_X + FUEL_T)) &&
                  (px < (FUEL_X + FUEL_W - FUEL_T)) &&
                  (py >= (FUEL_Y + FUEL_H - FUEL_T - fill_h)) &&
                  (py < (FUEL_Y + FUEL_H - FUEL_T));
        fuel_gauge = on_border || in_fill;
    end
endfunction

function [4:0] glyph_row;
    input [2:0] ch, row;
    begin
        case (ch)
            3'd0: case (row)
                3'd0: glyph_row=5'b01110; 3'd1: glyph_row=5'b10001;
                3'd2: glyph_row=5'b10000; 3'd3: glyph_row=5'b10111;
                3'd4: glyph_row=5'b10001; 3'd5: glyph_row=5'b10001;
                default: glyph_row=5'b01110;
            endcase
            3'd1: case (row)
                3'd0: glyph_row=5'b01110; 3'd1: glyph_row=5'b10001;
                3'd2: glyph_row=5'b10001; 3'd3: glyph_row=5'b11111;
                3'd4: glyph_row=5'b10001; 3'd5: glyph_row=5'b10001;
                default: glyph_row=5'b10001;
            endcase
            3'd2: case (row)
                3'd0: glyph_row=5'b10001; 3'd1: glyph_row=5'b11011;
                3'd2: glyph_row=5'b10101; 3'd3: glyph_row=5'b10001;
                3'd4: glyph_row=5'b10001; 3'd5: glyph_row=5'b10001;
                default: glyph_row=5'b10001;
            endcase
            3'd3: case (row)
                3'd0: glyph_row=5'b11111; 3'd1: glyph_row=5'b10000;
                3'd2: glyph_row=5'b10000; 3'd3: glyph_row=5'b11110;
                3'd4: glyph_row=5'b10000; 3'd5: glyph_row=5'b10000;
                default: glyph_row=5'b11111;
            endcase
            3'd4: case (row)
                3'd0: glyph_row=5'b01110; 3'd1: glyph_row=5'b10001;
                3'd2: glyph_row=5'b10001; 3'd3: glyph_row=5'b10001;
                3'd4: glyph_row=5'b10001; 3'd5: glyph_row=5'b10001;
                default: glyph_row=5'b01110;
            endcase
            3'd5: case (row)
                3'd0: glyph_row=5'b10001; 3'd1: glyph_row=5'b10001;
                3'd2: glyph_row=5'b10001; 3'd3: glyph_row=5'b10001;
                3'd4: glyph_row=5'b10001; 3'd5: glyph_row=5'b01010;
                default: glyph_row=5'b00100;
            endcase
            3'd6: case (row)
                3'd0: glyph_row=5'b11110; 3'd1: glyph_row=5'b10001;
                3'd2: glyph_row=5'b10001; 3'd3: glyph_row=5'b11110;
                3'd4: glyph_row=5'b10100; 3'd5: glyph_row=5'b10010;
                default: glyph_row=5'b10001;
            endcase
            default: glyph_row = 5'b00000;
        endcase
    end
endfunction

function block_letter;
    input [9:0] px, py, ox, oy;
    input [2:0] ch;
    reg [9:0] rx, ry, qcol, qrow;
    reg [2:0] col, row;
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
    input [9:0] px, py;
    begin
        game_over_text =
            block_letter(px, py, 10'd241, 10'd219, 3'd0) ||
            block_letter(px, py, 10'd277, 10'd219, 3'd1) ||
            block_letter(px, py, 10'd313, 10'd219, 3'd2) ||
            block_letter(px, py, 10'd349, 10'd219, 3'd3) ||
            block_letter(px, py, 10'd421, 10'd219, 3'd4) ||
            block_letter(px, py, 10'd457, 10'd219, 3'd5) ||
            block_letter(px, py, 10'd493, 10'd219, 3'd3) ||
            block_letter(px, py, 10'd529, 10'd219, 3'd6);
    end
endfunction

function star_rom_hit;
    input [9:0] px, py;
    begin
        case ({py[8:0], px})
            {9'd50,  10'd90}:  star_rom_hit = 1'b1;
            {9'd60,  10'd130}: star_rom_hit = 1'b1;
            {9'd55,  10'd170}: star_rom_hit = 1'b1;
            {9'd70,  10'd210}: star_rom_hit = 1'b1;
            {9'd100, 10'd230}: star_rom_hit = 1'b1;
            {9'd110, 10'd270}: star_rom_hit = 1'b1;
            {9'd95,  10'd300}: star_rom_hit = 1'b1;
            {9'd40,  10'd520}: star_rom_hit = 1'b1;
            {9'd70,  10'd560}: star_rom_hit = 1'b1;
            {9'd45,  10'd600}: star_rom_hit = 1'b1;
            {9'd75,  10'd640}: star_rom_hit = 1'b1;
            {9'd50,  10'd680}: star_rom_hit = 1'b1;
            {9'd360, 10'd100}: star_rom_hit = 1'b1;
            {9'd350, 10'd180}: star_rom_hit = 1'b1;
            {9'd390, 10'd130}: star_rom_hit = 1'b1;
            {9'd395, 10'd150}: star_rom_hit = 1'b1;
            {9'd400, 10'd170}: star_rom_hit = 1'b1;
            {9'd440, 10'd110}: star_rom_hit = 1'b1;
            {9'd445, 10'd190}: star_rom_hit = 1'b1;
            {9'd400, 10'd650}: star_rom_hit = 1'b1;
            {9'd420, 10'd680}: star_rom_hit = 1'b1;
            {9'd400, 10'd710}: star_rom_hit = 1'b1;
            {9'd440, 10'd690}: star_rom_hit = 1'b1;
            {9'd380, 10'd720}: star_rom_hit = 1'b1;
            {9'd160, 10'd720}: star_rom_hit = 1'b1;
            {9'd130, 10'd700}: star_rom_hit = 1'b1;
            {9'd130, 10'd740}: star_rom_hit = 1'b1;
            {9'd100, 10'd760}: star_rom_hit = 1'b1;
            default: star_rom_hit = 1'b0;
        endcase
    end
endfunction

wire        in_fb = de_now && (pix_x < FB_W) && (pix_y < FB_H);
reg         in_fb_d;
reg [9:0]   pix_x_d, pix_y_d;

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
wire star_hit = star_rom_hit(pix_x_d, pix_y_d);

wire [9:0] score0_abs = score0[9] ? (-score0) : score0;
wire [9:0] score1_abs = score1[9] ? (-score1) : score1;
wire [3:0] s0_hund = dec_hundreds(score0_abs);
wire [3:0] s1_hund = dec_hundreds(score1_abs);
wire [9:0] s0_rem  = score0_abs - ({6'b0, s0_hund} * 10'd100);
wire [9:0] s1_rem  = score1_abs - ({6'b0, s1_hund} * 10'd100);
wire [3:0] s0_tens = dec_tens(s0_rem[6:0]);
wire [3:0] s1_tens = dec_tens(s1_rem[6:0]);
wire [6:0] s0_ten10 = {s0_tens, 3'b0} + {2'b0, s0_tens, 1'b0};
wire [6:0] s1_ten10 = {s1_tens, 3'b0} + {2'b0, s1_tens, 1'b0};
wire [6:0] s0_ones7 = s0_rem[6:0] - s0_ten10;
wire [6:0] s1_ones7 = s1_rem[6:0] - s1_ten10;
wire [3:0] s0_ones = s0_ones7[3:0];
wire [3:0] s1_ones = s1_ones7[3:0];
// Leading-zero blanking; minus sits immediately left of first visible digit
wire s0_show_h = (score0_abs >= 10'd100);
wire s0_show_t = (score0_abs >= 10'd10);
wire s1_show_h = (score1_abs >= 10'd100);
wire s1_show_t = (score1_abs >= 10'd10);
wire [9:0] s0_hx = 10'd52;
wire [9:0] s0_tx = 10'd92;
wire [9:0] s0_ox = 10'd132;
wire [9:0] s1_hx = 10'd616;
wire [9:0] s1_tx = 10'd656;
wire [9:0] s1_ox = 10'd696;
wire [9:0] s0_first = s0_show_h ? s0_hx : (s0_show_t ? s0_tx : s0_ox);
wire [9:0] s1_first = s1_show_h ? s1_hx : (s1_show_t ? s1_tx : s1_ox);
wire [9:0] s0_minus_x = s0_first - DIG_W[9:0];
wire [9:0] s1_minus_x = s1_first - DIG_W[9:0];
// Counter 00:00..99:99 (hi/lo each 0..99), not a clock
wire [13:0] tm_hi14 = timer_sec / 14'd100;
wire [13:0] tm_lo14 = timer_sec % 14'd100;
wire [6:0]  tm_hi   = tm_hi14[6:0];
wire [6:0]  tm_lo   = tm_lo14[6:0];
wire [3:0]  tm_htens = dec_tens(tm_hi);
wire [6:0]  tm_hten10 = {tm_htens, 3'b0} + {2'b0, tm_htens, 1'b0};
wire [6:0]  tm_hones7 = tm_hi - tm_hten10;
wire [3:0]  tm_hones = tm_hones7[3:0];
wire [3:0]  tm_ltens = dec_tens(tm_lo);
wire [6:0]  tm_lten10 = {tm_ltens, 3'b0} + {2'b0, tm_ltens, 1'b0};
wire [6:0]  tm_lones7 = tm_lo - tm_lten10;
wire [3:0]  tm_lones = tm_lones7[3:0];
// DIG_W=32, pitch 40; colon 8 wide → block 160 px, centered on 800
localparam integer TM_X0 = 320;
wire timer_hit =
    hud_mark(pix_x_d, pix_y_d, TM_X0[9:0],           10'd18, tm_htens, 2'd0) ||
    hud_mark(pix_x_d, pix_y_d, TM_X0[9:0] + 10'd40,   10'd18, tm_hones, 2'd0) ||
    hud_mark(pix_x_d, pix_y_d, TM_X0[9:0] + 10'd76,   10'd18, 4'd0,     2'd2) ||
    hud_mark(pix_x_d, pix_y_d, TM_X0[9:0] + 10'd88,   10'd18, tm_ltens, 2'd0) ||
    hud_mark(pix_x_d, pix_y_d, TM_X0[9:0] + 10'd128,  10'd18, tm_lones, 2'd0);
wire score_hit =
    (score0[9] && hud_mark(pix_x_d, pix_y_d, s0_minus_x, 10'd18, 4'd0, 2'd1)) ||
    (s0_show_h && hud_mark(pix_x_d, pix_y_d, s0_hx, 10'd18, s0_hund, 2'd0)) ||
    (s0_show_t && hud_mark(pix_x_d, pix_y_d, s0_tx, 10'd18, s0_tens, 2'd0)) ||
    hud_mark(pix_x_d, pix_y_d, s0_ox, 10'd18, s0_ones, 2'd0) ||
    (score1[9] && hud_mark(pix_x_d, pix_y_d, s1_minus_x, 10'd18, 4'd0, 2'd1)) ||
    (s1_show_h && hud_mark(pix_x_d, pix_y_d, s1_hx, 10'd18, s1_hund, 2'd0)) ||
    (s1_show_t && hud_mark(pix_x_d, pix_y_d, s1_tx, 10'd18, s1_tens, 2'd0)) ||
    hud_mark(pix_x_d, pix_y_d, s1_ox, 10'd18, s1_ones, 2'd0);
wire lives0_hit =
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
wire fuel_hit = fuel_gauge(pix_x_d, pix_y_d, fuel_fill_h);
wire go_flash = (frame_cnt < 6'd13) ||
                ((frame_cnt >= 6'd25) && (frame_cnt < 6'd38));
wire go_hit   = game_over && go_flash && game_over_text(pix_x_d, pix_y_d);

always @(posedge clk) begin
    if (in_fb_d && go_hit) begin
        pix_r <= 5'h1F; pix_g <= 6'h00; pix_b <= 5'h00;
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
    end else if (in_fb_d && (rdata != COL_OFF)) begin
        if (rdata == COL_PL) begin
            pix_r <= 5'h00; pix_g <= 6'h3F; pix_b <= 5'h00; // Enterprise green
        end else if (rdata == COL_AI) begin
            pix_r <= 5'h1F; pix_g <= 6'h3F; pix_b <= 5'h00; // AI bright yellow
        end else begin
            pix_r <= 5'h1F; pix_g <= 6'h3F; pix_b <= 5'h1F; // shots white
        end
    end else if (in_fb_d && timer_hit) begin
        if (timer_sec < 14'd10) begin
            pix_r <= 5'h19; pix_g <= 6'h00; pix_b <= 5'h00;
        end else if (timer_sec < 14'd30) begin
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

endmodule
