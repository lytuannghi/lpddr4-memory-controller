#!/usr/bin/env python3
import os
from build_layout_engine import build_asic_layout

if __name__ == "__main__":
    lay_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    gds_out = os.path.join(lay_root, "gds", "lpddr4_controller.gds")
    rep_out = os.path.join(lay_root, "reports", "drc_report.txt")
    build_asic_layout(
        gds_path=gds_out,
        report_path=rep_out,
        top_name="lpddr4_controller_top",
        libname="LPDDR4_CONTROLLER_TOP_LIB",
        die_w=680000,
        die_h=680000,
        macro_cols=4,
        macro_rows=3,
        pad_count_per_side=6,
    )
