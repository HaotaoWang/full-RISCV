// RV32 AXI4-Lite Adapter
// Adapted from the brilliant picorv32_axi_adapter
// Translates simple valid/ready memory requests into AXI4-Lite protocol.

module RV32_AXI_Adapter (
    input clk, 
    input reset,

    // ----------------------------------------------------
    // AXI4-Lite Master Interface
    // ----------------------------------------------------
    // Write Address Channel
    output        axi_awvalid,
    input         axi_awready,
    output [31:0] axi_awaddr,
    output [ 2:0] axi_awprot,

    // Write Data Channel
    output        axi_wvalid,
    input         axi_wready,
    output [31:0] axi_wdata,
    output [ 3:0] axi_wstrb,

    // Write Response Channel
    input         axi_bvalid,
    output        axi_bready,

    // Read Address Channel
    output        axi_arvalid,
    input         axi_arready,
    output [31:0] axi_araddr,
    output [ 2:0] axi_arprot,

    // Read Data Channel
    input         axi_rvalid,
    output        axi_rready,
    input  [31:0] axi_rdata,

    // ----------------------------------------------------
    // Native CPU Memory Interface (Simple Handshake)
    // ----------------------------------------------------
    input         mem_valid,
    input         mem_instr, // 1 for Instruction Fetch, 0 for Data Access
    input  [31:0] mem_addr,
    input  [31:0] mem_wdata,
    input  [ 3:0] mem_wstrb, // 0000 indicates a READ operation
    
    output        mem_ready,
    output [31:0] mem_rdata
);

    reg ack_awvalid;
    reg ack_arvalid;
    reg ack_wvalid;
    reg xfer_done;

    wire is_write = |mem_wstrb;
    wire is_read = !is_write;

    // AXI Write Address Channel
    assign axi_awvalid = mem_valid && is_write && !ack_awvalid;
    assign axi_awaddr  = mem_addr;
    assign axi_awprot  = 3'b000;

    // AXI Write Data Channel
    assign axi_wvalid  = mem_valid && is_write && !ack_wvalid;
    assign axi_wdata   = mem_wdata;
    assign axi_wstrb   = mem_wstrb;

    // AXI Read Address Channel
    assign axi_arvalid = mem_valid && is_read && !ack_arvalid;
    assign axi_araddr  = mem_addr;
    // PROT: Data vs Instruction access (bit 2 is 1 for instruction, 0 for data)
    assign axi_arprot  = mem_instr ? 3'b100 : 3'b000;

    // AXI Response Channels
    assign mem_ready   = axi_bvalid || axi_rvalid;
    assign axi_bready  = mem_valid && is_write;
    assign axi_rready  = mem_valid && is_read;
    assign mem_rdata   = axi_rdata;

    // AXI Handshake State Machine
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            ack_awvalid <= 0;
            ack_arvalid <= 0;
            ack_wvalid  <= 0;
            xfer_done   <= 0;
        end else begin
            xfer_done <= mem_valid && mem_ready;
            
            if (axi_awready && axi_awvalid) ack_awvalid <= 1;
            if (axi_arready && axi_arvalid) ack_arvalid <= 1;
            if (axi_wready  && axi_wvalid)  ack_wvalid  <= 1;
            
            // Clear acknowledgments when transaction finishes or becomes invalid
            if (xfer_done || !mem_valid) begin
                ack_awvalid <= 0;
                ack_arvalid <= 0;
                ack_wvalid  <= 0;
            end
        end
    end

endmodule
