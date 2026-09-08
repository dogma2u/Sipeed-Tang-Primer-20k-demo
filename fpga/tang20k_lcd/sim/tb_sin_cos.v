// tb_sin_cos.v -- smoke checks for sin_cos.v (combinational LUT)
// Angle 0..255 = full turn. Output Q8.8 signed (1.0 ~= 256).
// Run with Icarus: iverilog -o tb_sin_cos.vvp ../src/sin_cos.v tb_sin_cos.v && vvp tb_sin_cos.vvp

`timescale 1ns/1ps

module tb_sin_cos;
    reg  [7:0]         angle;
    wire signed [15:0] sin_val;
    wire signed [15:0] cos_val;
    integer            errors;

    sin_cos dut (
        .angle   (angle),
        .sin_val (sin_val),
        .cos_val (cos_val)
    );

    task check_signs;
        input [7:0] a;
        input       sin_pos; // 1 = expect sin >= 0
        input       cos_pos; // 1 = expect cos >= 0
        begin
            angle = a;
            #1;
            if (sin_pos && (sin_val < 0)) begin
                $display("FAIL angle=%0d sin=%0d (expected >= 0)", a, sin_val);
                errors = errors + 1;
            end
            if (!sin_pos && (sin_val > 0)) begin
                $display("FAIL angle=%0d sin=%0d (expected <= 0)", a, sin_val);
                errors = errors + 1;
            end
            if (cos_pos && (cos_val < 0)) begin
                $display("FAIL angle=%0d cos=%0d (expected >= 0)", a, cos_val);
                errors = errors + 1;
            end
            if (!cos_pos && (cos_val > 0)) begin
                $display("FAIL angle=%0d cos=%0d (expected <= 0)", a, cos_val);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        errors = 0;

        // Quadrant smoke: 0, 64, 128, 192
        check_signs(8'd0,   1'b1, 1'b1);
        check_signs(8'd64,  1'b1, 1'b0);
        check_signs(8'd128, 1'b0, 1'b0);
        check_signs(8'd192, 1'b0, 1'b1);

        // Angle 0: sin near 0, cos near +256
        angle = 8'd0;
        #1;
        if (sin_val !== 16'sd0) begin
            $display("FAIL angle=0 sin=%0d expected 0", sin_val);
            errors = errors + 1;
        end
        if (cos_val < 16'sd200) begin
            $display("FAIL angle=0 cos=%0d expected near +256", cos_val);
            errors = errors + 1;
        end

        if (errors == 0)
            $display("tb_sin_cos: PASS");
        else
            $display("tb_sin_cos: FAIL (%0d errors)", errors);

        $finish;
    end
endmodule
