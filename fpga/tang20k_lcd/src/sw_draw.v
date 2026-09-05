// Space Wars framebuffer draw engine (Tang Primer 20K).
// CLEAR / ERASE / XFORM / SHIP / FLAME / DONE / SHOT / BOOM.
// No FB star wipe -- after erase or clear, route straight to XFORM/SHOT.

module sw_draw (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               draw_go,
    output reg                draw_done,
    output reg                busy,
    output reg                sc_sel,

    input  wire signed [23:0] pos0_x,
    input  wire signed [23:0] pos0_y,
    input  wire signed [23:0] pos1_x,
    input  wire signed [23:0] pos1_y,
    input  wire        [7:0]  ang0,
    input  wire        [7:0]  ang1,
    input  wire               thrusting0,
    input  wire               thrusting1,

    input  wire        [7:0]  shot_on,
    input  wire       [191:0] shot_x,
    input  wire       [191:0] shot_y,
    input  wire       [127:0] shot_vx,
    input  wire       [127:0] shot_vy,

    input  wire        [4:0]  boom0,
    input  wire        [4:0]  boom1,
    input  wire signed [15:0] boom0_x,
    input  wire signed [15:0] boom0_y,
    input  wire signed [15:0] boom_x,
    input  wire signed [15:0] boom_y,
    input  wire               boom0_dirty,
    input  wire               boom_dirty,
    output reg                clr_boom0_dirty,
    output reg                clr_boom1_dirty,

    input  wire signed [15:0] sin_a,
    input  wire signed [15:0] cos_a,

    output reg                plot_en,
    output reg         [9:0]  plot_x,
    output reg         [8:0]  plot_y,
    output reg         [1:0]  plot_col,
    output reg                clear_mode,
    output reg         [18:0] clear_addr
);

// Gowin Education often fails include of .vh -- keep constants/helpers local.
localparam integer FB_W   = 800;
localparam integer FB_H   = 470;
localparam integer FB_SZ  = FB_W * FB_H;
localparam integer MAXV     = 12;
localparam integer NSHOT    = 8;

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

function signed [15:0] abs16;
    input signed [15:0] v;
    begin
        abs16 = v[15] ? -v : v;
    end
endfunction

localparam [3:0] ST_IDLE  = 4'd0;
localparam [3:0] ST_CLEAR = 4'd1;
localparam [3:0] ST_ERASE = 4'd2;
localparam [3:0] ST_XFORM = 4'd3;
localparam [3:0] ST_SHIP  = 4'd4;
localparam [3:0] ST_FLAME = 4'd5;
localparam [3:0] ST_DONE  = 4'd6;
localparam [3:0] ST_SHOT  = 4'd7;
localparam [3:0] ST_BOOM  = 4'd8;

reg [3:0]  state;
reg        ship_sel; // 0=player, 1=AI
reg        have_prev0, have_prev1;
reg        prev_thrust0, prev_thrust1;

reg signed [15:0] sxv [0:MAXV-1];
reg signed [15:0] syv [0:MAXV-1];
reg signed [15:0] pxv0 [0:MAXV-1];
reg signed [15:0] pyv0 [0:MAXV-1];
reg signed [15:0] pxv1 [0:MAXV-1];
reg signed [15:0] pyv1 [0:MAXV-1];
reg signed [15:0] pflame0_x, pflame0_y, pflame1_x, pflame1_y;

reg               shot_have_prev [0:7];
reg        [9:0]  shot_ox  [0:7];
reg        [9:0]  shot_ox2 [0:7];
reg        [8:0]  shot_oy  [0:7];
reg        [8:0]  shot_oy2 [0:7];
reg               shot_phase; // 0=erase, 1=draw

reg [4:0]  boom0_len_prev, boom_len_prev;
reg        boom_sel;

// Snapshot at draw_go -- physics must not change these mid-erase/redraw
reg signed [23:0] d_pos0_x, d_pos0_y, d_pos1_x, d_pos1_y;
reg               d_thrust0, d_thrust1;
reg        [7:0]  d_shot_on;
reg       [191:0] d_shot_x, d_shot_y;
reg       [127:0] d_shot_vx, d_shot_vy;
reg        [4:0]  d_boom0, d_boom1;
reg signed [15:0] d_boom0_x, d_boom0_y, d_boom_x, d_boom_y;
reg               d_boom0_dirty, d_boom_dirty;

