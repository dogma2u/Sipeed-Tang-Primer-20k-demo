// Space Wars physics: IDLE / PHYS / NEXT. Snapshot outputs for draw.
// Shot bank: 0..4 = player mag, 5..7 = AI. sin_cos is external.

module sw_physics(
    input  wire               clk,
    input  wire               rst_n,
    input  wire               frame_start,
    input  wire               draw_done,
    input  wire               draw_busy,
    input  wire               btn_left_n,
    input  wire               btn_right_n,
    input  wire               btn_thrust_n,
    input  wire               btn_fire_n,
    input  wire               btn_hyper_n,
    input  wire signed [15:0] sin_a,
    input  wire signed [15:0] cos_a,
    output reg                sc_sel,
    output reg                draw_go,
    output wire               busy,
    output reg signed [23:0]  pos0_x,
    output reg signed [23:0]  pos0_y,
    output reg signed [23:0]  pos1_x,
    output reg signed [23:0]  pos1_y,
    output reg        [7:0]   ang0,
    output reg        [7:0]   ang1,
    output reg                thrusting0,
    output reg                thrusting1,
    output wire       [7:0]   shot_on,
    output wire       [191:0] shot_x,
    output wire       [191:0] shot_y,
    output wire       [127:0] shot_vx,
    output wire       [127:0] shot_vy,
    output wire       [47:0]  shot_life,
    // Boom retired -- ports kept for glue; always 0
    output wire       [4:0]   boom0,
    output wire       [4:0]   boom1,
    output wire signed [15:0] boom0_x,
    output wire signed [15:0] boom0_y,
    output wire signed [15:0] boom_x,
    output wire signed [15:0] boom_y,
    output wire               boom0_dirty,
    output wire               boom_dirty,
    input  wire               clr_boom0_dirty,
    input  wire               clr_boom1_dirty,
    output reg signed [10:0]  score0,
    output reg signed [10:0]  score1,
    output reg                game_over,
    output reg                await_start,
    output reg        [13:0]  timer_sec,
    output reg        [5:0]   frame_cnt,
    output reg        [2:0]   lives0,
    output reg        [14:0]  fuel_ms,
    output reg                black_hole,
    output wire               border_red,
    output wire               pl_flash_red,
    output wire               pl_hs_flash
);

// Gameplay knobs: `include "sw_config.vh" (also listed in tang20k_lcd.gprj FileList).
`include "sw_config.vh"

localparam integer FB_W   = `CFG_FB_W;
localparam integer FB_H   = `CFG_FB_H;
localparam integer FB_SZ  = FB_W * FB_H;
localparam integer SUN_X  = `CFG_SUN_X;
localparam integer SUN_Y  = `CFG_SUN_Y;
localparam integer SUN_R  = `CFG_SUN_R;
localparam integer SUN_HITS_BH = `CFG_SUN_HITS_BH;
localparam integer BH_HITS_SUN = `CFG_BH_HITS_SUN;
localparam integer MARGIN   = `CFG_MARGIN;
localparam integer NSHOT    = `CFG_NSHOT;
localparam integer NSHOT_PL = `CFG_NSHOT_PL;
localparam integer BUL_LIFE = `CFG_PL_BUL_LIFE;
localparam integer FRAMES_PER_SEC = `CFG_FRAMES_PER_SEC;
localparam integer TIMER_START    = `CFG_TIMER_START;
localparam integer TIMER_BONUS    = `CFG_TIMER_BONUS;
localparam integer TIMER_MAX      = `CFG_TIMER_MAX;
localparam integer LIFE_MAX       = `CFG_LIFE_MAX;
localparam integer KILL_FOR_LIFE  = `CFG_KILL_FOR_LIFE;
localparam integer FUEL_MAX_MS    = `CFG_FUEL_MAX_MS;
localparam integer FUEL_FRAME_MS  = `CFG_FUEL_FRAME_MS;
localparam integer PLAY_MAX_SEC   = `CFG_PLAY_MAX_SEC;
localparam integer SHOT_SPD_PX    = `CFG_SHOT_SPD_PX;
localparam integer USER_RANGE     = SHOT_SPD_PX * BUL_LIFE;
localparam integer AI_RANGE_NUM   = `CFG_AI_RANGE_NUM;
localparam integer AI_RANGE_DEN   = `CFG_AI_RANGE_DEN;
localparam integer AI_LIFE_CAP    = (USER_RANGE * AI_RANGE_NUM) / (AI_RANGE_DEN * SHOT_SPD_PX);
localparam integer DEMO_TIMER     = `CFG_DEMO_TIMER;
localparam integer SPAWN_INVULN_FR = `CFG_SPAWN_INVULN_FR;
localparam integer AI_VANISH_FR   = `CFG_AI_VANISH_FR;
localparam integer HS_VANISH_FR   = `CFG_HS_VANISH_FR;
localparam integer HS_FLASH_FR    = `CFG_HS_FLASH_FR;
localparam integer AI_RELOAD_POOR_EXTRA = `CFG_AI_RELOAD_POOR_EXTRA;
localparam integer AI_GAP_POOR_EXTRA    = `CFG_AI_GAP_POOR_EXTRA;
localparam integer AI_AIM_FIRE_MIN_PCT  = `CFG_AI_AIM_FIRE_MIN_PCT;
localparam integer FIRE_GAP_FR    = `CFG_FIRE_GAP_FR;
localparam integer FIRE_RELOAD_FR = `CFG_FIRE_RELOAD_FR;
localparam integer FIRE_MAG_MAX   = `CFG_FIRE_MAG_MAX;
localparam signed [10:0] SCORE_LO = `CFG_SCORE_LO;
localparam signed [10:0] SCORE_HI = `CFG_SCORE_HI;
localparam signed [15:0] SUN_XS = `CFG_SUN_X;
localparam signed [15:0] SUN_YS = `CFG_SUN_Y;
localparam signed [15:0] WALL_KEEP_S = `CFG_WALL_KEEP;
localparam signed [15:0] SUN_HIT_S  = `CFG_SUN_HIT_M;
localparam signed [15:0] SUN_NEAR_S = `CFG_SUN_NEAR_M;
localparam signed [15:0] FB_W_S = `CFG_FB_W;
localparam signed [15:0] FB_H_S = `CFG_FB_H;
localparam integer AI_CD_INIT     = `CFG_AI_CD_INIT;
localparam integer LIFE_START     = `CFG_LIFE_START;
localparam integer PL_THRUST      = `CFG_PL_THRUST;
localparam integer AI_WILD_SEC    = `CFG_AI_WILD_SEC;
localparam integer AI_BP_LIFE_0   = `CFG_AI_BP_LIFE_0;
localparam integer AI_BP_LIFE_1   = `CFG_AI_BP_LIFE_1;
localparam integer AI_LIFE_0      = `CFG_AI_LIFE_0;
localparam integer AI_LIFE_1      = `CFG_AI_LIFE_1;
localparam integer AI_BP_SO_0     = `CFG_AI_BP_SO_0;
localparam integer AI_BP_SO_1     = `CFG_AI_BP_SO_1;
localparam integer AI_BP_SO_2     = `CFG_AI_BP_SO_2;
localparam integer AI_SO_0        = `CFG_AI_SO_0;
localparam integer AI_SO_1        = `CFG_AI_SO_1;
localparam integer AI_SO_2        = `CFG_AI_SO_2;
localparam integer AI_SO_3        = `CFG_AI_SO_3;
localparam integer AI_BP_AIM_0    = `CFG_AI_BP_AIM_0;
localparam integer AI_BP_AIM_1    = `CFG_AI_BP_AIM_1;
localparam integer AI_BP_AIM_2    = `CFG_AI_BP_AIM_2;
localparam integer AI_BP_AIM_3    = `CFG_AI_BP_AIM_3;
localparam integer AI_AIM_0       = `CFG_AI_AIM_0;
localparam integer AI_AIM_1       = `CFG_AI_AIM_1;
localparam integer AI_AIM_2       = `CFG_AI_AIM_2;
localparam integer AI_AIM_3       = `CFG_AI_AIM_3;
localparam integer AI_AIM_4       = `CFG_AI_AIM_4;
localparam integer AI_BP_THR_0    = `CFG_AI_BP_THR_0;
localparam integer AI_BP_THR_1    = `CFG_AI_BP_THR_1;
localparam integer AI_BP_THR_2    = `CFG_AI_BP_THR_2;
localparam integer AI_THR_0       = `CFG_AI_THR_0;
localparam integer AI_THR_1       = `CFG_AI_THR_1;
localparam integer AI_THR_2       = `CFG_AI_THR_2;
localparam integer AI_THR_3       = `CFG_AI_THR_3;
localparam integer SHIP_MAXV      = `CFG_SHIP_MAXV;
localparam integer DEMO_THR_NUM   = `CFG_DEMO_THR_NUM;
localparam integer DEMO_THR_DEN   = `CFG_DEMO_THR_DEN;
// Attract: full top thrust * NUM/DEN (not playtime ramp)
localparam signed [15:0] DEMO_THRUST = (AI_THR_3 * DEMO_THR_NUM) / DEMO_THR_DEN;
localparam signed [15:0] SHIP_MAXV_Q88 = SHIP_MAXV <<< 8;

