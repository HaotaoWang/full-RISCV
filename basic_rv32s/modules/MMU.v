module MMU #(
    parameter XLEN = 32
)(
    input clk,
    input reset,

    // CSR Inputs
    input [XLEN-1:0] satp,
    input [XLEN-1:0] mstatus,
    input [1:0] current_mode,

    // Backdoor TLB Write (from CSR)
    input [19:0] tlb_wvpn,
    input [31:0] tlb_wpte,
    input itlb_we,
    input dtlb_we,

    // Instruction Fetch Interface (IF Phase)
    input [XLEN-1:0] if_virtual_address,
    input if_request,
    output [XLEN-1:0] if_physical_address,
    output if_page_fault,

    // Memory Access Interface (MEM Phase)
    input [XLEN-1:0] mem_virtual_address,
    input mem_request_read,
    input mem_request_write,
    output [XLEN-1:0] mem_physical_address,
    output mem_load_page_fault,
    output mem_store_page_fault
);

    wire is_bare_mode = (satp[31] == 1'b0);

    // mstatus flags
    wire mstatus_sum = mstatus[18];
    wire mstatus_mxr = mstatus[19];
    wire is_supervisor = (current_mode == 2'b01);
    wire is_user = (current_mode == 2'b00);

    // --------------------------------------------------------
    // ITLB (1 Entry)
    // --------------------------------------------------------
    reg itlb_valid;
    reg [19:0] itlb_vpn;
    reg [21:0] itlb_ppn;
    reg [9:0]  itlb_flags; // R, W, X, U, G, A, D, etc.

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            itlb_valid <= 1'b0;
            itlb_vpn <= 20'b0;
            itlb_ppn <= 22'b0;
            itlb_flags <= 10'b0;
        end else if (itlb_we) begin
            itlb_valid <= 1'b1;
            itlb_vpn <= tlb_wvpn;
            itlb_ppn <= tlb_wpte[31:10];
            itlb_flags <= tlb_wpte[9:0];
        end
    end

    wire [19:0] if_vpn = if_virtual_address[31:12];
    wire [11:0] if_offset = if_virtual_address[11:0];
    wire itlb_hit = itlb_valid && (itlb_vpn == if_vpn);
    
    wire pte_v = itlb_flags[0];
    wire pte_r = itlb_flags[1];
    wire pte_w = itlb_flags[2];
    wire pte_x = itlb_flags[3];
    wire pte_u = itlb_flags[4];

    reg if_pf_logic;
    always @(*) begin
        if_pf_logic = 1'b0;
        if (!is_bare_mode && if_request) begin
            if (!itlb_hit) begin
                if_pf_logic = 1'b1; // Miss triggers PF for now (no PTW)
            end else if (!pte_v || (!pte_r && !pte_w && !pte_x)) begin
                if_pf_logic = 1'b1; // Invalid PTE
            end else begin
                if (is_supervisor) begin
                    if (pte_u) if_pf_logic = 1'b1; // S-Mode cannot execute U-Mode pages
                    else if (!pte_x) if_pf_logic = 1'b1;
                end else if (is_user) begin
                    if (!pte_u || !pte_x) if_pf_logic = 1'b1;
                end
            end
        end
    end

    assign if_physical_address = is_bare_mode ? if_virtual_address : {itlb_ppn, if_offset};
    assign if_page_fault = if_pf_logic;


    // --------------------------------------------------------
    // DTLB (1 Entry)
    // --------------------------------------------------------
    reg dtlb_valid;
    reg [19:0] dtlb_vpn;
    reg [21:0] dtlb_ppn;
    reg [9:0]  dtlb_flags; 

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            dtlb_valid <= 1'b0;
            dtlb_vpn <= 20'b0;
            dtlb_ppn <= 22'b0;
            dtlb_flags <= 10'b0;
        end else if (dtlb_we) begin
            dtlb_valid <= 1'b1;
            dtlb_vpn <= tlb_wvpn;
            dtlb_ppn <= tlb_wpte[31:10];
            dtlb_flags <= tlb_wpte[9:0];
        end
    end

    wire [19:0] mem_vpn = mem_virtual_address[31:12];
    wire [11:0] mem_offset = mem_virtual_address[11:0];
    wire dtlb_hit = dtlb_valid && (dtlb_vpn == mem_vpn);

    wire dpte_v = dtlb_flags[0];
    wire dpte_r = dtlb_flags[1];
    wire dpte_w = dtlb_flags[2];
    wire dpte_x = dtlb_flags[3];
    wire dpte_u = dtlb_flags[4];

    reg load_pf_logic;
    always @(*) begin
        load_pf_logic = 1'b0;
        if (!is_bare_mode && mem_request_read) begin
            if (!dtlb_hit) begin
                load_pf_logic = 1'b1; // Miss -> PF
            end else if (!dpte_v || (!dpte_r && !dpte_w && !dpte_x)) begin
                load_pf_logic = 1'b1;
            end else begin
                if (is_supervisor) begin
                    if (dpte_u && !mstatus_sum) load_pf_logic = 1'b1;
                    else if (!dpte_r && !(mstatus_mxr && dpte_x)) load_pf_logic = 1'b1;
                end else if (is_user) begin
                    if (!dpte_u) load_pf_logic = 1'b1;
                    else if (!dpte_r && !(mstatus_mxr && dpte_x)) load_pf_logic = 1'b1;
                end
            end
        end
    end

    reg store_pf_logic;
    always @(*) begin
        store_pf_logic = 1'b0;
        if (!is_bare_mode && mem_request_write) begin
            if (!dtlb_hit) begin
                store_pf_logic = 1'b1; // Miss -> PF
            end else if (!dpte_v || (!dpte_r && !dpte_w && !dpte_x)) begin
                store_pf_logic = 1'b1;
            end else begin
                if (is_supervisor) begin
                    if (dpte_u && !mstatus_sum) store_pf_logic = 1'b1;
                    else if (!dpte_w) store_pf_logic = 1'b1;
                end else if (is_user) begin
                    if (!dpte_u || !dpte_w) store_pf_logic = 1'b1;
                end
            end
        end
    end

    assign mem_physical_address = is_bare_mode ? mem_virtual_address : {dtlb_ppn, mem_offset};
    assign mem_load_page_fault = load_pf_logic;
    assign mem_store_page_fault = store_pf_logic;

endmodule
