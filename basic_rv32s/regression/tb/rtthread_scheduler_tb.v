`timescale 1ns/1ps

module rtthread_scheduler_tb;
    reg clk = 0;
    reg rst = 1;
    reg [2047:0] hex_file;
    integer main_thread_addr, main_stack_addr, main_stack_size;
    integer idle_thread_addr, idle_stack_addr, idle_stack_size;
    integer tick_addr, nest_addr, current_addr;
    integer main_pc, main_pc_size, idle_pc, idle_pc_size;
    integer ready_addr, delay_count_addr, delay_fail_addr;
    integer tick_before_addr, tick_after_addr;
    integer boot, cycles;
    integer watchdog_cycles = 0;
    integer main_seen, idle_seen, switch_count, stack_errors;
    integer nest_seen, nest_max;
    reg [31:0] previous_thread;
    reg [31:0] initial_tick;
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

    function [31:0] ram_word;
        input integer byte_address;
        begin
            ram_word = soc.main_memory.mem[byte_address >> 2];
        end
    endfunction

    function [7:0] ram_byte;
        input integer byte_address;
        reg [31:0] word_value;
        begin
            word_value = ram_word(byte_address);
            case (byte_address[1:0])
                0: ram_byte = word_value[7:0];
                1: ram_byte = word_value[15:8];
                2: ram_byte = word_value[23:16];
                default: ram_byte = word_value[31:24];
            endcase
        end
    endfunction

    task load_plusargs;
        begin
            if (!$value$plusargs("HEX_FILE=%s", hex_file) ||
                !$value$plusargs("MAIN_THREAD=%h", main_thread_addr) ||
                !$value$plusargs("MAIN_STACK=%h", main_stack_addr) ||
                !$value$plusargs("MAIN_STACK_SIZE=%h", main_stack_size) ||
                !$value$plusargs("IDLE_THREAD=%h", idle_thread_addr) ||
                !$value$plusargs("IDLE_STACK=%h", idle_stack_addr) ||
                !$value$plusargs("IDLE_STACK_SIZE=%h", idle_stack_size) ||
                !$value$plusargs("TICK=%h", tick_addr) ||
                !$value$plusargs("NEST=%h", nest_addr) ||
                !$value$plusargs("CURRENT=%h", current_addr) ||
                !$value$plusargs("MAIN_PC=%h", main_pc) ||
                !$value$plusargs("MAIN_PC_SIZE=%h", main_pc_size) ||
                !$value$plusargs("IDLE_PC=%h", idle_pc) ||
                !$value$plusargs("IDLE_PC_SIZE=%h", idle_pc_size) ||
                !$value$plusargs("READY=%h", ready_addr) ||
                !$value$plusargs("DELAY_COUNT=%h", delay_count_addr) ||
                !$value$plusargs("DELAY_FAIL=%h", delay_fail_addr) ||
                !$value$plusargs("TICK_BEFORE=%h", tick_before_addr) ||
                !$value$plusargs("TICK_AFTER=%h", tick_after_addr))
                $fatal(1, "REGRESSION_FAIL: missing RT-Thread symbol plusarg");
        end
    endtask

    always @(posedge clk) begin
        integer current_nest;
        reg [31:0] current_thread;
        reg [31:0] current_sp;
        if (!rst && ready_addr != 0) begin
            watchdog_cycles = watchdog_cycles + 1;
            if ((watchdog_cycles % 50000) == 0)
                $display("RT_SCHED_HEARTBEAT: cycles=%0d pc=%h ready=%h tick=%0d current=%h delays=%0d fails=%0d before=%0d after=%0d",
                         watchdog_cycles, soc.cpu_core.pc, ram_word(ready_addr),
                         ram_word(tick_addr), ram_word(current_addr),
                         ram_word(delay_count_addr), ram_word(delay_fail_addr),
                         ram_word(tick_before_addr), ram_word(tick_after_addr));
            current_thread = ram_word(current_addr);
            current_sp = soc.cpu_core.register_file.registers[2];
            current_nest = ram_byte(nest_addr);

            if (current_nest > nest_max)
                nest_max = current_nest;
            if (current_nest != 0)
                nest_seen = 1;
            if (current_nest > 1)
                $fatal(1, "REGRESSION_FAIL: interrupt nesting exceeded one (%0d)", current_nest);

            if (current_thread != previous_thread &&
                (current_thread == main_thread_addr || current_thread == idle_thread_addr)) begin
                if (previous_thread == main_thread_addr || previous_thread == idle_thread_addr)
                    switch_count = switch_count + 1;
                previous_thread = current_thread;
            end

            /* The exposed PC is the fetch PC. Ignore the first eight fetched
               instructions after a context switch while the restored SP is
               still moving through the pipeline. */
            if (soc.cpu_core.pc >= main_pc + 32 &&
                soc.cpu_core.pc < main_pc + main_pc_size) begin
                main_seen = 1;
                if (current_thread != main_thread_addr ||
                    current_sp < main_stack_addr ||
                    current_sp > main_stack_addr + main_stack_size) begin
                    if (stack_errors < 4)
                        $display("RT_SCHED_STACK_ERROR: main pc=%h sp=%h current=%h",
                                 soc.cpu_core.pc, current_sp, current_thread);
                    stack_errors = stack_errors + 1;
                end
            end

            if (soc.cpu_core.pc >= idle_pc + 32 &&
                soc.cpu_core.pc < idle_pc + idle_pc_size) begin
                idle_seen = 1;
                if (current_thread != idle_thread_addr ||
                    current_sp < idle_stack_addr ||
                    current_sp > idle_stack_addr + idle_stack_size) begin
                    if (stack_errors < 4)
                        $display("RT_SCHED_STACK_ERROR: idle pc=%h sp=%h current=%h",
                                 soc.cpu_core.pc, current_sp, current_thread);
                    stack_errors = stack_errors + 1;
                end
            end
        end
    end

    initial begin
        load_plusargs();
        $readmemh(hex_file, soc.main_memory.mem);

        for (boot = 1; boot <= 2; boot = boot + 1) begin
            $display("RT_SCHED_PROGRESS: boot %0d reset", boot);
            rst = 1;
            soc.main_memory.mem[ready_addr >> 2] = 32'hdeadbeef;
            repeat (20) @(posedge clk);
            rst = 0;
            watchdog_cycles = 0;

            main_seen = 0;
            idle_seen = 0;
            switch_count = 0;
            stack_errors = 0;
            nest_seen = 0;
            nest_max = 0;
            previous_thread = 0;

            while (ram_word(ready_addr) != 0)
                @(posedge clk);
            while (ram_word(ready_addr) != 32'h52545359)
                @(posedge clk);
            $display("RT_SCHED_PROGRESS: boot %0d ready tick=%0d", boot, ram_word(tick_addr));
            initial_tick = ram_word(tick_addr);

            for (cycles = 0; cycles < 800000; cycles = cycles + 1) begin
                @(posedge clk);
                if (ram_word(delay_count_addr) >= 3)
                    cycles = 800000;
            end
            $display("RT_SCHED_PROGRESS: boot %0d delays=%0d tick=%0d main=%0d idle=%0d switches=%0d stack_errors=%0d nest_max=%0d",
                     boot, ram_word(delay_count_addr), ram_word(tick_addr), main_seen,
                     idle_seen, switch_count, stack_errors, nest_max);

            if (ram_word(delay_count_addr) < 3)
                $fatal(1, "REGRESSION_FAIL: boot %0d mdelay did not wake three times", boot);
            if (ram_word(delay_fail_addr) != 0)
                $fatal(1, "REGRESSION_FAIL: boot %0d mdelay woke early (%0d)",
                       boot, ram_word(delay_fail_addr));
            if (ram_word(tick_after_addr) - ram_word(tick_before_addr) < 2)
                $fatal(1, "REGRESSION_FAIL: boot %0d final delay tick delta=%0d",
                       boot, ram_word(tick_after_addr) - ram_word(tick_before_addr));
            if (ram_word(tick_addr) <= initial_tick + 4)
                $fatal(1, "REGRESSION_FAIL: boot %0d tick did not keep increasing", boot);
            if (!main_seen || !idle_seen || switch_count < 6)
                $fatal(1, "REGRESSION_FAIL: boot %0d scheduling main=%0d idle=%0d switches=%0d",
                       boot, main_seen, idle_seen, switch_count);
            if (stack_errors != 0)
                $fatal(1, "REGRESSION_FAIL: boot %0d observed %0d stack-range errors",
                       boot, stack_errors);
            if (!nest_seen || nest_max != 1)
                $fatal(1, "REGRESSION_FAIL: boot %0d nesting was not observed correctly max=%0d",
                       boot, nest_max);

            while (ram_byte(nest_addr) != 0 || !soc.cpu_core.mstatus_out[3])
                @(posedge clk);
            repeat (20) @(posedge clk);
            if (ram_byte(nest_addr) != 0)
                $fatal(1, "REGRESSION_FAIL: boot %0d interrupt nest did not return to zero", boot);
        end

        $display("REGRESSION_PASS: rtthread_scheduler");
        $finish;
    end

    initial begin
        repeat (600000) @(posedge clk);
        $fatal(1, "REGRESSION_FAIL: rtthread_scheduler timeout boot=%0d cycles=%0d pc=%h ready=%h tick=%0d current=%h",
               boot, watchdog_cycles, soc.cpu_core.pc, ram_word(ready_addr),
               ram_word(tick_addr), ram_word(current_addr));
    end
endmodule
