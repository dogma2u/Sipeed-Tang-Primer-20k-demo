// Space Wars physics: IDLE / PHYS / NEXT. Snapshot outputs for draw.
// Shot bank: 0..4 = player mag, 5..7 = AI. sin_cos is external.

module sw_physics(
    input  wire               clk,
    input  wire               rst_n,
    input  wire               frame_start,
    input  wire               draw_done,
    input  wire               btn_left_n,
    input  wire               btn_right_n,
    input  wire               btn_thrust_n,
    input  wire               btn_fire_n,
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
    output reg        [4:0]   boom0,
    output reg        [4:0]   boom1,
    output reg signed [15:0]  boom0_x,
    output reg signed [15:0]  boom0_y,
    output reg signed [15:0]  boom_x,
    output reg signed [15:0]  boom_y,
    output reg                boom0_dirty,
    output reg                boom_dirty,
    input  wire               clr_boom0_dirty,
    input  wire               clr_boom1_dirty,
    output reg signed [9:0]   score0,
    output reg signed [9:0]   score1,
    output reg                game_over,
    output reg        [13:0]  timer_sec,
    output reg        [5:0]   frame_cnt,
    output reg        [2:0]   lives0,
    output reg        [14:0]  fuel_ms,
    output reg                black_hole,
    output wire               border_red
);

