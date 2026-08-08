// 超级简化的测试：只测试JAL跳转
// 不使用复杂的SoC，直接测试核心模块

`timescale 1ns / 1ps

module simple_jal_test;
    reg clk, rst;

    // 时钟
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("simple_jal.vcd");
        $dumpvars(0, simple_jal_test);

        rst = 1;
        #50;
        rst = 0;

        // 运行100个周期
        #1000;

        $display("Test completed");
        $finish;
    end

    // 我们需要一个最小化的CPU实例
    // 但这需要很多模块...让我换个思路

endmodule
