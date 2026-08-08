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

    parameter TLB_ENTRIES = 8;
    integer i, j;

    // --------------------------------------------------------
    // ITLB (8 Entries Fully Associative)
    // --------------------------------------------------------
    reg [TLB_ENTRIES-1:0] itlb_valid;
    reg [19:0] itlb_vpn [0:TLB_ENTRIES-1];
    reg [21:0] itlb_ppn [0:TLB_ENTRIES-1];
    reg [9:0]  itlb_flags [0:TLB_ENTRIES-1]; // R, W, X, U, G, A, D, etc.
    reg [2:0]  itlb_replace_idx; // Round-Robin Counter

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            itlb_valid <= {TLB_ENTRIES{1'b0}};
            itlb_replace_idx <= 3'b0;
            for (i = 0; i < TLB_ENTRIES; i = i + 1) begin
                itlb_vpn[i] <= 20'b0;
                itlb_ppn[i] <= 22'b0;
                itlb_flags[i] <= 10'b0;
            end
        end else if (itlb_we) begin
            itlb_valid[itlb_replace_idx] <= 1'b1;
            itlb_vpn[itlb_replace_idx] <= tlb_wvpn;
            itlb_ppn[itlb_replace_idx] <= tlb_wpte[31:10];
            itlb_flags[itlb_replace_idx] <= tlb_wpte[9:0];
            itlb_replace_idx <= itlb_replace_idx + 1'b1;
        end
    end

    wire [19:0] if_vpn = if_virtual_address[31:12];
    wire [11:0] if_offset = if_virtual_address[11:0];
    
    reg itlb_hit;
    reg [21:0] itlb_hit_ppn;
    reg [9:0]  itlb_hit_flags;
    
    always @(*) begin
        itlb_hit = 1'b0;
        itlb_hit_ppn = 22'b0;
        itlb_hit_flags = 10'b0;
        for (i = 0; i < TLB_ENTRIES; i = i + 1) begin
            if (itlb_valid[i] && (itlb_vpn[i] == if_vpn)) begin
                itlb_hit = 1'b1;
                itlb_hit_ppn = itlb_ppn[i];
                itlb_hit_flags = itlb_flags[i];
            end
        end
    end
    
    wire pte_v = itlb_hit_flags[0];
    wire pte_r = itlb_hit_flags[1];
    wire pte_w = itlb_hit_flags[2];
    wire pte_x = itlb_hit_flags[3];
    wire pte_u = itlb_hit_flags[4];

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

    assign if_physical_address = is_bare_mode ? if_virtual_address : {itlb_hit_ppn, if_offset};
    assign if_page_fault = if_pf_logic;


    // --------------------------------------------------------
    // DTLB (8 Entries Fully Associative)
    // --------------------------------------------------------
    reg [TLB_ENTRIES-1:0] dtlb_valid;
    reg [19:0] dtlb_vpn [0:TLB_ENTRIES-1];
    reg [21:0] dtlb_ppn [0:TLB_ENTRIES-1];
    reg [9:0]  dtlb_flags [0:TLB_ENTRIES-1]; 
    reg [2:0]  dtlb_replace_idx;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            dtlb_valid <= {TLB_ENTRIES{1'b0}};
            dtlb_replace_idx <= 3'b0;
            for (j = 0; j < TLB_ENTRIES; j = j + 1) begin
                dtlb_vpn[j] <= 20'b0;
                dtlb_ppn[j] <= 22'b0;
                dtlb_flags[j] <= 10'b0;
            end
        end else if (dtlb_we) begin
            dtlb_valid[dtlb_replace_idx] <= 1'b1;
            dtlb_vpn[dtlb_replace_idx] <= tlb_wvpn;
            dtlb_ppn[dtlb_replace_idx] <= tlb_wpte[31:10];
            dtlb_flags[dtlb_replace_idx] <= tlb_wpte[9:0];
            dtlb_replace_idx <= dtlb_replace_idx + 1'b1;
        end
    end

    wire [19:0] mem_vpn = mem_virtual_address[31:12];
    wire [11:0] mem_offset = mem_virtual_address[11:0];
    
    reg dtlb_hit;
    reg [21:0] dtlb_hit_ppn;
    reg [9:0]  dtlb_hit_flags;
    
    always @(*) begin
        dtlb_hit = 1'b0;
        dtlb_hit_ppn = 22'b0;
        dtlb_hit_flags = 10'b0;
        for (j = 0; j < TLB_ENTRIES; j = j + 1) begin
            if (dtlb_valid[j] && (dtlb_vpn[j] == mem_vpn)) begin
                dtlb_hit = 1'b1;
                dtlb_hit_ppn = dtlb_ppn[j];
                dtlb_hit_flags = dtlb_flags[j];
            end
        end
    end

    wire dpte_v = dtlb_hit_flags[0];
    wire dpte_r = dtlb_hit_flags[1];
    wire dpte_w = dtlb_hit_flags[2];
    wire dpte_x = dtlb_hit_flags[3];
    wire dpte_u = dtlb_hit_flags[4];

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

    assign mem_physical_address = is_bare_mode ? mem_virtual_address : {dtlb_hit_ppn, mem_offset};
    assign mem_load_page_fault = load_pf_logic;
    assign mem_store_page_fault = store_pf_logic;

endmodule
