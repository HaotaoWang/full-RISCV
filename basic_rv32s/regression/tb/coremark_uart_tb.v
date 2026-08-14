`timescale 1ns/1ps

module coremark_uart_tb;
    reg clk = 0;
    reg rst = 1;
    reg [2047:0] hex_file;
    wire [7:0] uart_data;
    wire uart_start;
    reg uart_busy = 0;
    integer uart_busy_cycles = 0;
    wire [31:0] retire_instruction;
    wire [3:0] led;
    integer uart_count = 0;
    integer valid_index = 0, list_index = 0, matrix_index = 0, state_index = 0;
    integer pass_index = 0, fail_index = 0, trap_index = 0;
    reg valid_seen = 0, list_seen = 0, matrix_seen = 0, state_seen = 0;
    reg pass_prefix_seen = 0, pass_seen = 0, cycle_nonzero = 0;
    reg fail_seen = 0, trap_seen = 0;
    reg [8*28-1:0] valid_text = "Correct operation validated.";
    reg [8*25-1:0] list_text = "[0]crclist       : 0xe714";
    reg [8*25-1:0] matrix_text = "[0]crcmatrix     : 0x1fd7";
    reg [8*25-1:0] state_text = "[0]crcstate      : 0x8e3a";
    reg [8*33-1:0] pass_text = "COREMARK PASS iterations=1 ticks=";
    reg [8*13-1:0] fail_text = "COREMARK FAIL";
    reg [8*6-1:0] trap_text = "[TRAP]";

    always #5 clk = ~clk;

    RV32_SoC_AXI_Top soc (
        .clk(clk), .rst(rst), .UART_busy(uart_busy),
        .mmio_uart_tx_data(uart_data), .mmio_uart_tx_start(uart_start),
        .retire_instruction(retire_instruction), .mmio_led(led)
    );

    // Model the transmitter accepting one byte and remaining busy afterward.
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

            if (!valid_seen && uart_data == valid_text[8*(27-valid_index) +: 8]) begin
                if (valid_index == 27) valid_seen = 1;
                else valid_index = valid_index + 1;
            end else valid_index = (uart_data == "C") ? 1 : 0;

            if (!list_seen && uart_data == list_text[8*(24-list_index) +: 8]) begin
                if (list_index == 24) list_seen = 1;
                else list_index = list_index + 1;
            end else list_index = (uart_data == "[") ? 1 : 0;

            if (!matrix_seen && uart_data == matrix_text[8*(24-matrix_index) +: 8]) begin
                if (matrix_index == 24) matrix_seen = 1;
                else matrix_index = matrix_index + 1;
            end else matrix_index = (uart_data == "[") ? 1 : 0;

            if (!state_seen && uart_data == state_text[8*(24-state_index) +: 8]) begin
                if (state_index == 24) state_seen = 1;
                else state_index = state_index + 1;
            end else state_index = (uart_data == "[") ? 1 : 0;

            if (!pass_prefix_seen && uart_data == pass_text[8*(32-pass_index) +: 8]) begin
                if (pass_index == 32) begin
                    pass_prefix_seen = 1;
                    pass_index = 0;
                end else pass_index = pass_index + 1;
            end else pass_index = (uart_data == "C") ? 1 : 0;
            if (pass_prefix_seen) begin
                if (uart_data >= "1" && uart_data <= "9") cycle_nonzero = 1;
                if (uart_data == 8'h0a && cycle_nonzero) pass_seen = 1;
            end

            if (!fail_seen && uart_data == fail_text[8*(12-fail_index) +: 8]) begin
                if (fail_index == 12) fail_seen = 1;
                else fail_index = fail_index + 1;
            end else fail_index = (uart_data == "C") ? 1 : 0;

            if (!trap_seen && uart_data == trap_text[8*(5-trap_index) +: 8]) begin
                if (trap_index == 5) trap_seen = 1;
                else trap_index = trap_index + 1;
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

        if (fail_seen || trap_seen)
            $fatal(1, "REGRESSION_FAIL: CoreMark reported failure or trap");
        if (!valid_seen || !list_seen || !matrix_seen || !state_seen || !pass_seen)
            $fatal(1, "REGRESSION_FAIL: incomplete CoreMark validation valid=%0d list=%0d matrix=%0d state=%0d pass=%0d",
                   valid_seen, list_seen, matrix_seen, state_seen, pass_seen);
        if (uart_count < 300)
            $fatal(1, "REGRESSION_FAIL: incomplete CoreMark UART report (%0d bytes)", uart_count);
        $display("\nREGRESSION_PASS: coremark_smoke");
        $finish;
    end

    initial begin
        repeat (2500000) @(posedge clk);
        $fatal(1, "REGRESSION_FAIL: coremark_smoke timeout pc=%h uart_bytes=%0d",
               soc.cpu_core.pc, uart_count);
    end
endmodule
