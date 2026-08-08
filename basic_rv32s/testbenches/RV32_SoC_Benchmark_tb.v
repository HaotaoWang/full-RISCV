`timescale 1ns / 1ps

module RV32_SoC_Benchmark_tb;

    reg clk;
    reg rst;
    reg UART_busy;
    wire [31:0] retire_instruction;
    wire [7:0]  mmio_uart_tx_data;
    wire        mmio_uart_tx_start;
    wire [3:0]  mmio_led;

    RV32_SoC_AXI_Top #(
        .RAM_ADDR_WIDTH(16)
    ) soc (
        .clk(clk),
        .rst(rst),
        .UART_busy(UART_busy),
        .retire_instruction(retire_instruction),
        .mmio_uart_tx_data(mmio_uart_tx_data),
        .mmio_uart_tx_start(mmio_uart_tx_start),
        .mmio_led(mmio_led)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer i;

    initial begin
        $dumpfile("benchmark.vcd");
        $dumpvars(0, RV32_SoC_Benchmark_tb);
        rst = 1;
        UART_busy = 0;
        #100;

        $readmemh("d:/riscv/basic_rv32s/software/build/coremark/coremark.hex", soc.main_memory.mem);

        #20;
        rst = 0;

        // Run enough time for 100 iterations of loop
        // Each iteration is ~4 insts. With IPC~1, 400 cycles = 4000ns.
        // Cache miss takes ~15 cycles. Let's wait 500000ns.
        #500000;

        $display("========================================");
        $display(" RV32 SoC 跑分结果 (IPC Benchmark) ");
        $display("========================================");
        
        // 开天眼：直接从 CPU 的寄存器堆里拿结果！
        $display(" 耗时周期 (Cycles) : %0d", soc.cpu_core.register_file.registers[8]);
        $display(" 执行指令 (Insts)  : %0d", soc.cpu_core.register_file.registers[9]);
        $display(" 最终结果 (Math)   : %0d", soc.cpu_core.register_file.registers[3]);
        
        if (soc.cpu_core.register_file.registers[9] > 0) begin
            $display(" ========================================");
            $display(" 你的 IPC = %f", 
                     $itor(soc.cpu_core.register_file.registers[9]) / $itor(soc.cpu_core.register_file.registers[8]));
            $display(" ========================================");
        end

        $finish;
    end

    // 监控 UART 发送，并打印到仿真控制台
    always @(posedge clk) begin
        if (mmio_uart_tx_start) begin
            $write("%c", mmio_uart_tx_data);
        end
    end

endmodule
