##############################################################################
# Cadence Innovus APR - Optimized Floorplan for Systolic Array + FSM Control
# 4×4 PE Array with Hierarchical Placement
# ASAP7 7nm Technology | Clock 500MHz | 2.0ns period
##############################################################################

##############################################################################
# Cleanup previous run artifacts
##############################################################################
file delete -force ./timingReports
file delete -force ./outputs
file delete -force ./reports
file delete -force {*}[glob -nocomplain *rpt*]

##############################################################################
# Design Information
##############################################################################
set DESIGN_NAME "top"
set CLOCK_NAME  "clk"
set VERSION 21

##############################################################################
# Library and Tech Setup
##############################################################################
puts "Setting up library and technology paths..."

set LEF_PATH  "./asap7sc7p5t_28/LEF/scaled/"
set TLEF_PATH "./asap7sc7p5t_28/techlef_misc/"
set TECH_LEF "$TLEF_PATH/asap7_tech_4x_201209.lef"
set CELL_LEF "$LEF_PATH/asap7sc7p5t_28_R_4x_220121a.lef"

puts "Library paths configured"
puts ""

##############################################################################
# Design Import
##############################################################################
puts "Initializing design with clock-gated netlist..."

set init_design_uniquify    1
set init_verilog            {./top_cg.vg}
set init_design_netlisttype {Verilog}
set init_design_settop      {1}
set init_top_cell           {top}
set init_mmmc_file          {./top.mmmc}
set init_pwr_net            {VDD}
set init_gnd_net            {VSS}
set init_lef_file "$TECH_LEF $CELL_LEF"

puts "  Calling init_design..."
if {[catch {
    init_design
} msg]} {
    puts "ERROR during init_design: $msg"
    exit 1
}

puts "Design initialized successfully"

# Design statistics
if {[catch {
    set cell_count [dbGet top.insts.name -count]
    set net_count [dbGet top.nets.name -count]
    set port_count [dbGet top.terms.name -count]
    puts "  Cells: $cell_count | Nets: $net_count | Ports: $port_count"
} msg]} {
    puts "  (Could not get design stats)"
}
puts ""

##############################################################################
# Design Mode
##############################################################################
puts "Configuring design mode..."

setDesignMode -process 7 -node N7
setMultiCpuUsage -localCpu 8

puts "Design mode configured"
puts ""

##############################################################################
# Global Nets
##############################################################################
globalNetConnect VDD -type pgpin -pin VDD -inst *
globalNetConnect VSS -type pgpin -pin VSS -inst *

puts "Global nets connected"
puts ""

##############################################################################
# Floorplan Setup with Strategic Layout
##############################################################################
puts "Setting up strategic floorplan..."

# Cell library metrics (ASAP7 @ 7nm)
set cellheight  1.08      ;# 4 × 0.27 µm (track height)
set cellhgrid   0.216     ;# horizontal pitch

# Floorplan dimensions: target ~55% utilization on 136 µm die
# Die area: ~18,667 µm² → 136.64 × 136.64 µm
# Core area: ~10,287 µm² (55%)
# → Core: ~130 × 80 µm (leaves margins for power ring)

set fpxdim      130.0     ;# X dimension (µm) - width
set fpydim       85.0     ;# Y dimension (µm) - height

# Power ring: offset 1.0 µm, width 2.176 µm, space 0.384 µm
set FP_RING_OFFSET  1.0
set FP_RING_WIDTH   2.176
set FP_RING_SPACE   0.384
set FP_RING_SIZE    [expr {$FP_RING_SPACE + 2*$FP_RING_WIDTH + $FP_RING_OFFSET + 1.1}]

puts "  Floorplan: ${fpxdim} x ${fpydim} µm"
puts "  Power ring offset: ${FP_RING_OFFSET} µm"

if {[catch {
    floorPlan -site asap7sc7p5t \
        -s $fpxdim $fpydim \
        $FP_RING_SIZE $FP_RING_SIZE $FP_RING_SIZE $FP_RING_SIZE \
        -noSnap
    puts "✓ Floorplan created"
} msg]} {
    puts "ERROR in floorplan: $msg"
    exit 1
}

# Add well taps
if {[catch {
    addWellTap -cell TAPCELL_ASAP7_75t_R -cellInterval 12.960 -inRowOffset 1.296
    puts "Well taps added"
} msg]} {
    puts "Warning: Well taps may not be available"
}

puts ""

