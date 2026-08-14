`timescale 1ns/1ps
`include "modules/headers/trap.vh"

module context_restore_tb;
    reg clk = 0;
    reg rst = 1;
    reg [2047:0] hex_file;
    reg [255:0] pass_name;
    integer interrupt_target = 4;
    integer interrupt_index;
    integer register_index;
    integer expected;
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

    task check_context;
        begin
            if (soc.cpu_core.register_file.registers[2] !== 32'h0000_f000)
                $fatal(1, "REGRESSION_FAIL: stack pointer was not restored: %h",
                       soc.cpu_core.register_file.registers[2]);
            for (register_index = 1; register_index < 32; register_index = register_index + 1) begin
                if (register_index != 2) begin
                    expected = 32'h100 + register_index;
                    if (soc.cpu_core.register_file.registers[register_index] !== expected)
                        $fatal(1, "REGRESSION_FAIL: x%0d=%h expected=%h after interrupt %0d",
                               register_index,
                               soc.cpu_core.register_file.registers[register_index],
                               expected, interrupt_index);
                end
            end
        end
    endtask

    initial begin
        if (!$value$plusargs("HEX_FILE=%s", hex_file))
            $fatal(1, "REGRESSION_FAIL: missing HEX_FILE plusarg");
        if (!$value$plusargs("INTERRUPTS=%d", interrupt_target))
            interrupt_target = 4;
        if (!$value$plusargs("PASS_NAME=%s", pass_name))
            pass_name = "context_restore";
        $readmemh(hex_file, soc.main_memory.mem);
        force soc.timer_irq = 1'b0;
        repeat (8) @(posedge clk);
        rst = 0;
        wait (soc.main_memory.mem[3073] == 1);
        wait (soc.cpu_core.register_file.registers[31] == 32'h11f);
        check_context();

        for (interrupt_index = 1; interrupt_index <= interrupt_target; interrupt_index = interrupt_index + 1) begin
            wait (soc.cpu_core.mstatus_out[3] && soc.cpu_core.trap_done &&
                  !soc.cpu_core.trapped);
            repeat (3 + (interrupt_index % 7)) @(posedge clk);
            force soc.timer_irq = 1'b1;
            wait (soc.cpu_core.trapped &&
                  soc.cpu_core.trap_status == `TRAP_TIMER_INTERRUPT);
            force soc.timer_irq = 1'b0;
            wait (soc.main_memory.mem[3072] >= interrupt_index);
            wait (soc.cpu_core.trap_jump &&
                  soc.cpu_core.trap_status == `TRAP_MRET);
            repeat (12) @(posedge clk);
            check_context();
        end

        if (soc.main_memory.mem[3072] != interrupt_target)
            $fatal(1, "REGRESSION_FAIL: interrupt count %0d expected %0d",
                   soc.main_memory.mem[3072], interrupt_target);
        $display("REGRESSION_PASS: %0s", pass_name);
        $finish;
    end

    initial begin
        #20000000;
        $fatal(1, "REGRESSION_FAIL: context/interrupt stress timeout");
    end
endmodule
