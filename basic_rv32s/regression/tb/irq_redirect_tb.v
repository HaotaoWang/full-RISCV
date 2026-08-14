`timescale 1ns/1ps
`include "modules/headers/trap.vh"

module irq_redirect_tb;
    reg clk = 0;
    reg rst = 1;
    reg [2047:0] hex_file;
    wire [7:0] uart_data;
    wire uart_start;
    wire [31:0] retire_instruction;
    wire [3:0] led;
    integer timeout;

    always #5 clk = ~clk;

    RV32_SoC_AXI_Top soc (
        .clk(clk), .rst(rst), .UART_busy(1'b0),
        .mmio_uart_tx_data(uart_data), .mmio_uart_tx_start(uart_start),
        .retire_instruction(retire_instruction), .mmio_led(led)
    );

    task collide_with_branch;
        begin
            wait (soc.cpu_core.branch === 1'b1);
            force soc.timer_irq = 1'b1;
            wait (soc.cpu_core.raw_async_interrupt && soc.cpu_core.older_ex_redirect);
            #1;
            if (soc.cpu_core.trapped)
                $fatal(1, "REGRESSION_FAIL: interrupt overtook older branch");
            wait (soc.cpu_core.trapped &&
                  soc.cpu_core.trap_status == `TRAP_TIMER_INTERRUPT);
            force soc.timer_irq = 1'b0;
            wait (soc.main_memory.mem[3072] >= 1);
        end
    endtask

    task collide_with_jump;
        begin
            wait (soc.cpu_core.jump === 1'b1);
            force soc.timer_irq = 1'b1;
            wait (soc.cpu_core.raw_async_interrupt && soc.cpu_core.older_ex_redirect);
            #1;
            if (soc.cpu_core.trapped)
                $fatal(1, "REGRESSION_FAIL: interrupt overtook older jump");
            wait (soc.cpu_core.trapped &&
                  soc.cpu_core.trap_status == `TRAP_TIMER_INTERRUPT);
            force soc.timer_irq = 1'b0;
            wait (soc.main_memory.mem[3072] >= 1);
        end
    endtask

    initial begin
        if (!$value$plusargs("HEX_FILE=%s", hex_file))
            $fatal(1, "REGRESSION_FAIL: missing HEX_FILE plusarg");
        $readmemh(hex_file, soc.main_memory.mem);
        // The CLINT reset value makes mtime >= mtimecmp. Keep its output low
        // and drive deterministic interrupt pulses explicitly in this test.
        force soc.timer_irq = 1'b0;
        repeat (8) @(posedge clk);
        rst = 0;
        wait (soc.main_memory.mem[3073] == 1);

        collide_with_branch();
        if (soc.main_memory.mem[3072] != 1)
            $fatal(1, "REGRESSION_FAIL: branch collision interrupt count=%0d",
                   soc.main_memory.mem[3072]);
        wait (soc.cpu_core.mstatus_out[3] === 1'b1);

        // Run the jump collision from a fresh architectural state so a stale
        // level from the branch scenario cannot satisfy the second stimulus.
        rst = 1;
        repeat (20) @(posedge clk);
        rst = 0;
        wait (soc.main_memory.mem[3073] == 1);
        wait (soc.main_memory.mem[3072] == 0);
        collide_with_jump();
        wait (soc.cpu_core.mstatus_out[3] === 1'b1);
        wait (soc.cpu_core.register_file.registers[8] != 0 &&
              soc.cpu_core.register_file.registers[18] != 0 &&
              soc.cpu_core.register_file.registers[19] != 0);
        repeat (10) @(posedge clk);

        if (soc.main_memory.mem[3072] != 1)
            $fatal(1, "REGRESSION_FAIL: jump collision interrupt count=%0d",
                   soc.main_memory.mem[3072]);
        if (soc.cpu_core.register_file.registers[9] != 0)
            $fatal(1, "REGRESSION_FAIL: branch fall-through executed");
        if (soc.cpu_core.register_file.registers[8] == 0 ||
            soc.cpu_core.register_file.registers[18] == 0 ||
            soc.cpu_core.register_file.registers[19] == 0)
            $fatal(1, "REGRESSION_FAIL: program did not resume after redirects");
        $display("REGRESSION_PASS: irq_redirect");
        $finish;
    end

    initial begin
        #2000000;
        $fatal(1, "REGRESSION_FAIL: irq_redirect timeout");
    end
endmodule
