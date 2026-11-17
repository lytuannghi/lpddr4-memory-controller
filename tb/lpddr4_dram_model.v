// =============================================================================
// Project: JEDEC LPDDR4 Memory Controller Subsystem
// File:    lpddr4_dram_model.v
// Description: Behavioral LPDDR4 DRAM Bus Functional Model (BFM)
//              Simulates 8 Memory Banks, Enforces JEDEC Protocol & Timing Checks
// =============================================================================

`timescale 1ns / 1ps
`include "lpddr4_pkg.vh"

module lpddr4_dram_model (
    input  wire                   clk,
    input  wire                   rst_n,

    // DFI 4.0 Interface from Controller
    input  wire [`ROW_WIDTH-1:0]  dfi_address,
    input  wire [`BANK_WIDTH-1:0] dfi_bank,
    input  wire                   dfi_cs_n,
    input  wire                   dfi_ras_n,
    input  wire                   dfi_cas_n,
    input  wire                   dfi_we_n,
    input  wire [`DATA_WIDTH-1:0] dfi_wrdata,
    input  wire [`MASK_WIDTH-1:0] dfi_wrdata_mask,
    input  wire                   dfi_wrdata_en,

    // DFI Read Data Path to Controller
    output reg  [`DATA_WIDTH-1:0] dfi_rddata,
    output reg                    dfi_rddata_valid,
    output wire                   dfi_init_complete
);

    assign dfi_init_complete = 1'b1;

    // Sparse Behavioral Storage (Indexed by {Bank[2:0], Row[5:0], Col[6:0]} for fast simulation)
    reg [31:0] mem_array [0:65535];

    // Bank Tracking in DRAM
    reg [7:0]            bank_opened;
    reg [`ROW_WIDTH-1:0] bank_open_row [0:7];

    // Timing check counters
    integer last_act_time [0:7];
    integer last_pre_time [0:7];
    integer last_wr_time  [0:7];

    // Read Latency Pipeline (CAS Latency = `TIMING_TCL)
    reg [`DATA_WIDTH-1:0] rd_pipe_data  [0:7];
    reg                   rd_pipe_valid [0:7];

    wire [3:0] current_cmd = {dfi_cs_n, dfi_ras_n, dfi_cas_n, dfi_we_n};
    integer i;

    // Helper function to calculate memory index
    function [15:0] get_mem_idx;
        input [2:0] b;
        input [15:0] r;
        input [9:0] c;
        begin
            get_mem_idx = {b, r[5:0], c[6:0]};
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dfi_rddata       <= 32'd0;
            dfi_rddata_valid <= 1'b0;
            bank_opened      <= 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
                bank_open_row[i] <= 16'd0;
                last_act_time[i] <= -100;
                last_pre_time[i] <= -100;
                last_wr_time[i]  <= -100;
                rd_pipe_data[i]  <= 32'd0;
                rd_pipe_valid[i] <= 1'b0;
            end
        end else begin
            // Read pipeline shift
            for (i = 0; i < `TIMING_TCL - 1; i = i + 1) begin
                rd_pipe_data[i]  <= rd_pipe_data[i+1];
                rd_pipe_valid[i] <= rd_pipe_valid[i+1];
            end
            rd_pipe_data[`TIMING_TCL - 1]  <= 32'd0;
            rd_pipe_valid[`TIMING_TCL - 1] <= 1'b0;

            // Output read beat
            dfi_rddata       <= rd_pipe_data[0];
            dfi_rddata_valid <= rd_pipe_valid[0];

            // Decode JEDEC Commands
            case (current_cmd)
                `JEDEC_CMD_ACT: begin
                    // Timing Check: tRP (Precharge to Active)
                    if ($time - last_pre_time[dfi_bank] < `TIMING_TRP * 10 && last_pre_time[dfi_bank] > 0) begin
                        $display("[DRAM BFM VIOLATION] Bank %0d: tRP Violation at time %0t!", dfi_bank, $time);
                    end
                    bank_opened[dfi_bank]   <= 1'b1;
                    bank_open_row[dfi_bank] <= dfi_address;
                    last_act_time[dfi_bank] <= $time;
                end

                `JEDEC_CMD_PRE: begin
                    // Timing Check: tRAS (Active to Precharge)
                    if ($time - last_act_time[dfi_bank] < `TIMING_TRAS * 10 && last_act_time[dfi_bank] > 0) begin
                        $display("[DRAM BFM VIOLATION] Bank %0d: tRAS Violation at time %0t!", dfi_bank, $time);
                    end
                    bank_opened[dfi_bank]   <= 1'b0;
                    last_pre_time[dfi_bank] <= $time;
                end

                `JEDEC_CMD_PREA: begin
                    bank_opened <= 8'd0;
                    for (i = 0; i < 8; i = i + 1) begin
                        last_pre_time[i] <= $time;
                    end
                end

                `JEDEC_CMD_READ: begin
                    // Timing Check: tRCD (Active to Read)
                    if ($time - last_act_time[dfi_bank] < `TIMING_TRCD * 10 && last_act_time[dfi_bank] > 0) begin
                        $display("[DRAM BFM VIOLATION] Bank %0d: tRCD Violation on READ at time %0t!", dfi_bank, $time);
                    end
                    // Schedule read data after CAS Latency
                    rd_pipe_valid[`TIMING_TCL - 1] <= 1'b1;
                    rd_pipe_data[`TIMING_TCL - 1]  <= mem_array[get_mem_idx(dfi_bank, bank_open_row[dfi_bank], dfi_address[9:0])];
                end

                `JEDEC_CMD_WRITE: begin
                    // Timing Check: tRCD (Active to Write)
                    if ($time - last_act_time[dfi_bank] < `TIMING_TRCD * 10 && last_act_time[dfi_bank] > 0) begin
                        $display("[DRAM BFM VIOLATION] Bank %0d: tRCD Violation on WRITE at time %0t!", dfi_bank, $time);
                    end
                    last_wr_time[dfi_bank] <= $time;
                    
                    // Write with Byte Strobes
                    if (dfi_wrdata_mask[0]) mem_array[get_mem_idx(dfi_bank, bank_open_row[dfi_bank], dfi_address[9:0])][7:0]   <= dfi_wrdata[7:0];
                    if (dfi_wrdata_mask[1]) mem_array[get_mem_idx(dfi_bank, bank_open_row[dfi_bank], dfi_address[9:0])][15:8]  <= dfi_wrdata[15:8];
                    if (dfi_wrdata_mask[2]) mem_array[get_mem_idx(dfi_bank, bank_open_row[dfi_bank], dfi_address[9:0])][23:16] <= dfi_wrdata[23:16];
                    if (dfi_wrdata_mask[3]) mem_array[get_mem_idx(dfi_bank, bank_open_row[dfi_bank], dfi_address[9:0])][31:24] <= dfi_wrdata[31:24];
                end

                `JEDEC_CMD_REF: begin
                    // Auto-Refresh
                end

                default: ; // NOP
            endcase
        end
    end

endmodule