reg [4:0]  vi;
reg [4:0]  ei;
reg [4:0]  si;
reg [4:0]  nvert;
reg [4:0]  nedge;
reg [4:0]  hitch;

reg signed [15:0] b_x, b_y, b_dx, b_dy, b_sx, b_sy, b_err, end_x, end_y;
reg        [12:0] line_steps; // abort runaway lines (wrap / bad verts)
reg               line_active;

wire signed [15:0] boom_cx   = boom_sel ? d_boom_x : d_boom0_x;
wire signed [15:0] boom_cy   = boom_sel ? d_boom_y : d_boom0_y;
wire        [4:0]  boom_clen = boom_sel ? boom_len_prev : boom0_len_prev;
wire        [4:0]  boom_cnt  = boom_sel ? d_boom1 : d_boom0;

// Packed shot buses -> per-index locals (combinational mux)
reg               shot_on_i;
reg signed [23:0] shot_x_i, shot_y_i;
reg signed [15:0] shot_vx_i, shot_vy_i;

always @(*) begin
    case (si[2:0])
        3'd0: begin
            shot_on_i = d_shot_on[0];
            shot_x_i  = d_shot_x[23:0];
            shot_y_i  = d_shot_y[23:0];
            shot_vx_i = d_shot_vx[15:0];
            shot_vy_i = d_shot_vy[15:0];
        end
        3'd1: begin
            shot_on_i = d_shot_on[1];
            shot_x_i  = d_shot_x[47:24];
            shot_y_i  = d_shot_y[47:24];
            shot_vx_i = d_shot_vx[31:16];
            shot_vy_i = d_shot_vy[31:16];
        end
        3'd2: begin
            shot_on_i = d_shot_on[2];
            shot_x_i  = d_shot_x[71:48];
            shot_y_i  = d_shot_y[71:48];
            shot_vx_i = d_shot_vx[47:32];
            shot_vy_i = d_shot_vy[47:32];
        end
        3'd3: begin
            shot_on_i = d_shot_on[3];
            shot_x_i  = d_shot_x[95:72];
            shot_y_i  = d_shot_y[95:72];
            shot_vx_i = d_shot_vx[63:48];
            shot_vy_i = d_shot_vy[63:48];
        end
        3'd4: begin
            shot_on_i = d_shot_on[4];
            shot_x_i  = d_shot_x[119:96];
            shot_y_i  = d_shot_y[119:96];
            shot_vx_i = d_shot_vx[79:64];
            shot_vy_i = d_shot_vy[79:64];
        end
        3'd5: begin
            shot_on_i = d_shot_on[5];
            shot_x_i  = d_shot_x[143:120];
            shot_y_i  = d_shot_y[143:120];
            shot_vx_i = d_shot_vx[95:80];
            shot_vy_i = d_shot_vy[95:80];
        end
        3'd6: begin
            shot_on_i = d_shot_on[6];
            shot_x_i  = d_shot_x[167:144];
            shot_y_i  = d_shot_y[167:144];
            shot_vx_i = d_shot_vx[111:96];
            shot_vy_i = d_shot_vy[111:96];
        end
        default: begin
            shot_on_i = d_shot_on[7];
            shot_x_i  = d_shot_x[191:168];
            shot_y_i  = d_shot_y[191:168];
            shot_vx_i = d_shot_vx[127:112];
            shot_vy_i = d_shot_vy[127:112];
        end
    endcase
end

// ang0/ang1 unused here -- glue selects angle with sc_sel for external sin_cos.

