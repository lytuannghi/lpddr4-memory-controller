# ==============================================================================
# Synopsys Design Constraints (SDC) for JEDEC LPDDR4 Memory Controller
# Target Foundry: High-Performance CMOS (Standard Cell Target)
# Operating Conditions: Worst-Case Slow (WCS) 125C, 0.9V
# Target Operating Frequency: 800.00 MHz (Clock Period = 1.25 ns)
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Primary Clock Definition
# ------------------------------------------------------------------------------
set CLK_PERIOD 1.25
set CLK_PORT   [get_ports clk]

create_clock -name clk -period $CLK_PERIOD [get_ports clk]

# Clock Uncertainty (Jitter + Skew margin)
set_clock_uncertainty -setup 0.050 [get_clocks clk]
set_clock_uncertainty -hold  0.030 [get_clocks clk]

# Clock Transition / Slew
set_clock_transition 0.080 [get_clocks clk]
set_clock_latency -source 0.120 [get_clocks clk]

# ------------------------------------------------------------------------------
# 2. Input Delay Constraints (AXI4 Slave & DFI Read Path)
# ------------------------------------------------------------------------------
# AXI4 Write/Read Channel Inputs (Assuming 40% clock period budget from SoC Bus)
set_input_delay -clock clk -max 0.500 [get_ports s_axi_aw*]
set_input_delay -clock clk -min 0.100 [get_ports s_axi_aw*]
set_input_delay -clock clk -max 0.500 [get_ports s_axi_w*]
set_input_delay -clock clk -min 0.100 [get_ports s_axi_w*]
set_input_delay -clock clk -max 0.500 [get_ports s_axi_ar*]
set_input_delay -clock clk -min 0.100 [get_ports s_axi_ar*]
set_input_delay -clock clk -max 0.400 [get_ports s_axi_bready]
set_input_delay -clock clk -max 0.400 [get_ports s_axi_rready]

# DFI 4.0 Read Data Path from High-Speed PHY
set_input_delay -clock clk -max 0.450 [get_ports dfi_rddata*]
set_input_delay -clock clk -min 0.100 [get_ports dfi_rddata*]
set_input_delay -clock clk -max 0.400 [get_ports dfi_init_complete]

# ------------------------------------------------------------------------------
# 3. Output Delay Constraints (AXI4 Responses & DFI Command/Data)
# ------------------------------------------------------------------------------
# AXI4 Ready / Valid outputs
set_output_delay -clock clk -max 0.450 [get_ports s_axi_awready]
set_output_delay -clock clk -max 0.450 [get_ports s_axi_wready]
set_output_delay -clock clk -max 0.450 [get_ports s_axi_bvalid]
set_output_delay -clock clk -max 0.450 [get_ports s_axi_bid]
set_output_delay -clock clk -max 0.450 [get_ports s_axi_bresp]
set_output_delay -clock clk -max 0.450 [get_ports s_axi_arready]
set_output_delay -clock clk -max 0.450 [get_ports s_axi_rvalid]
set_output_delay -clock clk -max 0.450 [get_ports s_axi_rdata*]

# DFI 4.0 Master Command & Write Data Outputs to PHY
set_output_delay -clock clk -max 0.400 [get_ports dfi_address*]
set_output_delay -clock clk -max 0.400 [get_ports dfi_bank*]
set_output_delay -clock clk -max 0.350 [get_ports dfi_cs_n]
set_output_delay -clock clk -max 0.350 [get_ports dfi_ras_n]
set_output_delay -clock clk -max 0.350 [get_ports dfi_cas_n]
set_output_delay -clock clk -max 0.350 [get_ports dfi_we_n]
set_output_delay -clock clk -max 0.400 [get_ports dfi_wrdata*]
set_output_delay -clock clk -max 0.400 [get_ports dfi_wrdata_mask*]
set_output_delay -clock clk -max 0.350 [get_ports dfi_wrdata_en]

# ------------------------------------------------------------------------------
# 4. Environmental & Design Rule Constraints
# ------------------------------------------------------------------------------
set_max_fanout 16 [current_design]
set_max_transition 0.150 [current_design]
set_driving_cell -lib_cell BUF_X4 [all_inputs]
set_load -pin_load 0.020 [all_outputs]

# ------------------------------------------------------------------------------
# 5. Timing Exceptions (False Paths)
# ------------------------------------------------------------------------------
# Asynchronous Reset Path
set_false_path -from [get_ports rst_n]
