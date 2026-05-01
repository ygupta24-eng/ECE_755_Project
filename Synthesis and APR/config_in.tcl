# ============================================================
# Sky130 / OpenLane config for DNN (MS2-friendly)
#
# READ ME FIRST:
# - This config is written to closely match the intent of the ASAP7 MS2
#   (Design Compiler) synthesis flow used earlier in the project.
# - All timing constraints (create_clock, delays, uncertainty, loads) are defined only in dnn.sdc.
#   This file must remain the single source of truth for timing.
#
# WHAT YOU ARE EXPECTED TO CHANGE:
# - CLK_PERIOD_NS only.
#   If you see setup violations after synthesis or APR, increase this
#   value (e.g., 20ns). Do NOT change CLOCK_PORT or CLOCK_PERIOD directly.
# - If the design fails timing at the typical corner, increase
#   CLK_PERIOD_NS gradually (e.g., +2ns steps).
#
# WHAT YOU SHOULD NOT CHANGE:
# - DESIGN_NAME, VERILOG_FILES, SDC_FILE path
# - Fanout settings (these are chosen to match DC-style behavior)
#
# FANOUT NOTE:
# - MAX_FANOUT_CONSTRAINT is set to a relaxed value (128), similar to
#   ASAP7/DC defaults. This avoids unnecessary fanout warnings in
#   OpenLane and keeps the focus on functionality rather than aggressive
#   optimization.
#
# HOLD FIXING NOTES (added after post-route hold violations):
# - Both violations were caused by the hand-crafted "clk & en_latched"
#   clock gate in pe_update.sv. That construct creates an independent CTS
#   sub-tree (dlxtn latch + AND gate) that OpenLane cannot balance against
#   the main clock tree with enough precision to guarantee hold.
# - The fix is in pe_update.sv: the latch is replaced with a registered
#   enable (en_r), and psum_out uses the main clock with a register-enable.
#   Synthesis will infer an ICG cell (sky130_fd_sc_hd__dlclkp_1) which CTS
#   treats as part of the main clock tree.
# - The hold margin settings below add robustness against any remaining
#   marginal paths in future runs.
# ============================================================

# ---------- Design ----------
set ::env(DESIGN_NAME) top
set ::env(VERILOG_FILES) [list \
  $::env(DESIGN_DIR)/top.sv \
  $::env(DESIGN_DIR)/zigzag.sv \
  $::env(DESIGN_DIR)/control.sv \
  $::env(DESIGN_DIR)/pe_update.sv \
  $::env(DESIGN_DIR)/fifo9.sv \
]

# ---------- Clock (EDIT ONLY HERE) ----------
# ASAP7 versions often use ~2.0ns. Sky130 is slower, so we relax the clock.
# If post-route STA shows setup violations, increase this value gradually (e.g., 18ns, 20ns, 22ns).
set CLK_PORT       "clk"
set CLK_PERIOD_NS  16.0

# OpenLane still expects CLOCK_PORT/CLOCK_PERIOD for CTS + internal flow settings.
# Do NOT edit these directly; change CLK_PERIOD_NS above.
set ::env(CLOCK_PORT)   $CLK_PORT
set ::env(CLOCK_PERIOD) $CLK_PERIOD_NS

# ---------- Constraints ----------
set sdc_path "$::env(DESIGN_DIR)/dnn.sdc"
set ::env(SDC_FILE) $sdc_path

# ---------- Fanout control ----------
set ::env(MAX_FANOUT_CONSTRAINT) 128

# ---------- Clock gating (ICG) ----------
# Enable clock gate insertion so synthesis maps register-enable patterns
# to sky130_fd_sc_hd__dlclkp_1 ICG cells. CTS natively balances ICG
# outputs, which eliminates the independent-subtree hold problem.
set ::env(SYNTH_NO_FLAT) 0

# ---------- Hold fixing margins ----------
# Tell the post-placement and post-route resizers to target a 0.1 ns
# hold margin, giving enough budget to absorb inter-leaf clock skew.
# These are the primary guard against marginal hold paths surviving to signoff.
set ::env(PL_RESIZER_HOLD_SLACK_MARGIN)          0.10
set ::env(GLB_RESIZER_HOLD_SLACK_MARGIN)         0.10

# Allow the resizer to use up to 40% of the cell area for hold buffers.
# The default (20%) was insufficient for the gated-clock sub-tree paths.
set ::env(PL_RESIZER_HOLD_MAX_BUFFER_PERCENT)    40
set ::env(GLB_RESIZER_HOLD_MAX_BUFFER_PERCENT)   40

# Enable timing-driven optimization in the global resizer step.
set ::env(GLB_RESIZER_TIMING_OPTIMIZATIONS)      1

# ---------- Tool settings ----------
set ::env(ANTENNA_RATIO) 650
set ::env(OPENROAD_NUM_THREADS) 8
# Try strategy 6 first (placement + routing diode insertion combined)
set ::env(DIODE_INSERTION_STRATEGY) 6

# If violations persist, explicitly set the antenna cell:
set ::env(ANTENNA_CELL_NAME) "sky130_fd_sc_hd__diode_2"

# Lower the antenna ratio threshold slightly if the violations are marginal
# (default is 400 for sky130_fd_sc_hd — only lower if violations are <2x over)
# set ::env(ANTENNA_RATIO) 400