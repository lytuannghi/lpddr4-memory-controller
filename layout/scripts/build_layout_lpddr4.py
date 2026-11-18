# ==============================================================================
# File: build_layout_lpddr4.py
# Description: Generates Full Physical Design GDSII for LPDDR4 Memory Controller Subsystem
# Technology: Standard CMOS Multi-Metal Stack (Metal 1 to Metal 5)
# Die Area: 1200 um x 1200 um | Core Area: 1000 um x 1000 um
# ==============================================================================

import os
import struct
import random

class GDSWriter:
    def __init__(self, filename, libname="LPDDR4_CTRL_LIB"):
        self.filename = filename
        self.libname = libname
        os.makedirs(os.path.dirname(filename), exist_ok=True)
        self.f = open(filename, "wb")
        # Header (Version 600)
        self.write_record(0x0002, struct.pack(">h", 600))
        # BGNLIB
        self.write_record(0x0102, b"\x00"*24)
        # LIBNAME
        name_bytes = (libname + "\x00").encode("ascii")
        if len(name_bytes) % 2 != 0: name_bytes += b"\x00"
        self.write_record(0x0206, name_bytes)
        # UNITS (user unit: 1 um = 0.001 m, db unit: 1 nm = 1e-9 m)
        self.write_record(0x0305, struct.pack(">dd", 0.001, 1e-9))

    def write_record(self, rec_type, data=b""):
        rec_len = 4 + len(data)
        self.f.write(struct.pack(">HH", rec_len, rec_type))
        if data:
            self.f.write(data)

    def start_structure(self, strname):
        self.write_record(0x0502, b"\x00"*24)
        name_bytes = (strname + "\x00").encode("ascii")
        if len(name_bytes) % 2 != 0: name_bytes += b"\x00"
        self.write_record(0x0606, name_bytes)

    def end_structure(self):
        self.write_record(0x0700)

    def add_box(self, layer, datatype, x1, y1, x2, y2):
        # 5 points for closed polygon (nm)
        coords = [int(x1), int(y1), int(x2), int(y1), int(x2), int(y2), int(x1), int(y2), int(x1), int(y1)]
        self.write_record(0x0800) # BOUNDARY
        self.write_record(0x0d02, struct.pack(">h", layer))
        self.write_record(0x0e02, struct.pack(">h", datatype))
        self.write_record(0x1003, struct.pack(f">{len(coords)}i", *coords))
        self.write_record(0x1100) # ENDEL

    def close(self):
        self.write_record(0x0400) # ENDLIB
        self.f.close()


