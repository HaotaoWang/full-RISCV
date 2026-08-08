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

        $readmemh("timer_test.hex", soc.main_memory.mem);

        // 释放复位
        #20;
        rst = 0;

        // 运行足够多的周期让指令通过 AXI 总线和 5 级流水线
        // AXI interconnect 引入额外延迟, 且 ICache/DCache 复位后需要 ~256 周期清空 Tag
        // 中断测试需要较长时间 (等待延时 + Trap + MRET)
        #25000;

        // 打印寄存器状态
        $display("========================================");
        $display(" RV32 SoC AXI 仿真结果");
        $display("========================================");
        $display(" x3 = %0d (被中断打断的次数)", soc.cpu_core.register_file.registers[3]);
        $display("========================================");

        if (soc.cpu_core.register_file.registers[3] > 0) begin
            $display(" [PASS] 成功检测到定时器中断！ x3 = %0d", soc.cpu_core.register_file.registers[3]);
        end else begin
            $display(" [FAIL] 没有进入定时器中断！");
        end

        $display("========================================");
        $finish;
    end

endmodule
