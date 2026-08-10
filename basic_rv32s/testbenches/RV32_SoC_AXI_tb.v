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

    // UART 串口输出捕获 - 用于显示 RT-Thread 启动信息
    always @(posedge clk) begin
        if (mmio_uart_tx_start && !UART_busy) begin
            $write("%c", mmio_uart_tx_data);
            $fflush();
        end
    end

    // 调试：追踪PC和关键事件
    integer instr_count = 0;
    integer jal_count = 0;
    integer jalr_count = 0;
    integer uart_busy_cycles = 0;
    integer uart_busy_count = 0;
    integer simulation_time_ns = 2000000;
    integer misaligned_trace_count = 0;

    // Optional realistic UART back-pressure.  The original testbench kept
    // UART_busy low permanently, so console output completed before the
    // timer could interrupt most printf paths.  Use +UART_BUSY_CYCLES=4340
    // to model a complete 115200-baud character at a 50 MHz CPU clock.
    always @(posedge clk) begin
        if (rst) begin
            UART_busy <= 1'b0;
            uart_busy_count <= 0;
        end else if (UART_busy) begin
            if (uart_busy_count <= 1) begin
                UART_busy <= 1'b0;
                uart_busy_count <= 0;
            end else begin
                uart_busy_count <= uart_busy_count - 1;
            end
        end else if (mmio_uart_tx_start && uart_busy_cycles > 0) begin
            UART_busy <= 1'b1;
            uart_busy_count <= uart_busy_cycles;
        end
    end


    always @(posedge clk) begin
        if (!rst) begin
            // 追踪ID阶段的JAL指令（只追踪前100个，避免输出过多）
            if (soc.cpu_core.opcode == 7'b1101111 && soc.cpu_core.ID_jump && jal_count < 100) begin
                $display("[%0t] ID_JAL: ID_pc=0x%h, imm=0x%h, ID_jump_target=0x%h",
                    $time, soc.cpu_core.ID_pc, soc.cpu_core.imm, soc.cpu_core.ID_jump_target);
                $display("       Control: ID_jump=%b, pc_stall=%b, trapped=%b, IF_ID_stall=%b",
                    soc.cpu_core.ID_jump, soc.cpu_core.pc_stall,
                    soc.cpu_core.trapped, soc.cpu_core.IF_ID_stall);
            end

            // 追踪WB阶段退休的JAL指令
            if (soc.cpu_core.instruction_retired && soc.cpu_core.WB_register_write_enable && soc.cpu_core.WB_rd != 0) begin
                if (soc.cpu_core.WB_opcode == 7'b1101111) begin // JAL
                    jal_count = jal_count + 1;
                    $display("[%0t] WB_JAL #%0d: PC=0x%h, rd=x%0d, return_addr=0x%h",
                        $time, jal_count, soc.cpu_core.WB_pc, soc.cpu_core.WB_rd,
                        soc.cpu_core.register_file_write_data);
                end
            end

            // 追踪所有JALR指令（包括rd=x0的返回指令ret）
            if (soc.cpu_core.instruction_retired && soc.cpu_core.WB_opcode == 7'b1100111) begin // JALR
                jalr_count = jalr_count + 1;
                if (soc.cpu_core.WB_rd == 0) begin
                    // rd=x0的JALR通常是ret（函数返回）
                    $display("[%0t] WB_JALR(RET) #%0d: PC=0x%h, returned_to=0x%h",
                        $time, jalr_count, soc.cpu_core.WB_pc, soc.cpu_core.pc);
                end else begin
                    // rd!=x0的JALR（链接跳转）
                    $display("[%0t] WB_JALR #%0d: PC=0x%h, rd=x%0d, return_addr=0x%h",
                        $time, jalr_count, soc.cpu_core.WB_pc, soc.cpu_core.WB_rd,
                        soc.cpu_core.register_file_write_data);
                end
            end


            if (soc.cpu_core.instruction_retired)
                instr_count = instr_count + 1;

            // 每10000指令打印一次进度
            if (instr_count % 10000 == 0 && instr_count > 0 && instr_count <= 10000) begin
                $display("[%0t] Progress: %0d instructions, PC=0x%h, JAL=%0d, JALR=%0d",
                    $time, instr_count, soc.cpu_core.pc, jal_count, jalr_count);
            end

            // 检测trap/异常

            if (soc.cpu_core.trapped) begin
                $display("[%0t] *** TRAP *** PC=0x%h, mcause=0x%h, mtval=0x%h",
                    $time, soc.cpu_core.WB_pc,
                    soc.cpu_core.csr_file.mcause,
                    soc.cpu_core.csr_file.mtval);

                if (soc.cpu_core.trap_status == 4'b1001 &&
                    soc.cpu_core.trap_controller.trap_handle_state == 4'b0000) begin
                    $display("[%0t] TIMER_ACCEPT pc=%08x sp=%08x ID=%08x/%08x EX=%08x/%08x MEM=%08x/%08x WB=%08x/%08x",
                        $time, soc.cpu_core.pc,
                        soc.cpu_core.register_file.registers[2],
                        soc.cpu_core.ID_pc, soc.cpu_core.ID_instruction,
                        soc.cpu_core.EX_pc, soc.cpu_core.EX_instruction,
                        soc.cpu_core.MEM_pc, soc.cpu_core.MEM_instruction,
                        soc.cpu_core.WB_pc, soc.cpu_core.WB_instruction);
                    $display("  active_pc=%08x next_pc=%08x stalls=%b%b%b%b flush=%b%b%b%b",
                        soc.cpu_core.trap_controller.incoming_trap_pc,
                        soc.cpu_core.next_pc,
                        soc.cpu_core.IF_ID_stall, soc.cpu_core.ID_EX_stall,
                        soc.cpu_core.EX_MEM_stall, soc.cpu_core.MEM_WB_stall,
                        soc.cpu_core.IF_ID_flush, soc.cpu_core.ID_EX_flush,
                        soc.cpu_core.EX_MEM_flush, soc.cpu_core.MEM_WB_flush);
                end

            end

            // Capture the first raw instruction-misalignment events before
            // the multi-cycle trap controller changes the visible pipeline.
            if (soc.cpu_core.trap_status_raw == 4'b0011 &&
                misaligned_trace_count < 12) begin
                misaligned_trace_count = misaligned_trace_count + 1;
                $display("[%0t] MISALIGN_RAW #%0d src(ID/EX/MEM)=%b/%b/%b",
                    $time, misaligned_trace_count,
                    soc.cpu_core.exception_detector.ID_trapped,
                    soc.cpu_core.exception_detector.EX_trapped,
                    soc.cpu_core.exception_detector.MEM_trapped);
                $display("  PC=%08x ID=%08x/%08x EX=%08x/%08x MEM=%08x/%08x WB=%08x/%08x",
                    soc.cpu_core.pc,
                    soc.cpu_core.ID_pc, soc.cpu_core.ID_instruction,
                    soc.cpu_core.EX_pc, soc.cpu_core.EX_instruction,
                    soc.cpu_core.MEM_pc, soc.cpu_core.MEM_instruction,
                    soc.cpu_core.WB_pc, soc.cpu_core.WB_instruction);
                $display("  alu=%08x mem_alu=%08x x1=%08x x2=%08x next_pc=%08x",
                    soc.cpu_core.alu_result, soc.cpu_core.MEM_alu_result,
                    soc.cpu_core.register_file.registers[1],
                    soc.cpu_core.register_file.registers[2],
                    soc.cpu_core.next_pc);
                $display("  stack[29a4]=%08x load_data=%08x wb_data=%08x",
                    soc.main_memory.mem[32'h000029a4 >> 2],
                    soc.cpu_core.data_memory_read_data,
                    soc.cpu_core.register_file_write_data);
                $display("  stall(IF/ID/EX/MEM/WB)=%b/%b/%b/%b/%b mem=%b/%b trap=%b/%x",
                    soc.cpu_core.pc_stall, soc.cpu_core.IF_ID_stall,
                    soc.cpu_core.ID_EX_stall, soc.cpu_core.EX_MEM_stall,
                    soc.cpu_core.MEM_WB_stall, soc.cpu_core.mem_valid,
                    soc.cpu_core.mem_ready, soc.cpu_core.trapped_raw,
                    soc.cpu_core.trap_status_raw);
            end

            if ((soc.cpu_core.MEM_alu_result == 32'h000029a4) &&
                (soc.cpu_core.MEM_memory_read || soc.cpu_core.MEM_memory_write)) begin
                $display("[%0t] STACK_RA_ACCESS pc=%08x instr=%08x rd=%b wr=%b wdata=%08x rdata=%08x ready=%b memword=%08x",
                    $time, soc.cpu_core.MEM_pc, soc.cpu_core.MEM_instruction,
                    soc.cpu_core.MEM_memory_read, soc.cpu_core.MEM_memory_write,
                    soc.cpu_core.data_memory_write_data,
                    soc.cpu_core.data_memory_read_data, soc.cpu_core.mem_ready,
                    soc.main_memory.mem[32'h000029a4 >> 2]);
            end

            if ((soc.cpu_core.MEM_pc == 32'h00001164 ||
                 soc.cpu_core.MEM_pc == 32'h00001174) &&
                soc.cpu_core.MEM_memory_read) begin
                $display("[%0t] OBJECT_LOAD pc=%08x addr=%08x rdata=%08x ready=%b pending=%b s0=%08x s3=%08x a5=%08x sp=%08x",
                    $time, soc.cpu_core.MEM_pc, soc.cpu_core.MEM_alu_result,
                    soc.cpu_core.data_memory_read_data, soc.cpu_core.mem_ready,
                    soc.cpu_core.data_response_pending,
                    soc.cpu_core.register_file.registers[8],
                    soc.cpu_core.register_file.registers[19],
                    soc.cpu_core.register_file.registers[15],
                    soc.cpu_core.register_file.registers[2]);
            end

            if (soc.cpu_core.WB_register_write_enable && soc.cpu_core.WB_rd == 5'd1) begin
                $display("[%0t] X1_WRITE wb_pc=%08x instr=%08x data=%08x stall=%b flush=%b",
                    $time, soc.cpu_core.WB_pc, soc.cpu_core.WB_instruction,
                    soc.cpu_core.register_file_write_data,
                    soc.cpu_core.MEM_WB_stall, soc.cpu_core.MEM_WB_flush);
            end

            // Track the rt_kprintf prologue store that must replace the old
            // contents of 0x29a4 with the caller's return address.
            if (soc.cpu_core.ID_pc == 32'h00000f8c ||
                soc.cpu_core.EX_pc == 32'h00000f8c ||
                soc.cpu_core.MEM_pc == 32'h00000f8c ||
                soc.cpu_core.WB_pc == 32'h00000f8c) begin
                $display("[%0t] KPRINTF_SAVE ID=%08x/%08x EX=%08x/%08x MEM=%08x/%08x WB=%08x/%08x",
                    $time,
                    soc.cpu_core.ID_pc, soc.cpu_core.ID_instruction,
                    soc.cpu_core.EX_pc, soc.cpu_core.EX_instruction,
                    soc.cpu_core.MEM_pc, soc.cpu_core.MEM_instruction,
                    soc.cpu_core.WB_pc, soc.cpu_core.WB_instruction);
                $display("  sp=%08x x1=%08x ex_alu=%08x mem_alu=%08x wr=%b wdata=%08x valid/ready=%b/%b stalls=%b%b%b flush=%b%b%b",
                    soc.cpu_core.register_file.registers[2],
                    soc.cpu_core.register_file.registers[1],
                    soc.cpu_core.alu_result, soc.cpu_core.MEM_alu_result,
                    soc.cpu_core.MEM_memory_write,
                    soc.cpu_core.data_memory_write_data,
                    soc.cpu_core.mem_valid, soc.cpu_core.mem_ready,
                    soc.cpu_core.ID_EX_stall, soc.cpu_core.EX_MEM_stall,
                    soc.cpu_core.MEM_WB_stall,
                    soc.cpu_core.ID_EX_flush, soc.cpu_core.EX_MEM_flush,
                    soc.cpu_core.MEM_WB_flush);
            end
        end
    end

    reg [1023:0] hex_file;

    initial begin
        // 波形输出
        // $dumpfile("soc_axi_test.vcd");
        // $dumpvars(0, RV32_SoC_AXI_tb);

        // 初始化
        rst = 1;
        UART_busy = 0;
        if (!$value$plusargs("UART_BUSY_CYCLES=%d", uart_busy_cycles))
            uart_busy_cycles = 0;
        if (!$value$plusargs("SIM_TIME_NS=%d", simulation_time_ns))
            simulation_time_ns = 2000000;

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

        // 加载 RT-Thread 固件
        if (!$value$plusargs("HEX_FILE=%s", hex_file)) begin
            hex_file = "software/rt_thread_app/rtthread.hex";
        end
        $readmemh(hex_file, soc.main_memory.mem);

        // 释放复位
        #20;
        rst = 0;

        // 快速验证测试 - 运行长一点时间以等待 RT-Thread 启动
        #(simulation_time_ns);

        // 打印测试结果
        $display("\n========================================");
        $display(" RT-Thread 仿真结果");
        $display("========================================");
        $display(" 执行统计:");
        $display("   总指令数: ~%0d", instr_count);
        $display("   JAL执行次数: %0d", jal_count);
        $display("   JALR执行次数: %0d (包括函数返回)", jalr_count);
        $display("   最终PC: 0x%h", soc.cpu_core.pc);
        $display("========================================");

        if (jalr_count > 0) begin
            $display(" ✅ JALR正常工作 - 函数调用/返回机制正常");
        end else begin
            $display(" ⚠️  警告: 没有检测到JALR执行");
        end

        $display("\n 如果上方出现 RT-Thread 启动信息，说明系统成功启动");
        $display(" 预期输出：");
        $display("  \\ | /");
        $display("  - RT-Thread Operating System");
        $display("========================================");

        $finish;
    end

endmodule
