`timescale 1ns/1ps

module misaligned_csr_tb;
    reg clk = 0;
    reg rst = 1;
    reg [2047:0] hex_file;
    wire [7:0] uart_data;
    wire uart_start;
    wire [31:0] retire_instruction;
    wire [3:0] led;
    integer cycles, record;
    integer expected_cause;
    reg [31:0] expected_tval;

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

        for (cycles = 0; cycles < 100000; cycles = cycles + 1) begin
            @(posedge clk);
            if (soc.main_memory.mem[3136] == 32'h600d600d) begin
                if (soc.main_memory.mem[3200] != 4)
                    $fatal(1, "REGRESSION_FAIL: exception count=%0d",
                           soc.main_memory.mem[3200]);
                for (record = 0; record < 4; record = record + 1) begin
                    expected_cause = (record < 2) ? 4 : 6;
                    expected_tval = (record == 3) ? 32'h3002 : 32'h3001;
                    if (soc.main_memory.mem[3204 + record*4] != expected_cause)
                        $fatal(1, "REGRESSION_FAIL: record %0d mcause=%h expected=%h",
                               record, soc.main_memory.mem[3204 + record*4], expected_cause);
                    if (soc.main_memory.mem[3205 + record*4] !=
                        soc.main_memory.mem[3264 + record])
                        $fatal(1, "REGRESSION_FAIL: record %0d mepc=%h expected=%h",
                               record, soc.main_memory.mem[3205 + record*4],
                               soc.main_memory.mem[3264 + record]);
                    if (soc.main_memory.mem[3206 + record*4] != expected_tval)
                        $fatal(1, "REGRESSION_FAIL: record %0d mtval=%h expected=%h",
                               record, soc.main_memory.mem[3206 + record*4], expected_tval);
                    if (soc.main_memory.mem[3207 + record*4][3] != 1'b0 ||
                        soc.main_memory.mem[3207 + record*4][7] != 1'b1 ||
                        soc.main_memory.mem[3207 + record*4][12:11] != 2'b11)
                        $fatal(1, "REGRESSION_FAIL: record %0d trap mstatus=%h",
                               record, soc.main_memory.mem[3207 + record*4]);
                end
                if (soc.main_memory.mem[3201][3] != 1'b1 ||
                    soc.main_memory.mem[3201][7] != 1'b1 ||
                    soc.main_memory.mem[3201][12:11] != 2'b00)
                    $fatal(1, "REGRESSION_FAIL: returned mstatus=%h",
                           soc.main_memory.mem[3201]);
                $display("REGRESSION_PASS: misaligned_csr");
                $finish;
            end
            if (soc.main_memory.mem[3136] != 0 &&
                soc.main_memory.mem[3136] != 32'h600d600d)
                $fatal(1, "REGRESSION_FAIL: firmware error code=%0d",
                       soc.main_memory.mem[3136]);
        end
        $fatal(1, "REGRESSION_FAIL: misaligned_csr timeout pc=%h count=%0d",
               soc.cpu_core.pc, soc.main_memory.mem[3200]);
    end
endmodule
