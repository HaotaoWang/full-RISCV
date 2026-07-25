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
// FPGA 专用 SoC 顶层 (内嵌于此文件, 避免 Vivado 需要手动加文件)
// 使用 axi_ram_init 替代 axi_ram, Full AXI4 双通道 (ICache + DCache)
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

    // --- CPU IF (取指) Full AXI4 Master 信号 ---
    wire        cpu_if_awvalid, cpu_if_awready;
    wire [31:0] cpu_if_awaddr;
    wire [ 3:0] cpu_if_awid;
    wire [ 7:0] cpu_if_awlen;
    wire [ 1:0] cpu_if_awburst;
    wire        cpu_if_wvalid,  cpu_if_wready;
    wire [31:0] cpu_if_wdata;
    wire [ 3:0] cpu_if_wstrb;
    wire        cpu_if_wlast;
    wire        cpu_if_bready;
    wire        cpu_if_arvalid, cpu_if_arready;
    wire [31:0] cpu_if_araddr;
    wire [ 3:0] cpu_if_arid;
    wire [ 7:0] cpu_if_arlen;
    wire [ 1:0] cpu_if_arburst;
    wire        cpu_if_rready;
    wire        cpu_if_bvalid;
    wire [ 1:0] cpu_if_bresp;
    wire [ 3:0] cpu_if_bid;
    wire        cpu_if_rvalid;
    wire [31:0] cpu_if_rdata;
    wire [ 1:0] cpu_if_rresp;
    wire [ 3:0] cpu_if_rid;
    wire        cpu_if_rlast;

    // --- ICache 未用到的 AXI 信号 (补零) ---
    wire [ 2:0] cpu_if_awsize  = 3'b010;
    wire        cpu_if_awlock  = 1'b0;
    wire [ 3:0] cpu_if_awcache = 4'b0;
    wire [ 2:0] cpu_if_awprot  = 3'b100;
    wire [ 3:0] cpu_if_awqos   = 4'b0;
    wire [ 2:0] cpu_if_arsize  = 3'b010;
    wire        cpu_if_arlock  = 1'b0;
    wire [ 3:0] cpu_if_arcache = 4'b0;
    wire [ 2:0] cpu_if_arprot  = 3'b100;
    wire [ 3:0] cpu_if_arqos   = 4'b0;

    // --- CPU MEM (数据) Full AXI4 Master 信号 (DCache) ---
    wire        cpu_mem_awvalid, cpu_mem_awready;
    wire [31:0] cpu_mem_awaddr;
    wire [ 3:0] cpu_mem_awid;
    wire [ 7:0] cpu_mem_awlen;
    wire [ 1:0] cpu_mem_awburst;
    wire [ 2:0] cpu_mem_awprot;
    wire        cpu_mem_wvalid,  cpu_mem_wready;
    wire [31:0] cpu_mem_wdata;
    wire [ 3:0] cpu_mem_wstrb;
    wire        cpu_mem_wlast;
    wire        cpu_mem_bvalid,  cpu_mem_bready;
    wire [ 1:0] cpu_mem_bresp;
    wire [ 3:0] cpu_mem_bid;
    wire        cpu_mem_arvalid, cpu_mem_arready;
    wire [31:0] cpu_mem_araddr;
    wire [ 3:0] cpu_mem_arid;
    wire [ 7:0] cpu_mem_arlen;
    wire [ 1:0] cpu_mem_arburst;
    wire [ 2:0] cpu_mem_arprot;
    wire        cpu_mem_rvalid,  cpu_mem_rready;
    wire [31:0] cpu_mem_rdata;
    wire [ 1:0] cpu_mem_rresp;
    wire [ 3:0] cpu_mem_rid;
    wire        cpu_mem_rlast;

    // --- DCache 未用到的 AXI 信号 (补零) ---
    wire [ 2:0] cpu_mem_awsize  = 3'b010;
    wire        cpu_mem_awlock  = 1'b0;
    wire [ 3:0] cpu_mem_awcache = 4'b0;
    wire [ 3:0] cpu_mem_awqos   = 4'b0;
    wire [ 2:0] cpu_mem_arsize  = 3'b010;
    wire        cpu_mem_arlock  = 1'b0;
    wire [ 3:0] cpu_mem_arcache = 4'b0;
    wire [ 3:0] cpu_mem_arqos   = 4'b0;

    // --- Interconnect -> RAM AXI 信号 ---
    wire        ram_awvalid, ram_awready;
    wire [31:0] ram_awaddr;
    wire [ 3:0] ram_awid;
    wire [ 7:0] ram_awlen;
    wire [ 2:0] ram_awsize;
    wire [ 1:0] ram_awburst;
    wire        ram_awlock;
    wire [ 3:0] ram_awcache;
    wire [ 2:0] ram_awprot;
    wire [ 3:0] ram_awqos;
    wire        ram_wvalid, ram_wready;
    wire [31:0] ram_wdata;
    wire [ 3:0] ram_wstrb;
    wire        ram_wlast;
    wire        ram_bvalid, ram_bready;
    wire [ 3:0] ram_bid;
    wire [ 1:0] ram_bresp;
    wire        ram_arvalid, ram_arready;
    wire [31:0] ram_araddr;
    wire [ 3:0] ram_arid;
    wire [ 7:0] ram_arlen;
    wire [ 2:0] ram_arsize;
    wire [ 1:0] ram_arburst;
    wire        ram_arlock;
    wire [ 3:0] ram_arcache;
    wire [ 2:0] ram_arprot;
    wire [ 3:0] ram_arqos;
    wire        ram_rvalid, ram_rready;
    wire [31:0] ram_rdata;
    wire [ 3:0] ram_rid;
    wire [ 1:0] ram_rresp;
    wire        ram_rlast;

    // =========================================================
    // CPU 核心
    // =========================================================
    RV32I46F5SPMMIO cpu_core (
        .clk(clk), .reset(rst), .UART_busy(UART_busy),
        .retire_instruction(retire_instruction),
        .mmio_uart_tx_data(mmio_uart_tx_data),
        .mmio_uart_tx_start(mmio_uart_tx_start),
        .mmio_led(mmio_led),
        // IF AXI Master (ICache)
        .m_axi_if_awvalid(cpu_if_awvalid),  .m_axi_if_awready(cpu_if_awready),
        .m_axi_if_awaddr(cpu_if_awaddr),    .m_axi_if_awid(cpu_if_awid),
        .m_axi_if_awlen(cpu_if_awlen),      .m_axi_if_awburst(cpu_if_awburst),
        .m_axi_if_wvalid(cpu_if_wvalid),    .m_axi_if_wready(cpu_if_wready),
        .m_axi_if_wdata(cpu_if_wdata),      .m_axi_if_wstrb(cpu_if_wstrb),
        .m_axi_if_wlast(cpu_if_wlast),
        .m_axi_if_bvalid(cpu_if_bvalid),    .m_axi_if_bready(cpu_if_bready),
        .m_axi_if_bresp(cpu_if_bresp),      .m_axi_if_bid(cpu_if_bid),
        .m_axi_if_arvalid(cpu_if_arvalid),  .m_axi_if_arready(cpu_if_arready),
        .m_axi_if_araddr(cpu_if_araddr),    .m_axi_if_arid(cpu_if_arid),
        .m_axi_if_arlen(cpu_if_arlen),      .m_axi_if_arburst(cpu_if_arburst),
        .m_axi_if_rready(cpu_if_rready),    .m_axi_if_rvalid(cpu_if_rvalid),
        .m_axi_if_rdata(cpu_if_rdata),      .m_axi_if_rresp(cpu_if_rresp),
        .m_axi_if_rid(cpu_if_rid),          .m_axi_if_rlast(cpu_if_rlast),
        // MEM AXI Master (DCache - Full AXI4)
        .m_axi_mem_awvalid(cpu_mem_awvalid), .m_axi_mem_awready(cpu_mem_awready),
        .m_axi_mem_awaddr(cpu_mem_awaddr),   .m_axi_mem_awid(cpu_mem_awid),
        .m_axi_mem_awlen(cpu_mem_awlen),     .m_axi_mem_awburst(cpu_mem_awburst),
        .m_axi_mem_awprot(cpu_mem_awprot),
        .m_axi_mem_wvalid(cpu_mem_wvalid),   .m_axi_mem_wready(cpu_mem_wready),
        .m_axi_mem_wdata(cpu_mem_wdata),     .m_axi_mem_wstrb(cpu_mem_wstrb),
        .m_axi_mem_wlast(cpu_mem_wlast),
        .m_axi_mem_bvalid(cpu_mem_bvalid),   .m_axi_mem_bready(cpu_mem_bready),
        .m_axi_mem_bresp(cpu_mem_bresp),     .m_axi_mem_bid(cpu_mem_bid),
        .m_axi_mem_arvalid(cpu_mem_arvalid), .m_axi_mem_arready(cpu_mem_arready),
        .m_axi_mem_araddr(cpu_mem_araddr),   .m_axi_mem_arid(cpu_mem_arid),
        .m_axi_mem_arlen(cpu_mem_arlen),     .m_axi_mem_arburst(cpu_mem_arburst),
        .m_axi_mem_arprot(cpu_mem_arprot),
        .m_axi_mem_rvalid(cpu_mem_rvalid),   .m_axi_mem_rready(cpu_mem_rready),
        .m_axi_mem_rdata(cpu_mem_rdata),     .m_axi_mem_rresp(cpu_mem_rresp),
        .m_axi_mem_rid(cpu_mem_rid),         .m_axi_mem_rlast(cpu_mem_rlast)
    );

    // =========================================================
    // AXI 总线互联矩阵 (2主1从: ICache + DCache -> RAM)
    // =========================================================
    axi_interconnect #(
        .S_COUNT(2), .M_COUNT(1),
        .DATA_WIDTH(32), .ADDR_WIDTH(32),
        .ID_WIDTH(4),
        .M_ADDR_WIDTH({1{32'd16}})
    ) bus_interconnect (
        .clk(clk), .rst(rst),
        // Slave 端口 [MEM:IF] 拼接
        .s_axi_awid     ({cpu_mem_awid,    cpu_if_awid}),
        .s_axi_awaddr   ({cpu_mem_awaddr,  cpu_if_awaddr}),
        .s_axi_awlen    ({cpu_mem_awlen,   cpu_if_awlen}),
        .s_axi_awsize   ({cpu_mem_awsize,  cpu_if_awsize}),
        .s_axi_awburst  ({cpu_mem_awburst, cpu_if_awburst}),
        .s_axi_awlock   ({cpu_mem_awlock,  cpu_if_awlock}),
        .s_axi_awcache  ({cpu_mem_awcache, cpu_if_awcache}),
        .s_axi_awprot   ({cpu_mem_awprot,  cpu_if_awprot}),
        .s_axi_awqos    ({cpu_mem_awqos,   cpu_if_awqos}),
        .s_axi_awvalid  ({cpu_mem_awvalid, cpu_if_awvalid}),
        .s_axi_awready  ({cpu_mem_awready, cpu_if_awready}),
        .s_axi_wdata    ({cpu_mem_wdata,   cpu_if_wdata}),
        .s_axi_wstrb    ({cpu_mem_wstrb,   cpu_if_wstrb}),
        .s_axi_wlast    ({cpu_mem_wlast,   cpu_if_wlast}),
        .s_axi_wvalid   ({cpu_mem_wvalid,  cpu_if_wvalid}),
        .s_axi_wready   ({cpu_mem_wready,  cpu_if_wready}),
        .s_axi_bid      ({cpu_mem_bid,     cpu_if_bid}),
        .s_axi_bresp    ({cpu_mem_bresp,   cpu_if_bresp}),
        .s_axi_bvalid   ({cpu_mem_bvalid,  cpu_if_bvalid}),
        .s_axi_bready   ({cpu_mem_bready,  cpu_if_bready}),
        .s_axi_arid     ({cpu_mem_arid,    cpu_if_arid}),
        .s_axi_araddr   ({cpu_mem_araddr,  cpu_if_araddr}),
        .s_axi_arlen    ({cpu_mem_arlen,   cpu_if_arlen}),
        .s_axi_arsize   ({cpu_mem_arsize,  cpu_if_arsize}),
        .s_axi_arburst  ({cpu_mem_arburst, cpu_if_arburst}),
        .s_axi_arlock   ({cpu_mem_arlock,  cpu_if_arlock}),
        .s_axi_arcache  ({cpu_mem_arcache, cpu_if_arcache}),
        .s_axi_arprot   ({cpu_mem_arprot,  cpu_if_arprot}),
        .s_axi_arqos    ({cpu_mem_arqos,   cpu_if_arqos}),
        .s_axi_arvalid  ({cpu_mem_arvalid, cpu_if_arvalid}),
        .s_axi_arready  ({cpu_mem_arready, cpu_if_arready}),
        .s_axi_rid      ({cpu_mem_rid,     cpu_if_rid}),
        .s_axi_rdata    ({cpu_mem_rdata,   cpu_if_rdata}),
        .s_axi_rresp    ({cpu_mem_rresp,   cpu_if_rresp}),
        .s_axi_rlast    ({cpu_mem_rlast,   cpu_if_rlast}),
        .s_axi_rvalid   ({cpu_mem_rvalid,  cpu_if_rvalid}),
        .s_axi_rready   ({cpu_mem_rready,  cpu_if_rready}),
        // Master 端口 -> RAM
        .m_axi_awid(ram_awid),       .m_axi_awaddr(ram_awaddr),
        .m_axi_awlen(ram_awlen),     .m_axi_awsize(ram_awsize),
        .m_axi_awburst(ram_awburst), .m_axi_awlock(ram_awlock),
        .m_axi_awcache(ram_awcache), .m_axi_awprot(ram_awprot),
        .m_axi_awqos(ram_awqos),     .m_axi_awvalid(ram_awvalid),
        .m_axi_awready(ram_awready),
        .m_axi_wdata(ram_wdata),     .m_axi_wstrb(ram_wstrb),
        .m_axi_wlast(ram_wlast),     .m_axi_wvalid(ram_wvalid),
        .m_axi_wready(ram_wready),
        .m_axi_bid(ram_bid),         .m_axi_bresp(ram_bresp),
        .m_axi_bvalid(ram_bvalid),   .m_axi_bready(ram_bready),
        .m_axi_arid(ram_arid),       .m_axi_araddr(ram_araddr),
        .m_axi_arlen(ram_arlen),     .m_axi_arsize(ram_arsize),
        .m_axi_arburst(ram_arburst), .m_axi_arlock(ram_arlock),
        .m_axi_arcache(ram_arcache), .m_axi_arprot(ram_arprot),
        .m_axi_arqos(ram_arqos),     .m_axi_arvalid(ram_arvalid),
        .m_axi_arready(ram_arready),
        .m_axi_rid(ram_rid),         .m_axi_rdata(ram_rdata),
        .m_axi_rresp(ram_rresp),     .m_axi_rlast(ram_rlast),
        .m_axi_rvalid(ram_rvalid),   .m_axi_rready(ram_rready)
    );

    // =========================================================
    // AXI RAM (带初始化, 使用 $readmemh 加载程序)
    // =========================================================
    axi_ram_init #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(RAM_ADDR_WIDTH),
        .ID_WIDTH(4),
        .INIT_FILE(INIT_FILE)
    ) main_memory (
        .clk(clk), .rst(rst),
        .s_axi_awid(ram_awid),
        .s_axi_awaddr(ram_awaddr[RAM_ADDR_WIDTH-1:0]),
        .s_axi_awlen(ram_awlen),     .s_axi_awsize(ram_awsize),
        .s_axi_awburst(ram_awburst), .s_axi_awlock(ram_awlock),
        .s_axi_awcache(ram_awcache), .s_axi_awprot(ram_awprot),
        .s_axi_awvalid(ram_awvalid), .s_axi_awready(ram_awready),
        .s_axi_wdata(ram_wdata),     .s_axi_wstrb(ram_wstrb),
        .s_axi_wlast(ram_wlast),     .s_axi_wvalid(ram_wvalid),
        .s_axi_wready(ram_wready),
        .s_axi_bid(ram_bid),         .s_axi_bresp(ram_bresp),
        .s_axi_bvalid(ram_bvalid),   .s_axi_bready(ram_bready),
        .s_axi_arid(ram_arid),
        .s_axi_araddr(ram_araddr[RAM_ADDR_WIDTH-1:0]),
        .s_axi_arlen(ram_arlen),     .s_axi_arsize(ram_arsize),
        .s_axi_arburst(ram_arburst), .s_axi_arlock(ram_arlock),
        .s_axi_arcache(ram_arcache), .s_axi_arprot(ram_arprot),
        .s_axi_arvalid(ram_arvalid), .s_axi_arready(ram_arready),
        .s_axi_rid(ram_rid),         .s_axi_rdata(ram_rdata),
        .s_axi_rresp(ram_rresp),     .s_axi_rlast(ram_rlast),
        .s_axi_rvalid(ram_rvalid),   .s_axi_rready(ram_rready)
    );

endmodule
