#!/usr/bin/env python3
# =============================================================================
# Project: JEDEC LPDDR4 Memory Controller Subsystem
# File:    run_simulation.py
# Description: Automated Compilation, Simulation, and Regression Verification
# =============================================================================

import os
import sys
import subprocess
import time

def main():
    proj_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    rtl_dir = os.path.join(proj_dir, "rtl")
    tb_dir = os.path.join(proj_dir, "tb")
    
    # Store build artifacts in workspace output directory
    output_dir = r"D:\CODE\GGANTIGRAVITY\minipj\output"
    os.makedirs(output_dir, exist_ok=True)

    vvp_out = os.path.join(output_dir, "lpddr4_sim.vvp")
    vcd_out = os.path.join(output_dir, "lpddr4_waveform.vcd")

    print("=" * 75)
    print("  JEDEC LPDDR4 MEMORY CONTROLLER - AUTOMATED SIMULATION & REGRESSION")
    print("=" * 75)
    print(f"[*] Project Root: {proj_dir}")

    # Step 1: Collect Verilog Sources
    rtl_sources = [
        os.path.join(rtl_dir, "address_mapper.v"),
        os.path.join(rtl_dir, "bank_fsm.v"),
        os.path.join(rtl_dir, "refresh_controller.v"),
        os.path.join(rtl_dir, "command_scheduler.v"),
        os.path.join(rtl_dir, "dfi_master.v"),
        os.path.join(rtl_dir, "axi_slave_frontend.v"),
        os.path.join(rtl_dir, "lpddr4_controller_top.v"),
    ]
    tb_sources = [
        os.path.join(tb_dir, "lpddr4_dram_model.v"),
        os.path.join(tb_dir, "lpddr4_tb.v"),
    ]

    # Step 2: Compile with Icarus Verilog
    print("[*] Compiling RTL and Testbench using iverilog...")
    iverilog_cmd = [
        r"D:\CODE\GGANTIGRAVITY\iverilog\bin\iverilog.exe",
        "-g2005",
        f"-I{rtl_dir}",
        "-o", vvp_out
    ] + rtl_sources + tb_sources

    compile_res = subprocess.run(
        iverilog_cmd,
        cwd=proj_dir,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace"
    )

    if compile_res.returncode != 0:
        print("[!] Compilation FAILED with errors:")
        print(compile_res.stderr)
        sys.exit(1)
    print("    -> Compilation SUCCESSFUL! Binary generated:", vvp_out)

    # Step 3: Run Simulation using vvp
    print("[*] Running Cycle-Accurate Protocol Simulation with vvp...")
    t0 = time.time()
    sim_res = subprocess.run(
        [r"D:\CODE\GGANTIGRAVITY\iverilog\bin\vvp.exe", vvp_out],
        cwd=proj_dir,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace"
    )
    sim_time = time.time() - t0

    print("\n--- Simulation Output ---")
    print(sim_res.stdout)
    if sim_res.stderr:
        print("--- Simulation Warnings/Errors ---")
        print(sim_res.stderr)

    # Step 4: Verification Check
    if "ALL TESTS PASSED SUCCESSFULLY!" in sim_res.stdout:
        print(f"[*] Simulation Elapsed Time: {sim_time:.2f} seconds")
        if os.path.exists(vcd_out):
            vcd_size = os.path.getsize(vcd_out) / 1024
            print(f"[*] Waveform generated: {vcd_out} ({vcd_size:.1f} KB)")
        print("\n[SUCCESS] LPDDR4 Memory Controller Subsystem is 100% VERIFIED!\n")
    else:
        print("\n[ERROR] Test suite did not complete with full pass.\n")
        sys.exit(1)

if __name__ == "__main__":
    main()
