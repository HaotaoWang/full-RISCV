`timescale 1ns/1ps
`include "modules/headers/opcode.vh"
`include "modules/headers/trap.vh"

module irq_boundaries_tb;
    reg clk = 0;
    reg rst = 1;
    reg [2047:0] hex_file;
    reg [31:0] expected_mepc;
    reg [31:0] progress_before;
    integer scenario;
    wire [7:0] uart_data;
    wire uart_start;
    wire [31:0] retire_instruction;
    wire [3:0] led;

    always #5 clk = ~clk;

    RV32_SoC_AXI_Top soc (
        .clk(clk), .rst(rst), .UART_busy(1'b0),
        .mmio_uart_tx_data(uart_data), .mmio_uart_tx_start(uart_start),
        .retire_instruction(retire_instruction), .mmio_led(led)
    );

    task restart_scenario;
        begin
            force soc.timer_irq = 1'b0;
            rst = 1;
            // BRAM is not reset on a board-button reset. Poison the software
            // ready/count words so this task cannot accidentally accept the
            // previous scenario's values before startup rewrites them.
            soc.main_memory.mem[3073] = 32'hdeadbeef;
            soc.main_memory.mem[3264] = 32'b0;
            soc.main_memory.mem[3265] = 32'b0;
            soc.main_memory.mem[3266] = 32'b0;
            soc.main_memory.mem[3267] = 32'b0;
            soc.main_memory.mem[3268] = 32'b0;
            soc.main_memory.mem[3269] = 32'b0;
            soc.main_memory.mem[3270] = 32'b0;
            soc.main_memory.mem[3271] = 32'b0;
            soc.main_memory.mem[3272] = 32'b0;
            repeat (20) @(posedge clk);
            rst = 0;
            wait (soc.main_memory.mem[3073] == 1);
            // Program initialization has completed once the last exported PC
            // is visible; reset the test-only handler record from the TB.
            wait ((^soc.main_memory.mem[3264]) !== 1'bx &&
                  soc.main_memory.mem[3264] != 0 &&
                  (^soc.main_memory.mem[3272]) !== 1'bx &&
                  soc.main_memory.mem[3272] != 0);
            soc.main_memory.mem[3200] = 32'b0;
            soc.main_memory.mem[3201] = 32'b0;
            soc.main_memory.mem[3202] = 32'b0;
            soc.main_memory.mem[3203] = 32'b0;
            wait (soc.cpu_core.mstatus_out[3] && soc.cpu_core.trap_done);
        end
    endtask

    task accept_and_check;
        begin
            // Redirect deferral can be only one cycle. By the time the caller
            // observes the redirect deassert, the registered trap may already
            // be entering its handler, so accept either the trap level or the
            // handler's software count as proof of acceptance.
            if (!soc.cpu_core.trapped && soc.main_memory.mem[3200] == 0)
                wait ((soc.cpu_core.trapped &&
                       soc.cpu_core.trap_status == `TRAP_TIMER_INTERRUPT) ||
                      soc.main_memory.mem[3200] != 0);
            force soc.timer_irq = 1'b0;
            wait (soc.main_memory.mem[3200] == 1);
            wait (soc.cpu_core.mstatus_out[3] && soc.cpu_core.trap_done &&
                  soc.cpu_core.trap_controller.trap_handle_state == 0 &&
                  soc.cpu_core.trap_status == `TRAP_NONE);
            repeat (20) @(posedge clk);

            if (soc.main_memory.mem[3201] != 32'h80000007)
                $fatal(1, "REGRESSION_FAIL: scenario %0d mcause=%h",
                       scenario, soc.main_memory.mem[3201]);
            if (soc.main_memory.mem[3202] != expected_mepc)
                $fatal(1, "REGRESSION_FAIL: scenario %0d mepc=%h expected=%h",
                       scenario, soc.main_memory.mem[3202], expected_mepc);
            if (soc.main_memory.mem[3203][3] != 1'b0 ||
                soc.main_memory.mem[3203][7] != 1'b1 ||
                soc.main_memory.mem[3203][12:11] != 2'b11)
                $fatal(1, "REGRESSION_FAIL: scenario %0d trap mstatus=%h",
                       scenario, soc.main_memory.mem[3203]);
            if (soc.cpu_core.register_file.registers[2] != 32'h0000f000 ||
                soc.cpu_core.register_file.registers[8] != 32'h180 ||
                soc.cpu_core.register_file.registers[9] != 32'h181 ||
                soc.cpu_core.register_file.registers[18] != 32'h182 ||
                soc.cpu_core.register_file.registers[19] != 32'h183)
                $fatal(1, "REGRESSION_FAIL: scenario %0d context corrupt sp=%h",
                       scenario, soc.cpu_core.register_file.registers[2]);
            if (soc.main_memory.mem[3200] != 1)
                $fatal(1, "REGRESSION_FAIL: scenario %0d duplicate IRQ count=%0d",
                       scenario, soc.main_memory.mem[3200]);
        end
    endtask

    initial begin
        if (!$value$plusargs("HEX_FILE=%s", hex_file))
            $fatal(1, "REGRESSION_FAIL: missing HEX_FILE plusarg");
        $readmemh(hex_file, soc.main_memory.mem);
        force soc.timer_irq = 1'b0;

        // 1: ordinary ALU instruction. The older ALU operation must retire,
        // and mepc must identify the first uncommitted ID instruction.
        scenario = 1;
        restart_scenario();
        wait (soc.cpu_core.EX_pc == soc.main_memory.mem[3264]);
        expected_mepc = soc.cpu_core.ID_pc;
        force soc.timer_irq = 1'b1;
        accept_and_check();

        // 2: interrupt becomes pending while a load is waiting in MEM.
        scenario = 2;
        restart_scenario();
        wait (soc.cpu_core.MEM_pc == soc.main_memory.mem[3265] &&
              soc.cpu_core.MEM_memory_read && soc.cpu_core.mem_valid &&
              !soc.cpu_core.mem_ready);
        expected_mepc = soc.cpu_core.ID_pc;
        force soc.timer_irq = 1'b1;
        wait (soc.cpu_core.raw_async_interrupt);
        if (soc.cpu_core.trapped)
            $fatal(1, "REGRESSION_FAIL: IRQ overtook waiting load");
        accept_and_check();
        if (soc.main_memory.mem[3077] != 32'h12345678)
            $fatal(1, "REGRESSION_FAIL: load/store data wrong after load IRQ");

        // 3: same rule for a waiting store; the store must commit once.
        scenario = 3;
        restart_scenario();
        wait (soc.cpu_core.MEM_pc == soc.main_memory.mem[3266] &&
              soc.cpu_core.MEM_memory_write && soc.cpu_core.mem_valid &&
              !soc.cpu_core.mem_ready);
        expected_mepc = soc.cpu_core.ID_pc;
        force soc.timer_irq = 1'b1;
        wait (soc.cpu_core.raw_async_interrupt);
        if (soc.cpu_core.trapped)
            $fatal(1, "REGRESSION_FAIL: IRQ overtook waiting store");
        accept_and_check();
        if (soc.main_memory.mem[3077] != 32'h12345678)
            $fatal(1, "REGRESSION_FAIL: waiting store did not commit");

        // 4: interrupt collides with an older indirect JALR redirect.
        scenario = 4;
        restart_scenario();
        wait (soc.cpu_core.EX_pc == soc.main_memory.mem[3267] &&
              soc.cpu_core.EX_opcode == `OPCODE_JALR && soc.cpu_core.EX_jump);
        expected_mepc = soc.main_memory.mem[3268];
        force soc.timer_irq = 1'b1;
        wait (soc.cpu_core.raw_async_interrupt && soc.cpu_core.older_ex_redirect);
        #1;
        if (soc.cpu_core.trapped)
            $fatal(1, "REGRESSION_FAIL: IRQ overtook JALR");
        wait (!soc.cpu_core.older_ex_redirect);
        accept_and_check();

        // 5: a RET is also JALR, but its target comes from the restored RA.
        scenario = 5;
        restart_scenario();
        wait (soc.cpu_core.EX_pc == soc.main_memory.mem[3269] &&
              soc.cpu_core.EX_opcode == `OPCODE_JALR && soc.cpu_core.EX_jump);
        expected_mepc = soc.main_memory.mem[3270];
        force soc.timer_irq = 1'b1;
        wait (soc.cpu_core.raw_async_interrupt && soc.cpu_core.older_ex_redirect);
        #1;
        if (soc.cpu_core.trapped)
            $fatal(1, "REGRESSION_FAIL: IRQ overtook RET");
        wait (!soc.cpu_core.older_ex_redirect);
        accept_and_check();

        // 6: exact completion boundary: lw ra is in MEM, RET is waiting in ID,
        // and IRQ is asserted while mem_ready releases the pipeline.
        scenario = 6;
        restart_scenario();
        wait (soc.cpu_core.mem_valid && !soc.cpu_core.mem_ready &&
              soc.cpu_core.ID_pc == soc.main_memory.mem[3271]);
        wait (soc.cpu_core.mem_ready);
        @(negedge clk);
        if (!soc.cpu_core.mem_ready ||
            soc.cpu_core.ID_pc != soc.main_memory.mem[3271])
            $fatal(1, "REGRESSION_FAIL: missed AXI-complete/RET boundary");
        progress_before = soc.cpu_core.register_file.registers[23];
        expected_mepc = soc.main_memory.mem[3271];
        force soc.timer_irq = 1'b1;
        accept_and_check();
        wait (soc.cpu_core.register_file.registers[23] > progress_before);

        $display("REGRESSION_PASS: irq_boundaries");
        $finish;
    end

    initial begin
        #2000000;
        $fatal(1, "REGRESSION_FAIL: irq_boundaries timeout scenario=%0d pc=%h ready=%h count=%h p0=%h p8=%h",
               scenario, soc.cpu_core.pc, soc.main_memory.mem[3073],
               soc.main_memory.mem[3200], soc.main_memory.mem[3264],
               soc.main_memory.mem[3272]);
    end
endmodule
