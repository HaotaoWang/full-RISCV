// ============================================================================
// FPGA Top-Level Wrapper for Kintex-7 MK160FA
// ============================================================================
// 功能:
//   1. 时钟分频: 板载时钟 -> CPU 工作时钟
//   2. 复位消抖: 物理按键 -> 干净的同步复位信号
//   3. LED 输出: 将寄存器 x3 的低 8 位映射到板载 LED
//   4. UART 直通 (预留)
// ============================================================================

`timescale 1ns / 1ps

module FPGA_Top (
    input  wire       sys_clk,     // 板载系统时钟 (需要查原理图确认频率)
    input  wire       sys_rst_n,   // 板载复位按键 (active low, 按下=0)

    output wire [3:0] led          // 板载 LED x4 (active high)
);

    // =====================================================================
    //  时钟分频 (简单二分频)
    // =====================================================================
    // 如果板载时钟是 200MHz, 分频后为 100MHz
    // 如果板载时钟是 100MHz, 分频后为 50MHz
    // 你可以根据实际需求调整分频比

    reg clk_div = 1'b0;
    always @(posedge sys_clk) begin
        clk_div <= ~clk_div;
    end

    wire cpu_clk;
    BUFG bufg_inst (
        .I(clk_div),
        .O(cpu_clk)
    );

    // =====================================================================
    //  复位消抖 (Synchronous Reset Generator)
    // =====================================================================
    // 将异步的外部按键信号同步到 cpu_clk 域
    // 并产生 active-high 的内部复位
    // KEY1 是 Active Low: 按下=0, 松开=1（带PULLUP）

    reg [3:0] rst_shift = 4'b0000;  // 上电后默认处于复位状态，等待时钟稳定及外部拉高
    wire cpu_rst = ~rst_shift[3];   // 取反：rst_shift=1111->cpu_rst=0(运行), rst_shift=0000->cpu_rst=1(复位)

    always @(posedge cpu_clk) begin
        rst_shift <= {rst_shift[2:0], sys_rst_n};
        // sys_rst_n=1 (松开/PULLUP) -> 移入1 -> rst_shift全1 -> cpu_rst=0 (运行)
        // sys_rst_n=0 (按下KEY1)    -> 移入0 -> rst_shift全0 -> cpu_rst=1 (复位)
        // 上电后 rst_shift=0000 -> cpu_rst=1(短暂复位), PULLUP后sys_rst_n=1, 4个周期后cpu_rst=0(运行)
    end

    // =====================================================================
    //  SoC 核心实例化
    // =====================================================================

    wire [31:0] retire_instruction;
    wire [7:0]  mmio_uart_tx_data;
    wire        mmio_uart_tx_start;
    wire [3:0]  mmio_led;

    RV32_SoC_AXI_Top_FPGA #(
        .RAM_ADDR_WIDTH(16),
        .INIT_FILE("led_test_axi.hex")
        //.INIT_FILE("simple_led_test.hex")
    ) soc_inst (
        .clk(cpu_clk),
        .rst(cpu_rst),
        .UART_busy(1'b0),
        .retire_instruction(retire_instruction),
        .mmio_uart_tx_data(mmio_uart_tx_data),
        .mmio_uart_tx_start(mmio_uart_tx_start),
        .mmio_led(mmio_led)
    );

    // =====================================================================
    //  LED 输出
    // =====================================================================
    assign led = mmio_led;

endmodule


// ============================================================================
// FPGA 专用 SoC 顶层 (使用 axil_ram_init 替代 axil_ram)
// ============================================================================

module RV32_SoC_AXI_Top_FPGA #(
    parameter RAM_ADDR_WIDTH = 16,
    parameter INIT_FILE = ""
)(
    input  wire clk,
    input  wire rst,
    input  wire        UART_busy,
    output wire [7:0]  mmio_uart_tx_data,
    output wire        mmio_uart_tx_start,
    output wire [31:0] retire_instruction,
    output wire [3:0]  mmio_led
);

    // --- CPU IF AXI Master ---
    wire        cpu_if_awvalid, cpu_if_awready;
    wire [31:0] cpu_if_awaddr;
    wire [ 2:0] cpu_if_awprot;
    wire        cpu_if_wvalid,  cpu_if_wready;
    wire [31:0] cpu_if_wdata;
    wire [ 3:0] cpu_if_wstrb;
    wire        cpu_if_bvalid,  cpu_if_bready;
    wire        cpu_if_arvalid, cpu_if_arready;
    wire [31:0] cpu_if_araddr;
    wire [ 2:0] cpu_if_arprot;
    wire        cpu_if_rvalid,  cpu_if_rready;
    wire [31:0] cpu_if_rdata;

    // --- CPU MEM AXI Master ---
    wire        cpu_mem_awvalid, cpu_mem_awready;
    wire [31:0] cpu_mem_awaddr;
    wire [ 2:0] cpu_mem_awprot;
    wire        cpu_mem_wvalid,  cpu_mem_wready;
    wire [31:0] cpu_mem_wdata;
    wire [ 3:0] cpu_mem_wstrb;
    wire        cpu_mem_bvalid,  cpu_mem_bready;
    wire        cpu_mem_arvalid, cpu_mem_arready;
    wire [31:0] cpu_mem_araddr;
    wire [ 2:0] cpu_mem_arprot;
    wire        cpu_mem_rvalid,  cpu_mem_rready;
    wire [31:0] cpu_mem_rdata;

    // --- Interconnect -> RAM ---
    wire        ram_awvalid, ram_awready;
    wire [31:0] ram_awaddr;
    wire [ 2:0] ram_awprot;
    wire [31:0] ram_wdata;
    wire [ 3:0] ram_wstrb;
    wire        ram_wvalid, ram_wready;
    wire [ 1:0] ram_bresp;
    wire        ram_bvalid, ram_bready;
    wire        ram_arvalid, ram_arready;
    wire [31:0] ram_araddr;
    wire [ 2:0] ram_arprot;
    wire [31:0] ram_rdata;
    wire [ 1:0] ram_rresp;
    wire        ram_rvalid, ram_rready;

    // CPU 核心
    RV32I46F5SPMMIO cpu_core (
        .clk(clk), .reset(rst), .UART_busy(UART_busy),
        .retire_instruction(retire_instruction),
        .mmio_uart_tx_data(mmio_uart_tx_data),
        .mmio_uart_tx_start(mmio_uart_tx_start),
        .mmio_led(mmio_led),
        // IF AXI
        .m_axi_if_awvalid(cpu_if_awvalid), .m_axi_if_awready(cpu_if_awready),
        .m_axi_if_awaddr(cpu_if_awaddr),   .m_axi_if_awprot(cpu_if_awprot),
        .m_axi_if_wvalid(cpu_if_wvalid),   .m_axi_if_wready(cpu_if_wready),
        .m_axi_if_wdata(cpu_if_wdata),     .m_axi_if_wstrb(cpu_if_wstrb),
        .m_axi_if_bvalid(cpu_if_bvalid),   .m_axi_if_bready(cpu_if_bready),
        .m_axi_if_arvalid(cpu_if_arvalid), .m_axi_if_arready(cpu_if_arready),
        .m_axi_if_araddr(cpu_if_araddr),   .m_axi_if_arprot(cpu_if_arprot),
        .m_axi_if_rvalid(cpu_if_rvalid),   .m_axi_if_rready(cpu_if_rready),
        .m_axi_if_rdata(cpu_if_rdata),
        // MEM AXI
        .m_axi_mem_awvalid(cpu_mem_awvalid), .m_axi_mem_awready(cpu_mem_awready),
        .m_axi_mem_awaddr(cpu_mem_awaddr),   .m_axi_mem_awprot(cpu_mem_awprot),
        .m_axi_mem_wvalid(cpu_mem_wvalid),   .m_axi_mem_wready(cpu_mem_wready),
        .m_axi_mem_wdata(cpu_mem_wdata),     .m_axi_mem_wstrb(cpu_mem_wstrb),
        .m_axi_mem_bvalid(cpu_mem_bvalid),   .m_axi_mem_bready(cpu_mem_bready),
        .m_axi_mem_arvalid(cpu_mem_arvalid), .m_axi_mem_arready(cpu_mem_arready),
        .m_axi_mem_araddr(cpu_mem_araddr),   .m_axi_mem_arprot(cpu_mem_arprot),
        .m_axi_mem_rvalid(cpu_mem_rvalid),   .m_axi_mem_rready(cpu_mem_rready),
        .m_axi_mem_rdata(cpu_mem_rdata)
    );

    // AXI Interconnect
    axil_interconnect #(
        .S_COUNT(2), .M_COUNT(1),
        .DATA_WIDTH(32), .ADDR_WIDTH(32),
        .M_ADDR_WIDTH({1{32'd16}})
    ) bus_interconnect (
        .clk(clk), .rst(rst),
        .s_axil_awaddr  ({cpu_mem_awaddr,  cpu_if_awaddr}),
        .s_axil_awprot  ({cpu_mem_awprot,  cpu_if_awprot}),
        .s_axil_awvalid ({cpu_mem_awvalid, cpu_if_awvalid}),
        .s_axil_awready ({cpu_mem_awready, cpu_if_awready}),
        .s_axil_wdata   ({cpu_mem_wdata,   cpu_if_wdata}),
        .s_axil_wstrb   ({cpu_mem_wstrb,   cpu_if_wstrb}),
        .s_axil_wvalid  ({cpu_mem_wvalid,  cpu_if_wvalid}),
        .s_axil_wready  ({cpu_mem_wready,  cpu_if_wready}),
        .s_axil_bresp   (),
        .s_axil_bvalid  ({cpu_mem_bvalid,  cpu_if_bvalid}),
        .s_axil_bready  ({cpu_mem_bready,  cpu_if_bready}),
        .s_axil_araddr  ({cpu_mem_araddr,  cpu_if_araddr}),
        .s_axil_arprot  ({cpu_mem_arprot,  cpu_if_arprot}),
        .s_axil_arvalid ({cpu_mem_arvalid, cpu_if_arvalid}),
        .s_axil_arready ({cpu_mem_arready, cpu_if_arready}),
        .s_axil_rdata   ({cpu_mem_rdata,   cpu_if_rdata}),
        .s_axil_rresp   (),
        .s_axil_rvalid  ({cpu_mem_rvalid,  cpu_if_rvalid}),
        .s_axil_rready  ({cpu_mem_rready,  cpu_if_rready}),
        // RAM slave
        .m_axil_awaddr(ram_awaddr), .m_axil_awprot(ram_awprot),
        .m_axil_awvalid(ram_awvalid), .m_axil_awready(ram_awready),
        .m_axil_wdata(ram_wdata), .m_axil_wstrb(ram_wstrb),
        .m_axil_wvalid(ram_wvalid), .m_axil_wready(ram_wready),
        .m_axil_bresp(ram_bresp), .m_axil_bvalid(ram_bvalid), .m_axil_bready(ram_bready),
        .m_axil_araddr(ram_araddr), .m_axil_arprot(ram_arprot),
        .m_axil_arvalid(ram_arvalid), .m_axil_arready(ram_arready),
        .m_axil_rdata(ram_rdata), .m_axil_rresp(ram_rresp),
        .m_axil_rvalid(ram_rvalid), .m_axil_rready(ram_rready)
    );

    // 使用自带初始化的 RAM
    axil_ram_init #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(RAM_ADDR_WIDTH),
        .INIT_FILE(INIT_FILE)
    ) main_memory (
        .clk(clk), .rst(rst),
        .s_axil_awaddr(ram_awaddr[RAM_ADDR_WIDTH-1:0]), .s_axil_awprot(ram_awprot),
        .s_axil_awvalid(ram_awvalid), .s_axil_awready(ram_awready),
        .s_axil_wdata(ram_wdata), .s_axil_wstrb(ram_wstrb),
        .s_axil_wvalid(ram_wvalid), .s_axil_wready(ram_wready),
        .s_axil_bresp(ram_bresp), .s_axil_bvalid(ram_bvalid), .s_axil_bready(ram_bready),
        .s_axil_araddr(ram_araddr[RAM_ADDR_WIDTH-1:0]), .s_axil_arprot(ram_arprot),
        .s_axil_arvalid(ram_arvalid), .s_axil_arready(ram_arready),
        .s_axil_rdata(ram_rdata), .s_axil_rresp(ram_rresp),
        .s_axil_rvalid(ram_rvalid), .s_axil_rready(ram_rready)
    );

endmodule
