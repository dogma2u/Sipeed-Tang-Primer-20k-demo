// 800x480 LCD timing (Sipeed 5"). Active-low HSYNC/VSYNC.
// Composites RGB565 scene pixels with a 5px border (white, or red in black-hole mode).

module lcd_timing (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [4:0] pix_r_i,
    input  wire [5:0] pix_g_i,
    input  wire [4:0] pix_b_i,
    input  wire       border_red,
    output wire       lcd_clk,
    output reg        lcd_hsync,
    output reg        lcd_vsync,
    output reg        lcd_de,
    output reg  [4:0] lcd_r,
    output reg  [5:0] lcd_g,
    output reg  [4:0] lcd_b,
    output reg  [9:0] pix_x,
    output reg  [9:0] pix_y,
    output reg        de_now,
    output reg        frame_start
);

localparam [11:0] H_PULSE  = 12'd1;
localparam [11:0] H_BP     = 12'd182;
localparam [11:0] H_ACTIVE = 12'd800;
localparam [11:0] H_FP     = 12'd210;
localparam [11:0] H_TOTAL  = H_ACTIVE + H_BP + H_FP;

localparam [11:0] V_PULSE  = 12'd5;
localparam [11:0] V_BP     = 12'd6;
localparam [11:0] V_ACTIVE = 12'd480;
localparam [11:0] V_FP     = 12'd62;
localparam [11:0] V_TOTAL  = V_ACTIVE + V_BP + V_FP;

localparam [11:0] BORDER   = 12'd5;

reg [11:0] h_cnt;
reg [11:0] v_cnt;

wire h_active = (h_cnt >= H_BP) && (h_cnt < (H_BP + H_ACTIVE));
wire v_active = (v_cnt >= V_BP) && (v_cnt < (V_BP + V_ACTIVE));
wire de       = h_active && v_active;

wire [11:0] x_now = h_cnt - H_BP;
wire [11:0] y_now = v_cnt - V_BP;

wire on_border = de &&
                 ((x_now < BORDER) || (x_now >= (H_ACTIVE - BORDER)) ||
                  (y_now < BORDER) || (y_now >= (V_ACTIVE - BORDER)));

wire hs = ~((h_cnt >= H_PULSE) && (h_cnt <= (H_TOTAL - H_FP)));
wire vs = ~((v_cnt >= V_PULSE) && (v_cnt <= V_TOTAL));
wire at_frame = (h_cnt == 12'd0) && (v_cnt == 12'd0);

assign lcd_clk = clk;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        h_cnt <= 12'd0;
        v_cnt <= 12'd0;
    end else if (h_cnt == (H_TOTAL - 12'd1)) begin
        h_cnt <= 12'd0;
        if (v_cnt == (V_TOTAL - 12'd1))
            v_cnt <= 12'd0;
        else
            v_cnt <= v_cnt + 12'd1;
    end else begin
        h_cnt <= h_cnt + 12'd1;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        lcd_hsync   <= 1'b1;
        lcd_vsync   <= 1'b1;
        lcd_de      <= 1'b0;
        lcd_r       <= 5'd0;
        lcd_g       <= 6'd0;
        lcd_b       <= 5'd0;
        pix_x       <= 10'd0;
        pix_y       <= 10'd0;
        de_now      <= 1'b0;
        frame_start <= 1'b0;
    end else begin
        lcd_hsync   <= hs;
        lcd_vsync   <= vs;
        lcd_de      <= de;
        lcd_r       <= on_border ? 5'h1F : (de ? pix_r_i : 5'h00);
        lcd_g       <= on_border ? (border_red ? 6'h00 : 6'h3F) : (de ? pix_g_i : 6'h00);
        lcd_b       <= on_border ? (border_red ? 5'h00 : 5'h1F) : (de ? pix_b_i : 5'h00);
        pix_x       <= x_now[9:0];
        pix_y       <= y_now[9:0];
        de_now      <= de;
        frame_start <= at_frame;
    end
end

endmodule
