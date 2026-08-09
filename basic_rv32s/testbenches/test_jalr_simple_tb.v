`timescale 1ns / 1ps

module test_jalr_simple_tb;
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
    reg [31:0] last_t0 = 0;

    always @(posedge clk) begin
        if (!rst) begin
            cycle = cycle + 1;
            
            // 监控 t0 寄存器变化
            if (soc.cpu_core.register_file.registers[5] != last_t0) begin
                last_t0 = soc.cpu_core.register_file.registers[5];
                $display("[%0t] t0 = 0x%h, PC = 0x%h", $time, last_t0, soc.cpu_core.pc);
                
                if (last_t0 == 32'hFFFF) begin
                    $display("\n✅ 测试通过！JALR 正常工作");
                    #100;
                    $finish;
                end
            end
            
            // 监控 JALR 执行
            if (soc.cpu_core.opcode == 7'b1100111) begin
                $display("[%0t] JALR detected: PC=0x%h, rs1=x%0d, base=0x%h, imm=0x%h, target=0x%h",
                    $time, soc.cpu_core.ID_pc, soc.cpu_core.rs1,
                    soc.cpu_core.jalr_forwarded_rs1, soc.cpu_core.imm,
                    soc.cpu_core.ID_jump_target);
            end
            
            if (cycle > 100) begin
                $display("\n❌ 超时！t0=%h, PC=%h", last_t0, soc.cpu_core.pc);
                $finish;
            end
        end
    end

    initial begin
        $dumpfile("jalr_simple.vcd");
        $dumpvars(0, test_jalr_simple_tb);
        
        rst = 1; UART_busy = 0;
        #100;
        
        $readmemh("test_jalr_simple.hex", soc.main_memory.mem);
        $display("加载测试程序: test_jalr_simple.hex\n");
        
        #20; rst = 0;
        $display("开始测试...\n");
    end
endmodule
