// =============================================================================
// Project: JEDEC LPDDR4 Memory Controller Subsystem
// File:    dfi_master.v
// Description: DFI 4.0 (DRAM PHY Interface) Protocol Master
//              Translates Internal Scheduler Commands to Industry-Standard DFI Bus
// =============================================================================

`timescale 1ns / 1ps
`include "lpddr4_pkg.vh"

module dfi_master (
    input  wire                   clk,
    input  wire                   rst_n,

    // Interface with Command Scheduler
    input  wire [3:0]             sched_cmd,
    input  wire [`BANK_WIDTH-1:0] sched_bank,
    input  wire [`ROW_WIDTH-1:0]  sched_addr,
    input  wire [`DATA_WIDTH-1:0] sched_wrdata,
    input  wire [`MASK_WIDTH-1:0] sched_wrdata_mask,
    input  wire                   sched_wrdata_en,
    input  wire [3:0]             sched_req_id,
    input  wire                   sched_is_read,

    // Response back to AXI Frontend
    output reg                    rsp_valid,
    output reg  [`DATA_WIDTH-1:0] rsp_rdata,
    output reg  [3:0]             rsp_id,

    // DFI 4.0 Physical Interface (to PHY / DRAM BFM)
    output reg  [`ROW_WIDTH-1:0]  dfi_address,
    output reg  [`BANK_WIDTH-1:0] dfi_bank,
    output reg                    dfi_cs_n,
    output reg                    dfi_ras_n,
    output reg                    dfi_cas_n,
    output reg                    dfi_we_n,
    output reg  [`DATA_WIDTH-1:0] dfi_wrdata,
    output reg  [`MASK_WIDTH-1:0] dfi_wrdata_mask,
    output reg                    dfi_wrdata_en,

    input  wire [`DATA_WIDTH-1:0] dfi_rddata,
    input  wire                   dfi_rddata_valid,
    input  wire                   dfi_init_complete
);

    // Read ID Tracking Pipeline (FIFO for out-of-order latency correlation)
    reg [3:0] rd_id_fifo [0:15];
    reg [3:0] rd_id_wr_ptr;
    reg [3:0] rd_id_rd_ptr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dfi_address       <= 16'd0;
            dfi_bank          <= 3'd0;
            dfi_cs_n          <= 1'b1;
            dfi_ras_n         <= 1'b1;
            dfi_cas_n         <= 1'b1;
            dfi_we_n          <= 1'b1;
            dfi_wrdata        <= 32'd0;
            dfi_wrdata_mask   <= 4'd0;
            dfi_wrdata_en     <= 1'b0;
            rsp_valid         <= 1'b0;
            rsp_rdata         <= 32'd0;
            rsp_id            <= 4'd0;
            rd_id_wr_ptr      <= 4'd0;
            rd_id_rd_ptr      <= 4'd0;
        end else begin
            // Issue DFI commands directly on bus
            dfi_address     <= sched_addr;
            dfi_bank        <= sched_bank;
            {dfi_cs_n, dfi_ras_n, dfi_cas_n, dfi_we_n} <= sched_cmd;

            // Write Data Path
            dfi_wrdata      <= sched_wrdata;
            dfi_wrdata_mask <= sched_wrdata_mask;
            dfi_wrdata_en   <= sched_wrdata_en;

            // Read ID FIFO Push
            if (sched_cmd == `JEDEC_CMD_READ) begin
                rd_id_fifo[rd_id_wr_ptr] <= sched_req_id;
                rd_id_wr_ptr             <= rd_id_wr_ptr + 1'b1;
            end

            // Capture incoming Read Data from PHY
            if (dfi_rddata_valid) begin
                rsp_valid    <= 1'b1;
                rsp_rdata    <= dfi_rddata;
                rsp_id       <= rd_id_fifo[rd_id_rd_ptr];
                rd_id_rd_ptr <= rd_id_rd_ptr + 1'b1;
            end else begin
                rsp_valid    <= 1'b0;
            end
        end
    end

endmodule
