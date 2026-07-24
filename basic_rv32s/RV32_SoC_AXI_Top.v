// ============================================================================
// RV32 SoC AXI Top — 纯 Verilog 顶层
// ============================================================================
// 架构概览:
//   CPU Core (2x AXI-Lite Master)
//       |                |
//       | IF port        | MEM port
//       v                v
//   +----------------------------+
//   | axil_interconnect          |
//   | (S_COUNT=2, M_COUNT=1)     |
//   +----------------------------+
//              |
//              v
//        +----------+
//        | axil_ram |  (统一指令+数据内存)
//        +----------+
//
// 地址映射:
//   0x0000_0000 ~ 0x0000_FFFF : RAM (64KB, ADDR_WIDTH=16)
// ============================================================================

`timescale 1ns / 1ps

module RV32_SoC_AXI_Top #(
    parameter RAM_ADDR_WIDTH = 16  // 2^16 = 64KB RAM
)(
    input  wire clk,
    input  wire rst,

    // UART 外部接口 (直通 CPU)
    input  wire        UART_busy,
    output wire [7:0]  mmio_uart_tx_data,
    output wire        mmio_uart_tx_start,

    // Debug: 退休指令观测口
    output wire [31:0] retire_instruction
);

    // =====================================================================
    //  内部连线声明
    // =====================================================================

    // --- CPU IF (取指) AXI Master 信号 ---
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

    // --- CPU MEM (数据) AXI Master 信号 ---
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

    // --- Interconnect -> RAM AXI 信号 ---
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

        // IF AXI Master
        .m_axi_if_awvalid(cpu_if_awvalid),
        .m_axi_if_awready(cpu_if_awready),
        .m_axi_if_awaddr(cpu_if_awaddr),
        .m_axi_if_awprot(cpu_if_awprot),
        .m_axi_if_wvalid(cpu_if_wvalid),
        .m_axi_if_wready(cpu_if_wready),
        .m_axi_if_wdata(cpu_if_wdata),
        .m_axi_if_wstrb(cpu_if_wstrb),
        .m_axi_if_bvalid(cpu_if_bvalid),
        .m_axi_if_bready(cpu_if_bready),
        .m_axi_if_arvalid(cpu_if_arvalid),
        .m_axi_if_arready(cpu_if_arready),
        .m_axi_if_araddr(cpu_if_araddr),
        .m_axi_if_arprot(cpu_if_arprot),
        .m_axi_if_rvalid(cpu_if_rvalid),
        .m_axi_if_rready(cpu_if_rready),
        .m_axi_if_rdata(cpu_if_rdata),

        // MEM AXI Master
        .m_axi_mem_awvalid(cpu_mem_awvalid),
        .m_axi_mem_awready(cpu_mem_awready),
        .m_axi_mem_awaddr(cpu_mem_awaddr),
        .m_axi_mem_awprot(cpu_mem_awprot),
        .m_axi_mem_wvalid(cpu_mem_wvalid),
        .m_axi_mem_wready(cpu_mem_wready),
        .m_axi_mem_wdata(cpu_mem_wdata),
        .m_axi_mem_wstrb(cpu_mem_wstrb),
        .m_axi_mem_bvalid(cpu_mem_bvalid),
        .m_axi_mem_bready(cpu_mem_bready),
        .m_axi_mem_arvalid(cpu_mem_arvalid),
        .m_axi_mem_arready(cpu_mem_arready),
        .m_axi_mem_araddr(cpu_mem_araddr),
        .m_axi_mem_arprot(cpu_mem_arprot),
        .m_axi_mem_rvalid(cpu_mem_rvalid),
        .m_axi_mem_rready(cpu_mem_rready),
        .m_axi_mem_rdata(cpu_mem_rdata)
    );

    // =====================================================================
    //  模块实例化 2: AXI-Lite Interconnect (总线互联矩阵)
    // =====================================================================
    //  S_COUNT = 2: 两个 Master (CPU IF + CPU MEM)
    //  M_COUNT = 1: 一个 Slave  (RAM)
    //
    //  注意: axil_interconnect 的 slave 端口是给 master 用的 (命名习惯)
    //        s_axil_* = 接收来自 CPU master 的请求
    //        m_axil_* = 发送到 RAM slave 的请求

    axil_interconnect #(
        .S_COUNT(2),
        .M_COUNT(1),
        .DATA_WIDTH(32),
        .ADDR_WIDTH(32),
        .M_ADDR_WIDTH({1{32'd16}})    // RAM 地址空间 = 16 bits = 64KB
    ) bus_interconnect (
        .clk(clk),
        .rst(rst),

        // Slave 端口 (CPU Masters 接入)
        // 两路 Master 的信号拼接: {MEM, IF}
        .s_axil_awaddr  ({cpu_mem_awaddr,   cpu_if_awaddr}),
        .s_axil_awprot  ({cpu_mem_awprot,   cpu_if_awprot}),
        .s_axil_awvalid ({cpu_mem_awvalid,  cpu_if_awvalid}),
        .s_axil_awready ({cpu_mem_awready,  cpu_if_awready}),
        .s_axil_wdata   ({cpu_mem_wdata,    cpu_if_wdata}),
        .s_axil_wstrb   ({cpu_mem_wstrb,    cpu_if_wstrb}),
        .s_axil_wvalid  ({cpu_mem_wvalid,   cpu_if_wvalid}),
        .s_axil_wready  ({cpu_mem_wready,   cpu_if_wready}),
        .s_axil_bresp   (),  // 不使用 resp
        .s_axil_bvalid  ({cpu_mem_bvalid,   cpu_if_bvalid}),
        .s_axil_bready  ({cpu_mem_bready,   cpu_if_bready}),
        .s_axil_araddr  ({cpu_mem_araddr,   cpu_if_araddr}),
        .s_axil_arprot  ({cpu_mem_arprot,   cpu_if_arprot}),
        .s_axil_arvalid ({cpu_mem_arvalid,  cpu_if_arvalid}),
        .s_axil_arready ({cpu_mem_arready,  cpu_if_arready}),
        .s_axil_rdata   ({cpu_mem_rdata,    cpu_if_rdata}),
        .s_axil_rresp   (),  // 不使用 resp
        .s_axil_rvalid  ({cpu_mem_rvalid,   cpu_if_rvalid}),
        .s_axil_rready  ({cpu_mem_rready,   cpu_if_rready}),

        // Master 端口 (RAM Slave 接入)
        .m_axil_awaddr  (ram_awaddr),
        .m_axil_awprot  (ram_awprot),
        .m_axil_awvalid (ram_awvalid),
        .m_axil_awready (ram_awready),
        .m_axil_wdata   (ram_wdata),
        .m_axil_wstrb   (ram_wstrb),
        .m_axil_wvalid  (ram_wvalid),
        .m_axil_wready  (ram_wready),
        .m_axil_bresp   (ram_bresp),
        .m_axil_bvalid  (ram_bvalid),
        .m_axil_bready  (ram_bready),
        .m_axil_araddr  (ram_araddr),
        .m_axil_arprot  (ram_arprot),
        .m_axil_arvalid (ram_arvalid),
        .m_axil_arready (ram_arready),
        .m_axil_rdata   (ram_rdata),
        .m_axil_rresp   (ram_rresp),
        .m_axil_rvalid  (ram_rvalid),
        .m_axil_rready  (ram_rready)
    );

    // =====================================================================
    //  模块实例化 3: AXI-Lite RAM (统一内存)
    // =====================================================================
    //  注意: axil_ram 的 ADDR_WIDTH 参数决定 RAM 大小
    //        输入地址端口宽度 = ADDR_WIDTH (不是 32 位!)

    axil_ram #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(RAM_ADDR_WIDTH)   // 16 bits = 64KB
    ) main_memory (
        .clk(clk),
        .rst(rst),

        .s_axil_awaddr  (ram_awaddr[RAM_ADDR_WIDTH-1:0]),
        .s_axil_awprot  (ram_awprot),
        .s_axil_awvalid (ram_awvalid),
        .s_axil_awready (ram_awready),
        .s_axil_wdata   (ram_wdata),
        .s_axil_wstrb   (ram_wstrb),
        .s_axil_wvalid  (ram_wvalid),
        .s_axil_wready  (ram_wready),
        .s_axil_bresp   (ram_bresp),
        .s_axil_bvalid  (ram_bvalid),
        .s_axil_bready  (ram_bready),
        .s_axil_araddr  (ram_araddr[RAM_ADDR_WIDTH-1:0]),
        .s_axil_arprot  (ram_arprot),
        .s_axil_arvalid (ram_arvalid),
        .s_axil_arready (ram_arready),
        .s_axil_rdata   (ram_rdata),
        .s_axil_rresp   (ram_rresp),
        .s_axil_rvalid  (ram_rvalid),
        .s_axil_rready  (ram_rready)
    );

endmodule