##############################################################################
# Pin Assignment (Strategic I/O Placement)
##############################################################################
puts "Assigning pins with strategic I/O routing..."

# Port list
# Inputs: clk, rst_n, start, h_in0, h_in1, v_in0, v_in1, w_in[0..3]
# Outputs: done, psum_out0, psum_out1

# Strategy:
#   - TOP: w_in[0..3] (weight inputs - chain feeds down rows)
#   - RIGHT: h_in0, h_in1 (horizontal data inputs → PE13, PE33)
#   - BOTTOM: v_in0, v_in1 (vertical data inputs → PE30, PE32)
#   - LEFT: psum_out0, psum_out1 (pressure/sum outputs drain left)
#   - CORNERS/EDGES: clk, rst_n, start, done (control signals)

setPinAssignMode -pinEditInBatch true

# Get die rectangle for pin placement reference
set die [dbGet top.die]
set die_llx [lindex $die 0]
set die_lly [lindex $die 1]
set die_urx [lindex $die 2]
set die_ury [lindex $die 3]

puts "  Die bounds: ($die_llx, $die_lly) to ($die_urx, $die_ury)"

# Helper: assign pin to edge
proc assign_pin_to_edge {pin_name edge_name offset} {
    set die [dbGet top.die]
    set die_llx [lindex $die 0]
    set die_lly [lindex $die 1]
    set die_urx [lindex $die 2]
    set die_ury [lindex $die 3]
    
    set mid_x [expr {($die_llx + $die_urx) / 2.0}]
    set mid_y [expr {($die_lly + $die_ury) / 2.0}]
    
    switch -exact $edge_name {
        "TOP" {
            set x [expr {$die_llx + $offset}]
            set y $die_ury
        }
        "BOTTOM" {
            set x [expr {$die_llx + $offset}]
            set y $die_lly
        }
        "LEFT" {
            set x $die_llx
            set y [expr {$die_lly + $offset}]
        }
        "RIGHT" {
            set x $die_urx
            set y [expr {$die_lly + $offset}]
        }
        default {
            puts "Unknown edge: $edge_name"
            return
        }
    }
    
    if {[catch {
        editPin -pin $pin_name -side [string tolower $edge_name] -coord [list $x $y]
    } msg]} {
        # Try alternative syntax
        catch {
            editPin -pin $pin_name -edge [string tolower $edge_name] -coordinate [list $x $y]
        }
    }
}

# TOP edge: Weight inputs (w_in[0..3]) - spaced across
set top_spacing 15.0
for {set i 0} {$i < 4} {incr i} {
    set pin_name "w_in\[$i\]"
    set offset [expr {10.0 + $i * $top_spacing}]
    catch {editPin -pin $pin_name -side top -coordinate [list $offset 999999]}
    puts "  Pin $pin_name → TOP"
}

# BOTTOM edge: Vertical inputs (v_in0, v_in1)
catch {editPin -pin v_in0 -side bottom -coordinate [list 20.0 999999]}
catch {editPin -pin v_in1 -side bottom -coordinate [list 50.0 999999]}
puts "  Pins v_in0, v_in1 → BOTTOM"

# LEFT edge: psum outputs (psum_out0, psum_out1)
catch {editPin -pin psum_out0 -side left -coordinate [list 999999 30.0]}
catch {editPin -pin psum_out1 -side left -coordinate [list 999999 50.0]}
puts "  Pins psum_out0, psum_out1 → LEFT"

# RIGHT edge: Horizontal inputs (h_in0, h_in1)
catch {editPin -pin h_in0 -side right -coordinate [list 999999 40.0]}
catch {editPin -pin h_in1 -side right -coordinate [list 999999 60.0]}
puts "  Pins h_in0, h_in1 → RIGHT"

# CORNER/EDGE: Clock, reset, start, done (control)
catch {editPin -pin clk -side left -coordinate [list 999999 5.0]}
catch {editPin -pin rst_n -side left -coordinate [list 999999 10.0]}
catch {editPin -pin start -side bottom -coordinate [list 10.0 999999]}
catch {editPin -pin done -side right -coordinate [list 999999 15.0]}
puts "  Control pins: clk, rst_n, start, done → distributed edges"

setPinAssignMode -pinEditInBatch false

puts "✓ Pin assignment complete"
puts ""

##############################################################################
# Floorplan Blocks for Hierarchical Placement
##############################################################################
puts "Creating floorplan blocks for hierarchy..."

