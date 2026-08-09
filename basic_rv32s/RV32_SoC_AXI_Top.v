// ============================================================================
// RV32 SoC AXI Top — 纯 Verilog 顶层
// ============================================================================
// 架构概览:
//   CPU Core (2x AXI Master)
//       |                |
//       | IF port(Full)  | MEM port(AXI-Lite)
//       v                v
//   +----------------------------+
//   | axi_interconnect           |
//   | (S_COUNT=2, M_COUNT=1)     |
//   +----------------------------+
//              |
//              v
//        +----------+
//        | axi_ram  |  (统一指令+数据内存)
//        +----------+
//
// 地址映射:
//   0x0000_0000 ~ 0x0000_FFFF : RAM (64KB, ADDR_WIDTH=16)
// ============================================================================

`timescale 1ns / 1ps

module RV32_SoC_AXI_Top #(
    parameter RAM_ADDR_WIDTH = 16, // 2^16 = 64KB RAM
    parameter INIT_FILE = ""       // 内存初始化文件
)(
    input  wire clk,
    input  wire rst,

    // UART 外部接口 (直通 CPU)
    input  wire        UART_busy,
    output wire [7:0]  mmio_uart_tx_data,
    output wire        mmio_uart_tx_start,

    // Debug: 退休指令观测口
    output wire [31:0] retire_instruction,
    
    // Board LED 输出
    output wire [3:0]  mmio_led
);

    // =====================================================================
    //  内部连线声明
    // =====================================================================
    
    wire timer_irq;

    // --- CPU IF (取指) AXI Master 信号 (Full AXI4) ---
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

    // --- CPU IF ICache missing AXI signals (tied off) ---
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

    // --- CPU MEM (数据) Full AXI4 Master 信号 (用于 DCache) ---
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

    // --- CPU MEM missing AXI signals (tied off) ---
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

    // --- Interconnect -> CLINT AXI 信号 ---
    wire        clint_awvalid, clint_awready;
    wire [31:0] clint_awaddr;
    wire [ 3:0] clint_awid;
    wire [ 7:0] clint_awlen;
    wire [ 2:0] clint_awsize;
    wire [ 1:0] clint_awburst;
    wire [ 0:0] clint_awlock;
    wire [ 3:0] clint_awcache;
    wire [ 2:0] clint_awprot;
    wire [ 3:0] clint_awqos;
    wire        clint_wvalid, clint_wready;
    wire [31:0] clint_wdata;
    wire [ 3:0] clint_wstrb;
    wire        clint_wlast;
    wire        clint_bvalid, clint_bready;
    wire [ 3:0] clint_bid;
    wire [ 1:0] clint_bresp;
    wire        clint_arvalid, clint_arready;
    wire [31:0] clint_araddr;
    wire [ 3:0] clint_arid;
    wire [ 7:0] clint_arlen;
    wire [ 2:0] clint_arsize;
    wire [ 1:0] clint_arburst;
    wire [ 0:0] clint_arlock;
    wire [ 3:0] clint_arcache;
    wire [ 2:0] clint_arprot;
    wire [ 3:0] clint_arqos;
    wire        clint_rvalid, clint_rready;
    wire [31:0] clint_rdata;
    wire [ 3:0] clint_rid;
    wire [ 1:0] clint_rresp;
    wire        clint_rlast;

    // =====================================================================
    //  模块实例化 1: CPU 核心
    // =====================================================================

    RV32I46F5SPMMIO cpu_core (
        .clk(clk),
        .reset(rst),
        .UART_busy(UART_busy),

        .retire_instruction(retire_instruction),
        .mmio_uart_tx_data(mmio_uart_tx_data),
        .mmio_uart_tx_start(mmio_uart_tx_start),
        .mmio_led(mmio_led),

        .timer_irq(timer_irq),
        .external_irq(1'b0), // 未使用外部中断

        // IF AXI Master
        .m_axi_if_awvalid(cpu_if_awvalid),
        .m_axi_if_awready(cpu_if_awready),
        .m_axi_if_awaddr(cpu_if_awaddr),
        .m_axi_if_awid(cpu_if_awid),
        .m_axi_if_awlen(cpu_if_awlen),
        .m_axi_if_awburst(cpu_if_awburst),
        .m_axi_if_wvalid(cpu_if_wvalid),
        .m_axi_if_wready(cpu_if_wready),
        .m_axi_if_wdata(cpu_if_wdata),
        .m_axi_if_wstrb(cpu_if_wstrb),
        .m_axi_if_wlast(cpu_if_wlast),
        .m_axi_if_bvalid(cpu_if_bvalid),
        .m_axi_if_bready(cpu_if_bready),
        .m_axi_if_bresp(cpu_if_bresp),
        .m_axi_if_bid(cpu_if_bid),
        .m_axi_if_arvalid(cpu_if_arvalid),
        .m_axi_if_arready(cpu_if_arready),
        .m_axi_if_araddr(cpu_if_araddr),
        .m_axi_if_arid(cpu_if_arid),
        .m_axi_if_arlen(cpu_if_arlen),
        .m_axi_if_arburst(cpu_if_arburst),
        .m_axi_if_rready(cpu_if_rready),
        .m_axi_if_rvalid(cpu_if_rvalid),
        .m_axi_if_rdata(cpu_if_rdata),
        .m_axi_if_rresp(cpu_if_rresp),
        .m_axi_if_rid(cpu_if_rid),
        .m_axi_if_rlast(cpu_if_rlast),

        // MEM AXI Master
        .m_axi_mem_awvalid(cpu_mem_awvalid),
        .m_axi_mem_awready(cpu_mem_awready),
        .m_axi_mem_awaddr(cpu_mem_awaddr),
        .m_axi_mem_awid(cpu_mem_awid),
        .m_axi_mem_awlen(cpu_mem_awlen),
        .m_axi_mem_awburst(cpu_mem_awburst),
        .m_axi_mem_awprot(cpu_mem_awprot),
        .m_axi_mem_wvalid(cpu_mem_wvalid),
        .m_axi_mem_wready(cpu_mem_wready),
        .m_axi_mem_wdata(cpu_mem_wdata),
        .m_axi_mem_wstrb(cpu_mem_wstrb),
        .m_axi_mem_wlast(cpu_mem_wlast),
        .m_axi_mem_bvalid(cpu_mem_bvalid),
        .m_axi_mem_bready(cpu_mem_bready),
        .m_axi_mem_bresp(cpu_mem_bresp),
        .m_axi_mem_bid(cpu_mem_bid),
        .m_axi_mem_arvalid(cpu_mem_arvalid),
        .m_axi_mem_arready(cpu_mem_arready),
        .m_axi_mem_araddr(cpu_mem_araddr),
        .m_axi_mem_arid(cpu_mem_arid),
        .m_axi_mem_arlen(cpu_mem_arlen),
        .m_axi_mem_arburst(cpu_mem_arburst),
        .m_axi_mem_arprot(cpu_mem_arprot),
        .m_axi_mem_rvalid(cpu_mem_rvalid),
        .m_axi_mem_rready(cpu_mem_rready),
        .m_axi_mem_rdata(cpu_mem_rdata),
        .m_axi_mem_rresp(cpu_mem_rresp),
        .m_axi_mem_rid(cpu_mem_rid),
        .m_axi_mem_rlast(cpu_mem_rlast)
    );

    // =====================================================================
    //  模块实例化 2: AXI Interconnect (总线互联矩阵)
    // =====================================================================
    
    axi_interconnect #(
        .S_COUNT(2),
        .M_COUNT(2),
        .DATA_WIDTH(32),
        .ADDR_WIDTH(32),
        .ID_WIDTH(4),
        .M_BASE_ADDR({32'h02000000, 32'h00000000}),
        .M_ADDR_WIDTH({32'd24, 32'd16})
    ) bus_interconnect (
        .clk(clk),
        .rst(rst),

        // Slave 端口
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

        // Master 端口 (M1: CLINT, M0: RAM)
        .m_axi_awid     ({clint_awid,    ram_awid}),
        .m_axi_awaddr   ({clint_awaddr,  ram_awaddr}),
        .m_axi_awlen    ({clint_awlen,   ram_awlen}),
        .m_axi_awsize   ({clint_awsize,  ram_awsize}),
        .m_axi_awburst  ({clint_awburst, ram_awburst}),
        .m_axi_awlock   ({clint_awlock,  ram_awlock}),
        .m_axi_awcache  ({clint_awcache, ram_awcache}),
        .m_axi_awprot   ({clint_awprot,  ram_awprot}),
        .m_axi_awqos    ({clint_awqos,   ram_awqos}),
        .m_axi_awvalid  ({clint_awvalid, ram_awvalid}),
        .m_axi_awready  ({clint_awready, ram_awready}),
        .m_axi_wdata    ({clint_wdata,   ram_wdata}),
        .m_axi_wstrb    ({clint_wstrb,   ram_wstrb}),
        .m_axi_wlast    ({clint_wlast,   ram_wlast}),
        .m_axi_wvalid   ({clint_wvalid,  ram_wvalid}),
        .m_axi_wready   ({clint_wready,  ram_wready}),
        .m_axi_bid      ({clint_bid,     ram_bid}),
        .m_axi_bresp    ({clint_bresp,   ram_bresp}),
        .m_axi_bvalid   ({clint_bvalid,  ram_bvalid}),
        .m_axi_bready   ({clint_bready,  ram_bready}),
        .m_axi_arid     ({clint_arid,    ram_arid}),
        .m_axi_araddr   ({clint_araddr,  ram_araddr}),
        .m_axi_arlen    ({clint_arlen,   ram_arlen}),
        .m_axi_arsize   ({clint_arsize,  ram_arsize}),
        .m_axi_arburst  ({clint_arburst, ram_arburst}),
        .m_axi_arlock   ({clint_arlock,  ram_arlock}),
        .m_axi_arcache  ({clint_arcache, ram_arcache}),
        .m_axi_arprot   ({clint_arprot,  ram_arprot}),
        .m_axi_arqos    ({clint_arqos,   ram_arqos}),
        .m_axi_arvalid  ({clint_arvalid, ram_arvalid}),
        .m_axi_arready  ({clint_arready, ram_arready}),
        .m_axi_rid      ({clint_rid,     ram_rid}),
        .m_axi_rdata    ({clint_rdata,   ram_rdata}),
        .m_axi_rresp    ({clint_rresp,   ram_rresp}),
        .m_axi_rlast    ({clint_rlast,   ram_rlast}),
        .m_axi_rvalid   ({clint_rvalid,  ram_rvalid}),
        .m_axi_rready   ({clint_rready,  ram_rready})
    );

    // =====================================================================
    //  模块实例化 3: AXI RAM (统一内存)
    // =====================================================================
    
    // 使用带有初始化功能的 AXI RAM
    axi_ram_init #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(RAM_ADDR_WIDTH),
        .ID_WIDTH(4),
        .INIT_FILE(INIT_FILE)
    ) main_memory (
        .clk(clk),
        .rst(rst),

        .s_axi_awid     (ram_awid),
        .s_axi_awaddr   (ram_awaddr[RAM_ADDR_WIDTH-1:0]),
        .s_axi_awlen    (ram_awlen),
        .s_axi_awsize   (ram_awsize),
        .s_axi_awburst  (ram_awburst),
        .s_axi_awlock   (ram_awlock),
        .s_axi_awcache  (ram_awcache),
        .s_axi_awprot   (ram_awprot),
        .s_axi_awvalid  (ram_awvalid),
        .s_axi_awready  (ram_awready),
        .s_axi_wdata    (ram_wdata),
        .s_axi_wstrb    (ram_wstrb),
        .s_axi_wlast    (ram_wlast),
        .s_axi_wvalid   (ram_wvalid),
        .s_axi_wready   (ram_wready),
        .s_axi_bid      (ram_bid),
        .s_axi_bresp    (ram_bresp),
        .s_axi_bvalid   (ram_bvalid),
        .s_axi_bready   (ram_bready),
        .s_axi_arid     (ram_arid),
        .s_axi_araddr   (ram_araddr[RAM_ADDR_WIDTH-1:0]),
        .s_axi_arlen    (ram_arlen),
        .s_axi_arsize   (ram_arsize),
        .s_axi_arburst  (ram_arburst),
        .s_axi_arlock   (ram_arlock),
        .s_axi_arcache  (ram_arcache),
        .s_axi_arprot   (ram_arprot),
        .s_axi_arvalid  (ram_arvalid),
        .s_axi_arready  (ram_arready),
        .s_axi_rid      (ram_rid),
        .s_axi_rdata    (ram_rdata),
        .s_axi_rresp    (ram_rresp),
        .s_axi_rlast    (ram_rlast),
        .s_axi_rvalid   (ram_rvalid),
        .s_axi_rready   (ram_rready)
    );

    // =====================================================================
    //  模块实例化 4: CLINT (核心局部中断器)
    // =====================================================================

    axi_clint #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(32),
        .ID_WIDTH(4)
    ) clint_timer (
        .clk(clk),
        .rst(rst),
        
        .s_axi_awid     (clint_awid),
        .s_axi_awaddr   (clint_awaddr),
        .s_axi_awlen    (clint_awlen),
        .s_axi_awsize   (clint_awsize),
        .s_axi_awburst  (clint_awburst),
        .s_axi_awvalid  (clint_awvalid),
        .s_axi_awready  (clint_awready),
        .s_axi_wdata    (clint_wdata),
        .s_axi_wstrb    (clint_wstrb),
        .s_axi_wlast    (clint_wlast),
        .s_axi_wvalid   (clint_wvalid),
        .s_axi_wready   (clint_wready),
        .s_axi_bid      (clint_bid),
        .s_axi_bresp    (clint_bresp),
        .s_axi_bvalid   (clint_bvalid),
        .s_axi_bready   (clint_bready),
        .s_axi_arid     (clint_arid),
        .s_axi_araddr   (clint_araddr),
        .s_axi_arlen    (clint_arlen),
        .s_axi_arsize   (clint_arsize),
        .s_axi_arburst  (clint_arburst),
        .s_axi_arvalid  (clint_arvalid),
        .s_axi_arready  (clint_arready),
        .s_axi_rid      (clint_rid),
        .s_axi_rdata    (clint_rdata),
        .s_axi_rresp    (clint_rresp),
        .s_axi_rlast    (clint_rlast),
        .s_axi_rvalid   (clint_rvalid),
        .s_axi_rready   (clint_rready),
        
        .timer_irq      (timer_irq)
    );

endmodule
