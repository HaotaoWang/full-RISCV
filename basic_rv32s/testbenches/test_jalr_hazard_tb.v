// ============================================================================
// JALR 数据冒险修复测试 Testbench
// ============================================================================
// 测试目标: 验证 JALR 前递逻辑和 Load-Use 冒险检测
// 测试程序: test_jalr_hazard.S
// 预期结果: t0 最终值为 0xFFFF0000 (所有测试通过)
// ============================================================================

`timescale 1ns / 1ps

module test_jalr_hazard_tb;

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

    integer cycle_count = 0;
    integer jal_count = 0;
    integer jalr_count = 0;
    reg [31:0] last_t0_value = 0;
    reg test_passed = 0;

    // 追踪 t0 寄存器变化 (x5 = t0)
    always @(posedge clk) begin
        if (!rst) begin
            cycle_count = cycle_count + 1;

            // 检查 t0 寄存器的值变化
            if (soc.cpu_core.register_file.registers[5] != last_t0_value) begin
                last_t0_value = soc.cpu_core.register_file.registers[5];

                case (last_t0_value)
                    32'hAAAA0001: $display("[%0t] ✓ 进入 test_jal_jalr (t0=0x%h)", $time, last_t0_value);
                    32'hAAAA0002: $display("[%0t] ✓ JAL+JALR 返回成功 (t0=0x%h)", $time, last_t0_value);
                    32'hA001:     $display("[%0t]   - func1 内部标记", $time);
                    32'hBBBB0001: $display("[%0t] ✓ 进入 test_addi_jalr (t0=0x%h)", $time, last_t0_value);
                    32'hBBBB0002: $display("[%0t] ✓ ADDI+JALR 前递成功 (t0=0x%h)", $time, last_t0_value);
                    32'hCCCC0001: $display("[%0t] ✓ 进入 test_load_jalr (t0=0x%h)", $time, last_t0_value);
                    32'hCCCC0002: $display("[%0t] ✓ Load+JALR stall 成功 (t0=0x%h)", $time, last_t0_value);
                    32'hDDDD0001: $display("[%0t] ✓ 进入 test_chain_jalr (t0=0x%h)", $time, last_t0_value);
                    32'hDDDD0002: $display("[%0t]   - chain1", $time);
                    32'hDDDD0003: $display("[%0t]   - chain2", $time);
                    32'hDDDD0004: $display("[%0t]   - chain1 返回", $time);
                    32'hDDDD0005: $display("[%0t] ✓ 连续 JALR 调用成功 (t0=0x%h)", $time, last_t0_value);
                    32'hFFFF0000: begin
                        $display("[%0t] ✅ 全部测试通过！(t0=0x%h)", $time, last_t0_value);
                        test_passed = 1;
                    end
                    default: begin
                        if (last_t0_value != 0)
                            $display("[%0t] t0=0x%h", $time, last_t0_value);
                    end
                endcase
            end

            // 追踪 JALR 指令执行
            if (soc.cpu_core.opcode == 7'b1100111 && soc.cpu_core.ID_jump) begin
                jalr_count = jalr_count + 1;
                $display("[%0t] JALR: rs1=x%0d, read_data1=0x%h, jalr_forwarded_rs1=0x%h, imm=0x%h, target=0x%h",
                    $time,
                    soc.cpu_core.rs1,
                    soc.cpu_core.read_data1,
                    soc.cpu_core.jalr_forwarded_rs1,
                    soc.cpu_core.imm,
                    soc.cpu_core.ID_jump_target);

                // 检查是否有前递
                if (soc.cpu_core.read_data1 != soc.cpu_core.jalr_forwarded_rs1) begin
                    $display("       → 前递生效！(原值 0x%h -> 前递值 0x%h)",
                        soc.cpu_core.read_data1, soc.cpu_core.jalr_forwarded_rs1);
                end

                // 检查是否检测到 Load-Use 冒险
                if (soc.cpu_core.hazard_unit.jalr_load_use_hazard) begin
                    $display("       → 检测到 JALR Load-Use 冒险，插入 stall");
                end
            end

            // 追踪 JAL 指令
            if (soc.cpu_core.opcode == 7'b1101111 && soc.cpu_core.ID_jump) begin
                jal_count = jal_count + 1;
            end

            // 超时保护
            if (cycle_count > 1000 && !test_passed) begin
                $display("\n========================================");
                $display(" ⚠️  测试超时（%0d 周期）", cycle_count);
                $display("========================================");
                $display(" 最终状态:");
                $display("   t0 = 0x%h (预期: 0xFFFF0000)", last_t0_value);
                $display("   PC = 0x%h", soc.cpu_core.pc);
                $display("   JAL 执行次数: %0d", jal_count);
                $display("   JALR 执行次数: %0d", jalr_count);
                $display("========================================");
                $finish;
            end

            // 成功后再运行几个周期确保稳定
            if (test_passed) begin
                #100;
                $display("\n========================================");
                $display(" 🎉 JALR 修复测试完全通过！");
                $display("========================================");
                $display(" 测试统计:");
                $display("   执行周期数: %0d", cycle_count);
                $display("   JAL 执行次数: %0d", jal_count);
                $display("   JALR 执行次数: %0d", jalr_count);
                $display("   最终 t0 值: 0x%h ✓", last_t0_value);
                $display("   最终 PC: 0x%h", soc.cpu_core.pc);
                $display("========================================");
                $display("");
                $display(" 验证项目:");
                $display("   ✅ WB-ID 前递（JAL 写 ra → JALR 读 ra）");
                $display("   ✅ MEM-ID 前递（ADDI 写寄存器 → JALR 读）");
                $display("   ✅ Load-Use stall（Load 写寄存器 → JALR 读）");
                $display("   ✅ 连续 JALR 调用链");
                $display("========================================");
                $finish;
            end
        end
    end

    initial begin
        // 波形输出（可选）
        $dumpfile("jalr_test.vcd");
        $dumpvars(0, test_jalr_hazard_tb);

        // 初始化
        rst = 1;
        UART_busy = 0;

        // 等待复位稳定
        #100;

        // 加载测试程序到内存
        $readmemh("test_jalr_hazard.hex", soc.main_memory.mem);
        $display("========================================");
        $display(" 加载测试程序: test_jalr_hazard.hex");
        $display("========================================");

        // 释放复位
        #20;
        rst = 0;

        $display(" 开始执行测试...\n");
    end

endmodule
