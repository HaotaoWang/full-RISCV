`timescale 1ns/1ps
`include "modules/headers/trap.vh"

module trap_rearm_tb;
    reg clk = 0;
    reg reset = 1;
    reg [3:0] trap_status = `TRAP_NONE;
    reg [31:0] csr_read_data = 32'h0000_0100;
    wire [31:0] trap_target;
    wire ic_clean, debug_mode, csr_write_enable, trap_done;
    wire misaligned_instruction_flush, misaligned_memory_flush;
    wire pth_done_flush, trap_jump, standby_mode;
    wire [11:0] csr_trap_address;
    wire [31:0] csr_trap_write_data;
    integer jump_count = 0;

    always #5 clk = ~clk;
    always @(posedge clk)
        if (!reset && trap_jump)
            jump_count <= jump_count + 1;

    TrapController dut (
        .clk(clk), .reset(reset),
        .current_pc(32'h20), .ID_pc(32'h24), .EX_pc(32'h28),
        .MEM_pc(32'h2c), .WB_pc(32'h30),
        .trap_status(trap_status), .csr_read_data(csr_read_data),
        .trap_value(32'b0),
        .current_mode(2'b11), .medeleg(32'b0), .mideleg(32'b0),
        .trap_target(trap_target), .ic_clean(ic_clean), .debug_mode(debug_mode),
        .csr_write_enable(csr_write_enable), .csr_trap_address(csr_trap_address),
        .csr_trap_write_data(csr_trap_write_data), .trap_done(trap_done),
        .misaligned_instruction_flush(misaligned_instruction_flush),
        .misaligned_memory_flush(misaligned_memory_flush),
        .pth_done_flush(pth_done_flush), .trap_jump(trap_jump),
        .standby_mode(standby_mode)
    );

    initial begin
        repeat (3) @(posedge clk);
        reset = 0;
        @(negedge clk); trap_status = `TRAP_MRET;
        repeat (16) @(posedge clk);
        if (jump_count != 1)
            $fatal(1, "REGRESSION_FAIL: held MRET handled %0d times", jump_count);

        @(negedge clk); trap_status = `TRAP_NONE;
        repeat (3) @(posedge clk);
        @(negedge clk); trap_status = `TRAP_MRET;
        repeat (16) @(posedge clk);
        if (jump_count != 2)
            $fatal(1, "REGRESSION_FAIL: MRET did not rearm (%0d)", jump_count);

        $display("REGRESSION_PASS: trap_rearm");
        $finish;
    end
endmodule
