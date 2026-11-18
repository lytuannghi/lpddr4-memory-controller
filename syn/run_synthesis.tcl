# ==============================================================================
# Synthesis Automation Script for LPDDR4 Memory Controller
# Supported Tools: Synopsys Design Compiler (DC-Shell) / Yosys Open-Source EDA
# ==============================================================================

set DESIGN_NAME "lpddr4_controller_top"
set RTL_DIR     "../rtl"
set REPORT_DIR  "./reports"

file mkdir $REPORT_DIR

puts "========================================================="
puts " Starting Synthesis Run for $DESIGN_NAME"
puts "========================================================="

# Read Verilog Header Package & RTL Sources
analyze -format verilog [list \
    "$RTL_DIR/lpddr4_pkg.vh" \
    "$RTL_DIR/axi_slave_frontend.v" \
    "$RTL_DIR/address_mapper.v" \
    "$RTL_DIR/command_scheduler.v" \
    "$RTL_DIR/bank_fsm.v" \
    "$RTL_DIR/refresh_controller.v" \
    "$RTL_DIR/dfi_master.v" \
    "$RTL_DIR/lpddr4_controller_top.v" \
]

elaborate $DESIGN_NAME
current_design $DESIGN_NAME

# Check Design Hierarchy
check_design > "$REPORT_DIR/check_design.rpt"

# Apply Synopsys Design Constraints
source -echo -verbose "./lpddr4_timing.sdc"

# Compile Ultra & Optimization
compile_ultra -gate_clock -no_autoungroup

# Generate Detailed Engineering Reports
report_timing -delay_type max -max_paths 10 > "$REPORT_DIR/timing_report.txt"
report_timing -delay_type min -max_paths 5  >> "$REPORT_DIR/timing_report.txt"
report_area -hierarchy                      > "$REPORT_DIR/area_report.txt"
report_power -hierarchy                     > "$REPORT_DIR/power_report.txt"
report_qor                                  > "$REPORT_DIR/qor_report.txt"

# Export Gate-Level Netlist
write -format verilog -hierarchy -output "./netlist/${DESIGN_NAME}_gate.v"
write_sdc "./netlist/${DESIGN_NAME}_out.sdc"

puts "========================================================="
puts " Synthesis Run Completed Successfully!"
puts "========================================================="
