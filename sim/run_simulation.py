#!/usr/bin/env python3
# =============================================================================
# Project: JEDEC LPDDR4 Memory Controller Subsystem
# File:    run_simulation.py
# Description: Portable Compilation, Simulation, and Regression Verification
# =============================================================================

import os
import shutil
import subprocess
import sys
import time


def resolve_tool(name, proj_dir):
    found = shutil.which(name)
    if found:
        return found
    sibling = os.path.join(os.path.dirname(proj_dir), "iverilog", "bin", name + ".exe")
    return sibling if os.path.exists(sibling) else name


def main():
    proj_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    rtl_dir = os.path.join(proj_dir, "rtl")
    phy_dir = os.path.join(proj_dir, "phy_model")
    tb_dir = os.path.join(proj_dir, "tb")
    output_dir = os.path.join(proj_dir, "sim", "output")
    os.makedirs(output_dir, exist_ok=True)

    vvp_out = os.path.join(output_dir, "lpddr4_sim.vvp")
    vcd_out = os.path.join(output_dir, "lpddr4_waveform.vcd")

    iverilog_exe = resolve_tool("iverilog", proj_dir)
    vvp_exe = resolve_tool("vvp", proj_dir)

    print("=" * 75)
    print("  JEDEC LPDDR4 MEMORY CONTROLLER - AUTOMATED SIMULATION & REGRESSION")
    print("=" * 75)

    rtl_sources = [
        os.path.join(rtl_dir, "address_mapper.v"),
        os.path.join(rtl_dir, "bank_fsm.v"),
        os.path.join(rtl_dir, "refresh_controller.v"),
        os.path.join(rtl_dir, "command_scheduler.v"),
        os.path.join(rtl_dir, "dfi_master.v"),
        os.path.join(rtl_dir, "axi_slave_frontend.v"),
        os.path.join(rtl_dir, "lpddr4_controller_top.v"),
        os.path.join(phy_dir, "lpddr4_phy_model.v"),
        os.path.join(phy_dir, "lpddr4_phy_training.v"),
    ]
    tb_sources = [
        os.path.join(tb_dir, "lpddr4_dram_model.v"),
        os.path.join(tb_dir, "lpddr4_tb.v"),
    ]

    print("[*] Compiling RTL, PHY Models & Testbench using iverilog (-Wall)...")
    iverilog_cmd = [
        iverilog_exe,
        "-Wall",
        "-g2005",
        f"-I{rtl_dir}",
        "-o", vvp_out,
    ] + rtl_sources + tb_sources

    compile_res = subprocess.run(iverilog_cmd, cwd=proj_dir, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if compile_res.returncode != 0 or compile_res.stderr.strip():
        print("[!] Compilation FAILED or emitted -Wall warnings:")
        print(compile_res.stderr)
        sys.exit(1)
    print("    -> Compilation Clean (0 warnings)! Binary generated:", vvp_out)

    print("[*] Running Cycle-Accurate Protocol Simulation with vvp...")
    t0 = time.time()
    sim_res = subprocess.run([vvp_exe, vvp_out], cwd=proj_dir, capture_output=True, text=True, encoding="utf-8", errors="replace")
    sim_time = time.time() - t0
    print(sim_res.stdout)
    if sim_res.stderr:
        print(sim_res.stderr)

    if sim_res.returncode == 0 and "ALL TESTS PASSED SUCCESSFULLY!" in sim_res.stdout and "[FAIL]" not in sim_res.stdout:
        print(f"[*] Simulation Elapsed Time: {sim_time:.2f} seconds")
        if os.path.exists(vcd_out):
            print(f"[*] Waveform generated: {vcd_out} ({os.path.getsize(vcd_out) / 1024:.1f} KB)")
        print("\n[SUCCESS] LPDDR4 Memory Controller Subsystem is 100% VERIFIED!\n")
    else:
        print("\n[ERROR] Test suite did not complete with full pass.\n")
        sys.exit(1)


if __name__ == "__main__":
    main()
