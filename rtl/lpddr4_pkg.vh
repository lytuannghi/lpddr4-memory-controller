`ifndef LPDDR4_PKG_VH
`define LPDDR4_PKG_VH

// =============================================================================
// Project: JEDEC LPDDR4 Memory Controller Subsystem
// File:    lpddr4_pkg.vh
// Description: Global Parameters, JEDEC Commands, and Timing Constants
// =============================================================================

// JEDEC Command Encoding: {cs_n, ras_n, cas_n, we_n}
`define JEDEC_CMD_NOP      4'b1111  // Device Deselect / No Operation
`define JEDEC_CMD_ACT      4'b0011  // Row Activate
`define JEDEC_CMD_READ     4'b0101  // Column Read
`define JEDEC_CMD_WRITE    4'b0100  // Column Write
`define JEDEC_CMD_PRE      4'b0010  // Precharge Single Bank
`define JEDEC_CMD_PREA     4'b0010  // Precharge All (with A10/CA high)
`define JEDEC_CMD_REF      4'b0001  // Auto-Refresh
`define JEDEC_CMD_SRE      4'b0000  // Self-Refresh Entry

// DRAM Organization Constants
`define BANK_WIDTH       3     // 8 Banks (Bank 0 to 7)
`define ROW_WIDTH        16    // 64K Rows
`define COL_WIDTH        10    // 1024 Columns
`define DATA_WIDTH       32    // 32-bit Data bus
`define MASK_WIDTH       4     // Byte mask (4 bytes)
`define ADDR_WIDTH       32    // 32-bit Byte Address

// JEDEC Scaled Timing Constants (Cycles at Controller Clock)
// Modeled accurately for cycle-level protocol verification:
`define TIMING_TRCD      4     // Active to Read/Write delay (cycles)
`define TIMING_TRP       4     // Precharge period (cycles)
`define TIMING_TRAS      8     // Active to Precharge delay (cycles)
`define TIMING_TRC       12    // Active to Active delay in same bank (cycles)
`define TIMING_TCL       4     // Column Read Latency (CAS Latency)
`define TIMING_TCWL      3     // Column Write Latency (CWL)
`define TIMING_TWR       4     // Write Recovery time (cycles)
`define TIMING_TWTR      3     // Write to Read turnaround (cycles)
`define TIMING_TCCD      2     // Column to Column Delay (cycles)
`define TIMING_TRFC      12    // Refresh Cycle Time (cycles)
`define TIMING_TREFI     64    // Refresh Interval (scaled down for simulation)

// Bank State Encoding
`define BANK_IDLE          3'b000   // Precharged & Ready for ACT
`define BANK_ACTIVATING    3'b001   // Waiting for tRCD
`define BANK_ACTIVE        3'b010   // Row is open, ready for RD/WR
`define BANK_PRECHARGING   3'b011   // Waiting for tRP
`define BANK_REFRESHING    3'b100   // Global refresh in progress

`endif // LPDDR4_PKG_VH