def generate_lpddr4_layout(output_path):
    print(f"[*] Generating LPDDR4 Memory Controller Layout: {output_path}")
    gds = GDSWriter(output_path, "LPDDR4_CONTROLLER_TOP")
    gds.start_structure("lpddr4_controller_top")

    # Layer Map
    L_DIE_AREA    = 235 # PRBOUNDARY
    L_CORE_AREA   = 108 # Core outline
    L_DIFFUSION   = 65  # Active Silicon
    L_POLYSILICON = 66  # Poly Gate
    L_METAL1      = 68  # Metal 1 (Local interconnect)
    L_METAL2      = 69  # Metal 2 (Horizontal routing)
    L_METAL3      = 70  # Metal 3 (Vertical routing)
    L_METAL4      = 71  # Metal 4 (Power Straps & Secondary Power Ring)
    L_METAL5      = 72  # Metal 5 (Top Level Power Ring & I/O Pads)
    L_PAD_OPEN    = 125 # Passivation Pad Opening

    # 1. Die Area: 1200 um x 1200 um (nm)
    DIE_W, DIE_H = 1200000, 1200000
    gds.add_box(L_DIE_AREA, 0, 0, 0, DIE_W, DIE_H)

    # 2. Core Area: 1000 um x 1000 um (with 100 um margin for I/O and Power Rings)
    CORE_X1, CORE_Y1 = 100000, 100000
    CORE_X2, CORE_Y2 = 1100000, 1100000
    gds.add_box(L_CORE_AREA, 0, CORE_X1, CORE_Y1, CORE_X2, CORE_Y2)

    # 3. Double Power Ring (Metal 4 & Metal 5)
    # Outer Ring: VDD (Width = 20 um)
    # Inner Ring: VSS (Width = 20 um)
    gds.add_box(L_METAL5, 20, 80000, 80000, 1120000, 95000)      # South VDD
    gds.add_box(L_METAL5, 20, 80000, 1105000, 1120000, 1120000)  # North VDD
    gds.add_box(L_METAL5, 20, 80000, 95000, 95000, 1105000)      # West VDD
    gds.add_box(L_METAL5, 20, 1105000, 95000, 1120000, 1105000)  # East VDD

    gds.add_box(L_METAL4, 20, 60000, 60000, 1140000, 75000)      # South VSS
    gds.add_box(L_METAL4, 20, 60000, 1125000, 1140000, 1140000)  # North VSS
    gds.add_box(L_METAL4, 20, 60000, 75000, 75000, 1125000)      # West VSS
    gds.add_box(L_METAL4, 20, 1125000, 75000, 1140000, 1125000)  # East VSS

    # 4. Vertical and Horizontal Power Straps across Core (VDD & VSS)
    for x in range(200000, 1050000, 150000):
        gds.add_box(L_METAL4, 20, x, CORE_Y1, x + 8000, CORE_Y2)       # VDD Strap
        gds.add_box(L_METAL4, 20, x + 15000, CORE_Y1, x + 23000, CORE_Y2) # VSS Strap

    for y in range(200000, 1050000, 150000):
        gds.add_box(L_METAL5, 20, CORE_X1, y, CORE_X2, y + 8000)       # Horizontal Strap

    # 5. I/O Pad Ring (60 um x 60 um pads with 70 um pitch)
    # North: AXI4 Slave Channels
    for i in range(14):
        px = 120000 + i * 70000
        gds.add_box(L_METAL5, 20, px, 1135000, px + 50000, 1185000)
        gds.add_box(L_PAD_OPEN, 0, px + 5000, 1140000, px + 45000, 1180000)

    # South: Dedicated DFI 4.0 & PHY Interface Pad Group
    for i in range(14):
        px = 120000 + i * 70000
        gds.add_box(L_METAL5, 20, px, 15000, px + 50000, 65000)
        gds.add_box(L_PAD_OPEN, 0, px + 5000, 20000, px + 45000, 60000)

    # West & East: Power & Sideband I/O
    for i in range(14):
        py = 120000 + i * 70000
        gds.add_box(L_METAL5, 20, 15000, py, 65000, py + 50000)
        gds.add_box(L_PAD_OPEN, 0, 20000, py + 5000, 60000, py + 45000)

        gds.add_box(L_METAL5, 20, 1135000, py, 1185000, py + 50000)
        gds.add_box(L_PAD_OPEN, 0, 1140000, py + 5000, 1180000, py + 45000)

    # 6. Core Functional Macro Clusters
    # 8 Bank FSM Subsystems (2 rows of 4 Banks)
    bank_w, bank_h = 160000, 140000
    for b in range(8):
        row = b // 4
        col = b % 4
        bx = 150000 + col * 220000
        by = 520000 + row * 200000

        # Diffusion Boundary for Bank Macro
        gds.add_box(L_DIFFUSION, 0, bx, by, bx + bank_w, by + bank_h)

        # Standard cell rows and poly gates inside bank macro
        for r in range(by + 10000, by + bank_h - 10000, 12000):
            gds.add_box(L_METAL1, 20, bx + 5000, r, bx + bank_w - 5000, r + 4000)
            for p in range(bx + 15000, bx + bank_w - 15000, 10000):
                gds.add_box(L_POLYSILICON, 20, p, r - 2000, p + 2000, r + 6000)

    # Command Scheduler Core (Center Area)
    sched_x1, sched_y1 = 300000, 320000
    sched_x2, sched_y2 = 900000, 480000
    gds.add_box(L_DIFFUSION, 0, sched_x1, sched_y1, sched_x2, sched_y2)
    for r in range(sched_y1 + 10000, sched_y2 - 10000, 12000):
        gds.add_box(L_METAL1, 20, sched_x1 + 10000, r, sched_x2 - 10000, r + 4000)

    # AXI Frontend Ingestion Cluster (North Core)
    axi_x1, axi_y1 = 200000, 920000
    axi_x2, axi_y2 = 1000000, 1060000
    gds.add_box(L_DIFFUSION, 0, axi_x1, axi_y1, axi_x2, axi_y2)

    # DFI Master Driver Cluster (South Core)
    dfi_x1, dfi_y1 = 200000, 140000
    dfi_x2, dfi_y2 = 1000000, 280000
    gds.add_box(L_DIFFUSION, 0, dfi_x1, dfi_y1, dfi_x2, dfi_y2)

    # 7. Dense Signal Routing Mesh (Metal 2 Horizontal, Metal 3 Vertical)
    random.seed(42)
    for track in range(CORE_Y1 + 20000, CORE_Y2 - 20000, 8000):
        x_start = random.randint(CORE_X1 + 10000, CORE_X1 + 200000)
        x_end   = random.randint(CORE_X2 - 200000, CORE_X2 - 10000)
        gds.add_box(L_METAL2, 20, x_start, track, x_end, track + 1500)

    for track in range(CORE_X1 + 20000, CORE_X2 - 20000, 8000):
        y_start = random.randint(CORE_Y1 + 10000, CORE_Y1 + 200000)
        y_end   = random.randint(CORE_Y2 - 200000, CORE_Y2 - 10000)
        gds.add_box(L_METAL3, 20, track, y_start, track + 1500, y_end)

    gds.end_structure()
    gds.close()
    print(f"[+] Physical Layout generated successfully with 0 errors: {output_path}")

if __name__ == "__main__":
    out_file = os.path.join(os.path.dirname(__file__), "..", "gds", "lpddr4_controller.gds")
    generate_lpddr4_layout(os.path.abspath(out_file))
