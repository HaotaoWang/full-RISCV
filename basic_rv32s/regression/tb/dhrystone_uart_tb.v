`timescale 1ns/1ps

module dhrystone_uart_tb;
    reg clk = 0;
    reg rst = 1;
    reg [2047:0] hex_file;
    wire [7:0] uart_data;
    wire uart_start;
    reg uart_busy = 0;
    integer uart_busy_cycles = 0;
    wire [31:0] retire_instruction;
    wire [3:0] led;
    integer pass_index = 0;
    integer fail_index = 0;
    integer trap_index = 0;
    integer uart_count = 0;
    reg pass_prefix_seen = 0;
    reg pass_seen = 0;
    reg cycle_nonzero = 0;
    reg fail_seen = 0;
    reg trap_seen = 0;
    reg [8*30-1:0] pass_text = "DHRYSTONE PASS runs=20 cycles=";
    reg [8*14-1:0] fail_text = "DHRYSTONE FAIL";
    reg [8*6-1:0] trap_text = "[TRAP]";

    always #5 clk = ~clk;

    RV32_SoC_AXI_Top soc (
        .clk(clk), .rst(rst), .UART_busy(uart_busy),
        .mmio_uart_tx_data(uart_data), .mmio_uart_tx_start(uart_start),
        .retire_instruction(retire_instruction), .mmio_led(led)
    );

    // Model UART backpressure.  Tying busy low hid dropped FPGA output.
    always @(posedge clk) begin
        if (rst) begin
            uart_busy <= 0;
            uart_busy_cycles <= 0;
        end else if (uart_start) begin
            uart_busy <= 1;
            uart_busy_cycles <= 24;
        end else if (uart_busy_cycles > 1) begin
            uart_busy_cycles <= uart_busy_cycles - 1;
        end else begin
            uart_busy <= 0;
            uart_busy_cycles <= 0;
        end
    end

    always @(posedge clk) begin
        if (uart_start) begin
            uart_count = uart_count + 1;
            $write("%c", uart_data);

            if (!pass_prefix_seen && uart_data == pass_text[8*(29-pass_index) +: 8]) begin
                if (pass_index == 29) begin
                    pass_prefix_seen = 1;
                    pass_index = 0;
                end else pass_index = pass_index + 1;
            end else pass_index = (uart_data == "D") ? 1 : 0;

            if (pass_prefix_seen) begin
                if (uart_data >= "1" && uart_data <= "9")
                    cycle_nonzero = 1;
                if (uart_data == 8'h0a && cycle_nonzero)
                    pass_seen = 1;
            end

            if (uart_data == fail_text[8*(13-fail_index) +: 8]) begin
                if (fail_index == 13) begin
                    fail_seen = 1;
                    fail_index = 0;
                end else fail_index = fail_index + 1;
            end else fail_index = (uart_data == "D") ? 1 : 0;

            if (uart_data == trap_text[8*(5-trap_index) +: 8]) begin
                if (trap_index == 5) begin
                    trap_seen = 1;
                    trap_index = 0;
                end else trap_index = trap_index + 1;
            end else trap_index = (uart_data == "[") ? 1 : 0;
        end
    end

    initial begin
        if (!$value$plusargs("HEX_FILE=%s", hex_file))
            $fatal(1, "REGRESSION_FAIL: missing HEX_FILE plusarg");
        $readmemh(hex_file, soc.main_memory.mem);
        repeat (20) @(posedge clk);
        rst = 0;

        while (!pass_seen && !fail_seen && !trap_seen)
            @(posedge clk);
        repeat (80) @(posedge clk);

        if (fail_seen)
            $fatal(1, "REGRESSION_FAIL: Dhrystone variable self-check failed");
        if (trap_seen)
            $fatal(1, "REGRESSION_FAIL: Dhrystone trapped");
        if (!pass_seen || uart_count < 80)
            $fatal(1, "REGRESSION_FAIL: incomplete Dhrystone UART report (%0d bytes)", uart_count);
        $display("\nREGRESSION_PASS: dhrystone_smoke");
        $finish;
    end

    initial begin
        repeat (1000000) @(posedge clk);
        $fatal(1, "REGRESSION_FAIL: dhrystone_smoke timeout pc=%h uart_bytes=%0d",
               soc.cpu_core.pc, uart_count);
    end
endmodule
