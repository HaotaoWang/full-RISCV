`timescale 1ns/1ps

module arch_test_tb;
    reg clk = 0;
    reg rst = 1;
    reg [4095:0] hex_file;
    wire [7:0] uart_data;
    wire uart_start;
    wire [31:0] retire_instruction;
    wire [3:0] led;
    integer cycles;
    integer max_cycles;
    integer tohost_word;
    integer trace_start;
    integer trace_stop;

    always #5 clk = ~clk;

    RV32_SoC_AXI_Top #(
        .RAM_ADDR_WIDTH(18)
    ) soc (
        .clk(clk), .rst(rst), .UART_busy(1'b0),
        .mmio_uart_tx_data(uart_data), .mmio_uart_tx_start(uart_start),
        .retire_instruction(retire_instruction), .mmio_led(led)
    );

    always @(posedge clk) begin
        if (!rst && trace_start >= 0 && cycles >= trace_start && cycles < trace_stop)
            $display("ARCH_PIPE: cycle=%0d pc=%08x ID=%08x/%08x EX=%08x/%08x MEM=%08x/%08x WB=%08x/%08x alu=%08x MEMalu=%08x stall=%b%b%b%b",
                     cycles, soc.cpu_core.pc,
                     soc.cpu_core.ID_pc, soc.cpu_core.ID_instruction,
                     soc.cpu_core.EX_pc, soc.cpu_core.EX_instruction,
                     soc.cpu_core.MEM_pc, soc.cpu_core.MEM_instruction,
                     soc.cpu_core.WB_pc, soc.cpu_core.WB_instruction,
                     soc.cpu_core.alu_result, soc.cpu_core.MEM_alu_result,
                     soc.cpu_core.IF_ID_stall, soc.cpu_core.ID_EX_stall,
                     soc.cpu_core.EX_MEM_stall, soc.cpu_core.MEM_WB_stall);
        if (!rst && tohost_word >= 0 &&
            soc.main_memory.mem[tohost_word] == 32'd1 &&
            soc.main_memory.mem[tohost_word + 1] == 32'd0) begin
            $display("ARCH_TEST_HTIF: SIGRUN cycles=%0d pc=%08x", cycles, soc.cpu_core.pc);
            $finish;
        end else if (!rst && tohost_word >= 0 &&
                     soc.main_memory.mem[tohost_word] == 32'd3 &&
                     soc.main_memory.mem[tohost_word + 1] == 32'd0) begin
            $fatal(1, "ARCH_TEST_HTIF: FAIL cycles=%0d pc=%08x", cycles, soc.cpu_core.pc);
        end
        if (!rst && uart_start) begin
            if (uart_data == 8'h04) begin
                $display("\nARCH_TEST_HALT: PASS_PATH cycles=%0d pc=%08x", cycles, soc.cpu_core.pc);
                $finish;
            end else if (uart_data == 8'h05) begin
                $fatal(1, "ARCH_TEST_HALT: FAIL_PATH cycles=%0d pc=%08x", cycles, soc.cpu_core.pc);
            end else begin
                $write("%c", uart_data);
                $fflush();
            end
        end
    end

    initial begin
        if (!$value$plusargs("HEX_FILE=%s", hex_file))
            $fatal(1, "ARCH_TEST_ERROR: missing HEX_FILE plusarg");
        if (!$value$plusargs("MAX_CYCLES=%d", max_cycles))
            max_cycles = 2000000;
        if (!$value$plusargs("TOHOST_WORD=%d", tohost_word))
            tohost_word = -1;
        if (!$value$plusargs("TRACE_START=%d", trace_start))
            trace_start = -1;
        if (!$value$plusargs("TRACE_STOP=%d", trace_stop))
            trace_stop = trace_start + 200;

        $readmemh(hex_file, soc.main_memory.mem);
        repeat (12) @(posedge clk);
        rst = 0;

        for (cycles = 0; cycles < max_cycles; cycles = cycles + 1)
            @(posedge clk);

        $display("ARCH_TEST_DIAG: mem_valid=%b mem_ready=%b read=%b write=%b addr=%08x",
                 soc.cpu_core.mem_valid, soc.cpu_core.mem_ready,
                 soc.cpu_core.MEM_memory_read, soc.cpu_core.MEM_memory_write,
                 soc.cpu_core.MEM_alu_result);
        $display("ARCH_TEST_DIAG: axi_arvalid=%b axi_arready=%b axi_rvalid=%b data_pending=%b",
                 soc.cpu_core.m_axi_mem_arvalid, soc.cpu_core.m_axi_mem_arready,
                 soc.cpu_core.m_axi_mem_rvalid, soc.cpu_core.data_response_pending);
        $display("ARCH_TEST_DIAG: axi_awvalid=%b axi_awready=%b axi_wvalid=%b axi_wready=%b axi_bvalid=%b",
                 soc.cpu_core.m_axi_mem_awvalid, soc.cpu_core.m_axi_mem_awready,
                 soc.cpu_core.m_axi_mem_wvalid, soc.cpu_core.m_axi_mem_wready,
                 soc.cpu_core.m_axi_mem_bvalid);
        $display("ARCH_TEST_DIAG: mcause=%08x mepc=%08x mtval=%08x mscratch=%08x",
                 soc.cpu_core.csr_file.mcause, soc.cpu_core.csr_file.mepc,
                 soc.cpu_core.csr_file.mtval, soc.cpu_core.csr_file.mscratch);
        $display("ARCH_TEST_DIAG: x2=%08x x6=%08x x18=%08x x22=%08x",
                 soc.cpu_core.register_file.registers[2],
                 soc.cpu_core.register_file.registers[6],
                 soc.cpu_core.register_file.registers[18],
                 soc.cpu_core.register_file.registers[22]);
        $fatal(1, "ARCH_TEST_TIMEOUT: cycles=%0d pc=%08x instruction=%08x",
               cycles, soc.cpu_core.pc, retire_instruction);
    end
endmodule
