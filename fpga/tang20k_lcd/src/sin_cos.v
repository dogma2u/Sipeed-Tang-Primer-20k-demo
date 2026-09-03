// Angle 0..255 = full turn. Output Q8.8 signed (1.0 ~= 256).

module sin_cos (
    input  wire [7:0]         angle,
    output reg  signed [15:0] sin_val,
    output reg  signed [15:0] cos_val
);

function [8:0] qsin;
    input [5:0] i;
    begin
        case (i)
            6'd0:  qsin = 9'd0;
            6'd1:  qsin = 9'd6;
            6'd2:  qsin = 9'd13;
            6'd3:  qsin = 9'd19;
            6'd4:  qsin = 9'd25;
            6'd5:  qsin = 9'd31;
            6'd6:  qsin = 9'd37;
            6'd7:  qsin = 9'd44;
            6'd8:  qsin = 9'd50;
            6'd9:  qsin = 9'd56;
            6'd10: qsin = 9'd62;
            6'd11: qsin = 9'd68;
            6'd12: qsin = 9'd74;
            6'd13: qsin = 9'd80;
            6'd14: qsin = 9'd86;
            6'd15: qsin = 9'd92;
            6'd16: qsin = 9'd98;
            6'd17: qsin = 9'd104;
            6'd18: qsin = 9'd109;
            6'd19: qsin = 9'd115;
            6'd20: qsin = 9'd121;
            6'd21: qsin = 9'd126;
            6'd22: qsin = 9'd132;
            6'd23: qsin = 9'd137;
            6'd24: qsin = 9'd142;
            6'd25: qsin = 9'd147;
            6'd26: qsin = 9'd152;
            6'd27: qsin = 9'd157;
            6'd28: qsin = 9'd162;
            6'd29: qsin = 9'd167;
            6'd30: qsin = 9'd171;
            6'd31: qsin = 9'd176;
            6'd32: qsin = 9'd181;
            6'd33: qsin = 9'd185;
            6'd34: qsin = 9'd189;
            6'd35: qsin = 9'd193;
            6'd36: qsin = 9'd197;
            6'd37: qsin = 9'd200;
            6'd38: qsin = 9'd204;
            6'd39: qsin = 9'd207;
            6'd40: qsin = 9'd210;
            6'd41: qsin = 9'd213;
            6'd42: qsin = 9'd216;
            6'd43: qsin = 9'd218;
            6'd44: qsin = 9'd221;
            6'd45: qsin = 9'd223;
            6'd46: qsin = 9'd225;
            6'd47: qsin = 9'd227;
            6'd48: qsin = 9'd229;
            6'd49: qsin = 9'd231;
            6'd50: qsin = 9'd233;
            6'd51: qsin = 9'd234;
            6'd52: qsin = 9'd236;
            6'd53: qsin = 9'd237;
            6'd54: qsin = 9'd238;
            6'd55: qsin = 9'd239;
            6'd56: qsin = 9'd240;
            6'd57: qsin = 9'd241;
            6'd58: qsin = 9'd242;
            6'd59: qsin = 9'd243;
            6'd60: qsin = 9'd244;
            6'd61: qsin = 9'd244;
            6'd62: qsin = 9'd245;
            6'd63: qsin = 9'd245;
            default: qsin = 9'd0;
        endcase
    end
endfunction

function signed [15:0] sin_turn;
    input [7:0] a;
    reg   [8:0] mag;
    begin
        case (a[7:6])
            2'b00: begin
                mag = qsin(a[5:0]);
                sin_turn = $signed({7'd0, mag});
            end
            2'b01: begin
                mag = qsin(6'd63 - a[5:0]);
                sin_turn = $signed({7'd0, mag});
            end
            2'b10: begin
                mag = qsin(a[5:0]);
                sin_turn = -$signed({7'd0, mag});
            end
            default: begin
                mag = qsin(6'd63 - a[5:0]);
                sin_turn = -$signed({7'd0, mag});
            end
        endcase
    end
endfunction

always @* begin
    sin_val = sin_turn(angle);
    cos_val = sin_turn(angle + 8'd64);
end

endmodule
