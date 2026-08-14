`timescale 1ns/1ps

module rv32m_unit_tb;
    reg [31:0] a, b;
    reg [2:0] op;
    wire [31:0] result;

    Hardware_Multiplier dut (.src_A(a), .src_B(b), .mul_op(op), .mul_result(result));

    task check;
        input [2:0] test_op;
        input [31:0] test_a, test_b, expected;
        begin
            op = test_op; a = test_a; b = test_b; #1;
            if (result !== expected)
                $fatal(1, "REGRESSION_FAIL: rv32m op=%b a=%h b=%h got=%h expected=%h",
                       op, a, b, result, expected);
        end
    endtask

    initial begin
        check(3'b000, 32'hffffffff, 32'd3, 32'hfffffffd);
        check(3'b001, 32'h80000000, 32'd2, 32'hffffffff);
        check(3'b010, 32'hfffffffe, 32'hffffffff, 32'hfffffffe);
        check(3'b011, 32'hffffffff, 32'hffffffff, 32'hfffffffe);
        check(3'b100, -32'sd20, 32'd3, -32'sd6);
        check(3'b100, 32'h80000000, 32'hffffffff, 32'h80000000);
        check(3'b100, 32'd7, 32'd0, 32'hffffffff);
        check(3'b101, 32'hfffffffe, 32'd2, 32'h7fffffff);
        check(3'b101, 32'd7, 32'd0, 32'hffffffff);
        check(3'b110, -32'sd20, 32'd3, -32'sd2);
        check(3'b110, 32'h80000000, 32'hffffffff, 32'd0);
        check(3'b110, 32'h12345678, 32'd0, 32'h12345678);
        check(3'b111, 32'hfffffffe, 32'd3, 32'd2);
        check(3'b111, 32'h12345678, 32'd0, 32'h12345678);
        $display("REGRESSION_PASS: rv32m_unit");
        $finish;
    end
endmodule
