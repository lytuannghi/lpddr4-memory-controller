// =============================================================================
// Project: JEDEC LPDDR4 Memory Controller Subsystem
// File:    refresh_controller.v
// Description: JEDEC Periodic Refresh Controller (tREFI & tRFC Management)
//              Prevents DRAM Cell Charge Loss via Priority Arbitration
// =============================================================================

`timescale 1ns / 1ps
`include "lpddr4_pkg.vh"

module refresh_controller (
    input  wire        clk,
    input  wire        rst_n,

    // Interface with Command Scheduler
    output reg         ref_req,       // Standard refresh request
    output reg         ref_urgent,    // Urgent refresh (high priority)
    input  wire        ref_ack,       // Acknowledgment from scheduler that CMD_REF is issued
    
    // Status to indicate DRAM is in refresh
    output reg         in_refresh
);

    reg [15:0] refi_counter;
    reg [2:0]  pending_ref_cnt;
    reg [4:0]  rfc_counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            refi_counter    <= 16'd0;
            pending_ref_cnt <= 3'd0;
            ref_req         <= 1'b0;
            ref_urgent      <= 1'b0;
            rfc_counter     <= 5'd0;
            in_refresh      <= 1'b0;
        end else begin
            // tREFI Down Counter
            if (refi_counter >= `TIMING_TREFI - 1) begin
                refi_counter <= 16'd0;
                if (pending_ref_cnt < 3'd7) begin
                    pending_ref_cnt <= pending_ref_cnt + 1'b1;
                end
            end else begin
                refi_counter <= refi_counter + 1'b1;
            end

            // Refresh Request Generation
            if (pending_ref_cnt > 0) begin
                ref_req <= 1'b1;
            end else begin
                ref_req <= 1'b0;
            end

            // Urgent if 2 or more refreshes pending
            if (pending_ref_cnt >= 3'd2) begin
                ref_urgent <= 1'b1;
            end else begin
                ref_urgent <= 1'b0;
            end

            // Acknowledgment handling from scheduler
            if (ref_ack) begin
                if (pending_ref_cnt > 0) begin
                    pending_ref_cnt <= pending_ref_cnt - 1'b1;
                end
                in_refresh  <= 1'b1;
                rfc_counter <= `TIMING_TRFC - 1;
            end

            // tRFC timing lock
            if (in_refresh) begin
                if (rfc_counter > 0) begin
                    rfc_counter <= rfc_counter - 1'b1;
                end else begin
                    in_refresh <= 1'b0;
                end
            end
        end
    end

endmodule
