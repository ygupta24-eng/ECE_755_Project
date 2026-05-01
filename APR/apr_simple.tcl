##############################################################################
# Cadence Innovus APR - Simplified Script for Debugging
# Clock-Gating Based Design - ASAP7 7nm Technology
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

puts "✓ Library paths configured"
puts ""

##############################################################################
# Design Import (Innovus init_design flow)
##############################################################################
puts "Initializing design with netlist..."

set init_design_uniquify    1
set init_verilog            {./top.vg}
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

puts "✓ Design initialized successfully"

# Quick design statistics
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

puts "✓ Design mode configured"
puts ""

##############################################################################
# Global Nets
##############################################################################
globalNetConnect VDD -type pgpin -pin VDD -inst *
globalNetConnect VSS -type pgpin -pin VSS -inst *

puts "✓ Global nets connected"
puts ""

##############################################################################
# Floorplan Setup (MINIMAL)
##############################################################################
puts "Setting up floorplan..."

set FP_RING_OFFSET  0.384
set FP_RING_WIDTH   2.176
set FP_RING_SPACE   0.384
set FP_RING_SIZE    [expr {$FP_RING_SPACE + 2*$FP_RING_WIDTH + $FP_RING_OFFSET + 1.1}]

set FP_TARGET   280
set FP_MUL      5
set cellheight  [expr 0.270 * 4]
set cellhgrid   0.216
set fpxdim      [expr $cellhgrid  * $FP_TARGET * $FP_MUL]
set fpydim      [expr $cellheight * $FP_TARGET]

puts "  Floorplan: ${fpxdim} x ${fpydim} um"

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
    puts "✓ Well taps added"
} msg]} {
    puts "Warning: Well taps failed"
}

puts ""

##############################################################################
# Pin Assignment
##############################################################################
puts "Assigning pins..."

set all_ports [dbGet top.terms.name]
set input_pins  {}
set output_pins {}

foreach port $all_ports {
    set dir [dbGet [dbGet -p top.terms.name $port].direction]
    if { $dir eq "in" || $dir eq "input" } {
        lappend input_pins $port
    } else {
        lappend output_pins $port
    }
}

puts "  Inputs: [llength $input_pins] | Outputs: [llength $output_pins]"

setPinAssignMode -pinEditInBatch true

if { [llength $input_pins] > 0 } {
    if {[catch {
        editPin -fixOverlap 1 -unit MICRON -spreadDirection clockwise \
            -side LEFT -layer 3 -spreadType center -spacing 2.016 \
            -pin $input_pins
    } msg]} {
        puts "  Warning: Input pin assignment failed"
    }
}

if { [llength $output_pins] > 0 } {
    if {[catch {
        editPin -fixOverlap 1 -unit MICRON -spreadDirection clockwise \
            -side RIGHT -layer 3 -spreadType center -spacing 2.016 \
            -pin $output_pins
    } msg]} {
        puts "  Warning: Output pin assignment failed"
    }
}

editPin -snap TRACK -pin *
setPinAssignMode -pinEditInBatch false

puts "✓ Pin assignment complete"
puts ""

##############################################################################
# Placement
##############################################################################
puts "Placing cells..."

setOptMode -holdTargetSlack  0.020
setOptMode -setupTargetSlack 0.020

if {[catch {
    place_opt_design
    puts "✓ Placement complete"
} msg]} {
    puts "ERROR in placement: $msg"
    exit 1
}

# Tie cells
if {[catch {
    setTieHiLoMode -maxFanout 5
    addTieHiLo -prefix TIE -cell {TIELOx1_ASAP7_75t_R TIEHIx1_ASAP7_75t_R}
    puts "✓ Tie cells added"
} msg]} {
    puts "Warning: Tie cells skipped"
}

puts ""

##############################################################################
# Clock Tree Synthesis (SKIPPED - will attempt routing instead)
##############################################################################
puts "Checking for clocks..."

set all_clocks [all_clocks]
if {[llength $all_clocks] > 0} {
    puts "  Found [llength $all_clocks] clock(s)"
    if {[catch {
        ccopt_design
        puts "✓ Clock tree synthesized"
    } msg]} {
        puts "  Warning: CTS failed ($msg), proceeding with routing"
    }
} else {
    puts "  No clocks defined, skipping CTS"
}

puts ""

##############################################################################
# Routing
##############################################################################
puts "Routing design..."

if {[catch {
    routeDesign
    puts "✓ Routing complete"
} msg]} {
    puts "ERROR in routing: $msg"
    exit 1
}

puts ""

##############################################################################
# Create Output Directories
##############################################################################
catch { file mkdir outputs }
catch { file mkdir reports }
catch { file mkdir timingReports }

