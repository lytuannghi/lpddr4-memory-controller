// =============================================================================
// Project: JEDEC LPDDR4 Memory Controller Subsystem
// File:    address_mapper.v
// Description: Decodes Flat AXI4 Address into LPDDR4 Rank/Bank/Row/Column
//              Implements High-Bandwidth Bank-Interleaved Address Mapping
// =============================================================================

`timescale 1ns / 1ps
`include "lpddr4_pkg.vh"

module address_mapper (
    input  wire [31:0]              flat_addr,
    output wire [0:0]               rank_id,
    output wire [`BANK_WIDTH-1:0]   bank_id,
    output wire [`ROW_WIDTH-1:0]    row_addr,
    output wire [`COL_WIDTH-1:0]    col_addr,
    output wire [1:0]               byte_offset
);

    // Byte offset within 32-bit word
    assign byte_offset = flat_addr[1:0];

    // Column address (10 bits: up to 1024 columns = 4KB page size)
    assign col_addr    = flat_addr[11:2];

    // Bank address (3 bits: 8 banks for bank-interleaving)
    assign bank_id     = flat_addr[14:12];

    // Row address (16 bits: 64K rows per bank)
    assign row_addr    = flat_addr[30:15];

    // Rank address (1 bit: Rank 0 or 1)
    assign rank_id     = flat_addr[31];

endmodule
