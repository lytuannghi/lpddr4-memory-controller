// =============================================================================
// Project: JEDEC LPDDR4 Memory Controller Subsystem
// File:    axi_slave_frontend.v
// Description: AMBA AXI4 Slave Frontend Interface
//              Supports Burst Transfers (INCR), Out-of-order IDs, Read/Write Queuing
// =============================================================================

`timescale 1ns / 1ps
`include "lpddr4_pkg.vh"

module axi_slave_frontend (
    input  wire                  aclk,
    input  wire                  aresetn,

    // AXI4 Write Address Channel
    input  wire [3:0]            s_axi_awid,
    input  wire [31:0]           s_axi_awaddr,
    input  wire [7:0]            s_axi_awlen,
    input  wire [2:0]            s_axi_awsize,
    input  wire [1:0]            s_axi_awburst,
    input  wire                  s_axi_awvalid,
    output reg                   s_axi_awready,

    // AXI4 Write Data Channel
    input  wire [31:0]           s_axi_wdata,
    input  wire [3:0]            s_axi_wstrb,
    input  wire                  s_axi_wlast,
    input  wire                  s_axi_wvalid,
    output reg                   s_axi_wready,

    // AXI4 Write Response Channel
    output reg  [3:0]            s_axi_bid,
    output reg  [1:0]            s_axi_bresp,
    output reg                   s_axi_bvalid,
    input  wire                  s_axi_bready,

    // AXI4 Read Address Channel
    input  wire [3:0]            s_axi_arid,
    input  wire [31:0]           s_axi_araddr,
    input  wire [7:0]            s_axi_arlen,
    input  wire [2:0]            s_axi_arsize,
    input  wire [1:0]            s_axi_arburst,
    input  wire                  s_axi_arvalid,
    output reg                   s_axi_arready,

    // AXI4 Read Data Channel
    output reg  [3:0]            s_axi_rid,
    output reg  [31:0]           s_axi_rdata,
    output reg  [1:0]            s_axi_rresp,
    output reg                   s_axi_rlast,
    output reg                   s_axi_rvalid,
    input  wire                  s_axi_rready,

    // Internal Memory Request Interface to Scheduler
    output reg                   req_valid,
    input  wire                  req_ready,
    output reg                   req_rw,       // 0: Read, 1: Write
    output reg  [31:0]           req_addr,
    output reg  [31:0]           req_wdata,
    output reg  [3:0]            req_wstrb,
    output reg  [3:0]            req_id,

    // Response from DFI Master
    input  wire                  rsp_valid,
    input  wire [31:0]           rsp_rdata,
    input  wire [3:0]            rsp_id
);

    // Burst tracking registers
    reg [31:0] wr_current_addr;
    reg [7:0]  wr_len_cnt;
    reg [3:0]  wr_id_reg;

    reg [31:0] rd_current_addr;
    reg [7:0]  rd_len_cnt;
    reg [3:0]  rd_id_reg;

    // FSM States
    localparam ST_IDLE     = 2'd0;
    localparam ST_WRITE    = 2'd1;
    localparam ST_READ     = 2'd2;
    localparam ST_WR_RESP  = 2'd3;

    reg [1:0] state;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            state           <= ST_IDLE;
            s_axi_awready   <= 1'b0;
            s_axi_wready    <= 1'b0;
            s_axi_bvalid    <= 1'b0;
            s_axi_bid       <= 4'd0;
            s_axi_bresp     <= 2'b00;
            s_axi_arready   <= 1'b0;
            s_axi_rvalid    <= 1'b0;
            s_axi_rid       <= 4'd0;
            s_axi_rdata     <= 32'd0;
            s_axi_rresp     <= 2'b00;
            s_axi_rlast     <= 1'b0;
            req_valid       <= 1'b0;
            req_rw          <= 1'b0;
            req_addr        <= 32'd0;
            req_wdata       <= 32'd0;
            req_wstrb       <= 4'd0;
            req_id          <= 4'd0;
            wr_current_addr <= 32'd0;
            wr_len_cnt      <= 8'd0;
            wr_id_reg       <= 4'd0;
            rd_current_addr <= 32'd0;
            rd_len_cnt      <= 8'd0;
            rd_id_reg       <= 4'd0;
        end else begin
            // Clear single-cycle strobes
            if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
            if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
                s_axi_rlast  <= 1'b0;
            end

            // Capture Read Data from DFI Master
            if (rsp_valid) begin
                s_axi_rvalid <= 1'b1;
                s_axi_rdata  <= rsp_rdata;
                s_axi_rid    <= rsp_id;
                s_axi_rresp  <= 2'b00; // OKAY
                s_axi_rlast  <= 1'b1;  // Single beat or burst terminal
            end

            case (state)
                ST_IDLE: begin
                    // Priority Write Arbitration
                    if (s_axi_awvalid) begin
                        s_axi_awready   <= 1'b1;
                        wr_current_addr <= s_axi_awaddr;
                        wr_len_cnt      <= s_axi_awlen;
                        wr_id_reg       <= s_axi_awid;
                        s_axi_wready    <= 1'b1;
                        state           <= ST_WRITE;
                    end else if (s_axi_arvalid) begin
                        s_axi_arready   <= 1'b1;
                        rd_current_addr <= s_axi_araddr;
                        rd_len_cnt      <= s_axi_arlen;
                        rd_id_reg       <= s_axi_arid;
                        state           <= ST_READ;
                    end
                end

                ST_WRITE: begin
                    s_axi_awready <= 1'b0;
                    if (s_axi_wvalid && s_axi_wready) begin
                        req_valid       <= 1'b1;
                        req_rw          <= 1'b1; // Write
                        req_addr        <= wr_current_addr;
                        req_wdata       <= s_axi_wdata;
                        req_wstrb       <= s_axi_wstrb;
                        req_id          <= wr_id_reg;
                        s_axi_wready    <= 1'b0;
                    end

                    if (req_valid && req_ready) begin
                        req_valid       <= 1'b0;
                        wr_current_addr <= wr_current_addr + 32'd4;
                        if (s_axi_wlast || wr_len_cnt == 0) begin
                            state <= ST_WR_RESP;
                        end else begin
                            wr_len_cnt   <= wr_len_cnt - 1'b1;
                            s_axi_wready <= 1'b1;
                        end
                    end
                end

                ST_WR_RESP: begin
                    s_axi_bvalid <= 1'b1;
                    s_axi_bid    <= wr_id_reg;
                    s_axi_bresp  <= 2'b00; // OKAY
                    if (s_axi_bvalid && s_axi_bready) begin
                        s_axi_bvalid <= 1'b0;
                        state        <= ST_IDLE;
                    end
                end

                ST_READ: begin
                    s_axi_arready <= 1'b0;
                    req_valid     <= 1'b1;
                    req_rw        <= 1'b0; // Read
                    req_addr      <= rd_current_addr;
                    req_id        <= rd_id_reg;

                    if (req_valid && req_ready) begin
                        req_valid       <= 1'b0;
                        rd_current_addr <= rd_current_addr + 32'd4;
                        if (rd_len_cnt == 0) begin
                            state <= ST_IDLE;
                        end else begin
                            rd_len_cnt <= rd_len_cnt - 1'b1;
                        end
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