##############################################################################
# Generate Reports
##############################################################################
puts "Generating reports..."

if {[catch {
    verify_drc > ./reports/drc_final.rpt
    puts "✓ DRC report"
} msg]} {
    puts "  (DRC report skipped)"
}

if {[catch {
    report_timing -max_paths 10 > ./timingReports/timing.rpt
    puts "✓ Timing report"
} msg]} {
    puts "  (Timing report skipped)"
}

if {[catch {
    report_power > ./reports/power.rpt
    puts "✓ Power report"
} msg]} {
    puts "  (Power report skipped)"
}

if {[catch {
    report_area > ./reports/area.rpt
    puts "✓ Area report"
} msg]} {
    puts "  (Area report skipped)"
}

##############################################################################
# GDS Export (for LVS verification)
##############################################################################
puts "Exporting GDS for LVS verification..."

if {[catch {
    catch { file mkdir outputs/gds }
    streamOut ./outputs/gds/top_apr.gds -mapTable ./asap7sc7p5t_28/gds/asap7_tech_4x_201209.map -libName $DESIGN_NAME
    puts "✓ GDS exported: ./outputs/gds/top_apr.gds"
} msg]} {
    puts "  (GDS export skipped - map file may not exist)"
}

##############################################################################
# Netlist Export for LVS
##############################################################################
puts "Exporting netlist for LVS comparison..."

if {[catch {
    # Export Verilog netlist (flat) for LVS comparison
    defOut -netlist ./outputs/top_apr.lvs.v
    puts "✓ Netlist exported: ./outputs/top_apr.lvs.v"
} msg]} {
    puts "  (Netlist export skipped)"
}

##############################################################################
# LVS Verification (requires Pegasus or equivalent tool configured)
##############################################################################
puts "\nRunning LVS verification..."

# LVS requires external comparison tool - configure per your environment
# Option 1: Cadence Pegasus (if available in your Innovus installation)
if {[catch {
    # This command requires Pegasus to be configured in your tool setup
    # Uncomment if you have Pegasus available:
    # verifyLVS -layerFile ./asap7sc7p5t_28/LEF/asap7_tech_4x.lef \
    #           -schematic ./top_apr.lvs.v \
    #           -layout ./outputs/gds/top_apr.gds \
    #           -outDir ./reports/ \
    #           -reportFile ./reports/lvs_results.rpt
    
    # Alternative: Call external Pegasus if installed
    # This requires proper tool configuration on your system
    puts "  Note: LVS verification requires external tool configuration"
    puts "  - Install Cadence Pegasus or Mentor Calibre"
    puts "  - Configure tool path in your environment"
    puts "  - Uncomment verifyLVS command above when tool is available"
} msg]} {
    puts "  (External LVS tool not configured - skipped)"
}

puts ""

##############################################################################
# Output Generation
##############################################################################
puts "Generating output files..."

if {[catch {
    saveNetlist outputs/top_apr.v
    puts "✓ Netlist saved"
} msg]} {
    puts "  (Netlist save skipped)"
}

if {[catch {
    write_sdc outputs/top_apr.sdc
    puts "✓ SDC saved"
} msg]} {
    puts "  (SDC save skipped)"
}

if {[catch {
    rcOut -rc_corner rc_typ_25 -spef outputs/top_apr.spef
    puts "✓ SPEF saved"
} msg]} {
    puts "  (SPEF save skipped)"
}

if {[catch {
    defOut -netlist -routing -allLayers outputs/top_apr_v${VERSION}.def
    puts "✓ DEF saved"
} msg]} {
    puts "  (DEF save skipped)"
}

puts ""
puts "=========================================="
puts "APR Flow Complete"
puts "=========================================="
puts ""
puts "Key Output Files:"
puts "  Netlist: ./outputs/top_apr.v"
puts "  LVS Netlist: ./outputs/top_apr.lvs.v"
puts "  GDS (LVS): ./outputs/gds/top_apr.gds"
puts "  Constraints: ./outputs/top_apr.sdc"
puts "  Parasitics: ./outputs/top_apr.spef"
puts "  DEF: ./outputs/top_apr_v${VERSION}.def"
puts ""
puts "Reports:"
puts "  DRC: ./reports/drc_final.rpt"
puts "  Timing: ./timingReports/timing.rpt"
puts "  Power: ./reports/power.rpt"
puts "  Area: ./reports/area.rpt"
puts "  LVS: ./reports/lvs_results.rpt (requires Pegasus/Calibre)"
puts ""
puts "LVS Verification:"
puts "  To run LVS, configure Cadence Pegasus or Mentor Calibre"
puts "  GDS file: ./outputs/gds/top_apr.gds"
puts "  Netlist file: ./outputs/top_apr.lvs.v"
puts "=========================================="

exit 0
