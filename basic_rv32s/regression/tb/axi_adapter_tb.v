`timescale 1ns/1ps

module axi_adapter_tb;
    reg clk = 0;
    reg reset = 1;
    always #5 clk = ~clk;

    reg axi_awready = 0, axi_wready = 0, axi_bvalid = 0;
    reg axi_arready = 0, axi_rvalid = 0;
    reg [31:0] axi_rdata = 0;
    reg mem_valid = 0, mem_instr = 0;
    reg [31:0] mem_addr = 0, mem_wdata = 0;
    reg [3:0] mem_wstrb = 0;
    wire axi_awvalid, axi_wvalid, axi_bready;
    wire axi_arvalid, axi_rready, mem_ready;
    wire [31:0] axi_awaddr, axi_wdata, axi_araddr, mem_rdata;
    wire [3:0] axi_wstrb;
    wire [2:0] axi_awprot, axi_arprot;
    integer completion_count = 0;

    RV32_AXI_Adapter dut (
        .clk(clk), .reset(reset),
        .axi_awvalid(axi_awvalid), .axi_awready(axi_awready),
        .axi_awaddr(axi_awaddr), .axi_awprot(axi_awprot),
        .axi_wvalid(axi_wvalid), .axi_wready(axi_wready),
        .axi_wdata(axi_wdata), .axi_wstrb(axi_wstrb),
        .axi_bvalid(axi_bvalid), .axi_bready(axi_bready),
        .axi_arvalid(axi_arvalid), .axi_arready(axi_arready),
        .axi_araddr(axi_araddr), .axi_arprot(axi_arprot),
        .axi_rvalid(axi_rvalid), .axi_rready(axi_rready),
        .axi_rdata(axi_rdata),
        .mem_valid(mem_valid), .mem_instr(mem_instr),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata), .mem_wstrb(mem_wstrb),
        .mem_ready(mem_ready), .mem_rdata(mem_rdata)
    );

    always @(posedge clk)
        if (!reset && mem_ready)
            completion_count <= completion_count + 1;

    initial begin
        repeat (3) @(posedge clk);
        reset = 0;

        // Read request: the native request stays asserted after completion.
        @(negedge clk);
        mem_valid = 1;
        mem_instr = 1;
        mem_addr = 32'h0000_1234;
        mem_wstrb = 0;
        wait (axi_arvalid);
        if (axi_araddr !== 32'h0000_1234 || axi_arprot !== 3'b100)
            $fatal(1, "REGRESSION_FAIL: AXI read payload changed");
        @(negedge clk); axi_arready = 1;
        @(negedge clk); axi_arready = 0;
        wait (axi_rready);
        @(negedge clk); axi_rdata = 32'hCAFE_BABE; axi_rvalid = 1; #1;
        if (!mem_ready || mem_rdata !== 32'hCAFE_BABE)
            $fatal(1, "REGRESSION_FAIL: AXI read completion missing");
        @(posedge clk);
        @(negedge clk); axi_rvalid = 0;
        repeat (3) @(posedge clk);
        if (completion_count != 1)
            $fatal(1, "REGRESSION_FAIL: read response replayed (%0d)", completion_count);
        @(negedge clk); mem_valid = 0;
        repeat (2) @(posedge clk);

        // Write request: AW and W are deliberately accepted separately.
        @(negedge clk);
        mem_valid = 1;
        mem_addr = 32'h0000_5678;
        mem_wdata = 32'h1234_ABCD;
        mem_wstrb = 4'hF;
        wait (axi_awvalid && axi_wvalid);
        @(negedge clk); axi_awready = 1;
        @(negedge clk); axi_awready = 0;
        repeat (2) @(negedge clk);
        axi_wready = 1;
        @(negedge clk); axi_wready = 0;
        wait (axi_bready);
        @(negedge clk); axi_bvalid = 1; #1;
        if (!mem_ready)
            $fatal(1, "REGRESSION_FAIL: AXI write completion missing");
        @(posedge clk);
        @(negedge clk); axi_bvalid = 0;
        repeat (3) @(posedge clk);
        if (completion_count != 2)
            $fatal(1, "REGRESSION_FAIL: write response replayed (%0d)", completion_count);

        $display("REGRESSION_PASS: axi_adapter");
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "REGRESSION_FAIL: axi_adapter timeout");
    end
endmodule