localparam [1:0] COL_OFF  = 2'b00;
localparam [1:0] COL_PL   = 2'b01;
localparam [1:0] COL_AI   = 2'b10;
localparam [1:0] COL_SHOT = 2'b11;

function signed [15:0] mul_q88;
    input signed [15:0] a, b;
    reg signed [31:0] p;
    begin
        p = a * b;
        mul_q88 = $signed(p[23:8]);
    end
endfunction

function signed [15:0] grav_acc;
    input signed [15:0] dcomp;
    input signed [15:0] gdx;
    input signed [15:0] gdy;
    input               invert;
    reg signed [31:0] r2v;
    reg signed [31:0] num;
    reg signed [31:0] q;
    begin
        r2v = (gdx * gdx) + (gdy * gdy);
        if (r2v < 32'sd256)
            r2v = 32'sd256;
        // Pass B: softer pull (was 768 / clamp 48) -- fewer DSP hot paths at limit
        num = dcomp * 32'sd384;
        q   = num / r2v;
        if (q > 32'sd24)
            q = 32'sd24;
        else if (q < -32'sd24)
            q = -32'sd24;
        grav_acc = invert ? -$signed(q[15:0]) : q[15:0];
    end
endfunction

// Homebrew-style seek: 4-way desired nose, shortest turn (no cross/DSP)
function [7:0] want_facing;
    input signed [15:0] tx, ty; // vector to target
    reg [15:0] ax, ay;
    begin
        ax = tx[15] ? -tx : tx;
        ay = ty[15] ? -ty : ty;
        if (ax >= ay)
            want_facing = tx[15] ? 8'd128 : 8'd0;   // left / right
        else
            want_facing = ty[15] ? 8'd192 : 8'd64;  // up / down (Y grows down)
    end
endfunction

function facing_ok;
    input [7:0] ang, want;
    reg   [7:0] d;
    begin
        d = want - ang;
        facing_ok = (d <= 8'd48) || (d >= 8'd208); // within ~48/256 turn
    end
endfunction

function [7:0] turn_step;
    input [7:0] ang, want;
    input [7:0] step;
    reg   [7:0] cw;
    begin
        cw = want - ang;
        if (cw == 8'd0)
            turn_step = ang;
        else if (cw <= 8'd128)
            turn_step = ang + step;
        else
            turn_step = ang - step;
    end
endfunction

// Per-axis speed limit (Q8.8)
function signed [15:0] clamp_vel;
    input signed [15:0] v;
    input signed [15:0] lim;
    begin
        if (v > lim)
            clamp_vel = lim;
        else if (v < -lim)
            clamp_vel = -lim;
        else
            clamp_vel = v;
    end
endfunction

function sun_hit_m;
    input signed [15:0] px, py;
    reg [15:0] ax, ay;
    begin
        ax = (px > SUN_XS) ? (px - SUN_XS) : (SUN_XS - px);
        ay = (py > SUN_YS) ? (py - SUN_YS) : (SUN_YS - py);
        sun_hit_m = ((ax + ay) < SUN_HIT_S);
    end
endfunction

// Soft keep-out around sun/BH (same center)
function sun_near_m;
    input signed [15:0] px, py;
    reg [15:0] ax, ay;
    begin
        ax = (px > SUN_XS) ? (px - SUN_XS) : (SUN_XS - px);
        ay = (py > SUN_YS) ? (py - SUN_YS) : (SUN_YS - py);
        sun_near_m = ((ax + ay) < SUN_NEAR_S);
    end
endfunction

// Soft keep-out near playfield walls (inside MARGIN bounce)
function wall_near_m;
    input signed [15:0] px, py;
    begin
        wall_near_m = (px < WALL_KEEP_S) ||
                      (px > (FB_W_S - WALL_KEEP_S)) ||
                      (py < WALL_KEEP_S) ||
                      (py > (FB_H_S - WALL_KEEP_S));
    end
endfunction

// True if sun/BH roughly sits between shooter and target (do not fire through)
function shot_thru_sun;
    input signed [15:0] px, py, tx, ty;
    reg [15:0] d_ss, d_st, d_pt, ax, ay;
    begin
        ax = (px > SUN_XS) ? (px - SUN_XS) : (SUN_XS - px);
        ay = (py > SUN_YS) ? (py - SUN_YS) : (SUN_YS - py);
        d_ss = ax + ay;
        ax = (tx > SUN_XS) ? (tx - SUN_XS) : (SUN_XS - tx);
        ay = (ty > SUN_YS) ? (ty - SUN_YS) : (SUN_YS - ty);
        d_st = ax + ay;
        ax = (tx > px) ? (tx - px) : (px - tx);
        ay = (ty > py) ? (ty - py) : (py - ty);
        d_pt = ax + ay;
        shot_thru_sun = (d_ss > 16'd24) && ((d_ss + d_st) <= (d_pt + 16'd48));
    end
endfunction

// AI playtime ramps: step tables only (no combo /100 or lerp divides -- PnR)
// play_sec breakpoints: 0 / 45 / 90 / 150 / 300

localparam [1:0] ST_IDLE = 2'd0;
localparam [1:0] ST_PHYS = 2'd1;
localparam [1:0] ST_NEXT = 2'd2;

reg [1:0] state;
reg [2:0] phys_phase;
reg [3:0] ei;
reg       draw_pending;

reg signed [15:0] vel0_x, vel0_y, vel1_x, vel1_y;
reg signed [15:0] dx, dy;

reg               fire_hold;   // edge-latched single press
reg               fire_prev;
reg        [4:0]  fire_cd;     // gap between shots
reg        [4:0]  fire_reload; // post-mag reload
reg        [2:0]  fire_mag;    // 0..5 shots in current burst
reg        [4:0]  ai_cd;
reg        [4:0]  ai_reload;
reg        [2:0]  ai_mag;
reg        [7:0]  lfsr;
reg        [4:0]  ai_pulse;
reg        [8:0]  play_sec;
reg               ship_lock;
reg        [2:0]  ai_streak;
reg        [3:0]  sun_hits;
reg        [2:0]  bh_hits;
reg               crash_sun0; // player ship into sun/BH this cycle
reg               crash_sun1; // AI ship into sun/BH this cycle
reg               anti_grav;
reg        [2:0]  hit_si;     // sequential shot hit index (Pass B)
reg               hit_ai_r, hit_pl_r, sun_p_r, sun_e_r;
reg        [6:0]  spawn0_fr;  // player spawn invuln countdown
reg        [6:0]  spawn1_fr;  // AI spawn invuln countdown
reg        [4:0]  ai_vanish_fr; // AI park (no boom): sun or kill
reg        [4:0]  pl_vanish_fr; // Diamond park (no boom): sun or kill
reg        [1:0]  hs_phase;     // 0 idle, 1 vanish, 2 flash
reg        [6:0]  hs_fr;
reg               hs_red;
reg               hyper_prev;

// Internal unified shot bank (packed to ports combinationally)
reg               shot_on_i   [0:7];
reg signed [23:0] shot_x_i    [0:7];
reg signed [23:0] shot_y_i    [0:7];
reg signed [15:0] shot_vx_i   [0:7];
reg signed [15:0] shot_vy_i   [0:7];
reg        [5:0]  shot_life_i [0:7];

assign border_red = black_hole;
assign busy = (state != ST_IDLE) || draw_pending;
assign boom0 = 5'd0;
assign boom1 = 5'd0;
assign boom0_x = 16'sd0;
assign boom0_y = 16'sd0;
assign boom_x = 16'sd0;
assign boom_y = 16'sd0;
assign boom0_dirty = 1'b0;
assign boom_dirty = 1'b0;
assign shot_on = {shot_on_i[7], shot_on_i[6], shot_on_i[5], shot_on_i[4],
                  shot_on_i[3], shot_on_i[2], shot_on_i[1], shot_on_i[0]};
assign shot_x = {shot_x_i[7], shot_x_i[6], shot_x_i[5], shot_x_i[4],
                 shot_x_i[3], shot_x_i[2], shot_x_i[1], shot_x_i[0]};
assign shot_y = {shot_y_i[7], shot_y_i[6], shot_y_i[5], shot_y_i[4],
                 shot_y_i[3], shot_y_i[2], shot_y_i[1], shot_y_i[0]};
assign shot_vx = {shot_vx_i[7], shot_vx_i[6], shot_vx_i[5], shot_vx_i[4],
                  shot_vx_i[3], shot_vx_i[2], shot_vx_i[1], shot_vx_i[0]};
assign shot_vy = {shot_vy_i[7], shot_vy_i[6], shot_vy_i[5], shot_vy_i[4],
                  shot_vy_i[3], shot_vy_i[2], shot_vy_i[1], shot_vy_i[0]};
assign shot_life = {shot_life_i[7], shot_life_i[6], shot_life_i[5], shot_life_i[4],
                    shot_life_i[3], shot_life_i[2], shot_life_i[1], shot_life_i[0]};

wire left_p   = ~btn_left_n;
wire right_p  = ~btn_right_n;
wire thrust_p = ~btn_thrust_n;
wire fire_p   = ~btn_fire_n;
wire hyper_p  = ~btn_hyper_n;
wire               demo_mode = game_over || await_start;

// Registered once per frame (FF, not combo trees) -- cuts LUT fanout
reg        [8:0]  play_cap_r;
reg               ai_wild;
reg        [5:0]  ai_life_n;
reg        [9:0]  ai_standoff;
reg        [7:0]  aim_pct;
reg signed [15:0] ai_thrust;
reg        [4:0]  ai_dec;
reg               demo_mode_r;
reg               pl_invuln_r;
reg               ai_invuln_r;
reg               sun_near0_r;
reg               sun_near1_r;
reg               wall_near0_r;
reg               wall_near1_r;

wire               pl_invuln = pl_invuln_r;
wire               ai_invuln = ai_invuln_r;
// Pass B: demo fire on even frames only; steer runs every frame (full turn rate)
wire               demo_ai_tick = !demo_mode_r || !frame_cnt[0];
assign pl_hs_flash  = (hs_phase == 2'd2);
assign pl_flash_red = pl_hs_flash && hs_red;

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

task respawn;
    input kind;
    begin
        // Random anywhere in playfield (incl. sun/BH). Vel always 0.
        if (!kind) begin
            pos0_x  <= {6'd0, (10'd40 + {1'b0, lfsr, 1'b0}), 8'd0}; // ~40..550
            pos0_y  <= {6'd0, (10'd40 + {2'b0, lfsr[6:0], 1'b0}), 8'd0}; // ~40..294
            vel0_x  <= 16'sd0;
            vel0_y  <= 16'sd0;
            ang0    <= lfsr;
            fuel_ms <= FUEL_MAX_MS[14:0];
            spawn0_fr <= SPAWN_INVULN_FR[6:0];
            pl_vanish_fr <= 5'd0;
        end else begin
            pos1_x <= {6'd0, (10'd80 + {1'b0, lfsr[7:0], 1'b0}), 8'd0};
            pos1_y <= {6'd0, (10'd60 + {2'b0, lfsr[6:0], 1'b0}), 8'd0};
            vel1_x <= 16'sd0;
            vel1_y <= 16'sd0;
            ang1   <= lfsr ^ 8'h55;
            spawn1_fr <= SPAWN_INVULN_FR[6:0];
            ai_vanish_fr <= 5'd0;
        end
    end
endtask

// Score +1 with wrap 999 -> 0
task score_bump0;
    begin
        if (score0 >= SCORE_HI)
            score0 <= 11'sd0;
        else
            score0 <= score0 + 11'sd1;
    end
endtask

task score_bump1;
    begin
        if (score1 >= SCORE_HI)
            score1 <= 11'sd0;
        else
            score1 <= score1 + 11'sd1;
    end
endtask

integer si;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state        <= ST_IDLE;
        phys_phase   <= 3'd0;
        ei           <= 4'd0;
        draw_go      <= 1'b0;
        draw_pending <= 1'b0;
        sc_sel       <= 1'b0;
        thrusting0   <= 1'b0;
        thrusting1   <= 1'b0;
        fire_hold    <= 1'b0;
        fire_prev    <= 1'b0;
        fire_cd      <= 5'd0;
        fire_reload  <= 5'd0;
        fire_mag     <= 3'd0;
        ai_cd        <= AI_CD_INIT[4:0];
        ai_reload    <= 5'd0;
        ai_mag       <= 3'd0;
        lfsr         <= 8'hA5;
        ai_pulse     <= 5'd0;
        play_sec     <= 9'd0;
        score0       <= 11'sd0;
        score1       <= 11'sd0;
        ship_lock    <= 1'b0;
        game_over    <= 1'b0;
        await_start  <= 1'b1;
        timer_sec    <= DEMO_TIMER[13:0];
        frame_cnt    <= 6'd0;
        lives0       <= LIFE_MAX[2:0];
        ai_streak    <= 3'd0;
        fuel_ms      <= FUEL_MAX_MS[14:0];
        sun_hits     <= 4'd0;
        bh_hits      <= 3'd0;
        crash_sun0   <= 1'b0;
        crash_sun1   <= 1'b0;
        black_hole   <= 1'b0;
        anti_grav    <= 1'b0;
        hit_si       <= 3'd0;
        hit_ai_r     <= 1'b0;
        hit_pl_r     <= 1'b0;
        sun_p_r      <= 1'b0;
        sun_e_r      <= 1'b0;
        spawn0_fr    <= 7'd0;
        spawn1_fr    <= 7'd0;
        ai_vanish_fr <= 5'd0;
        pl_vanish_fr <= 5'd0;
        hs_phase     <= 2'd0;
        hs_fr        <= 7'd0;
        hs_red       <= 1'b0;
        hyper_prev   <= 1'b0;
        play_cap_r   <= 9'd0;
        ai_wild      <= 1'b0;
        ai_life_n    <= AI_LIFE_0[5:0];
        ai_standoff  <= AI_SO_0[9:0];
        aim_pct      <= AI_AIM_0[7:0];
        ai_thrust    <= AI_THR_0[15:0];
        ai_dec       <= 5'd0;
        demo_mode_r  <= 1'b1;
        pl_invuln_r  <= 1'b1;
        ai_invuln_r  <= 1'b1;
        sun_near0_r  <= 1'b0;
        sun_near1_r  <= 1'b0;
        wall_near0_r <= 1'b0;
        wall_near1_r <= 1'b0;
        dx           <= 16'sd0;
        dy           <= 16'sd0;
        for (si = 0; si < 8; si = si + 1) begin
            shot_on_i[si]   <= 1'b0;
            shot_x_i[si]    <= 24'sd0;
            shot_y_i[si]    <= 24'sd0;
            shot_vx_i[si]   <= 16'sd0;
            shot_vy_i[si]   <= 16'sd0;
            shot_life_i[si] <= 6'd0;
        end
        respawn(1'b0);
        respawn(1'b1);
    end else begin
        // clr_boom* ignored (boom ports tied off)
        if (draw_done)
            draw_pending <= 1'b0;
        // Level draw_go while pending and draw idle (retries if pulse was missed)
        draw_go <= draw_pending & ~draw_busy;

        hyper_prev <= hyper_p;

        // Fire to start (boot or GAME OVER) -- only when draw idle (no mid-pass mutate)
        if (demo_mode && fire_p && !fire_prev && !draw_pending && !draw_busy) begin
            state        <= ST_IDLE;
            phys_phase   <= 3'd0;
            ei           <= 4'd0;
            draw_pending <= 1'b1;
            sc_sel       <= 1'b0;
            thrusting0   <= 1'b0;
            thrusting1   <= 1'b0;
            fire_hold    <= 1'b0;
            fire_cd      <= 5'd0;
            fire_reload  <= 5'd0;
            fire_mag     <= 3'd0;
            ai_cd        <= AI_CD_INIT[4:0];
            ai_reload    <= 5'd0;
            ai_mag       <= 3'd0;
            play_sec     <= 9'd0;
            score0       <= 11'sd0;
            score1       <= 11'sd0;
            ship_lock    <= 1'b0;
            game_over    <= 1'b0;
            await_start  <= 1'b0;
            timer_sec    <= TIMER_START[13:0];
            frame_cnt    <= 6'd0;
            lives0       <= LIFE_START[2:0];
            ai_streak    <= 3'd0;
            fuel_ms      <= FUEL_MAX_MS[14:0];
            sun_hits     <= 4'd0;
            bh_hits      <= 3'd0;
            crash_sun0   <= 1'b0;
            crash_sun1   <= 1'b0;
            black_hole   <= 1'b0;
            anti_grav    <= 1'b0;
            for (si = 0; si < 8; si = si + 1) begin
                shot_on_i[si]   <= 1'b0;
                shot_life_i[si] <= 6'd0;
            end
            pos0_x  <= 24'sd140 <<< 8;
            pos0_y  <= 24'sd160 <<< 8;
            vel0_x  <= 16'sd0;
            vel0_y  <= 16'sd0;
            ang0    <= 8'd192;
            pos1_x  <= 24'sd660 <<< 8;
            pos1_y  <= 24'sd320 <<< 8;
            vel1_x  <= 16'sd0;
            vel1_y  <= 16'sd0;
            ang1    <= 8'd64;
            spawn0_fr    <= SPAWN_INVULN_FR[6:0];
            spawn1_fr    <= SPAWN_INVULN_FR[6:0];
            ai_vanish_fr <= 5'd0;
            pl_vanish_fr <= 5'd0;
            hs_phase     <= 2'd0;
            hs_fr        <= 7'd0;
            hs_red       <= 1'b0;
        end

        // S0 hyperspace edge (match only; not during death vanish)
        if (!demo_mode && hyper_p && !hyper_prev &&
            (hs_phase == 2'd0) && (pl_vanish_fr == 5'd0)) begin
            hs_phase   <= 2'd1;
            hs_fr      <= HS_VANISH_FR[6:0];
            thrusting0 <= 1'b0;
            vel0_x     <= 16'sd0;
            vel0_y     <= 16'sd0;
            pos0_x     <= -(24'sd80 <<< 8);
            pos0_y     <= -(24'sd80 <<< 8);
        end

        // Rising edge -> one shot; hold keeps auto-fire via fire_p
        if (fire_p && !fire_prev && !demo_mode)
            fire_hold <= 1'b1;
        fire_prev <= fire_p;

        case (state)
            ST_IDLE: begin
                if (frame_start && !draw_pending) begin
                    if (frame_cnt == (FRAMES_PER_SEC[5:0] - 6'd1)) begin
                        frame_cnt <= 6'd0;
                        if (demo_mode) begin
                            if (timer_sec == 14'd0)
                                timer_sec <= DEMO_TIMER[13:0];
                            else
                                timer_sec <= timer_sec - 14'd1;
                            fuel_ms <= FUEL_MAX_MS[14:0];
                            lives0  <= LIFE_MAX[2:0];
                            if (play_sec < PLAY_MAX_SEC[8:0])
                                play_sec <= play_sec + 9'd1;
                            // Demo auto-HS off (vanish/warp + turn was flooding FB)
                        end else begin
                            if (timer_sec == 14'd0) begin
                                game_over <= 1'b1;
                                timer_sec <= DEMO_TIMER[13:0]; // demo wrap / start at 99:99
                            end else
                                timer_sec <= timer_sec - 14'd1;
                            if (play_sec < PLAY_MAX_SEC[8:0])
                                play_sec <= play_sec + 9'd1;
                        end
                    end else
                        frame_cnt <= frame_cnt + 6'd1;
                    // Latch AI ramps + keep-out + invuln once/frame (FF, not combo)
                    begin : ai_ramp_latch
                        reg [8:0] pc;
                        reg [5:0] life_raw;
                        pc = (play_sec > PLAY_MAX_SEC[8:0]) ? PLAY_MAX_SEC[8:0] : play_sec;
                        play_cap_r <= pc;
                        ai_wild    <= (play_sec >= AI_WILD_SEC[8:0]);
                        ai_dec     <= pc[8:4];
                        life_raw = (pc < AI_BP_LIFE_0[8:0]) ? AI_LIFE_0[5:0] :
                                   (pc < AI_BP_LIFE_1[8:0]) ? AI_LIFE_1[5:0] :
                                   AI_LIFE_CAP[5:0];
                        ai_life_n <= (life_raw > AI_LIFE_CAP[5:0]) ?
                                     AI_LIFE_CAP[5:0] : life_raw;
                        ai_standoff <= (pc < AI_BP_SO_0[8:0]) ? AI_SO_0[9:0] :
                                      (pc < AI_BP_SO_1[8:0]) ? AI_SO_1[9:0] :
                                      (pc < AI_BP_SO_2[8:0]) ? AI_SO_2[9:0] :
                                      AI_SO_3[9:0];
                        aim_pct <= (pc < AI_BP_AIM_0[8:0]) ? AI_AIM_0[7:0] :
                                   (pc < AI_BP_AIM_1[8:0]) ? AI_AIM_1[7:0] :
                                   (pc < AI_BP_AIM_2[8:0]) ? AI_AIM_2[7:0] :
                                   (pc < AI_BP_AIM_3[8:0]) ? AI_AIM_3[7:0] :
                                   AI_AIM_4[7:0];
                        ai_thrust <= (pc < AI_BP_THR_0[8:0]) ? AI_THR_0[15:0] :
                                     (pc < AI_BP_THR_1[8:0]) ? AI_THR_1[15:0] :
                                     (pc < AI_BP_THR_2[8:0]) ? AI_THR_2[15:0] :
                                     AI_THR_3[15:0];
                        demo_mode_r  <= demo_mode;
                        pl_invuln_r  <= (spawn0_fr != 7'd0) || (pl_vanish_fr != 5'd0) ||
                                        (hs_phase != 2'd0);
                        ai_invuln_r  <= (spawn1_fr != 7'd0) || (ai_vanish_fr != 5'd0);
                        sun_near0_r  <= sun_near_m($signed(pos0_x[23:8]), $signed(pos0_y[23:8]));
                        sun_near1_r  <= sun_near_m($signed(pos1_x[23:8]), $signed(pos1_y[23:8]));
                        wall_near0_r <= wall_near_m($signed(pos0_x[23:8]), $signed(pos0_y[23:8]));
                        wall_near1_r <= wall_near_m($signed(pos1_x[23:8]), $signed(pos1_y[23:8]));
                    end
                    // Spawn invuln + vanish + hyperspace timers (1x per frame)
                    if (spawn0_fr != 7'd0)
                        spawn0_fr <= spawn0_fr - 7'd1;
                    if (spawn1_fr != 7'd0)
                        spawn1_fr <= spawn1_fr - 7'd1;
                    if (ai_vanish_fr == 5'd1) begin
                        respawn(1'b1);
                        ai_vanish_fr <= 5'd0;
                    end else if (ai_vanish_fr != 5'd0)
                        ai_vanish_fr <= ai_vanish_fr - 5'd1;
                    if (pl_vanish_fr == 5'd1) begin
                        if (demo_mode || (lives0 != 3'd0))
                            respawn(1'b0);
                        pl_vanish_fr <= 5'd0;
                    end else if (pl_vanish_fr != 5'd0)
                        pl_vanish_fr <= pl_vanish_fr - 5'd1;
                    // Hyperspace: vanish -> random warp -> flash invuln
                    if (hs_phase == 2'd1) begin
                        pos0_x <= -(24'sd80 <<< 8);
                        pos0_y <= -(24'sd80 <<< 8);
                        if (hs_fr == 7'd1) begin
                            respawn(1'b0);
                            hs_phase <= 2'd2;
                            hs_fr    <= HS_FLASH_FR[6:0];
                            hs_red   <= 1'b1;
                        end else if (hs_fr != 7'd0)
                            hs_fr <= hs_fr - 7'd1;
                    end else if (hs_phase == 2'd2) begin
                        if (hs_fr == 7'd1) begin
                            hs_phase <= 2'd0;
                            hs_fr    <= 7'd0;
                            hs_red   <= 1'b0;
                        end else begin
                            if (hs_fr != 7'd0)
                                hs_fr <= hs_fr - 7'd1;
                            // 10 Hz toggle @ 50 fps => every 5 frames
                            if (frame_cnt[2:0] == 3'd0)
                                hs_red <= ~hs_red;
                        end
                    end
                    phys_phase <= 3'd0;
                    state <= ST_PHYS;
                end
            end

            ST_PHYS: begin
                case (phys_phase)
                    3'd0: begin
                        if ((pl_vanish_fr != 5'd0) || (hs_phase == 2'd1)) begin
                            thrusting0 <= 1'b0;
                        end else if (demo_mode) begin
                            // Attract: full player turn rate (4) every frame; wall > sun > hunt
                            begin : demo_pl_steer
                                reg signed [15:0] tdx, tdy, adx, ady, fx, fy;
                                reg [7:0] want;
                                fx = SUN_XS - $signed(pos0_x[23:8]);
                                fy = SUN_YS - $signed(pos0_y[23:8]);
                                if (wall_near0_r) begin
                                    want = want_facing(fx, fy); // toward center
                                    ang0 <= turn_step(ang0, want, 8'd4);
                                    thrusting0 <= 1'b1;
                                end else if (sun_near0_r) begin
                                    want = want_facing(-fx, -fy); // away from sun/BH
                                    ang0 <= turn_step(ang0, want, 8'd4);
                                    thrusting0 <= 1'b1;
                                end else begin
                                    tdx = $signed(pos1_x[23:8]) - $signed(pos0_x[23:8]);
                                    tdy = $signed(pos1_y[23:8]) - $signed(pos0_y[23:8]);
                                    adx = tdx[15] ? -tdx : tdx;
                                    ady = tdy[15] ? -tdy : tdy;
                                    want = want_facing(tdx, tdy);
                                    ang0 <= turn_step(ang0, want, 8'd4);
                                    thrusting0 <= (facing_ok(ang0, want) ||
                                                   ((adx + ady) > 16'sd400)) &&
                                                  ((adx + ady) > $signed({6'b0, ai_standoff}));
                                end
                            end
                            fuel_ms <= FUEL_MAX_MS[14:0];
                        end else begin
                            if (left_p)  ang0 <= ang0 - 8'd4;
                            if (right_p) ang0 <= ang0 + 8'd4;
                            if (thrust_p && (fuel_ms != 15'd0) && (pl_vanish_fr == 5'd0)) begin
                                thrusting0 <= 1'b1;
                                if (fuel_ms > FUEL_FRAME_MS[14:0])
                                    fuel_ms <= fuel_ms - FUEL_FRAME_MS[14:0];
                                else
                                    fuel_ms <= 15'd0;
                            end else
                                thrusting0 <= 1'b0;
                        end
                        dx <= $signed(pos0_x[23:8]) - $signed(pos1_x[23:8]);
                        dy <= $signed(pos0_y[23:8]) - $signed(pos1_y[23:8]);
                        lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
                        ai_pulse <= ai_pulse + 5'd1;
                        phys_phase <= 3'd1;
                    end
                    3'd1: begin
                        sc_sel <= 1'b1;
                        phys_phase <= 3'd2;
                    end
                    3'd2: begin
                        // settle sc_sel=1 sin/cos for AI thrust/fire (no cross/dot)
                        phys_phase <= 3'd3;
                    end
                    3'd3: begin
                        if ((ai_vanish_fr == 5'd0)) begin
                            begin : ai_steer
                                reg signed [15:0] adx, ady, fx, fy;
                                reg [7:0] turn, want;
                                // Demo: full turn 4; match: ramped 1..3
                                if (demo_mode_r)
                                    turn = 8'd4;
                                else begin
                                    turn = 8'd1 + {6'b0, ai_dec[4:3]};
                                    if (ai_wild)
                                        turn = 8'd3;
                                end
                                // wall > sun > hunt (demo + match)
                                fx = SUN_XS - $signed(pos1_x[23:8]);
                                fy = SUN_YS - $signed(pos1_y[23:8]);
                                if (demo_mode_r && wall_near1_r) begin
                                    want = want_facing(fx, fy);
                                    ang1 <= turn_step(ang1, want, turn);
                                    thrusting1 <= 1'b1;
                                end else if (sun_near1_r) begin
                                    want = want_facing(-fx, -fy);
                                    ang1 <= turn_step(ang1, want, turn);
                                    thrusting1 <= 1'b1;
                                end else begin
                                    adx = dx[15] ? -dx : dx;
                                    ady = dy[15] ? -dy : dy;
                                    // dx,dy = Diamond - wedge = vector toward player
                                    want = want_facing(dx, dy);
                                    ang1 <= turn_step(ang1, want, turn);
                                    thrusting1 <= (facing_ok(ang1, want) ||
                                                   ((adx + ady) > 16'sd400)) &&
                                                  ((adx + ady) > $signed({6'b0, ai_standoff}));
                                end
                            end
                        end else
                            thrusting1 <= 1'b0;
                        phys_phase <= 3'd4;
                    end
                    3'd4: begin
                        sc_sel <= 1'b0;
                        phys_phase <= 3'd5;
                    end
                    3'd5: begin
                        begin : grav0
                            reg signed [15:0] gdx, gdy, gx, gy;
                            reg signed [15:0] thr, nvx, nvy;
                            gdx = SUN_XS - $signed(pos0_x[23:8]);
                            gdy = SUN_YS - $signed(pos0_y[23:8]);
                            if (black_hole || anti_grav) begin
                                gx = grav_acc(gdx, gdx, gdy, anti_grav);
                                gy = grav_acc(gdy, gdx, gdy, anti_grav);
                            end else begin
                                gx = 16'sd0;
                                gy = 16'sd0;
                            end
                            if (!thrusting0)
                                thr = 16'sd0;
                            else if (demo_mode_r)
                                thr = DEMO_THRUST;
                            else
                                thr = PL_THRUST[15:0];
                            nvx = vel0_x + mul_q88(cos_a, thr) + gx - (vel0_x >>> 8);
                            nvy = vel0_y + mul_q88(sin_a, thr) + gy - (vel0_y >>> 8);
                            if (demo_mode_r) begin
                                nvx = clamp_vel(nvx, SHIP_MAXV_Q88);
                                nvy = clamp_vel(nvy, SHIP_MAXV_Q88);
                            end
                            vel0_x <= nvx;
                            vel0_y <= nvy;
                        end
                        if (fire_reload != 5'd0)
                            fire_reload <= fire_reload - 5'd1;
                        else if (fire_cd != 5'd0)
                            fire_cd <= fire_cd - 5'd1;
                        else if ((pl_vanish_fr == 5'd0) && (ai_vanish_fr == 5'd0) &&
                                 (hs_phase != 2'd1)) begin
                            // Match: player fire. Demo: fire when nose toward wedge
                            begin : pl_fire_gate
                                reg signed [15:0] tdx, tdy;
                                reg               want;
                                want = 1'b0;
                                if (!demo_mode)
                                    want = (fire_hold || fire_p);
                                else begin
                                    tdx = $signed(pos1_x[23:8]) - $signed(pos0_x[23:8]);
                                    tdy = $signed(pos1_y[23:8]) - $signed(pos0_y[23:8]);
                                    want = demo_ai_tick &&
                                           facing_ok(ang0, want_facing(tdx, tdy)) &&
                                           !shot_thru_sun($signed(pos0_x[23:8]),
                                                          $signed(pos0_y[23:8]),
                                                          $signed(pos1_x[23:8]),
                                                          $signed(pos1_y[23:8])) &&
                                           ((aim_pct > AI_AIM_FIRE_MIN_PCT[7:0]) || lfsr[6]);
                                end
                                if (want) begin
                            begin : spawn_shot
                                reg signed [15:0] ox, oy, svx, svy;
                                reg               placed;
                                ox  = mul_q88(cos_a, 16'sd18);
                                oy  = mul_q88(sin_a, 16'sd18);
                                svx = mul_q88(cos_a, 16'sd10 <<< 8) + (vel0_x >>> 1);
                                svy = mul_q88(sin_a, 16'sd10 <<< 8) + (vel0_y >>> 1);
                                placed = 1'b0;
                                // Unrolled -- Gowin often breaks variable-index for-loops
                                if (!shot_on_i[0]) begin
                                    shot_x_i[0] <= pos0_x + {{8{ox[15]}}, ox};
                                    shot_y_i[0] <= pos0_y + {{8{oy[15]}}, oy};
                                    shot_vx_i[0] <= svx; shot_vy_i[0] <= svy;
                                    shot_on_i[0] <= 1'b1; shot_life_i[0] <= BUL_LIFE[5:0];
                                    placed = 1'b1;
                                end else if (!shot_on_i[1]) begin
                                    shot_x_i[1] <= pos0_x + {{8{ox[15]}}, ox};
                                    shot_y_i[1] <= pos0_y + {{8{oy[15]}}, oy};
                                    shot_vx_i[1] <= svx; shot_vy_i[1] <= svy;
                                    shot_on_i[1] <= 1'b1; shot_life_i[1] <= BUL_LIFE[5:0];
                                    placed = 1'b1;
                                end else if (!shot_on_i[2]) begin
                                    shot_x_i[2] <= pos0_x + {{8{ox[15]}}, ox};
                                    shot_y_i[2] <= pos0_y + {{8{oy[15]}}, oy};
                                    shot_vx_i[2] <= svx; shot_vy_i[2] <= svy;
                                    shot_on_i[2] <= 1'b1; shot_life_i[2] <= BUL_LIFE[5:0];
                                    placed = 1'b1;
                                end else if (!shot_on_i[3]) begin
                                    shot_x_i[3] <= pos0_x + {{8{ox[15]}}, ox};
                                    shot_y_i[3] <= pos0_y + {{8{oy[15]}}, oy};
                                    shot_vx_i[3] <= svx; shot_vy_i[3] <= svy;
                                    shot_on_i[3] <= 1'b1; shot_life_i[3] <= BUL_LIFE[5:0];
                                    placed = 1'b1;
                                end else if (!shot_on_i[4]) begin
                                    shot_x_i[4] <= pos0_x + {{8{ox[15]}}, ox};
                                    shot_y_i[4] <= pos0_y + {{8{oy[15]}}, oy};
                                    shot_vx_i[4] <= svx; shot_vy_i[4] <= svy;
                                    shot_on_i[4] <= 1'b1; shot_life_i[4] <= BUL_LIFE[5:0];
                                    placed = 1'b1;
                                end
                                if (placed) begin
                                    fire_hold <= 1'b0;
                                    if (fire_mag >= (FIRE_MAG_MAX[2:0] - 3'd1)) begin
                                        fire_mag    <= 3'd0;
                                        fire_reload <= FIRE_RELOAD_FR[4:0];
                                        fire_cd     <= 5'd0;
                                    end else begin
                                        fire_mag <= fire_mag + 3'd1;
                                        fire_cd  <= FIRE_GAP_FR[4:0];
                                    end
                                end
                            end
                                end
                            end
                        end
                        sc_sel <= 1'b1;
                        phys_phase <= 3'd6;
                    end
                    3'd6: begin
                        begin : grav1
                            reg signed [15:0] gdx, gdy, gx, gy;
                            reg signed [15:0] thr, nvx, nvy;
                            gdx = SUN_XS - $signed(pos1_x[23:8]);
                            gdy = SUN_YS - $signed(pos1_y[23:8]);
                            if (black_hole || anti_grav) begin
                                gx = grav_acc(gdx, gdx, gdy, anti_grav);
                                gy = grav_acc(gdy, gdx, gdy, anti_grav);
                            end else begin
                                gx = 16'sd0;
                                gy = 16'sd0;
                            end
                            if (!thrusting1)
                                thr = 16'sd0;
                            else if (demo_mode_r)
                                thr = DEMO_THRUST;
                            else
                                thr = ai_thrust;
                            nvx = vel1_x + mul_q88(cos_a, thr) + gx - (vel1_x >>> 8);
                            nvy = vel1_y + mul_q88(sin_a, thr) + gy - (vel1_y >>> 8);
                            if (demo_mode_r) begin
                                nvx = clamp_vel(nvx, SHIP_MAXV_Q88);
                                nvy = clamp_vel(nvy, SHIP_MAXV_Q88);
                            end
                            vel1_x <= nvx;
                            vel1_y <= nvy;
                        end
                        if (ai_reload != 5'd0)
                            ai_reload <= ai_reload - 5'd1;
                        else if (ai_cd != 5'd0)
                            ai_cd <= ai_cd - 5'd1;
                        else if ((pl_vanish_fr == 5'd0) && (ai_vanish_fr == 5'd0) &&
                                 demo_ai_tick &&
                                 facing_ok(ang1, want_facing(dx, dy)) &&
                                 !shot_thru_sun($signed(pos1_x[23:8]),
                                                $signed(pos1_y[23:8]),
                                                $signed(pos0_x[23:8]),
                                                $signed(pos0_y[23:8])) &&
                                 ((aim_pct > AI_AIM_FIRE_MIN_PCT[7:0]) || lfsr[6])) begin
                            begin : spawn_eshot
                                reg signed [15:0] ox, oy, svx, svy;
                                reg               placed;
                                ox  = mul_q88(cos_a, 16'sd16);
                                oy  = mul_q88(sin_a, 16'sd16);
                                svx = mul_q88(cos_a, 16'sd10 <<< 8) + (vel1_x >>> 1);
                                svy = mul_q88(sin_a, 16'sd10 <<< 8) + (vel1_y >>> 1);
                                placed = 1'b0;
                                if (!shot_on_i[5]) begin
                                    shot_x_i[5] <= pos1_x + {{8{ox[15]}}, ox};
                                    shot_y_i[5] <= pos1_y + {{8{oy[15]}}, oy};
                                    shot_vx_i[5] <= svx; shot_vy_i[5] <= svy;
                                    shot_on_i[5] <= 1'b1; shot_life_i[5] <= ai_life_n;
                                    placed = 1'b1;
                                end else if (!shot_on_i[6]) begin
                                    shot_x_i[6] <= pos1_x + {{8{ox[15]}}, ox};
                                    shot_y_i[6] <= pos1_y + {{8{oy[15]}}, oy};
                                    shot_vx_i[6] <= svx; shot_vy_i[6] <= svy;
                                    shot_on_i[6] <= 1'b1; shot_life_i[6] <= ai_life_n;
                                    placed = 1'b1;
                                end else if (!shot_on_i[7]) begin
                                    shot_x_i[7] <= pos1_x + {{8{ox[15]}}, ox};
                                    shot_y_i[7] <= pos1_y + {{8{oy[15]}}, oy};
                                    shot_vx_i[7] <= svx; shot_vy_i[7] <= svy;
                                    shot_on_i[7] <= 1'b1; shot_life_i[7] <= ai_life_n;
                                    placed = 1'b1;
                                end
                                if (placed) begin
                                    if (ai_mag >= (FIRE_MAG_MAX[2:0] - 3'd1)) begin
                                        ai_mag    <= 3'd0;
                                        ai_reload <= FIRE_RELOAD_FR[4:0] +
                                                     ((aim_pct < 8'd50) ? AI_RELOAD_POOR_EXTRA[4:0] : 5'd0);
                                        ai_cd     <= 5'd0;
                                    end else begin
                                        ai_mag <= ai_mag + 3'd1;
                                        ai_cd  <= (aim_pct < 8'd50) ?
                                                  (FIRE_GAP_FR[4:0] + AI_GAP_POOR_EXTRA[4:0]) :
                                                  (ai_wild ? 5'd3 : FIRE_GAP_FR[4:0]);
                                    end
                                end
                            end
                        end
                        phys_phase <= 3'd7;
                    end
                    3'd7: begin
                        if ((pl_vanish_fr == 5'd0) && (hs_phase != 2'd1)) begin
                            pos0_x <= pos0_x + {{8{vel0_x[15]}}, vel0_x};
                            pos0_y <= pos0_y + {{8{vel0_y[15]}}, vel0_y};
                        end else begin
                            pos0_x <= -(24'sd80 <<< 8);
                            pos0_y <= -(24'sd80 <<< 8);
                        end
                        if (ai_vanish_fr == 5'd0) begin
                            pos1_x <= pos1_x + {{8{vel1_x[15]}}, vel1_x};
                            pos1_y <= pos1_y + {{8{vel1_y[15]}}, vel1_y};
                        end else begin
                            pos1_x <= -(24'sd80 <<< 8);
                            pos1_y <= -(24'sd80 <<< 8);
                        end
                        phys_phase <= 3'd0;
                        ei <= 4'd0;
                        state <= ST_NEXT;
                    end
                    default: phys_phase <= 3'd0;
                endcase
            end

            ST_NEXT: begin
                if (ei == 4'd0) begin
                    begin : bnc
                        reg signed [23:0] t0x, t0y, t1x, t1y;
                        reg signed [15:0] v0x, v0y, v1x, v1y;
                        if ((pl_vanish_fr == 5'd0) && (hs_phase != 2'd1)) begin
                            t0x = pos0_x; t0y = pos0_y; v0x = vel0_x; v0y = vel0_y;
                            bounce_ship(t0x, t0y, v0x, v0y);
                            pos0_x <= t0x; pos0_y <= t0y; vel0_x <= v0x; vel0_y <= v0y;
                        end
                        if (ai_vanish_fr == 5'd0) begin
                            t1x = pos1_x; t1y = pos1_y; v1x = vel1_x; v1y = vel1_y;
                            bounce_ship(t1x, t1y, v1x, v1y);
                            pos1_x <= t1x; pos1_y <= t1y; vel1_x <= v1x; vel1_y <= v1y;
                        end
                    end
                    dx <= $signed(pos0_x[23:8]) - $signed(pos1_x[23:8]);
                    dy <= $signed(pos0_y[23:8]) - $signed(pos1_y[23:8]);
                    ei <= 4'd1;
                end else if (ei == 4'd1) begin
                    crash_sun0 <= 1'b0;
                    // Diamond sun/BH: vanish only (no boom), then respawn
                    if (sun_hit_m($signed(pos0_x[23:8]), $signed(pos0_y[23:8])) &&
                        (pl_vanish_fr == 5'd0) && !pl_invuln) begin
                        crash_sun0   <= 1'b1;
                        score_bump1;
                        pos0_x       <= -(24'sd80 <<< 8);
                        pos0_y       <= -(24'sd80 <<< 8);
                        vel0_x       <= 16'sd0;
                        vel0_y       <= 16'sd0;
                        thrusting0   <= 1'b0;
                        pl_vanish_fr <= AI_VANISH_FR[4:0];
                        if (!demo_mode && (lives0 != 3'd0)) begin
                            if (lives0 == 3'd1) begin
                                game_over <= 1'b1;
                                timer_sec <= DEMO_TIMER[13:0];
                            end
                            lives0 <= lives0 - 3'd1;
                        end
                    end
                    ei <= 4'd2;
                end else if (ei == 4'd2) begin
                    crash_sun1 <= 1'b0;
                    // AI sun/BH: vanish only (no boom), then respawn after AI_VANISH_FR
                    if (sun_hit_m($signed(pos1_x[23:8]), $signed(pos1_y[23:8])) &&
                        (ai_vanish_fr == 5'd0) && !ai_invuln) begin
                        crash_sun1   <= 1'b1;
                        score_bump0;
                        pos1_x       <= -(24'sd80 <<< 8);
                        pos1_y       <= -(24'sd80 <<< 8);
                        vel1_x       <= 16'sd0;
                        vel1_y       <= 16'sd0;
                        thrusting1   <= 1'b0;
                        ai_vanish_fr <= AI_VANISH_FR[4:0];
                    end
                    ei <= 4'd3;
                end else if (ei == 4'd3) begin
                    for (si = 0; si < 8; si = si + 1) begin
                        if (shot_on_i[si]) begin
                            shot_x_i[si] <= shot_x_i[si] + {{8{shot_vx_i[si][15]}}, shot_vx_i[si]};
                            shot_y_i[si] <= shot_y_i[si] + {{8{shot_vy_i[si][15]}}, shot_vy_i[si]};
                            if (shot_life_i[si] != 6'd0)
                                shot_life_i[si] <= shot_life_i[si] - 6'd1;
                        end
                    end
                    // Shot integrate only (boom retired)
                    ei <= 4'd4;
                end else if (ei == 4'd4) begin : ram_init
                    // Ram once, then sequential shot hits (Pass B)
                    reg signed [15:0] bdx, bdy, adx, ady;
                    bdx = $signed(pos0_x[23:8]) - $signed(pos1_x[23:8]);
                    bdy = $signed(pos0_y[23:8]) - $signed(pos1_y[23:8]);
                    adx = bdx[15] ? -bdx : bdx;
                    ady = bdy[15] ? -bdy : bdy;
                    if ((pl_vanish_fr == 5'd0) && (ai_vanish_fr == 5'd0) &&
                        !pl_invuln && !ai_invuln &&
                        (adx < 16'sd20) && (ady < 16'sd18)) begin
                        if (!ship_lock) begin
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
                            if (score0 > SCORE_LO) score0 <= score0 - 11'sd1;
                            if (score1 > SCORE_LO) score1 <= score1 - 11'sd1;
                        end
                        ship_lock <= 1'b1;
                    end else if ((adx >= 16'sd26) || (ady >= 16'sd24))
                        ship_lock <= 1'b0;
                    hit_ai_r <= 1'b0;
                    hit_pl_r <= 1'b0;
                    sun_p_r  <= crash_sun0;
                    sun_e_r  <= crash_sun1;
                    hit_si   <= 3'd0;
                    ei       <= 4'd5;
                end else if (ei == 4'd5) begin : hit_one
                    // One shot per cycle vs current ship pos (or sun)
                    reg signed [15:0] bdx, bdy, adx, ady;
                    reg signed [23:0] sx, sy;
                    reg        [5:0]  slife;
                    reg               son;
                    reg               kill;
                    case (hit_si)
                        3'd0: begin son = shot_on_i[0]; sx = shot_x_i[0]; sy = shot_y_i[0]; slife = shot_life_i[0]; end
                        3'd1: begin son = shot_on_i[1]; sx = shot_x_i[1]; sy = shot_y_i[1]; slife = shot_life_i[1]; end
                        3'd2: begin son = shot_on_i[2]; sx = shot_x_i[2]; sy = shot_y_i[2]; slife = shot_life_i[2]; end
                        3'd3: begin son = shot_on_i[3]; sx = shot_x_i[3]; sy = shot_y_i[3]; slife = shot_life_i[3]; end
                        3'd4: begin son = shot_on_i[4]; sx = shot_x_i[4]; sy = shot_y_i[4]; slife = shot_life_i[4]; end
                        3'd5: begin son = shot_on_i[5]; sx = shot_x_i[5]; sy = shot_y_i[5]; slife = shot_life_i[5]; end
                        3'd6: begin son = shot_on_i[6]; sx = shot_x_i[6]; sy = shot_y_i[6]; slife = shot_life_i[6]; end
                        default: begin son = shot_on_i[7]; sx = shot_x_i[7]; sy = shot_y_i[7]; slife = shot_life_i[7]; end
                    endcase
                    kill = 1'b0;
                    if (son && (slife != 6'd0) &&
                        (sx >= (MARGIN <<< 8)) && (sx <= ((FB_W - MARGIN) <<< 8)) &&
                        (sy >= (MARGIN <<< 8)) && (sy <= ((FB_H - MARGIN) <<< 8))) begin
                        if (hit_si <= 3'd4) begin
                            bdx = $signed(sx[23:8]) - $signed(pos1_x[23:8]);
                            bdy = $signed(sy[23:8]) - $signed(pos1_y[23:8]);
                            adx = bdx[15] ? -bdx : bdx;
                            ady = bdy[15] ? -bdy : bdy;
                            if (!hit_ai_r && !ai_invuln &&
                                (adx < 16'sd22) && (ady < 16'sd22)) begin
                                kill = 1'b1;
                                pos1_x       <= -(24'sd80 <<< 8);
                                pos1_y       <= -(24'sd80 <<< 8);
                                vel1_x       <= 16'sd0;
                                vel1_y       <= 16'sd0;
                                thrusting1   <= 1'b0;
                                ai_vanish_fr <= AI_VANISH_FR[4:0];
                                hit_ai_r <= 1'b1;
                                score_bump0;
                            end else if (sun_hit_m($signed(sx[23:8]), $signed(sy[23:8]))) begin
                                kill = 1'b1;
                                sun_p_r <= 1'b1;
                            end
                        end else begin
                            bdx = $signed(sx[23:8]) - $signed(pos0_x[23:8]);
                            bdy = $signed(sy[23:8]) - $signed(pos0_y[23:8]);
                            adx = bdx[15] ? -bdx : bdx;
                            ady = bdy[15] ? -bdy : bdy;
                            if (!hit_pl_r && !pl_invuln &&
                                (adx < 16'sd24) && (ady < 16'sd24)) begin
                                kill = 1'b1;
                                pos0_x       <= -(24'sd80 <<< 8);
                                pos0_y       <= -(24'sd80 <<< 8);
                                vel0_x       <= 16'sd0;
                                vel0_y       <= 16'sd0;
                                thrusting0   <= 1'b0;
                                pl_vanish_fr <= AI_VANISH_FR[4:0];
                                hit_pl_r <= 1'b1;
                                score_bump1;
                            end else if (sun_hit_m($signed(sx[23:8]), $signed(sy[23:8]))) begin
                                kill = 1'b1;
                                sun_e_r <= 1'b1;
                            end
                        end
                    end else if (son)
                        kill = 1'b1;
                    if (kill) begin
                        case (hit_si)
                            3'd0: shot_on_i[0] <= 1'b0;
                            3'd1: shot_on_i[1] <= 1'b0;
                            3'd2: shot_on_i[2] <= 1'b0;
                            3'd3: shot_on_i[3] <= 1'b0;
                            3'd4: shot_on_i[4] <= 1'b0;
                            3'd5: shot_on_i[5] <= 1'b0;
                            3'd6: shot_on_i[6] <= 1'b0;
                            default: shot_on_i[7] <= 1'b0;
                        endcase
                    end
                    if (hit_si == 3'd7)
                        ei <= 4'd6;
                    else
                        hit_si <= hit_si + 3'd1;
                end else begin : hit_wrap
                    // BH / lives / timer after all shots
                    reg [2:0]  nl0, nst;
                    reg [13:0] nt;
                    reg [3:0]  nsh;
                    reg [2:0]  nbh;
                    nl0 = lives0;
                    nst = ai_streak;
                    nt  = timer_sec;
                    nsh = sun_hits;
                    nbh = bh_hits;

                    if (black_hole) begin
                        if (sun_p_r) begin
                            if (nbh == (BH_HITS_SUN[2:0] - 3'd1)) begin
                                black_hole <= 1'b0;
                                anti_grav  <= 1'b1;
                                bh_hits    <= 3'd0;
                            end else
                                bh_hits <= nbh + 3'd1;
                        end
                    end else if (!anti_grav) begin
                        if (sun_p_r && (nsh < 4'd15)) nsh = nsh + 4'd1;
                        if (sun_e_r && (nsh < 4'd15)) nsh = nsh + 4'd1;
                        sun_hits <= nsh;
                        if (nsh >= SUN_HITS_BH[3:0])
                            black_hole <= 1'b1;
                    end

                    if (hit_pl_r && !demo_mode && (nl0 != 3'd0))
                        nl0 = nl0 - 3'd1;
                    if (hit_ai_r) begin
                        if (nst == (KILL_FOR_LIFE[2:0] - 3'd1)) begin
                            nst = 3'd0;
                            if (!demo_mode && (nl0 < LIFE_MAX[2:0]))
                                nl0 = nl0 + 3'd1;
                        end else
                            nst = nst + 3'd1;
                    end
                    if (!demo_mode && (hit_ai_r || hit_pl_r)) begin
                        if (nt > (TIMER_MAX[13:0] - TIMER_BONUS[13:0]))
                            nt = TIMER_MAX[13:0];
                        else
                            nt = nt + TIMER_BONUS[13:0];
                    end
                    if (nt > TIMER_MAX[13:0])
                        nt = TIMER_MAX[13:0];
                    lives0    <= nl0;
                    ai_streak <= nst;
                    if (!demo_mode && (nl0 == 3'd0)) begin
                        game_over <= 1'b1;
                        timer_sec <= DEMO_TIMER[13:0];
                    end else
                        timer_sec <= nt;
                    sc_sel       <= 1'b0;
                    ei           <= 4'd0;
                    draw_pending <= 1'b1;
                    state        <= ST_IDLE;
                end
            end

            default: state <= ST_IDLE;
        endcase
    end
end

endmodule
