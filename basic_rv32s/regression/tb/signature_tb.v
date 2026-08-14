`timescale 1ns/1ps

module signature_tb;
    reg clk = 0;
    reg rst = 1;
    reg [2047:0] hex_file;
    reg [255:0] pass_name;
    wire [7:0] uart_data;
    wire uart_start;
    wire [31:0] retire_instruction;
    wire [3:0] led;
    integer cycles;

    always #5 clk = ~clk;

    RV32_SoC_AXI_Top soc (
        .clk(clk), .rst(rst), .UART_busy(1'b0),
        .mmio_uart_tx_data(uart_data), .mmio_uart_tx_start(uart_start),
        .retire_instruction(retire_instruction), .mmio_led(led)
    );

    initial begin
        if (!$value$plusargs("HEX_FILE=%s", hex_file))
            $fatal(1, "REGRESSION_FAIL: missing HEX_FILE plusarg");
        if (!$value$plusargs("PASS_NAME=%s", pass_name))
            pass_name = "signature";
        $readmemh(hex_file, soc.main_memory.mem);
        repeat (8) @(posedge clk);
        rst = 0;

        for (cycles = 0; cycles < 30000; cycles = cycles + 1) begin
            @(posedge clk);
            if (soc.main_memory.mem[3136] == 32'h600d600d) begin
                $display("REGRESSION_PASS: %0s", pass_name);
                $finish;
            end
            if (soc.main_memory.mem[3136] != 0 &&
                soc.main_memory.mem[3136] != 32'h600d600d)
                $fatal(1, "REGRESSION_FAIL: %0s error code %0d",
                       pass_name, soc.main_memory.mem[3136]);
        end
        $fatal(1, "REGRESSION_FAIL: %0s timeout pc=%h signature=%h",
               pass_name, soc.cpu_core.pc, soc.main_memory.mem[3136]);
    end
endmodule
