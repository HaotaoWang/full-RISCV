// ============================================================================
// RV32 SoC AXI Testbench
// ============================================================================
// 测试目标: 验证 AXI 总线架构下 CPU 能正确执行指令
// 测试用例: addi x1, x0, 12  ->  addi x2, x0, 10  ->  mul x3, x1, x2
// 预期结果: x3 = 120 (0x78)
// ============================================================================

`timescale 1ns / 1ps

module RV32_SoC_AXI_tb;

    reg clk;
    reg rst;
    reg UART_busy;
    wire [31:0] retire_instruction;
    wire [7:0]  mmio_uart_tx_data;
    wire        mmio_uart_tx_start;

    // 实例化 SoC 顶层
    RV32_SoC_AXI_Top #(
        .RAM_ADDR_WIDTH(16)
    ) soc (
        .clk(clk),
        .rst(rst),
        .UART_busy(UART_busy),
        .retire_instruction(retire_instruction),
        .mmio_uart_tx_data(mmio_uart_tx_data),
        .mmio_uart_tx_start(mmio_uart_tx_start)
    );

    // 时钟生成: 10ns 周期 (100MHz)
    initial clk = 0;
    always #5 clk = ~clk;

    // 指令编码 (RV32IM):
    // addi x1, x0, 12   -> 0x00C00093
    // addi x2, x0, 10   -> 0x00A00113
    // mul  x3, x1, x2   -> 0x022081B3
    // nop (addi x0,x0,0) -> 0x00000013

    integer i;

    initial begin
        // 波形输出
        $dumpfile("soc_axi_test.vcd");
        $dumpvars(0, RV32_SoC_AXI_tb);

        // 初始化
        rst = 1;
        UART_busy = 0;

        // 等待复位稳定
        #100;

        // 在复位期间，往 RAM 里预装载测试指令
        // axil_ram 内部存储: mem[word_addr] = 32bit 数据
        // PC=0x00 -> word_addr=0, PC=0x04 -> word_addr=1, ...
        // axil_ram 的 VALID_ADDR_WIDTH = ADDR_WIDTH - clog2(STRB_WIDTH)
        //                              = 16 - clog2(4) = 16 - 2 = 14
        // 所以 mem 的索引范围是 [0 : 2^14-1] = [0:16383]
        
        // 但是 axil_ram 内部地址计算:
        //   s_axil_awaddr_valid = s_axil_awaddr >> (ADDR_WIDTH - VALID_ADDR_WIDTH)
        //                       = addr >> (16 - 14) = addr >> 2
        // 所以 mem[0] 对应地址 0x0000, mem[1] 对应地址 0x0004, 完美!

        soc.main_memory.mem[0] = 32'h00C00093;  // addi x1, x0, 12
        soc.main_memory.mem[1] = 32'h00A00113;  // addi x2, x0, 10
        soc.main_memory.mem[2] = 32'h022081B3;  // mul  x3, x1, x2
        soc.main_memory.mem[3] = 32'h00000013;  // nop
        soc.main_memory.mem[4] = 32'h00000013;  // nop
        soc.main_memory.mem[5] = 32'h00000013;  // nop
        soc.main_memory.mem[6] = 32'h00000013;  // nop
        soc.main_memory.mem[7] = 32'h00000013;  // nop
        soc.main_memory.mem[8] = 32'h00000013;  // nop
        soc.main_memory.mem[9] = 32'h00000013;  // nop

        // 填充剩余空间为 nop (防止 X 态传播)
        for (i = 10; i < 100; i = i + 1) begin
            soc.main_memory.mem[i] = 32'h00000013;  // nop
        end

        // 释放复位
        #20;
        rst = 0;

        // 运行足够多的周期让指令通过 AXI 总线和 5 级流水线
        // AXI interconnect 引入额外延迟, 需要更多周期
        #2000;

        // 打印寄存器状态
        $display("========================================");
        $display(" RV32 SoC AXI 仿真结果");
        $display("========================================");
        $display(" x1 = %0d (期望: 12)", soc.cpu_core.register_file.registers[1]);
        $display(" x2 = %0d (期望: 10)", soc.cpu_core.register_file.registers[2]);
        $display(" x3 = %0d (期望: 120)", soc.cpu_core.register_file.registers[3]);
        $display("========================================");

        if (soc.cpu_core.register_file.registers[3] == 32'd120) begin
            $display(" [PASS] AXI SoC 测试通过! 12 * 10 = 120");
        end else begin
            $display(" [FAIL] AXI SoC 测试失败!");
            $display("        x3 实际值 = 0x%08H", soc.cpu_core.register_file.registers[3]);
        end

        $display("========================================");
        $finish;
    end

endmodule
