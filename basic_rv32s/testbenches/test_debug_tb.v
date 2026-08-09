`timescale 1ns / 1ps

module test_debug_tb;
    reg clk;
    reg rst;
    reg UART_busy;
    wire [31:0] retire_instruction;
    wire [7:0]  mmio_uart_tx_data;
    wire        mmio_uart_tx_start;

    RV32_SoC_AXI_Top #(.RAM_ADDR_WIDTH(16)) soc (
        .clk(clk), .rst(rst), .UART_busy(UART_busy),
        .retire_instruction(retire_instruction),
        .mmio_uart_tx_data(mmio_uart_tx_data),
        .mmio_uart_tx_start(mmio_uart_tx_start)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer cycle = 0;

    always @(posedge clk) begin
        if (!rst) begin
            cycle = cycle + 1;
            
            // 打印每个周期的关键信号
            $display("[%0t] Cycle %0d: PC=0x%h, inst=0x%h, rst=%b, if_ready=%b, mem_ready=%b",
                $time, cycle, soc.cpu_core.pc, soc.cpu_core.instruction,
                rst, soc.cpu_core.if_ready, soc.cpu_core.mem_ready);
            
            if (cycle >= 20) begin
                $display("\n调试信息：前20个周期已执行");
                $finish;
            end
        end
    end

    initial begin
        rst = 1; UART_busy = 0;
        #100;
        
        $display("加载测试程序...");
        $readmemh("test_jalr_simple.hex", soc.main_memory.mem);
        
        // 检查内存前几个字
        $display("内存内容检查:");
        $display("  mem[0] = 0x%h", soc.main_memory.mem[0]);
        $display("  mem[1] = 0x%h", soc.main_memory.mem[1]);
        $display("  mem[2] = 0x%h", soc.main_memory.mem[2]);
        
        #20; rst = 0;
        $display("\n复位释放，开始执行...\n");
    end
endmodule