// Player: Diamond outline (Pass A slim). Nose = +X.
// Wedge: JS 4-point. kind 0=player (Diamond), 1=AI
function signed [7:0] shp_x;
    input        kind;
    input [4:0]  i;
    begin
        if (!kind) begin
            case (i)
                5'd0:  shp_x =  8'sd14; // nose
                5'd1:  shp_x =  8'sd4;  // diamond R
                5'd2:  shp_x = -8'sd2;  // neck R
                5'd3:  shp_x = -8'sd14; // nacelle R tip
                5'd4:  shp_x = -8'sd10; // aft / hitch
                5'd5:  shp_x = -8'sd14; // nacelle L tip
                5'd6:  shp_x = -8'sd2;  // neck L
                5'd7:  shp_x =  8'sd4;  // diamond L
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
                5'd1:  shp_y =  8'sd7;
                5'd2:  shp_y =  8'sd3;
                5'd3:  shp_y =  8'sd8;
                5'd4:  shp_y =  8'sd0;
                5'd5:  shp_y = -8'sd8;
                5'd6:  shp_y = -8'sd3;
                5'd7:  shp_y = -8'sd7;
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
                5'd0:  edge_a=5'd0;  5'd1:  edge_a=5'd1;  5'd2:  edge_a=5'd2;
                5'd3:  edge_a=5'd3;  5'd4:  edge_a=5'd4;  5'd5:  edge_a=5'd5;
                5'd6:  edge_a=5'd6;  5'd7:  edge_a=5'd7;
                5'd8:  edge_a=5'd2;  5'd9:  edge_a=5'd6; // pylons to aft
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
                5'd3:  edge_b=5'd4;  5'd4:  edge_b=5'd5;  5'd5:  edge_b=5'd6;
                5'd6:  edge_b=5'd7;  5'd7:  edge_b=5'd0;
                5'd8:  edge_b=5'd4;  5'd9:  edge_b=5'd4;
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
        line_steps <= 13'd0;
    end
endtask

