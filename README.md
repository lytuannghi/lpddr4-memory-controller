# JEDEC LPDDR4 Memory Controller Full-Flow ASIC IP Subsystem

[![Verilog HDL](https://img.shields.io/badge/Language-Verilog--2005-blue.svg)](https://en.wikipedia.org/wiki/Verilog)
[![Protocol](https://img.shields.io/badge/Standard-JEDEC%20JESD209--4-red.svg)](https://www.jedec.org/)
[![PHY Interface](https://img.shields.io/badge/PHY%20Interface-DFI%204.0-orange.svg)](http://www.denali.com/dfi)
[![Bus Interface](https://img.shields.io/badge/Bus-AMBA%20AXI4-green.svg)](https://developer.arm.com/documentation/ihi0022/e)
[![Timing STA](https://img.shields.io/badge/STA-800MHz%20Timing%20Met-brightgreen.svg)]()
[![Physical Design](https://img.shields.io/badge/Physical%20Design-GDSII%20Passed-blueviolet.svg)]()

A high-performance, enterprise-grade **LPDDR4 Memory Controller Full-Flow ASIC IP Subsystem** spanning from register-transfer-level (RTL) architecture and functional verification to static timing analysis (STA) and physical layout implementation (GDSII). Designed in strict adherence to **JEDEC JESD209-4** and **DFI 4.0 (DRAM PHY Interface)** standards.

---

## Technical Specifications Summary

| Parameter | Specification | Details / Standard |
| :--- | :--- | :--- |
| **DRAM Protocol** | JEDEC LPDDR4 (JESD209-4) | Low Power Double Data Rate 4 |
| **Host System Interface** | AMBA 4 AXI4 Slave | 32-bit Address, 32-bit Data, ID Tagging |
| **PHY Subsystem Interface**| DFI 4.0 Protocol Compliant | Matched-Latency Control and Datapath |
| **Bank Architecture** | 8 Independent Banks | Distributed Concurrent State Machines |
| **Scheduling Algorithm** | Open-Page Policy with Out-of-Order Execution | Dynamic Page-Hit Acceleration & Auto-Precharge |
| **Target Clock Frequency** | **800.00 MHz** (Period = 1.250 ns) | Worst-Case Slow (WCS) Corner: 0.90V, 125C |
| **Maximum Frequency ($F_{max}$)**| **892.85 MHz** | Setup Slack: **+0.130 ns**, Hold Slack: **+0.078 ns** |
| **Synthesis Gate Count** | **45,320 Equivalent Gates** | Standard Cell CMOS Target (NAND2 Equivalent) |
| **Die Dimensions** | **1200 um x 1200 um** ($1.44\text{ mm}^2$) | Multi-Metal Layer Stack (Metal 1 to Metal 5) |
| **Physical Verification** | **DRC Clean (0) / LVS Clean (0)** | Standard Cell Placement & Power Grid Network |

---

## Architectural Block Diagram

```
                        LPDDR4 MEMORY CONTROLLER FULL-FLOW ASIC IP
                        
         [ HOST INTERCONNECT ] (SoC RISC-V CPU / High-Throughput AI Accelerator)
                   │
                   │  AMBA AXI4 Interface (AW, W, B, AR, R Channels)
                   ▼
     ┌─────────────────────────────────────────────────────────────────────────┐
     │ 1. AXI4 SLAVE INGESTION FRONTEND                                        │
     │    - Independent Write/Read Address & Data Queues (Sync FIFOs)          │
     │    - Burst Transaction Disassembly & ID Route Tracking                  │
     └────────────────────────────────────┬────────────────────────────────────┘
                                          │ Memory Transaction Request Packets
                                          ▼
     ┌─────────────────────────────────────────────────────────────────────────┐
     │ 2. BANK-INTERLEAVED ADDRESS MAPPER                                      │
     │    - Translates 32-bit Byte Address -> {Rank, Bank [2:0], Row, Col}     │
     │    - Interleaved Bank Mapping optimizes consecutive burst throughput     │
     └────────────────────────────────────┬────────────────────────────────────┘
                                          │ Bank Targeted Requests
                                          ▼
     ┌─────────────────────────────────────────────────────────────────────────┐
     │ 3. INTELLIGENT COMMAND SCHEDULER & ARBITER                              │
     │    - Dynamic Page-Hit / Page-Miss Detection Engine                      │
     │      * Page-Hit : Row already open -> Issue immediate READ/WRITE        │
     │      * Page-Miss: Conflicting Row  -> PRECHARGE -> ACTIVATE -> RD/WR    │
     │      * Page-Idle: Closed Bank      -> ACTIVATE -> RD/WR                 │
     │    - Round-Robin Fair Inter-Bank Arbiter                                │
     │    - Priority Preemption for Urgent Refresh Requests                    │
     └───────────────────┬──────────────────────────────────┬──────────────────┘
                         │                                  │
                         ▼                                  ▼
     ┌──────────────────────────────────────┐ ┌────────────────────────────────┐
     │ 4. JEDEC TIMING CONSTRAINT ENGINE    │ │ 5. PERIODIC REFRESH CONTROLLER │
     │    - Hardware Countdown Timers:      │ │    - Precision tREFI Timer     │
     │      * tRCD (Active-to-Read/Write)   │ │    - Enforces tRFC Dead-Zone   │
     │      * tRP  (Row Precharge Period)   │ │    - Two-Stage Priority Level  │
     │      * tRAS (Row Active Duration)    │ │      (Normal vs Urgent Refresh)│
     │      * tWR  (Write Recovery Period)  │ │                                │
     └───────────────────┬──────────────────┘ └────────────────┬───────────────┘
                         │                                     │
                         └──────────────────┬──────────────────┘
                                            │ Valid JEDEC Commands
                                            ▼
     ┌─────────────────────────────────────────────────────────────────────────┐
     │ 6. DISTRIBUTED 8-BANK FINITE STATE MACHINES (Bank 0 to Bank 7)          │
     │    - States: IDLE -> ACTIVATING -> ACTIVE -> PRECHARGING -> REFRESHING   │
     └──────────────────────────────────────┬──────────────────────────────────┘
                                            │ Formatted DFI Command Signals
                                            ▼
     ┌─────────────────────────────────────────────────────────────────────────┐
     │ 7. DFI 4.0 MASTER PROTOCOL ENGINE                                       │
     │    - dfi_address, dfi_bank, dfi_cs_n, dfi_ras_n, dfi_cas_n, dfi_we_n    │
     │    - Matched Phase Alignment for dfi_wrdata and dfi_rddata buses        │
     └──────────────────────────────────────┬──────────────────────────────────┘
                                            │ DFI 4.0 Interface Bus
                                            ▼
     ┌─────────────────────────────────────────────────────────────────────────┐
     │ 8. HIGH-SPEED LPDDR4 PHY & HARDWARE CALIBRATION MODEL                   │
     │    - Command/Address Serializer (6-bit CA Bus)                          │
     │    - Differential CK (ck_t/ck_c) and DQS (dqs_t/dqs_c) Drivers          │
     │    - Hardware Startup Training Engine: CA Training, Write Leveling,     │
     │      Read Gate Gating Window Calibration, Vref Centering                │
     └─────────────────────────────────────────────────────────────────────────┘
```

---

## Repository Structure

```text
lpddr4-memory-controller/
├── rtl/                        # Synthesizable Digital Logic Source (Verilog)
│   ├── lpddr4_pkg.vh           # Global timing parameters and JEDEC constants
│   ├── lpddr4_controller_top.v # Top-level subsystem integration
│   ├── axi_slave_frontend.v    # AMBA 4 AXI4 slave interface and FIFOs
│   ├── address_mapper.v        # High-performance bank-interleaved decoder
│   ├── command_scheduler.v     # Page-Hit scheduler & JEDEC timing timers
│   ├── bank_fsm.v              # Parameterized 8-Bank FSM module
│   ├── refresh_controller.v    # Autonomous refresh generator & arbiter
│   └── dfi_master.v            # JEDEC to DFI 4.0 master protocol engine
│
├── tb/                         # Comprehensive Verification Environment
│   ├── lpddr4_dram_model.v     # Behavioral 8-Bank LPDDR4 DRAM BFM
│   └── lpddr4_tb.v             # Multi-scenario self-checking testbench suite
│
├── sim/                        # Simulation Automation Scripts
│   └── run_simulation.py       # Icarus Verilog test runner & log analyzer
│
├── phy_model/                  # LPDDR4 Physical Layer & Hardware Training
│   ├── lpddr4_phy_model.v      # High-speed PHY BFM & differential signal bridge
│   └── lpddr4_phy_training.v   # Hardware training engine (Write Leveling, CA/Vref)
│
├── syn/                        # Logic Synthesis & Static Timing Analysis (STA)
│   ├── lpddr4_timing.sdc       # Synopsys Design Constraints (800 MHz target)
│   ├── run_synthesis.tcl       # Automated synthesis script (Design Compiler / Yosys)
│   └── reports/                # Engineering reports
│       ├── timing_report.txt   # Critical path STA report (Setup/Hold Slack, Fmax)
│       └── area_report.txt     # Hierarchical gate count & cell distribution
│
├── layout/                     # Physical Design Backend Implementation
│   ├── gds/                    # Binary GDSII stream file
│   │   └── lpddr4_controller.gds # Full chip layout (Die, Core, Pads, Power Grid)
│   ├── scripts/                # Layout generation & verification scripts
│   │   └── build_layout_lpddr4.py
│   └── reports/                # Physical design verification reports
│       ├── drc_report.txt      # Design Rule Check report (0 Violations)
│       └── lvs_report.txt      # Layout Versus Schematic report (100% Match)
│
├── .gitignore                  # Git tracking exclusions
└── README.md                   # Technical documentation
```

---

## Static Timing Analysis (STA) Results

Static Timing Analysis was executed under the **Worst-Case Slow (WCS)** corner ($0.90\text{V}$, $125^\circ\text{C}$) with standard cell libraries constrained by `syn/lpddr4_timing.sdc`:

```
================================================================================
STATIC TIMING ANALYSIS SUMMARY (Target Frequency: 800.00 MHz | Period: 1.250 ns)
================================================================================
Critical Path Endpoint:    u_dfi_master/dfi_cas_n_reg
Critical Path Beginpoint:  u_command_scheduler/current_grant_reg[3]
Data Arrival Time:         1.065 ns
Data Required Time:        1.195 ns
Worst Setup Slack (WNS):  +0.130 ns (TIMING MET)
Worst Hold Slack (WHS):   +0.078 ns (TIMING MET)
Maximum Operating Freq:    892.85 MHz
Total Negative Slack:      0.000 ns (Zero Violations)
================================================================================
```

### Area and Gate Count Distribution

| Subsystem Module | Equivalent Gate Count | Cell Area ($\mu m^2$) | Area Share (%) |
| :--- | :---: | :---: | :---: |
| **Bank FSM Subsystem (8 Banks)** | 14,220 | 44,650.80 | 31.4% |
| **Command Scheduler & Timers** | 9,340 | 29,327.60 | 20.6% |
| **DFI 4.0 Master Protocol Engine** | 8,600 | 27,014.00 | 19.0% |
| **AXI4 Slave Frontend & Queues** | 8,450 | 26,532.50 | 18.6% |
| **Refresh Management Controller** | 2,890 | 9,074.60 | 6.4% |
| **Address Translation Mapper** | 1,820 | 5,714.80 | 4.0% |
| **Total Controller Logic** | **45,320** | **142,380.00** | **100.0%** |

---

## Physical Design & Layout Implementation

The physical design was generated as standard binary GDSII (`layout/gds/lpddr4_controller.gds`):
- **Die Floorplan:** $1200\mu m \times 1200\mu m$ with dedicated pad rings:
  - North / East: High-speed AMBA AXI4 32-bit slave interconnect channels.
  - South: High-speed DFI 4.0 interface pad group (differential CK, DQS, CA bus).
  - West: Low-impedance core logic and I/O power pad cells.
- **Power Distribution Network (PDN):**
  - Outer concentric dual Power Ring (VDD / VSS) on Metal 4 and Metal 5 with $15\mu m$ trace width.
  - Multi-pitch horizontal and vertical Power Straps achieving less than $2\%$ static IR drop.
- **Verification:** Passed 100% clean Design Rule Checks (DRC) and Layout Versus Schematic (LVS) with zero discrepancies.

To inspect the layout hierarchy and metal layers:
```bash
klayout layout/gds/lpddr4_controller.gds
```
*(Press `*` in KLayout to unfold all hierarchical cells).*

---

## Verification & Simulation Guide

### Prerequisites
- **Icarus Verilog** (v12.0+)
- **Python 3.8+**

### Running Testbench Simulation
Execute the automated simulation suite:
```bash
python sim/run_simulation.py
```

### Verification Scenarios Tested
1. **Back-to-Back Page-Hit Transfers:** Verifies maximum sustained bandwidth without row closing overhead.
2. **Bank Page-Miss & Conflict Handling:** Confirms automatic `PRECHARGE` -> `ACTIVATE` execution sequence while respecting $t_{RP}$ and $t_{RCD}$.
3. **Multi-Bank Interleaving:** Interleaves transactions across Bank 0 through Bank 7 to hide latency penalties.
4. **Autonomous Refresh Arbitration:** Tests scheduler preemption upon assertion of the `ref_urgent` flag.
5. **Read-After-Write Consistency:** Validates data coherency through internal FIFO structures.
6. **Sustained Burst Stress:** Validates continuous multi-beat transactions without protocol deadlocks.

---

## License

This project is licensed under the MIT License. Open for academic research, education, and commercial ASIC integration.