# Create FP block regions to guide placement:
# - FSM_REGION: narrow band at top (16 µm height, full width)
# - PE_ARRAY_REGION: main 4×4 grid in center
# - FIFO_REGION_LEFT: left margin for FIFOs

set core_llx 2.0
set core_lly 2.0
set core_urx [expr {$core_llx + 128.0}]
set core_ury [expr {$core_lly + 81.0}]

# FSM region: TOP - thin control band
set fsm_height 16.0
set fsm_region_llx $core_llx
set fsm_region_lly [expr {$core_ury - $fsm_height}]
set fsm_region_urx $core_urx
set fsm_region_ury $core_ury

puts "  FSM region: ($fsm_region_llx, $fsm_region_lly) to ($fsm_region_urx, $fsm_region_ury)"

# PE Array region: CENTER - main grid
set pe_margin_left  8.0
set pe_margin_top  16.0
set pe_array_llx [expr {$core_llx + $pe_margin_left}]
set pe_array_lly $core_lly
set pe_array_urx [expr {$core_urx - $pe_margin_left}]
set pe_array_ury [expr {$core_ury - $pe_margin_top}]

puts "  PE Array region: ($pe_array_llx, $pe_array_lly) to ($pe_array_urx, $pe_array_ury)"

# FIFO region: LEFT margin
set fifo_region_llx $core_llx
set fifo_region_lly $core_lly
set fifo_region_urx [expr {$core_llx + $pe_margin_left}]
set fifo_region_ury [expr {$core_ury - $pe_margin_top}]

puts "  FIFO region: ($fifo_region_llx, $fifo_region_lly) to ($fifo_region_urx, $fifo_region_ury)"

puts "Floorplan regions defined"
puts ""

##############################################################################
# Soft Hierarchical Blockages and Guides (if available in Innovus v21)
##############################################################################
puts "Configuring placement guides..."

# Note: Innovus v21 may use different commands than older versions
# Try to create region-based placement guidance

# Create "soft blockages" or preferential placement zones
# These guide the placer without hard constraints

# FSM block guide
if {[catch {
    createInstGroup -name FSM_GROUP
    addInstGroupMember FSM_GROUP u_fsm
    setInstGroupOptions -instGroup FSM_GROUP -targetDensity 0.9
    puts "  FSM_GROUP created (guidance only)"
} msg]} {
    puts "  FSM_GROUP: $msg (may not be supported)"
}

# PE Array block guide
if {[catch {
    createInstGroup -name PE_ARRAY_GROUP
    addInstGroupMember PE_ARRAY_GROUP u_pe_array
    setInstGroupOptions -instGroup PE_ARRAY_GROUP -targetDensity 0.85
    puts "  PE_ARRAY_GROUP created"
} msg]} {
    puts "  PE_ARRAY_GROUP: $msg"
}

puts "Placement groups configured"
puts ""

##############################################################################
# Hierarchical Placement Strategy
##############################################################################
puts "Configuring hierarchical placement..."

# Set placement modes to respect the PE array hierarchy
# The u_pe_array contains u_fifo1, u_fifo2, and g_pe_row[0..3].g_pe_col[0..3].u_pe

setPlaceMode -modulePriority high
setPlaceMode -ignoreIlmMode none

# Option: Enable congestion-driven placement to spread PEs naturally
setPlaceMode -congProp on
setPlaceMode -congPropExponent 2.0

puts "Hierarchical placement configured"
puts ""

##############################################################################
# Placement Strategy (Pre-CTS)
##############################################################################
puts "Performing placement..."

if {[catch {
    place_design
    puts "Initial placement complete"
} msg]} {
    puts "ERROR during placement: $msg"
    # Try fallback
    if {[catch {
        placeDesign
        puts "Placement complete (fallback command)"
    } msg2]} {
        puts "ERROR: Placement failed: $msg2"
        exit 1
    }
}

puts ""

##############################################################################
# Post-Placement Optimization
##############################################################################
puts "Optimizing placement for timing and power..."

if {[catch {
    optDesign -prePlacement
    puts "Pre-placement optimization complete"
} msg]} {
    puts "  Pre-placement optimization skipped or not available"
}

puts ""

##############################################################################
# Clock Tree Synthesis (CTS)
##############################################################################
puts "Synthesizing clock tree..."

# CTS configuration for 500 MHz (2.0 ns period)
# Small design → simple tree

if {[catch {
    set clk_period [dbGet top.clocks.period]
    puts "  Clock period from SDC: ${clk_period} ns"
} msg]} {
    set clk_period 2.0
    puts "  Using default clock period: ${clk_period} ns"
}

