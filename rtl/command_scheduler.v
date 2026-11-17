// =============================================================================
// Project: JEDEC LPDDR4 Memory Controller Subsystem
// File:    command_scheduler.v
// Description: Intelligent Command Scheduler with Page-Hit/Miss Optimization
//              Instantiates 8 Bank FSMs, Prioritizes Refresh, Minimizes Latency
// =============================================================================

`timescale 1ns / 1ps
`include "lpddr4_pkg.vh"

module command_scheduler (
    input  wire                   clk,
    input  wire                   rst_n,

    // Request from Request Queue / AXI Frontend
    input  wire                   req_valid,
    output reg                    req_ready,
    input  wire                   req_rw,       // 0: Read, 1: Write
    input  wire [`BANK_WIDTH-1:0] req_bank,
    input  wire [`ROW_WIDTH-1:0]  req_row,
    input  wire [`COL_WIDTH-1:0]  req_col,
    input  wire [`DATA_WIDTH-1:0] req_wdata,
    input  wire [`MASK_WIDTH-1:0] req_wstrb,
    input  wire [3:0]             req_id,

    // Refresh Interface
    input  wire                   ref_req,
    input  wire                   ref_urgent,
    input  wire                   in_refresh,
    output reg                    ref_ack,

    // Interface to DFI Master
    output reg  [3:0]             dfi_cmd,
    output reg  [`BANK_WIDTH-1:0] dfi_bank,
    output reg  [`ROW_WIDTH-1:0]  dfi_addr,
    output reg  [`DATA_WIDTH-1:0] dfi_wrdata,
    output reg  [`MASK_WIDTH-1:0] dfi_wrdata_mask,
    output reg                    dfi_wrdata_en,
    output reg  [3:0]             dfi_req_id,
    output reg                    dfi_is_read
);

    // Bank FSM Signals (8 Banks)
    wire [23:0]               bank_states;
    wire [8*`ROW_WIDTH-1:0]   bank_open_rows;
    wire [7:0]                bank_is_idle;
    wire                      all_banks_idle          = &bank_is_idle;
    wire                      all_banks_can_precharge = &(bank_can_pre | bank_is_idle);
    wire [7:0]                bank_is_active;
    wire [7:0]                bank_can_act;
    wire [7:0]                bank_can_pre;
    wire [7:0]                bank_can_rd;
    wire [7:0]                bank_can_wr;
    wire [7:0]                bank_page_hit;
    wire [7:0]                bank_page_miss;

    reg  [7:0]                bank_cmd_act;
    reg  [7:0]                bank_cmd_pre;
    reg  [7:0]                bank_cmd_read;
    reg  [7:0]                bank_cmd_write;
    reg                       bank_cmd_ref_all;

    // Scheduler Internal FSM
    localparam SCHED_IDLE        = 3'd0;
    localparam SCHED_PRE_WAIT    = 3'd1;
    localparam SCHED_ACT_WAIT    = 3'd2;
    localparam SCHED_RW_ISSUE    = 3'd3;
    localparam SCHED_REF_PRE_ALL = 3'd4;
    localparam SCHED_REF_WAIT    = 3'd5;

    reg [2:0] sched_state;
    reg [4:0] sched_rfc_cnt;
    reg [`BANK_WIDTH-1:0] active_bank;
    reg [`ROW_WIDTH-1:0]  active_row;
    reg [`COL_WIDTH-1:0]  active_col;
    reg                   active_rw;
    reg [`DATA_WIDTH-1:0] active_wdata;
    reg [`MASK_WIDTH-1:0] active_wstrb;
    reg [3:0]             active_id;

    wire [`ROW_WIDTH-1:0] cur_target_row = (sched_state == SCHED_IDLE) ? req_row : active_row;

    // Generate 8 Bank FSM Instances
    genvar b;
    generate
        for (b = 0; b < 8; b = b + 1) begin : gen_bank_fsm
            bank_fsm u_bank_fsm (
                .clk           (clk),
                .rst_n         (rst_n),
                .cmd_act       (bank_cmd_act[b]),
                .cmd_pre       (bank_cmd_pre[b]),
                .cmd_read      (bank_cmd_read[b]),
                .cmd_write     (bank_cmd_write[b]),
                .cmd_ref       (bank_cmd_ref_all),
                .target_row    (cur_target_row),
                .bank_state    (bank_states[b*3 +: 3]),
                .open_row      (bank_open_rows[b*`ROW_WIDTH +: `ROW_WIDTH]),
                .is_idle       (bank_is_idle[b]),
                .is_active     (bank_is_active[b]),
                .can_activate  (bank_can_act[b]),
                .can_precharge (bank_can_pre[b]),
                .can_read      (bank_can_rd[b]),
                .can_write     (bank_can_wr[b]),
                .page_hit      (bank_page_hit[b]),
                .page_miss     (bank_page_miss[b])
            );
        end
    endgenerate

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sched_state      <= SCHED_IDLE;
            sched_rfc_cnt    <= 5'd0;
            req_ready        <= 1'b0;
            ref_ack          <= 1'b0;
            dfi_cmd          <= `JEDEC_CMD_NOP;
            dfi_bank         <= 3'd0;
            dfi_addr         <= 16'd0;
            dfi_wrdata       <= 32'd0;
            dfi_wrdata_mask  <= 4'd0;
            dfi_wrdata_en    <= 1'b0;
            dfi_req_id       <= 4'd0;
            dfi_is_read      <= 1'b0;
            bank_cmd_act     <= 8'd0;
            bank_cmd_pre     <= 8'd0;
            bank_cmd_read    <= 8'd0;
            bank_cmd_write   <= 8'd0;
            bank_cmd_ref_all <= 1'b0;
            active_bank      <= 3'd0;
            active_row       <= 16'd0;
            active_col       <= 10'd0;
            active_rw        <= 1'b0;
            active_wdata     <= 32'd0;
            active_wstrb     <= 4'd0;
            active_id        <= 4'd0;
        end else begin
            // Default strobe clearances
            dfi_cmd          <= `JEDEC_CMD_NOP;
            dfi_wrdata_en    <= 1'b0;
            req_ready        <= 1'b0;
            ref_ack          <= 1'b0;
            bank_cmd_act     <= 8'd0;
            bank_cmd_pre     <= 8'd0;
            bank_cmd_read    <= 8'd0;
            bank_cmd_write   <= 8'd0;
            bank_cmd_ref_all <= 1'b0;

            case (sched_state)
                SCHED_IDLE: begin
                    // Priority 1: Urgent Refresh or Refresh when idle
                    if (ref_urgent || (ref_req && !req_valid)) begin
                        if (all_banks_idle) begin
                            dfi_cmd          <= `JEDEC_CMD_REF;
                            bank_cmd_ref_all <= 1'b1;
                            ref_ack          <= 1'b1;
                            sched_rfc_cnt    <= `TIMING_TRFC - 1;
                            sched_state      <= SCHED_REF_WAIT;
                        end else if (all_banks_can_precharge) begin
                            // Precharge all banks first
                            dfi_cmd      <= `JEDEC_CMD_PREA;
                            bank_cmd_pre <= 8'hFF;
                            sched_state  <= SCHED_REF_PRE_ALL;
                        end
                    end
                    // Priority 2: Service Memory Request
                    else if (req_valid && !in_refresh) begin
                        active_bank  <= req_bank;
                        active_row   <= req_row;
                        active_col   <= req_col;
                        active_rw    <= req_rw;
                        active_wdata <= req_wdata;
                        active_wstrb <= req_wstrb;
                        active_id    <= req_id;

                        // Case A: Page Hit! (The row in target bank is already open)
                        if (bank_page_hit[req_bank]) begin
                            req_ready <= 1'b1;
                            dfi_bank  <= req_bank;
                            dfi_addr  <= {6'd0, req_col};
                            dfi_req_id<= req_id;

                            if (req_rw == 1'b0) begin // READ
                                dfi_cmd                 <= `JEDEC_CMD_READ;
                                dfi_is_read             <= 1'b1;
                                bank_cmd_read[req_bank] <= 1'b1;
                            end else begin           // WRITE
                                dfi_cmd                  <= `JEDEC_CMD_WRITE;
                                dfi_is_read              <= 1'b0;
                                dfi_wrdata               <= req_wdata;
                                dfi_wrdata_mask          <= req_wstrb;
                                dfi_wrdata_en            <= 1'b1;
                                bank_cmd_write[req_bank] <= 1'b1;
                            end
                            // Stays in IDLE for continuous high-throughput Page-Hit stream!
                            sched_state <= SCHED_IDLE;
                        end
                        // Case B: Page Miss! (Row in target bank is open but doesn't match)
                        else if (bank_page_miss[req_bank]) begin
                            if (bank_can_pre[req_bank]) begin
                                dfi_cmd                <= `JEDEC_CMD_PRE;
                                dfi_bank               <= req_bank;
                                bank_cmd_pre[req_bank] <= 1'b1;
                                sched_state            <= SCHED_PRE_WAIT;
                            end
                        end
                        // Case C: Page Empty (Bank is IDLE)
                        else if (bank_is_idle[req_bank]) begin
                            dfi_cmd                <= `JEDEC_CMD_ACT;
                            dfi_bank               <= req_bank;
                            dfi_addr               <= req_row;
                            bank_cmd_act[req_bank] <= 1'b1;
                            sched_state            <= SCHED_ACT_WAIT;
                        end
                    end
                end

                SCHED_PRE_WAIT: begin
                    // Wait until the bank finishes precharge and becomes IDLE
                    if (bank_is_idle[active_bank]) begin
                        dfi_cmd                   <= `JEDEC_CMD_ACT;
                        dfi_bank                  <= active_bank;
                        dfi_addr                  <= active_row;
                        bank_cmd_act[active_bank] <= 1'b1;
                        sched_state               <= SCHED_ACT_WAIT;
                    end
                end

                SCHED_ACT_WAIT: begin
                    // Wait until the bank finishes activation and becomes ACTIVE
                    if (bank_is_active[active_bank]) begin
                        req_ready  <= 1'b1;
                        dfi_bank   <= active_bank;
                        dfi_addr   <= {6'd0, active_col};
                        dfi_req_id <= active_id;

                        if (active_rw == 1'b0) begin // READ
                            dfi_cmd                    <= `JEDEC_CMD_READ;
                            dfi_is_read                <= 1'b1;
                            bank_cmd_read[active_bank] <= 1'b1;
                        end else begin              // WRITE
                            dfi_cmd                     <= `JEDEC_CMD_WRITE;
                            dfi_is_read                 <= 1'b0;
                            dfi_wrdata                  <= active_wdata;
                            dfi_wrdata_mask             <= active_wstrb;
                            dfi_wrdata_en               <= 1'b1;
                            bank_cmd_write[active_bank] <= 1'b1;
                        end
                        sched_state <= SCHED_IDLE;
                    end
                end

                SCHED_REF_PRE_ALL: begin
                    if (all_banks_idle) begin
                        dfi_cmd          <= `JEDEC_CMD_REF;
                        bank_cmd_ref_all <= 1'b1;
                        ref_ack          <= 1'b1;
                        sched_rfc_cnt    <= `TIMING_TRFC - 1;
                        sched_state      <= SCHED_REF_WAIT;
                    end
                end

                SCHED_REF_WAIT: begin
                    if (sched_rfc_cnt > 0) begin
                        sched_rfc_cnt <= sched_rfc_cnt - 1'b1;
                    end else begin
                        sched_state <= SCHED_IDLE;
                    end
                end

                default: sched_state <= SCHED_IDLE;
            endcase
        end
    end

endmodule