task step_bresenham;
    begin
        if ((b_x == end_x) && (b_y == end_y))
            line_active <= 1'b0;
        else if (line_steps >= 13'd4095)
            line_active <= 1'b0; // hard stop -- prevents FB lockup
        else begin : bstep
            reg signed [15:0] e2, nerr, nx, ny;
            e2 = b_err <<< 1; nerr = b_err; nx = b_x; ny = b_y;
            if (e2 > -b_dy) begin nerr = nerr - b_dy; nx = nx + b_sx; end
            if (e2 <  b_dx) begin nerr = nerr + b_dx; ny = ny + b_sy; end
            b_err <= nerr; b_x <= nx; b_y <= ny;
            line_steps <= line_steps + 13'd1;
        end
    end
endtask

task load_ship_geom;
    input kind;
    begin
        if (!kind) begin nvert = 5'd8; nedge = 5'd10; hitch = 5'd4; end
        else       begin nvert = 5'd4;  nedge = 5'd4;  hitch = 5'd2; end
    end
endtask

// After CLEAR or ERASE. Boom retired -- hide ships parked off-screen.
task route_draw;
    begin
        vi <= 5'd0;
        si <= 5'd0;
        shot_phase <= 1'b0;
        line_active <= 1'b0;
        if (d_pos0_x[23]) begin
            have_prev0 <= 1'b0;
            if (d_pos1_x[23]) begin
                have_prev1 <= 1'b0;
                ei    <= 5'd0;
                state <= ST_SHOT;
            end else begin
                ship_sel <= 1'b1;
                sc_sel   <= 1'b1;
                nvert    <= 5'd4;
                nedge    <= 5'd4;
                hitch    <= 5'd2;
                state    <= ST_XFORM;
            end
        end else begin
            ship_sel <= 1'b0;
            sc_sel   <= 1'b0;
            nvert    <= 5'd8;
            nedge    <= 5'd10;
            hitch    <= 5'd4;
            state    <= ST_XFORM;
        end
    end
endtask

task go_idle_done;
    begin
        state     <= ST_IDLE;
        draw_done <= 1'b1;
        ei        <= 5'd0;
        si        <= 5'd0;
        shot_phase <= 1'b0;
    end
endtask

integer k;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state            <= ST_CLEAR;
        clear_addr       <= 19'd0;
        clear_mode       <= 1'b1;
        plot_en          <= 1'b0;
        plot_x           <= 10'd0;
        plot_y           <= 9'd0;
        plot_col         <= COL_OFF;
        line_active      <= 1'b0;
        have_prev0       <= 1'b0;
        have_prev1       <= 1'b0;
        prev_thrust0     <= 1'b0;
        prev_thrust1     <= 1'b0;
        ship_sel         <= 1'b0;
        sc_sel           <= 1'b0;
        vi <= 5'd0; ei <= 5'd0; si <= 5'd0;
        nvert <= 5'd8; nedge <= 5'd10; hitch <= 5'd4;
        shot_phase       <= 1'b0;
        boom0_len_prev   <= 5'd0;
        boom_len_prev    <= 5'd0;
        boom_sel         <= 1'b0;
        draw_done        <= 1'b0;
        busy             <= 1'b1;
        clr_boom0_dirty  <= 1'b0;
        clr_boom1_dirty  <= 1'b0;
        pflame0_x <= 16'sd0; pflame0_y <= 16'sd0;
        pflame1_x <= 16'sd0; pflame1_y <= 16'sd0;
        for (k = 0; k < 8; k = k + 1) begin
            shot_have_prev[k] <= 1'b0;
            shot_ox[k]  <= 10'd0;
            shot_oy[k]  <= 9'd0;
            shot_ox2[k] <= 10'd0;
            shot_oy2[k] <= 9'd0;
        end
    end else begin
        plot_en         <= 1'b0;
        clear_mode      <= 1'b0;
        draw_done       <= 1'b0;
        clr_boom0_dirty <= 1'b0;
        clr_boom1_dirty <= 1'b0;
        busy            <= (state != ST_IDLE);
        sc_sel          <= ship_sel;

        case (state)
            ST_IDLE: begin
                busy <= 1'b0;
                if (draw_go) begin
                    // Freeze live physics inputs for this whole erase/redraw pass
                    d_pos0_x      <= pos0_x;
                    d_pos0_y      <= pos0_y;
                    d_pos1_x      <= pos1_x;
                    d_pos1_y      <= pos1_y;
                    d_thrust0     <= thrusting0;
                    d_thrust1     <= thrusting1;
                    d_shot_on     <= shot_on;
                    d_shot_x      <= shot_x;
                    d_shot_y      <= shot_y;
                    d_shot_vx     <= shot_vx;
                    d_shot_vy     <= shot_vy;
                    // Boom retired -- keep latches cleared
                    d_boom0       <= 5'd0;
                    d_boom1       <= 5'd0;
                    d_boom0_x     <= 16'sd0;
                    d_boom0_y     <= 16'sd0;
                    d_boom_x      <= 16'sd0;
                    d_boom_y      <= 16'sd0;
                    d_boom0_dirty <= 1'b0;
                    d_boom_dirty  <= 1'b0;
                    clr_boom0_dirty <= 1'b1;
                    clr_boom1_dirty <= 1'b1;
                    busy        <= 1'b1;
                    line_active <= 1'b0;
                    plot_col    <= COL_OFF;
                    ei          <= 5'd0;
                    if (have_prev0 || have_prev1) begin
                        ship_sel <= 1'b0;
                        sc_sel   <= 1'b0;
                        state    <= ST_ERASE;
                    end else
                        route_draw;
                end
            end

            ST_CLEAR: begin
                clear_mode <= 1'b1;
                busy       <= 1'b1;
                if (clear_addr == FB_SZ - 1) begin
                    clear_addr <= 19'd0;
                    route_draw;
                end else
                    clear_addr <= clear_addr + 19'd1;
            end

            ST_ERASE: begin
                if (!line_active) begin
                    if (ei == 5'd0) begin
                        load_ship_geom(ship_sel);
                        nvert <= (!ship_sel) ? 5'd8 : 5'd4;
                        nedge <= (!ship_sel) ? 5'd10 : 5'd4;
                        hitch <= (!ship_sel) ? 5'd4 : 5'd2;
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
                            sc_sel   <= 1'b1;
                            ei <= 5'd0;
                        end else
                            route_draw;
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
                        plot_col <= COL_OFF;
                        ei <= ei + 5'd1;
                    end
                end else begin
                    plot_col <= COL_OFF;
                    if ((b_x >= 0) && (b_x < FB_W) && (b_y >= 0) && (b_y < FB_H)) begin
                        plot_en <= 1'b1;
                        plot_x <= b_x[9:0];
                        plot_y <= b_y[8:0];
                    end
                    step_bresenham;
                end
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
                    px = ship_sel ? d_pos1_x : d_pos0_x;
                    py = ship_sel ? d_pos1_y : d_pos0_y;
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
                        if (ship_sel ? d_thrust1 : d_thrust0) begin
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
                        plot_col <= ship_sel ? COL_AI : COL_PL;
                        ei <= ei + 5'd1;
                    end
                end else begin
                    plot_col <= ship_sel ? COL_AI : COL_PL;
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
                    plot_col <= ship_sel ? COL_AI : COL_PL;
                end else begin
                    plot_col <= ship_sel ? COL_AI : COL_PL;
                    if ((b_x >= 0) && (b_x < FB_W) && (b_y >= 0) && (b_y < FB_H)) begin
                        plot_en <= 1'b1;
                        plot_x <= b_x[9:0];
                        plot_y <= b_y[8:0];
                    end
                    if ((b_x == end_x) && (b_y == end_y)) begin
                        line_active <= 1'b0;
                        vi <= 5'd0;
                        state <= ST_DONE;
                    end else if (line_steps >= 13'd4094) begin
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
                    prev_thrust0 <= d_thrust0;
                    vi           <= 5'd0;
                    ei           <= 5'd0;
                    if (d_pos1_x[23]) begin
                        have_prev1 <= 1'b0;
                        si         <= 5'd0;
                        shot_phase <= 1'b0;
                        state      <= ST_SHOT;
                    end else begin
                        ship_sel <= 1'b1;
                        sc_sel   <= 1'b1;
                        nvert    <= 5'd4;
                        nedge    <= 5'd4;
                        hitch    <= 5'd2;
                        state    <= ST_XFORM;
                    end
                end else begin
                    have_prev1   <= 1'b1;
                    prev_thrust1 <= d_thrust1;
                    ship_sel     <= 1'b0;
                    sc_sel       <= 1'b0;
                    vi           <= 5'd0;
                    ei           <= 5'd0;
                    si           <= 5'd0;
                    shot_phase   <= 1'b0;
                    state        <= ST_SHOT;
                end
            end

            // Indexed shots: si=0..3, phase 0=erase prev streak, 1=draw
            ST_SHOT: begin
                if (!line_active) begin
                    if (si >= 5'd8) begin
                        ei <= 5'd0;
                        go_idle_done;
                    end else if (shot_phase == 1'b0) begin
                        if (shot_have_prev[si[2:0]]) begin
                            start_line($signed({6'b0, shot_ox[si[2:0]]}),
                                       $signed({7'b0, shot_oy[si[2:0]]}),
                                       $signed({6'b0, shot_ox2[si[2:0]]}),
                                       $signed({7'b0, shot_oy2[si[2:0]]}));
                            line_active <= 1'b1;
                            plot_col    <= COL_OFF;
                        end
                        shot_phase <= 1'b1;
                    end else begin
                        if (shot_on_i) begin
                            begin : sdir
                                reg signed [15:0] sx, sy, x0, y0, x1, y1;
                                x0 = $signed(shot_x_i[23:8]);
                                y0 = $signed(shot_y_i[23:8]);
                                sx = shot_vx_i >>> 9;
                                sy = shot_vy_i >>> 9;
                                if (sx == 0 && sy == 0) sx = 16'sd5;
                                x1 = x0 + sx;
                                y1 = y0 + sy;
                                start_line(x0, y0, x1, y1);
                                shot_ox[si[2:0]]  <= x0[9:0];
                                shot_oy[si[2:0]]  <= y0[8:0];
                                shot_ox2[si[2:0]] <= x1[9:0];
                                shot_oy2[si[2:0]] <= y1[8:0];
                            end
                            line_active <= 1'b1;
                            plot_col    <= COL_SHOT;
                            shot_have_prev[si[2:0]] <= 1'b1;
                        end else
                            shot_have_prev[si[2:0]] <= 1'b0;
                        shot_phase <= 1'b0;
                        si <= si + 5'd1;
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

            // Boom retired -- if entered, exit immediately
            ST_BOOM: begin
                go_idle_done;
            end

            default: state <= ST_IDLE;
        endcase
    end
end

endmodule