// Gowin Education often fails `include — keep constants/helpers local.
localparam integer FB_W   = 800;
localparam integer FB_H   = 470; // 480x2-bit needs 48 BSRAM; chip has 46
localparam integer FB_SZ  = FB_W * FB_H;
localparam integer SUN_X  = 400;
localparam integer SUN_Y  = 240;
localparam integer SUN_R  = 18;
localparam integer SUN_HITS_BH = 10;
localparam integer BH_HITS_SUN = 5;
localparam integer MARGIN   = 20;
localparam integer MAXV     = 21;
localparam integer NSHOT    = 8;  // 0..4 player, 5..7 AI
localparam integer NSHOT_PL = 5;
localparam integer BUL_LIFE = 28;
localparam integer BOOM_N   = 16;
localparam integer FRAMES_PER_SEC = 50;
localparam integer TIMER_START    = 90;
localparam integer TIMER_BONUS    = 5;
localparam integer TIMER_MAX      = 9999; // display 99:99 (not a clock)
localparam integer LIFE_MAX       = 5;
localparam integer KILL_FOR_LIFE  = 5;
localparam integer FUEL_MAX_MS    = 15000;
localparam integer FUEL_FRAME_MS  = 20;
localparam integer PLAY_MEAN_SEC  = 150;
// Mag: 5 shots across ~500 ms, then 500 ms reload @ 50 Hz
localparam integer FIRE_GAP_FR    = 5;   // ~100 ms between shots
localparam integer FIRE_RELOAD_FR = 25;  // ~500 ms reload
localparam integer FIRE_MAG_MAX   = 5;

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
        num = dcomp * 32'sd768;
        q   = num / r2v;
        if (q > 32'sd48)
            q = 32'sd48;
        else if (q < -32'sd48)
            q = -32'sd48;
        grav_acc = invert ? -$signed(q[15:0]) : q[15:0];
    end
endfunction

localparam [1:0] ST_IDLE = 2'd0;
localparam [1:0] ST_PHYS = 2'd1;
localparam [1:0] ST_NEXT = 2'd2;

reg [1:0] state;
reg [2:0] phys_phase;
reg [3:0] ei;
reg       draw_pending;

reg signed [15:0] vel0_x, vel0_y, vel1_x, vel1_y;
reg signed [15:0] dx, dy;
reg signed [31:0] r2;
reg signed [31:0] cross, dotp;

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
reg               anti_grav;

// Internal unified shot bank (packed to ports combinationally)
reg               shot_on_i   [0:7];
reg signed [23:0] shot_x_i    [0:7];
reg signed [23:0] shot_y_i    [0:7];
reg signed [15:0] shot_vx_i   [0:7];
reg signed [15:0] shot_vy_i   [0:7];
reg        [5:0]  shot_life_i [0:7];

assign border_red = black_hole;
assign busy = (state != ST_IDLE) || draw_pending;
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

wire [8:0] play_cap = (play_sec > PLAY_MEAN_SEC[8:0]) ? PLAY_MEAN_SEC[8:0] : play_sec;
wire       ai_wild  = (play_sec >= PLAY_MEAN_SEC[8:0]);
wire [8:0] ai_quot  = play_cap / 9'd5;
wire [4:0] ai_dec   = ai_quot[4:0];
wire signed [15:0] ai_thrust = 16'sd20 + $signed({7'b0, play_cap} * 16'd20 / 16'd150);

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
        if (!kind) begin
            pos0_x  <= 24'sd140 <<< 8;
            pos0_y  <= 24'sd240 <<< 8;
            vel0_x  <= 16'sd0;
            vel0_y  <= -16'sd40;
            ang0    <= 8'd192;
            fuel_ms <= FUEL_MAX_MS[14:0];
        end else begin
            pos1_x <= 24'sd660 <<< 8;
            pos1_y <= 24'sd240 <<< 8;
            vel1_x <= 16'sd0;
            vel1_y <= 16'sd40;
            ang1   <= 8'd64;
        end
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
        ai_cd        <= 5'd20;
        ai_reload    <= 5'd0;
        ai_mag       <= 3'd0;
        lfsr         <= 8'hA5;
        ai_pulse     <= 5'd0;
        play_sec     <= 9'd0;
        boom0        <= 5'd0;
        boom1        <= 5'd0;
        boom0_dirty  <= 1'b0;
        boom_dirty   <= 1'b0;
        boom0_x      <= 16'sd0;
        boom0_y      <= 16'sd0;
        boom_x       <= 16'sd0;
        boom_y       <= 16'sd0;
        score0       <= 10'sd0;
        score1       <= 10'sd0;
        ship_lock    <= 1'b0;
        game_over    <= 1'b0;
        timer_sec    <= TIMER_START[13:0];
        frame_cnt    <= 6'd0;
        lives0       <= 3'd3;
        ai_streak    <= 3'd0;
        fuel_ms      <= FUEL_MAX_MS[14:0];
        sun_hits     <= 4'd0;
        bh_hits      <= 3'd0;
        black_hole   <= 1'b0;
        anti_grav    <= 1'b0;
        dx           <= 16'sd0;
        dy           <= 16'sd0;
        r2           <= 32'sd0;
        cross        <= 32'sd0;
        dotp         <= 32'sd0;
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
        draw_go <= 1'b0;

        if (clr_boom0_dirty)
            boom0_dirty <= 1'b0;
        if (clr_boom1_dirty)
            boom_dirty <= 1'b0;
        if (draw_done)
            draw_pending <= 1'b0;

        // Rising edge → one shot; hold keeps auto-fire via fire_p
        if (fire_p && !fire_prev && !game_over)
            fire_hold <= 1'b1;
        fire_prev <= fire_p;

        case (state)
            ST_IDLE: begin
                if (frame_start && !draw_pending) begin
                    if (frame_cnt == (FRAMES_PER_SEC[5:0] - 6'd1)) begin
                        frame_cnt <= 6'd0;
                        if (!game_over) begin
                            if (timer_sec == 14'd0)
                                game_over <= 1'b1;
                            else
                                timer_sec <= timer_sec - 14'd1;
                            if (play_sec < PLAY_MEAN_SEC[8:0])
                                play_sec <= play_sec + 9'd1;
                        end
                    end else
                        frame_cnt <= frame_cnt + 6'd1;
                    phys_phase <= 3'd0;
                    state <= ST_PHYS;
                end
            end

            ST_PHYS: begin
                if (game_over) begin
                    thrusting0 <= 1'b0;
                    thrusting1 <= 1'b0;
                    fire_hold  <= 1'b0;
                    for (si = 0; si < 8; si = si + 1)
                        shot_on_i[si] <= 1'b0;
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
                    sc_sel       <= 1'b0;
                    draw_go      <= 1'b1;
                    draw_pending <= 1'b1;
                    state        <= ST_IDLE;
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
                        sc_sel <= 1'b1;
                        phys_phase <= 3'd2;
                    end
                    3'd2: begin
                        cross <= cos_a * dy - sin_a * dx;
                        dotp  <= cos_a * dx + sin_a * dy;
                        phys_phase <= 3'd3;
                    end
                    3'd3: begin
                        if (boom1 == 5'd0) begin : ai_steer
                            reg signed [15:0] adx, ady;
                            reg signed [31:0] across;
                            reg [7:0] turn;
                            adx = dx[15] ? -dx : dx;
                            ady = dy[15] ? -dy : dy;
                            across = cross[31] ? -cross : cross;
                            // Smooth 1..3 steps/frame; always track
                            turn = 8'd1 + {6'b0, ai_dec[4:3]};
                            if (ai_wild)
                                turn = 8'd3;
                            if (dotp[31]) begin
                                if (cross[31]) ang1 <= ang1 + turn;
                                else           ang1 <= ang1 - turn;
                            end else if (across > (32'sd8000 - {17'b0, play_cap, 5'b0})) begin
                                if (cross[31]) ang1 <= ang1 + turn;
                                else           ang1 <= ang1 - turn;
                            end
                            // Hunt: close distance unless already on top of player
                            thrusting1 <= ((adx + ady) > 16'sd28) &&
                                          (ai_wild || ~dotp[31] || (across < 32'sd40000));
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
                            gdx = 16'sd400 - $signed(pos0_x[23:8]);
                            gdy = 16'sd240 - $signed(pos0_y[23:8]);
                            if (black_hole || anti_grav) begin
                                gx = grav_acc(gdx, gdx, gdy, anti_grav);
                                gy = grav_acc(gdy, gdx, gdy, anti_grav);
                            end else begin
                                gx = 16'sd0;
                                gy = 16'sd0;
                            end
                            vel0_x <= vel0_x + mul_q88(cos_a, thrusting0 ? 16'sd40 : 16'sd0)
                                      + gx - (vel0_x >>> 8);
                            vel0_y <= vel0_y + mul_q88(sin_a, thrusting0 ? 16'sd40 : 16'sd0)
                                      + gy - (vel0_y >>> 8);
                        end
                        if (fire_reload != 5'd0)
                            fire_reload <= fire_reload - 5'd1;
                        else if (fire_cd != 5'd0)
                            fire_cd <= fire_cd - 5'd1;
                        else if ((fire_hold || fire_p) && (boom0 == 5'd0) && (boom1 == 5'd0)) begin
                            begin : spawn_shot
                                reg signed [15:0] ox, oy, svx, svy;
                                reg               placed;
                                ox  = mul_q88(cos_a, 16'sd18);
                                oy  = mul_q88(sin_a, 16'sd18);
                                svx = mul_q88(cos_a, 16'sd10 <<< 8) + (vel0_x >>> 1);
                                svy = mul_q88(sin_a, 16'sd10 <<< 8) + (vel0_y >>> 1);
                                placed = 1'b0;
                                // Unrolled — Gowin often breaks variable-index for-loops
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
                        sc_sel <= 1'b1;
                        phys_phase <= 3'd6;
                    end
                    3'd6: begin
                        begin : grav1
                            reg signed [15:0] gdx, gdy, gx, gy;
                            gdx = 16'sd400 - $signed(pos1_x[23:8]);
                            gdy = 16'sd240 - $signed(pos1_y[23:8]);
                            if (black_hole || anti_grav) begin
                                gx = grav_acc(gdx, gdx, gdy, anti_grav);
                                gy = grav_acc(gdy, gdx, gdy, anti_grav);
                            end else begin
                                gx = 16'sd0;
                                gy = 16'sd0;
                            end
                            vel1_x <= vel1_x + mul_q88(cos_a, thrusting1 ? ai_thrust : 16'sd0)
                                      + gx - (vel1_x >>> 8);
                            vel1_y <= vel1_y + mul_q88(sin_a, thrusting1 ? ai_thrust : 16'sd0)
                                      + gy - (vel1_y >>> 8);
                        end
                        // Aimed shots; aim gate opens with time → hunter by 2:30
                        if (ai_reload != 5'd0)
                            ai_reload <= ai_reload - 5'd1;
                        else if (ai_cd != 5'd0)
                            ai_cd <= ai_cd - 5'd1;
                        else if ((boom0 == 5'd0) && (boom1 == 5'd0) && ~dotp[31] &&
                                 (dotp > (32'sd8000 - {16'b0, play_cap, 6'b0})) &&
                                 ((cross[31] ? -cross : cross) <
                                  (32'sd6000 + {16'b0, play_cap, 7'b0}))) begin
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
                                    shot_on_i[5] <= 1'b1; shot_life_i[5] <= BUL_LIFE[5:0];
                                    placed = 1'b1;
                                end else if (!shot_on_i[6]) begin
                                    shot_x_i[6] <= pos1_x + {{8{ox[15]}}, ox};
                                    shot_y_i[6] <= pos1_y + {{8{oy[15]}}, oy};
                                    shot_vx_i[6] <= svx; shot_vy_i[6] <= svy;
                                    shot_on_i[6] <= 1'b1; shot_life_i[6] <= BUL_LIFE[5:0];
                                    placed = 1'b1;
                                end else if (!shot_on_i[7]) begin
                                    shot_x_i[7] <= pos1_x + {{8{ox[15]}}, ox};
                                    shot_y_i[7] <= pos1_y + {{8{oy[15]}}, oy};
                                    shot_vx_i[7] <= svx; shot_vy_i[7] <= svy;
                                    shot_on_i[7] <= 1'b1; shot_life_i[7] <= BUL_LIFE[5:0];
                                    placed = 1'b1;
                                end
                                if (placed) begin
                                    if (ai_mag >= (FIRE_MAG_MAX[2:0] - 3'd1)) begin
                                        ai_mag    <= 3'd0;
                                        ai_reload <= FIRE_RELOAD_FR[4:0];
                                        ai_cd     <= 5'd0;
                                    end else begin
                                        ai_mag <= ai_mag + 3'd1;
                                        ai_cd  <= ai_wild ? 5'd3 : FIRE_GAP_FR[4:0];
                                    end
                                end
                            end
                        end
                        phys_phase <= 3'd7;
                    end
                    3'd7: begin
                        pos0_x <= pos0_x + {{8{vel0_x[15]}}, vel0_x};
                        pos0_y <= pos0_y + {{8{vel0_y[15]}}, vel0_y};
                        pos1_x <= pos1_x + {{8{vel1_x[15]}}, vel1_x};
                        pos1_y <= pos1_y + {{8{vel1_y[15]}}, vel1_y};
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
                        t0x = pos0_x; t0y = pos0_y; v0x = vel0_x; v0y = vel0_y;
                        t1x = pos1_x; t1y = pos1_y; v1x = vel1_x; v1y = vel1_y;
                        bounce_ship(t0x, t0y, v0x, v0y);
                        bounce_ship(t1x, t1y, v1x, v1y);
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
                    if (r2 < 32'sd400)
                        respawn(1'b1);
                    for (si = 0; si < 8; si = si + 1) begin
                        if (shot_on_i[si]) begin
                            shot_x_i[si] <= shot_x_i[si] + {{8{shot_vx_i[si][15]}}, shot_vx_i[si]};
                            shot_y_i[si] <= shot_y_i[si] + {{8{shot_vy_i[si][15]}}, shot_vy_i[si]};
                            if (shot_life_i[si] != 6'd0)
                                shot_life_i[si] <= shot_life_i[si] - 6'd1;
                        end
                    end
                    if (boom0 == 5'd1) begin
                        if (lives0 != 3'd0)
                            respawn(1'b0);
                        else begin
                            pos0_x <= -(24'sd80 <<< 8);
                            pos0_y <= -(24'sd80 <<< 8);
                            vel0_x <= 16'sd0;
                            vel0_y <= 16'sd0;
                        end
                    end
                    if (boom1 == 5'd1)
                        respawn(1'b1);
                    if (boom0 != 5'd0)
                        boom0 <= boom0 - 5'd1;
                    if (boom1 != 5'd0)
                        boom1 <= boom1 - 5'd1;
                    ei <= 4'd4;
                end else begin : hits
                    reg signed [15:0] bdx, bdy, adx, ady;
                    reg [2:0]         nl0, nst;
                    reg [13:0]        nt;
                    reg [3:0]         nsh;
                    reg [2:0]         nbh;
                    reg               hit_ai, hit_pl, ram;
                    reg               sun_p, sun_e;
                    nl0 = lives0;
                    nst = ai_streak;
                    nt  = timer_sec;
                    nsh = sun_hits;
                    nbh = bh_hits;
                    hit_ai = 1'b0; hit_pl = 1'b0; ram = 1'b0;
                    sun_p = 1'b0; sun_e = 1'b0;

                    // Ram score first; kill score NBAs below run later and win same cycle
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
                            if (score0 > -10'sd99) score0 <= score0 - 10'sd1;
                            if (score1 > -10'sd99) score1 <= score1 - 10'sd1;
                        end
                        ship_lock <= 1'b1;
                    end else if ((adx >= 16'sd26) || (ady >= 16'sd24))
                        ship_lock <= 1'b0;

                    // Player shots 0..4 → AI / sun (score NBA in same branch as boom)
                    if (shot_on_i[0] && (shot_life_i[0] != 6'd0) &&
                        (shot_x_i[0] >= (MARGIN <<< 8)) && (shot_x_i[0] <= ((FB_W - MARGIN) <<< 8)) &&
                        (shot_y_i[0] >= (MARGIN <<< 8)) && (shot_y_i[0] <= ((FB_H - MARGIN) <<< 8))) begin
                        bdx = $signed(shot_x_i[0][23:8]) - $signed(pos1_x[23:8]);
                        bdy = $signed(shot_y_i[0][23:8]) - $signed(pos1_y[23:8]);
                        adx = bdx[15] ? -bdx : bdx;
                        ady = bdy[15] ? -bdy : bdy;
                        if ((boom1 == 5'd0) && !hit_ai && (adx < 16'sd22) && (ady < 16'sd22)) begin
                            shot_on_i[0] <= 1'b0;
                            boom1 <= BOOM_N[4:0]; boom_dirty <= 1'b1;
                            boom_x <= $signed(pos1_x[23:8]); boom_y <= $signed(pos1_y[23:8]);
                            hit_ai = 1'b1;
                            if (score0 < 10'sd500) score0 <= score0 + 10'sd1;
                        end else begin
                            bdx = $signed(shot_x_i[0][23:8]) - 16'sd400;
                            bdy = $signed(shot_y_i[0][23:8]) - 16'sd240;
                            if ((bdx * bdx + bdy * bdy) < 32'sd400) begin
                                shot_on_i[0] <= 1'b0; sun_p = 1'b1;
                            end
                        end
                    end else if (shot_on_i[0])
                        shot_on_i[0] <= 1'b0;
                    if (shot_on_i[1] && (shot_life_i[1] != 6'd0) &&
                        (shot_x_i[1] >= (MARGIN <<< 8)) && (shot_x_i[1] <= ((FB_W - MARGIN) <<< 8)) &&
                        (shot_y_i[1] >= (MARGIN <<< 8)) && (shot_y_i[1] <= ((FB_H - MARGIN) <<< 8))) begin
                        bdx = $signed(shot_x_i[1][23:8]) - $signed(pos1_x[23:8]);
                        bdy = $signed(shot_y_i[1][23:8]) - $signed(pos1_y[23:8]);
                        adx = bdx[15] ? -bdx : bdx;
                        ady = bdy[15] ? -bdy : bdy;
                        if ((boom1 == 5'd0) && !hit_ai && (adx < 16'sd22) && (ady < 16'sd22)) begin
                            shot_on_i[1] <= 1'b0;
                            boom1 <= BOOM_N[4:0]; boom_dirty <= 1'b1;
                            boom_x <= $signed(pos1_x[23:8]); boom_y <= $signed(pos1_y[23:8]);
                            hit_ai = 1'b1;
                            if (score0 < 10'sd500) score0 <= score0 + 10'sd1;
                        end else begin
                            bdx = $signed(shot_x_i[1][23:8]) - 16'sd400;
                            bdy = $signed(shot_y_i[1][23:8]) - 16'sd240;
                            if ((bdx * bdx + bdy * bdy) < 32'sd400) begin
                                shot_on_i[1] <= 1'b0; sun_p = 1'b1;
                            end
                        end
                    end else if (shot_on_i[1])
                        shot_on_i[1] <= 1'b0;
                    if (shot_on_i[2] && (shot_life_i[2] != 6'd0) &&
                        (shot_x_i[2] >= (MARGIN <<< 8)) && (shot_x_i[2] <= ((FB_W - MARGIN) <<< 8)) &&
                        (shot_y_i[2] >= (MARGIN <<< 8)) && (shot_y_i[2] <= ((FB_H - MARGIN) <<< 8))) begin
                        bdx = $signed(shot_x_i[2][23:8]) - $signed(pos1_x[23:8]);
                        bdy = $signed(shot_y_i[2][23:8]) - $signed(pos1_y[23:8]);
                        adx = bdx[15] ? -bdx : bdx;
                        ady = bdy[15] ? -bdy : bdy;
                        if ((boom1 == 5'd0) && !hit_ai && (adx < 16'sd22) && (ady < 16'sd22)) begin
                            shot_on_i[2] <= 1'b0;
                            boom1 <= BOOM_N[4:0]; boom_dirty <= 1'b1;
                            boom_x <= $signed(pos1_x[23:8]); boom_y <= $signed(pos1_y[23:8]);
                            hit_ai = 1'b1;
                            if (score0 < 10'sd500) score0 <= score0 + 10'sd1;
                        end else begin
                            bdx = $signed(shot_x_i[2][23:8]) - 16'sd400;
                            bdy = $signed(shot_y_i[2][23:8]) - 16'sd240;
                            if ((bdx * bdx + bdy * bdy) < 32'sd400) begin
                                shot_on_i[2] <= 1'b0; sun_p = 1'b1;
                            end
                        end
                    end else if (shot_on_i[2])
                        shot_on_i[2] <= 1'b0;
                    if (shot_on_i[3] && (shot_life_i[3] != 6'd0) &&
                        (shot_x_i[3] >= (MARGIN <<< 8)) && (shot_x_i[3] <= ((FB_W - MARGIN) <<< 8)) &&
                        (shot_y_i[3] >= (MARGIN <<< 8)) && (shot_y_i[3] <= ((FB_H - MARGIN) <<< 8))) begin
                        bdx = $signed(shot_x_i[3][23:8]) - $signed(pos1_x[23:8]);
                        bdy = $signed(shot_y_i[3][23:8]) - $signed(pos1_y[23:8]);
                        adx = bdx[15] ? -bdx : bdx;
                        ady = bdy[15] ? -bdy : bdy;
                        if ((boom1 == 5'd0) && !hit_ai && (adx < 16'sd22) && (ady < 16'sd22)) begin
                            shot_on_i[3] <= 1'b0;
                            boom1 <= BOOM_N[4:0]; boom_dirty <= 1'b1;
                            boom_x <= $signed(pos1_x[23:8]); boom_y <= $signed(pos1_y[23:8]);
                            hit_ai = 1'b1;
                            if (score0 < 10'sd500) score0 <= score0 + 10'sd1;
                        end else begin
                            bdx = $signed(shot_x_i[3][23:8]) - 16'sd400;
                            bdy = $signed(shot_y_i[3][23:8]) - 16'sd240;
                            if ((bdx * bdx + bdy * bdy) < 32'sd400) begin
                                shot_on_i[3] <= 1'b0; sun_p = 1'b1;
                            end
                        end
                    end else if (shot_on_i[3])
                        shot_on_i[3] <= 1'b0;
                    if (shot_on_i[4] && (shot_life_i[4] != 6'd0) &&
                        (shot_x_i[4] >= (MARGIN <<< 8)) && (shot_x_i[4] <= ((FB_W - MARGIN) <<< 8)) &&
                        (shot_y_i[4] >= (MARGIN <<< 8)) && (shot_y_i[4] <= ((FB_H - MARGIN) <<< 8))) begin
                        bdx = $signed(shot_x_i[4][23:8]) - $signed(pos1_x[23:8]);
                        bdy = $signed(shot_y_i[4][23:8]) - $signed(pos1_y[23:8]);
                        adx = bdx[15] ? -bdx : bdx;
                        ady = bdy[15] ? -bdy : bdy;
                        if ((boom1 == 5'd0) && !hit_ai && (adx < 16'sd22) && (ady < 16'sd22)) begin
                            shot_on_i[4] <= 1'b0;
                            boom1 <= BOOM_N[4:0]; boom_dirty <= 1'b1;
                            boom_x <= $signed(pos1_x[23:8]); boom_y <= $signed(pos1_y[23:8]);
                            hit_ai = 1'b1;
                            if (score0 < 10'sd500) score0 <= score0 + 10'sd1;
                        end else begin
                            bdx = $signed(shot_x_i[4][23:8]) - 16'sd400;
                            bdy = $signed(shot_y_i[4][23:8]) - 16'sd240;
                            if ((bdx * bdx + bdy * bdy) < 32'sd400) begin
                                shot_on_i[4] <= 1'b0; sun_p = 1'b1;
                            end
                        end
                    end else if (shot_on_i[4])
                        shot_on_i[4] <= 1'b0;

                    // AI shots 5..7 → player / sun
                    if (shot_on_i[5] && (shot_life_i[5] != 6'd0) &&
                        (shot_x_i[5] >= (MARGIN <<< 8)) && (shot_x_i[5] <= ((FB_W - MARGIN) <<< 8)) &&
                        (shot_y_i[5] >= (MARGIN <<< 8)) && (shot_y_i[5] <= ((FB_H - MARGIN) <<< 8))) begin
                        bdx = $signed(shot_x_i[5][23:8]) - $signed(pos0_x[23:8]);
                        bdy = $signed(shot_y_i[5][23:8]) - $signed(pos0_y[23:8]);
                        adx = bdx[15] ? -bdx : bdx;
                        ady = bdy[15] ? -bdy : bdy;
                        if ((boom0 == 5'd0) && !hit_pl && (adx < 16'sd24) && (ady < 16'sd24)) begin
                            shot_on_i[5] <= 1'b0;
                            boom0 <= BOOM_N[4:0]; boom0_dirty <= 1'b1;
                            boom0_x <= $signed(pos0_x[23:8]); boom0_y <= $signed(pos0_y[23:8]);
                            hit_pl = 1'b1;
                            if (score1 < 10'sd500) score1 <= score1 + 10'sd1;
                        end else begin
                            bdx = $signed(shot_x_i[5][23:8]) - 16'sd400;
                            bdy = $signed(shot_y_i[5][23:8]) - 16'sd240;
                            if ((bdx * bdx + bdy * bdy) < 32'sd400) begin
                                shot_on_i[5] <= 1'b0; sun_e = 1'b1;
                            end
                        end
                    end else if (shot_on_i[5])
                        shot_on_i[5] <= 1'b0;
                    if (shot_on_i[6] && (shot_life_i[6] != 6'd0) &&
                        (shot_x_i[6] >= (MARGIN <<< 8)) && (shot_x_i[6] <= ((FB_W - MARGIN) <<< 8)) &&
                        (shot_y_i[6] >= (MARGIN <<< 8)) && (shot_y_i[6] <= ((FB_H - MARGIN) <<< 8))) begin
                        bdx = $signed(shot_x_i[6][23:8]) - $signed(pos0_x[23:8]);
                        bdy = $signed(shot_y_i[6][23:8]) - $signed(pos0_y[23:8]);
                        adx = bdx[15] ? -bdx : bdx;
                        ady = bdy[15] ? -bdy : bdy;
                        if ((boom0 == 5'd0) && !hit_pl && (adx < 16'sd24) && (ady < 16'sd24)) begin
                            shot_on_i[6] <= 1'b0;
                            boom0 <= BOOM_N[4:0]; boom0_dirty <= 1'b1;
                            boom0_x <= $signed(pos0_x[23:8]); boom0_y <= $signed(pos0_y[23:8]);
                            hit_pl = 1'b1;
                            if (score1 < 10'sd500) score1 <= score1 + 10'sd1;
                        end else begin
                            bdx = $signed(shot_x_i[6][23:8]) - 16'sd400;
                            bdy = $signed(shot_y_i[6][23:8]) - 16'sd240;
                            if ((bdx * bdx + bdy * bdy) < 32'sd400) begin
                                shot_on_i[6] <= 1'b0; sun_e = 1'b1;
                            end
                        end
                    end else if (shot_on_i[6])
                        shot_on_i[6] <= 1'b0;
                    if (shot_on_i[7] && (shot_life_i[7] != 6'd0) &&
                        (shot_x_i[7] >= (MARGIN <<< 8)) && (shot_x_i[7] <= ((FB_W - MARGIN) <<< 8)) &&
                        (shot_y_i[7] >= (MARGIN <<< 8)) && (shot_y_i[7] <= ((FB_H - MARGIN) <<< 8))) begin
                        bdx = $signed(shot_x_i[7][23:8]) - $signed(pos0_x[23:8]);
                        bdy = $signed(shot_y_i[7][23:8]) - $signed(pos0_y[23:8]);
                        adx = bdx[15] ? -bdx : bdx;
                        ady = bdy[15] ? -bdy : bdy;
                        if ((boom0 == 5'd0) && !hit_pl && (adx < 16'sd24) && (ady < 16'sd24)) begin
                            shot_on_i[7] <= 1'b0;
                            boom0 <= BOOM_N[4:0]; boom0_dirty <= 1'b1;
                            boom0_x <= $signed(pos0_x[23:8]); boom0_y <= $signed(pos0_y[23:8]);
                            hit_pl = 1'b1;
                            if (score1 < 10'sd500) score1 <= score1 + 10'sd1;
                        end else begin
                            bdx = $signed(shot_x_i[7][23:8]) - 16'sd400;
                            bdy = $signed(shot_y_i[7][23:8]) - 16'sd240;
                            if ((bdx * bdx + bdy * bdy) < 32'sd400) begin
                                shot_on_i[7] <= 1'b0; sun_e = 1'b1;
                            end
                        end
                    end else if (shot_on_i[7])
                        shot_on_i[7] <= 1'b0;

                    if (black_hole) begin
                        if (sun_p) begin
                            if (nbh == (BH_HITS_SUN[2:0] - 3'd1)) begin
                                black_hole <= 1'b0;
                                anti_grav  <= 1'b1;
                                bh_hits    <= 3'd0;
                            end else
                                bh_hits <= nbh + 3'd1;
                        end
                    end else if (!anti_grav) begin
                        if (sun_p && (nsh < 4'd15)) nsh = nsh + 4'd1;
                        if (sun_e && (nsh < 4'd15)) nsh = nsh + 4'd1;
                        sun_hits <= nsh;
                        if (nsh >= SUN_HITS_BH[3:0])
                            black_hole <= 1'b1;
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
                        if (nt > (TIMER_MAX[13:0] - TIMER_BONUS[13:0]))
                            nt = TIMER_MAX[13:0];
                        else
                            nt = nt + TIMER_BONUS[13:0];
                    end
                    lives0    <= nl0;
                    ai_streak <= nst;
                    timer_sec <= nt;
                    if (nl0 == 3'd0)
                        game_over <= 1'b1;
                    sc_sel       <= 1'b0;
                    ei           <= 4'd0;
                    draw_go      <= 1'b1;
                    draw_pending <= 1'b1;
                    state        <= ST_IDLE;
                end
            end

            default: state <= ST_IDLE;
        endcase
    end
end

endmodule
