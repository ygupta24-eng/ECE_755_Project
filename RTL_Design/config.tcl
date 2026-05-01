# ============================================================
# config.tcl — Sky130 / OpenLane 2 config for zigzag accelerator
#
# EDIT ONLY CLK_PERIOD_NS if you see timing violations.
# All other timing constraints live in dnn.sdc.
# ============================================================

# ---------- Design ----------
set ::env(DESIGN_NAME) "top"

set ::env(VERILOG_FILES) [list \
    "$::env(DESIGN_DIR)/top.sv"       \
    "$::env(DESIGN_DIR)/zigzag.sv"    \
    "$::env(DESIGN_DIR)/control.sv"   \
    "$::env(DESIGN_DIR)/pe_update.sv" \
    "$::env(DESIGN_DIR)/fifo9.sv"     \
]

# SystemVerilog — tell Yosys to use read_verilog -sv
set ::env(SYNTH_READ_BLACKBOX_LIB) 0

# ---------- Clock (EDIT ONLY HERE) ----------
# Sky130 is ~3-5x slower than ASAP7. Start at 16 ns; relax if violated.
set CLK_PERIOD_NS 16.0

set ::env(CLOCK_PORT)   "clk"
set ::env(CLOCK_PERIOD) $CLK_PERIOD_NS

# ---------- Constraints ----------
set ::env(SDC_FILE) "$::env(DESIGN_DIR)/dnn.sdc"

# ---------- Synthesis ----------
# Yosys: allow SystemVerilog constructs (always_ff, always_comb, logic, etc.)
set ::env(SYNTH_TOOL)          "yosys"
set ::env(SYNTH_STRATEGY)      "AREA 0"
set ::env(SYNTH_MAX_FANOUT)    128
# Do NOT use SYNTH_ELABORATE_ONLY — we need full synthesis

# ---------- Floorplan ----------
# Let OpenLane auto-size; adjust if routing congestion is high
set ::env(FP_SIZING)           "relative"
set ::env(FP_CORE_UTIL)        50
set ::env(FP_ASPECT_RATIO)     1

# ---------- Placement ----------
set ::env(PL_TARGET_DENSITY)   0.55

# ---------- CTS ----------
# OpenLane inserts ICG cells automatically from clock-enable signals.
# Do NOT manually gate clocks in RTL — all gating must go through ICG here.
set ::env(CLOCK_TREE_SYNTH)    1

# ---------- Routing ----------
set ::env(ROUTING_CORES)       8

# ---------- PDK ----------
set ::env(PDK)                 "sky130A"
set ::env(STD_CELL_LIBRARY)    "sky130_fd_sc_hd"
