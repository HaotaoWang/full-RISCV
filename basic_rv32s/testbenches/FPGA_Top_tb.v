// ============================================================================
// FPGA Top 仿真测试台
// ============================================================================
// 用 iverilog 验证 FPGA_Top + axil_ram_init + $readmemh 流程是否正确
// ============================================================================

`timescale 1ns / 1ps

module FPGA_Top_tb;

    reg sys_clk;
    reg sys_rst_n;
    wire [7:0] led;

    FPGA_Top fpga (
        .sys_clk(sys_clk),
        .sys_rst_n(sys_rst_n),
        .led(led)
    );

    // 100MHz 时钟
    initial sys_clk = 0;
    always #5 sys_clk = ~sys_clk;

    always @(posedge sys_clk) begin
        if (fpga.soc_inst.cpu_core.pc != 0) begin
            $display("Time: %0t, PC: %h, x1: %h, x6: %h", $time, fpga.soc_inst.cpu_core.pc, fpga.soc_inst.cpu_core.register_file.registers[1], fpga.soc_inst.cpu_core.register_file.registers[6]);
        end
    end

    initial begin
        $dumpfile("fpga_top_test.vcd");
        $dumpvars(0, FPGA_Top_tb);

        // 按住复位
        sys_rst_n = 0;
        #200;

        // 释放复位
        sys_rst_n = 1;

        // 运行足够时间
        #5000;

        // 打印结果
        $display("========================================");
        $display(" FPGA Top 仿真结果 (带 hex 初始化)");
        $display("========================================");
        $display(" x1 = %0d ", fpga.soc_inst.cpu_core.register_file.registers[1]);
        $display(" x6 = %0d ", fpga.soc_inst.cpu_core.register_file.registers[6]);
        $display(" LED = %08b", led);
        $display("========================================");

        if (led == 8'b00000011) begin
            $display(" [PASS] FPGA 流程验证通过! LED correctly turned on!");
        end else begin
            $display(" [FAIL] 验证失败! LED is %08b", led);
        end
        $display("========================================");

        $finish;
    end

endmodule
