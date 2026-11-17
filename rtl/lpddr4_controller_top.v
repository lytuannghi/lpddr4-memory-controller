// =============================================================================
// Project: JEDEC LPDDR4 Memory Controller Subsystem
// File:    lpddr4_controller_top.v
// Description: Top-Level Integration of LPDDR4 Memory Controller Subsystem
//              Interconnects AXI4 Frontend, Address Mapper, Scheduler, 
//              Refresh Controller, and DFI 4.0 Master
// =============================================================================

`timescale 1ns / 1ps
`include "lpddr4_pkg.vh"

module lpddr4_controller_top (
    input  wire                   clk,
    input  wire                   rst_n,

    // -------------------------------------------------------------------------
    // AXI4 Slave Interface (SoC Interconnect Side)
    // -------------------------------------------------------------------------
    // Write Address Channel
    input  wire [3:0]             s_axi_awid,
    input  wire [31:0]            s_axi_awaddr,
    input  wire [7:0]             s_axi_awlen,
    input  wire [2:0]             s_axi_awsize,
    input  wire [1:0]             s_axi_awburst,
    input  wire                   s_axi_awvalid,
    output wire                   s_axi_awready,

    // Write Data Channel
    input  wire [31:0]            s_axi_wdata,
    input  wire [3:0]             s_axi_wstrb,
    input  wire                   s_axi_wlast,
    input  wire                   s_axi_wvalid,
    output wire                   s_axi_wready,

    // Write Response Channel
    output wire [3:0]             s_axi_bid,
    output wire [1:0]             s_axi_bresp,
    output wire                   s_axi_bvalid,
    input  wire                   s_axi_bready,

    // Read Address Channel
    input  wire [3:0]             s_axi_arid,
    input  wire [31:0]            s_axi_araddr,
    input  wire [7:0]             s_axi_arlen,
    input  wire [2:0]             s_axi_arsize,
    input  wire [1:0]             s_axi_arburst,
    input  wire                   s_axi_arvalid,
    output wire                   s_axi_arready,

    // Read Data Channel
    output wire [3:0]             s_axi_rid,
    output wire [31:0]            s_axi_rdata,
    output wire [1:0]             s_axi_rresp,
    output wire                   s_axi_rlast,
    output wire                   s_axi_rvalid,
    input  wire                   s_axi_rready,

    // -------------------------------------------------------------------------
    // DFI 4.0 Physical Interface (PHY / DRAM BFM Side)
    // -------------------------------------------------------------------------
    output wire [`ROW_WIDTH-1:0]  dfi_address,
    output wire [`BANK_WIDTH-1:0] dfi_bank,
    output wire                   dfi_cs_n,
    output wire                   dfi_ras_n,
    output wire                   dfi_cas_n,
    output wire                   dfi_we_n,
    output wire [`DATA_WIDTH-1:0] dfi_wrdata,
    output wire [`MASK_WIDTH-1:0] dfi_wrdata_mask,
    output wire                   dfi_wrdata_en,

    input  wire [`DATA_WIDTH-1:0] dfi_rddata,
    input  wire                   dfi_rddata_valid,
    input  wire                   dfi_init_complete
);

    // -------------------------------------------------------------------------
    // Internal Interconnect Signals
    // -------------------------------------------------------------------------
    // Frontend <-> Scheduler Request Bus
    wire                   req_valid;
    wire                   req_ready;
    wire                   req_rw;
    wire [31:0]            req_addr;
    wire [31:0]            req_wdata;
    wire [3:0]             req_wstrb;
    wire [3:0]             req_id;

    // Address Mapper Output Signals
    wire [0:0]             mapped_rank;
    wire [`BANK_WIDTH-1:0] mapped_bank;
    wire [`ROW_WIDTH-1:0]  mapped_row;
    wire [`COL_WIDTH-1:0]  mapped_col;
    wire [1:0]             mapped_byte_offset;

    // Refresh Controller <-> Scheduler
    wire                   ref_req;
    wire                   ref_urgent;
    wire                   ref_ack;
    wire                   in_refresh;

    // Scheduler <-> DFI Master
    wire [3:0]             sched_cmd;
    wire [`BANK_WIDTH-1:0] sched_bank;
    wire [`ROW_WIDTH-1:0]  sched_addr;
    wire [`DATA_WIDTH-1:0] sched_wrdata;
    wire [`MASK_WIDTH-1:0] sched_wrdata_mask;
    wire                   sched_wrdata_en;
    wire [3:0]             sched_req_id;
    wire                   sched_is_read;

    // DFI Master <-> Frontend Response Bus
    wire                   rsp_valid;
    wire [31:0]            rsp_rdata;
    wire [3:0]             rsp_id;

    // -------------------------------------------------------------------------
    // 1. AXI4 Slave Frontend Instance
    // -------------------------------------------------------------------------
    axi_slave_frontend u_axi_frontend (
        .aclk            (clk),
        .aresetn         (rst_n),
        .s_axi_awid      (s_axi_awid),
        .s_axi_awaddr    (s_axi_awaddr),
        .s_axi_awlen     (s_axi_awlen),
        .s_axi_awsize    (s_axi_awsize),
        .s_axi_awburst   (s_axi_awburst),
        .s_axi_awvalid   (s_axi_awvalid),
        .s_axi_awready   (s_axi_awready),
        .s_axi_wdata     (s_axi_wdata),
        .s_axi_wstrb     (s_axi_wstrb),
        .s_axi_wlast     (s_axi_wlast),
        .s_axi_wvalid    (s_axi_wvalid),
        .s_axi_wready    (s_axi_wready),
        .s_axi_bid       (s_axi_bid),
        .s_axi_bresp     (s_axi_bresp),
        .s_axi_bvalid    (s_axi_bvalid),
        .s_axi_bready    (s_axi_bready),
        .s_axi_arid      (s_axi_arid),
        .s_axi_araddr    (s_axi_araddr),
        .s_axi_arlen     (s_axi_arlen),
        .s_axi_arsize    (s_axi_arsize),
        .s_axi_arburst   (s_axi_arburst),
        .s_axi_arvalid   (s_axi_arvalid),
        .s_axi_arready   (s_axi_arready),
        .s_axi_rid       (s_axi_rid),
        .s_axi_rdata     (s_axi_rdata),
        .s_axi_rresp     (s_axi_rresp),
        .s_axi_rlast     (s_axi_rlast),
        .s_axi_rvalid    (s_axi_rvalid),
        .s_axi_rready    (s_axi_rready),
        .req_valid       (req_valid),
        .req_ready       (req_ready),
        .req_rw          (req_rw),
        .req_addr        (req_addr),
        .req_wdata       (req_wdata),
        .req_wstrb       (req_wstrb),
        .req_id          (req_id),
        .rsp_valid       (rsp_valid),
        .rsp_rdata       (rsp_rdata),
        .rsp_id          (rsp_id)
    );

    // -------------------------------------------------------------------------
    // 2. Address Mapper Instance
    // -------------------------------------------------------------------------
    address_mapper u_addr_mapper (
        .flat_addr       (req_addr),
        .rank_id         (mapped_rank),
        .bank_id         (mapped_bank),
        .row_addr        (mapped_row),
        .col_addr        (mapped_col),
        .byte_offset     (mapped_byte_offset)
    );

    // -------------------------------------------------------------------------
    // 3. Refresh Controller Instance
    // -------------------------------------------------------------------------
    refresh_controller u_refresh_ctrl (
        .clk             (clk),
        .rst_n           (rst_n),
        .ref_req         (ref_req),
        .ref_urgent      (ref_urgent),
        .ref_ack         (ref_ack),
        .in_refresh      (in_refresh)
    );

    // -------------------------------------------------------------------------
    // 4. Command Scheduler Instance
    // -------------------------------------------------------------------------
    command_scheduler u_cmd_scheduler (
        .clk             (clk),
        .rst_n           (rst_n),
        .req_valid       (req_valid),
        .req_ready       (req_ready),
        .req_rw          (req_rw),
        .req_bank        (mapped_bank),
        .req_row         (mapped_row),
        .req_col         (mapped_col),
        .req_wdata       (req_wdata),
        .req_wstrb       (req_wstrb),
        .req_id          (req_id),
        .ref_req         (ref_req),
        .ref_urgent      (ref_urgent),
        .in_refresh      (in_refresh),
        .ref_ack         (ref_ack),
        .dfi_cmd         (sched_cmd),
        .dfi_bank        (sched_bank),
        .dfi_addr        (sched_addr),
        .dfi_wrdata      (sched_wrdata),
        .dfi_wrdata_mask (sched_wrdata_mask),
        .dfi_wrdata_en   (sched_wrdata_en),
        .dfi_req_id      (sched_req_id),
        .dfi_is_read     (sched_is_read)
    );

    // -------------------------------------------------------------------------
    // 5. DFI 4.0 Master Instance
    // -------------------------------------------------------------------------
    dfi_master u_dfi_master (
        .clk               (clk),
        .rst_n             (rst_n),
        .sched_cmd         (sched_cmd),
        .sched_bank        (sched_bank),
        .sched_addr        (sched_addr),
        .sched_wrdata      (sched_wrdata),
        .sched_wrdata_mask (sched_wrdata_mask),
        .sched_wrdata_en   (sched_wrdata_en),
        .sched_req_id      (sched_req_id),
        .sched_is_read     (sched_is_read),
        .rsp_valid         (rsp_valid),
        .rsp_rdata         (rsp_rdata),
        .rsp_id            (rsp_id),
        .dfi_address       (dfi_address),
        .dfi_bank          (dfi_bank),
        .dfi_cs_n          (dfi_cs_n),
        .dfi_ras_n         (dfi_ras_n),
        .dfi_cas_n         (dfi_cas_n),
        .dfi_we_n          (dfi_we_n),
        .dfi_wrdata        (dfi_wrdata),
        .dfi_wrdata_mask   (dfi_wrdata_mask),
        .dfi_wrdata_en     (dfi_wrdata_en),
        .dfi_rddata        (dfi_rddata),
        .dfi_rddata_valid  (dfi_rddata_valid),
        .dfi_init_complete (dfi_init_complete)
    );

endmodule
