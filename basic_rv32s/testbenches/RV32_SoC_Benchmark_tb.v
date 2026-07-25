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

        soc.main_memory.mem[0] = 32'h06400113; // addi x2, x0, 100
        soc.main_memory.mem[1] = 32'h00000193; // addi x3, x0, 0
        soc.main_memory.mem[2] = 32'hB0002273; // csrr x4, mcycle
        soc.main_memory.mem[3] = 32'hB02022F3; // csrr x5, minstret
        soc.main_memory.mem[4] = 32'h00118193; // addi x3, x3, 1
        soc.main_memory.mem[5] = 32'h023181B3; // mul x3, x3, x3
        soc.main_memory.mem[6] = 32'hFFF10113; // addi x2, x2, -1
        soc.main_memory.mem[7] = 32'hFE011AE3; // bne x2, x0, loop (-12)
        soc.main_memory.mem[8] = 32'hB0002373; // csrr x6, mcycle
        soc.main_memory.mem[9] = 32'hB02023F3; // csrr x7, minstret
        soc.main_memory.mem[10] = 32'h40430433; // sub x8, x6, x4
        soc.main_memory.mem[11] = 32'h405384B3; // sub x9, x7, x5
        soc.main_memory.mem[12] = 32'h00001537; // lui x10, 1 -> 0x1000
        soc.main_memory.mem[13] = 32'h00852023; // sw x8, 0(x10) -> cycles
        soc.main_memory.mem[14] = 32'h00952223; // sw x9, 4(x10) -> insts
        soc.main_memory.mem[15] = 32'h00352423; // sw x3, 8(x10) -> sum
        soc.main_memory.mem[16] = 32'h0000006F; // j 0
        
        for (i = 17; i < 2000; i = i + 1) begin
            soc.main_memory.mem[i] = 32'h00000013;
        end

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

endmodule
