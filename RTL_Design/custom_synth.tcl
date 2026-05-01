# ============================================================
# Custom Yosys Synthesis Script for SystemVerilog Design
# Sky130 / OpenLane
#
# This script reads SystemVerilog files (-sv flag) instead of
# Verilog-2005, which is required for logic types and packed arrays.
# ============================================================

set ::num_procs [expr {$::env(OPENROAD_NUM_THREADS) > 4 ? 4 : $::env(OPENROAD_NUM_THREADS)}]

# Read all Verilog/SystemVerilog files with SystemVerilog support (-sv flag)
foreach file $::env(VERILOG_FILES) {
    read_verilog -sv "$file"
}

# Handle any black box libraries
if {[info exists ::env(SYNTH_READ_BLACKBOX_LIB)] && $::env(SYNTH_READ_BLACKBOX_LIB)} {
    if {[file exists $::env(LIB_SYNTH)] && $::env(LIB_SYNTH) ne ""} {
        read_liberty -lib $::env(LIB_SYNTH)
    }
}

# Elaborate with auto-top detection
hierarchy -check -auto-top

# Optimization passes
synth -flatten -abc9 -nobram -nodffe -nosrl -noshare -json $::env(SYNTHESIS_REPORTS)/synth.json

# Prepare for technology mapping
stat