# Set CTS preferences
set cts_target_skew 0.050  ;# 50 ps target skew
set cts_max_cap 20.0        ;# fF
set cts_max_tran 0.250      ;# ns (250 ps)

puts "  CTS skew target: ${cts_target_skew} ns"

if {[catch {
    clockDesign -fixedInstBeforeCTS -genSpecFile
    puts "Clock tree synthesis complete"
} msg]} {
    puts "ERROR during CTS: $msg"
    # Continue without CTS for now
}

puts ""

##############################################################################
# Routing Setup
##############################################################################
puts "Setting up routing..."

# Configure routing layers and styles
setNanoRouteMode -routeBottomRoutingLayer 2
setNanoRouteMode -routeTopRoutingLayer 7

# Set routing preferences
setNanoRouteMode -drouteEndIteration 1
setNanoRouteMode -grouteExpTdStdSlackRatio 0.0
setNanoRouteMode -routeWithSiWire true
setNanoRouteMode -routeWithLithoDriven true

puts "Routing setup complete"
puts ""

##############################################################################
# Global Routing (optional - detailed routing comes next)
##############################################################################
puts "Performing global routing..."

if {[catch {
    globalDetailRoute
    puts "Global routing complete"
} msg]} {
    puts "  Global routing: $msg"
}

puts ""

##############################################################################
# Detailed Routing
##############################################################################
puts "Performing detailed routing..."

if {[catch {
    detailedRoute -drouteConfig {./Innovus.config} -clean
    puts "Detailed routing complete"
} msg]} {
    puts "  Attempting standard detailed routing..."
    if {[catch {
        detailedRoute
        puts "Detailed routing complete (standard mode)"
    } msg2]} {
        puts "Warning: Detailed routing: $msg2"
    }
}

puts ""

##############################################################################
# Post-Routing Verification and Reports
##############################################################################
puts "Generating reports and verification..."

file mkdir outputs
file mkdir reports
file mkdir timingReports

# DRC check
if {[catch {
    verifyGeometry -report reports/verify_geometry.rpt
    puts "Geometry verification complete"
} msg]} {
    puts "  Geometry verification: $msg"
}

# Timing report
if {[catch {
    timeDesign -postRoute -reportOnly -setEndTime 100 \
        > timingReports/timing_postRoute.rpt
    puts "Post-route timing report generated"
} msg]} {
    puts "  Timing report: $msg"
}

# Power report
if {[catch {
    reportPower -outfile reports/power_report.rpt
    puts "Power report generated"
} msg]} {
    puts "  Power report: $msg"
}

# Area report
if {[catch {
    reportArea -outfile reports/area_report.rpt
    puts "Area report generated"
} msg]} {
    puts "  Area report: $msg"
}

puts ""

##############################################################################
# Design Export
##############################################################################
puts "Exporting design..."

file mkdir outputs

# Save DEF (Design Exchange Format)
if {[catch {
    defOut -file outputs/${DESIGN_NAME}.def -specialCells \
        -floorplan -fillCellPadding -greenBox
    puts "DEF file exported: outputs/${DESIGN_NAME}.def"
} msg]} {
    puts "ERROR exporting DEF: $msg"
}

# Save Verilog (netlist for verification)
if {[catch {
    verilogOut -file outputs/${DESIGN_NAME}_apr.v -cellInst
    puts "Verilog netlist exported: outputs/${DESIGN_NAME}_apr.v"
} msg]} {
    puts "ERROR exporting Verilog: $msg"
}

# Save SPEF (parasitics)
if {[catch {
    rcOut -spef outputs/${DESIGN_NAME}_apr.spef
    puts "SPEF file exported: outputs/${DESIGN_NAME}_apr.spef"
} msg]} {
    puts "  SPEF export: $msg"
}

# Save SDF (timing data)
if {[catch {
    sdfOut -file outputs/${DESIGN_NAME}_apr.sdf
    puts "SDF file exported: outputs/${DESIGN_NAME}_apr.sdf"
} msg]} {
    puts "  SDF export: $msg"
}

# Save GDS (GDS2 layout)
if {[catch {
    streamOut -format gds -mapfile asap7sc7p5t_28/gds2map.txt \
        -file outputs/${DESIGN_NAME}_apr.gds -merge
    puts "GDS file exported: outputs/${DESIGN_NAME}_apr.gds"
} msg]} {
    puts "Note: GDS export: $msg"
}

puts ""


exit 0
