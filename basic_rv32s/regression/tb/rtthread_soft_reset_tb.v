`timescale 1ns/1ps

module rtthread_soft_reset_tb;
    reg clk = 0;
    reg rst = 1;
    reg [2047:0] hex_file;
    wire [7:0] uart_data;
    wire uart_start;
    wire [31:0] retire_instruction;
    wire [3:0] led;
    integer hello_count = 0;
    integer uart_count = 0;

    always #5 clk = ~clk;

    RV32_SoC_AXI_Top soc (
        .clk(clk), .rst(rst), .UART_busy(1'b0),
        .mmio_uart_tx_data(uart_data), .mmio_uart_tx_start(uart_start),
        .retire_instruction(retire_instruction), .mmio_led(led)
    );

    always @(posedge clk) begin
        if (uart_start) begin
            uart_count <= uart_count + 1;
            // Uppercase H uniquely identifies the beginning of the application
            // message "Hello, RT-Thread..." in the current firmware output.
            if (uart_data == 8'h48)
                hello_count <= hello_count + 1;
        end
    end

    initial begin
        if (!$value$plusargs("HEX_FILE=%s", hex_file))
            $fatal(1, "REGRESSION_FAIL: missing HEX_FILE plusarg");
        $readmemh(hex_file, soc.main_memory.mem);

        repeat (12) @(posedge clk);
        rst = 0;
        #4000000;
        if (hello_count < 1)
            $fatal(1, "REGRESSION_FAIL: first RT-Thread boot produced no Hello");

        // BRAM contents are intentionally not reloaded here. This models the
        // board reset button and verifies the startup .data copy path.
        rst = 1;
        repeat (20) @(posedge clk);
        rst = 0;
        #4000000;

        if (hello_count != 2)
            $fatal(1, "REGRESSION_FAIL: expected two RT-Thread boots, got %0d", hello_count);
        if (uart_count < 100)
            $fatal(1, "REGRESSION_FAIL: UART output unexpectedly short (%0d bytes)", uart_count);
        $display("REGRESSION_PASS: rtthread_soft_reset");
        $finish;
    end
endmodule
