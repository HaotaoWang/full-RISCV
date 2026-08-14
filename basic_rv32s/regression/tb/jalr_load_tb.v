`timescale 1ns/1ps

module jalr_load_tb;
    reg clk = 0;
    reg rst = 1;
    reg [2047:0] hex_file;
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
        $readmemh(hex_file, soc.main_memory.mem);
        repeat (8) @(posedge clk);
        rst = 0;

        for (cycles = 0; cycles < 5000; cycles = cycles + 1) begin
            @(posedge clk);
            if ((soc.cpu_core.register_file.registers[8] == 32'd1) &&
                (soc.cpu_core.register_file.registers[9] == 32'd2)) begin
                $display("REGRESSION_PASS: jalr_load");
                $finish;
            end
        end
        $fatal(1, "REGRESSION_FAIL: lw->jalr/ret did not finish; s0=%h s1=%h",
               soc.cpu_core.register_file.registers[8],
               soc.cpu_core.register_file.registers[9]);
    end
endmodule
