// ============================================================================
// JAL + LUI 快速测试 Testbench
// ============================================================================
// 目标：验证 JAL 跳转后的 LUI 指令是否被正确执行

`timescale 1ns / 1ps

module test_jal_lui_tb;

    reg clk;
    reg rst;

    wire [31:0] retire_instruction;
    wire [7:0]  mmio_uart_tx_data;
    wire        mmio_uart_tx_start;

    // 实例化 SoC
    RV32_SoC_AXI_Top #(
        .RAM_ADDR_WIDTH(16)
    ) soc (
        .clk(clk),
        .rst(rst),
        .UART_busy(1'b0),
        .retire_instruction(retire_instruction),
        .mmio_uart_tx_data(mmio_uart_tx_data),
        .mmio_uart_tx_start(mmio_uart_tx_start)
    );

    // 时钟生成: 10ns 周期 (100MHz)
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("test_jal_lui.vcd");
        $dumpvars(0, test_jal_lui_tb);

        // 初始化
        rst = 1;
        #100;

        // 手动加载测试程序（使用正确的编码）
        // 0x00: jal x1, 0x0c (跳转到 target)
        soc.main_memory.mem[0] = 32'h00c000ef;
        // 0x04: addi x2, x0, 999 (错误路径标记)
        soc.main_memory.mem[1] = 32'h3e700113;
        // 0x08: j 0x08 (死循环)
        soc.main_memory.mem[2] = 32'h0000006f;

        // 0x0c: lui x3, 0x12345 (关键！这条指令不应该被跳过)
        soc.main_memory.mem[3] = 32'h123451b7;
        // 0x10: addi x3, x3, 0x678
        soc.main_memory.mem[4] = 32'h67818193;
        // 0x14: j 0x14 (死循环)
        soc.main_memory.mem[5] = 32'h0000006f;

        // 释放复位
        #20;
        rst = 0;

        // 运行足够的周期
        #5000;

        $display("========================================");
        $display(" JAL + LUI Test Results");
        $display("========================================");
        $display(" x1 (ra)  = 0x%h (应该是 0x00000004)", soc.cpu_core.register_file.registers[1]);
        $display(" x2       = 0x%h (应该是 0x00000000)", soc.cpu_core.register_file.registers[2]);
        $display(" x3       = 0x%h (应该是 0x12345678)", soc.cpu_core.register_file.registers[3]);

        if (soc.cpu_core.register_file.registers[3] == 32'h12345678) begin
            $display(" ✅ PASS: LUI 指令正确执行!");
        end else begin
            $display(" ❌ FAIL: LUI 指令被跳过! x3 = 0x%h", soc.cpu_core.register_file.registers[3]);
        end

        $display("========================================");
        $finish;
    end

    // 监控关键信号
    always @(posedge clk) begin
        if (soc.cpu_core.ID_jump) begin
            $display("[%0t] JAL_DECODE: pc=%h, ID_pc=%h, target=%h, next_pc=%h",
                     $time, soc.cpu_core.pc, soc.cpu_core.ID_pc, soc.cpu_core.ID_jump_target,
                     soc.cpu_core.next_pc);
        end

        // 监控冲刷信号
        if (soc.cpu_core.IF_ID_flush) begin
            $display("[%0t] FLUSH: IF_ID=1, current_pc=%h, next_pc=%h",
                     $time, soc.cpu_core.pc, soc.cpu_core.next_pc);
        end

        // 监控 ID 阶段的 PC 和指令
        if (soc.cpu_core.ID_pc < 32'h20) begin  // 只看程序开始部分
            $display("[%0t] ID: ID_pc=%h, opcode=%h",
                     $time, soc.cpu_core.ID_pc, soc.cpu_core.opcode);
        end

        // 监控 WB 阶段指令退休
        if (soc.cpu_core.WB_register_write_enable && soc.cpu_core.WB_rd != 0) begin
            $display("[%0t] WB: PC=%h, rd=x%0d, data=%h",
                     $time, soc.cpu_core.WB_pc, soc.cpu_core.WB_rd,
                     soc.cpu_core.register_file_write_data);
        end
    end

endmodule
