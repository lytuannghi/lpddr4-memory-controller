// =============================================================================
// Project: JEDEC LPDDR4 Memory Controller Subsystem
// File:    bank_fsm.v
// Description: Per-Bank State Machine & JEDEC Timing Enforcement Unit
//              Tracks Bank State, Open Row, and JEDEC Delays (tRCD, tRP, tRAS, tWR)
// =============================================================================

`timescale 1ns / 1ps
`include "lpddr4_pkg.vh"

module bank_fsm (
    input  wire                  clk,
    input  wire                  rst_n,

    // Command Strobes from Scheduler
    input  wire                  cmd_act,        // Activate command to this bank
    input  wire                  cmd_pre,        // Precharge command to this bank
    input  wire                  cmd_read,       // Read command to this bank
    input  wire                  cmd_write,      // Write command to this bank
    input  wire                  cmd_ref,        // Global refresh command
    input  wire [`ROW_WIDTH-1:0] target_row,     // Row requested by incoming command

    // Status Signals to Scheduler
    output reg  [2:0]            bank_state,
    output reg  [`ROW_WIDTH-1:0] open_row,
    output wire                  is_idle,
    output wire                  is_active,
    output wire                  can_activate,
    output wire                  can_precharge,
    output wire                  can_read,
    output wire                  can_write,
    output wire                  page_hit,
    output wire                  page_miss
);

    // Timing counters
    reg [3:0] trcd_cnt;
    reg [3:0] trp_cnt;
    reg [4:0] tras_cnt;
    reg [3:0] twr_cnt;
    reg [4:0] trfc_cnt;

    // Status flags
    assign is_idle       = (bank_state == `BANK_IDLE);
    assign is_active     = (bank_state == `BANK_ACTIVE);
    assign can_activate  = (bank_state == `BANK_IDLE);
    assign can_precharge = (bank_state == `BANK_ACTIVE) && (tras_cnt == 0) && (twr_cnt == 0);
    assign can_read      = (bank_state == `BANK_ACTIVE);
    assign can_write     = (bank_state == `BANK_ACTIVE);

    // Page Hit / Miss evaluation
    assign page_hit      = (bank_state == `BANK_ACTIVE) && (open_row == target_row);
    assign page_miss     = (bank_state == `BANK_ACTIVE) && (open_row != target_row);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bank_state <= `BANK_IDLE;
            open_row   <= {`ROW_WIDTH{1'b0}};
            trcd_cnt   <= 4'd0;
            trp_cnt    <= 4'd0;
            tras_cnt   <= 5'd0;
            twr_cnt    <= 4'd0;
            trfc_cnt   <= 5'd0;
        end else begin
            // Down-counters for Timing delays
            if (trcd_cnt > 0) trcd_cnt <= trcd_cnt - 1'b1;
            if (trp_cnt  > 0) trp_cnt  <= trp_cnt  - 1'b1;
            if (tras_cnt > 0) tras_cnt <= tras_cnt - 1'b1;
            if (twr_cnt  > 0) twr_cnt  <= twr_cnt  - 1'b1;
            if (trfc_cnt > 0) trfc_cnt <= trfc_cnt - 1'b1;

            // State Transitions
            case (bank_state)
                `BANK_IDLE: begin
                    if (cmd_ref) begin
                        bank_state <= `BANK_REFRESHING;
                        trfc_cnt   <= `TIMING_TRFC - 1;
                    end else if (cmd_act) begin
                        bank_state <= `BANK_ACTIVATING;
                        open_row   <= target_row;
                        trcd_cnt   <= `TIMING_TRCD - 1;
                        tras_cnt   <= `TIMING_TRAS - 1;
                    end
                end

                `BANK_ACTIVATING: begin
                    if (trcd_cnt == 0) begin
                        bank_state <= `BANK_ACTIVE;
                    end
                end

                `BANK_ACTIVE: begin
                    if (cmd_write) begin
                        twr_cnt <= `TIMING_TCWL + `TIMING_TWR;
                    end

                    if (cmd_pre && can_precharge) begin
                        bank_state <= `BANK_PRECHARGING;
                        trp_cnt    <= `TIMING_TRP - 1;
                    end
                end

                `BANK_PRECHARGING: begin
                    if (trp_cnt == 0) begin
                        bank_state <= `BANK_IDLE;
                    end
                end

                `BANK_REFRESHING: begin
                    if (trfc_cnt == 0) begin
                        bank_state <= `BANK_IDLE;
                    end
                end

                default: bank_state <= `BANK_IDLE;
            endcase
        end
    end

endmodule
