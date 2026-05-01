#!/bin/bash
# APR Quick-Start Guide
# Systolic Array Place & Route on ASAP7 (7 nm)

##############################################################################
# STEP 0: Pre-flight Checks
##############################################################################

echo "=== APR Quick-Start: Pre-flight Checks ==="
echo ""

# Check if required files exist
REQUIRED_FILES=(
    "top_cg.vg"
    "top.mmmc"
    "top_cg.sdc"
    "asap7sc7p5t_28/LEF/scaled/asap7sc7p5t_28_R_4x_220121a.lef"
    "asap7sc7p5t_28/techlef_misc/asap7_tech_4x_201209.lef"
)

MISSING=0
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ MISSING: $file"
        MISSING=$((MISSING + 1))
    else
        echo "✓ Found: $file"
    fi
done

if [ $MISSING -gt 0 ]; then
    echo ""
    echo "ERROR: $MISSING required files are missing!"
    echo "Please ensure all synthesis outputs and libraries are in the APR directory."
    exit 1
fi

echo ""
echo "✓ All required files present!"
echo ""

##############################################################################
# STEP 1: Verify Innovus Installation
##############################################################################

echo "=== Checking Innovus Installation ==="

if command -v innovus &> /dev/null; then
    INNOVUS_VERSION=$(innovus -version 2>&1 | head -1)
    echo "✓ Innovus found: $INNOVUS_VERSION"
else
    echo "❌ Innovus not in PATH!"
    echo "   Please load the Cadence environment:"
    echo "   source /path/to/cadence/setup.csh"
    exit 1
fi

echo ""

##############################################################################
# STEP 2: Create Backup
##############################################################################

echo "=== Creating Backup of Previous Run ==="

if [ -d "outputs" ] || [ -d "reports" ]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_DIR="backup_$TIMESTAMP"
    mkdir -p "$BACKUP_DIR"
    
    [ -d "outputs" ] && mv outputs "$BACKUP_DIR/" && echo "  Backed up: outputs"
    [ -d "reports" ] && mv reports "$BACKUP_DIR/" && echo "  Backed up: reports"
    [ -d "timingReports" ] && mv timingReports "$BACKUP_DIR/" && echo "  Backed up: timingReports"
    
    echo "  Backup saved to: $BACKUP_DIR"
fi

echo ""

##############################################################################
# STEP 3: Run APR Flow
##############################################################################

echo "=== Starting APR Flow ==="
echo ""
echo "  Design: top (4x4 Systolic Array + FSM)"
echo "  Technology: ASAP7 (7 nm)"
echo "  Target: 500 MHz (2.0 ns period)"
echo "  Strategy: Optimized floorplan with grid PE array + FSM band"
echo ""
echo "  Log file: apr_optimized_floorplan.log"
echo ""

# Run Innovus with the optimized floorplan script
innovus -64 -execute apr_optimized_floorplan.tcl -logFile apr_optimized_floorplan.log 2>&1

INNOVUS_EXIT=$?

echo ""
echo "=== APR Flow Completed ==="
echo ""

if [ $INNOVUS_EXIT -eq 0 ]; then
    echo "✓ Innovus exited successfully"
else
    echo "❌ Innovus exited with code $INNOVUS_EXIT"
    echo ""
    echo "   Check log file: tail apr_optimized_floorplan.log"
    echo "   or:"
    echo "   tail -100 apr_optimized_floorplan.log | grep -i error"
fi

echo ""

##############################################################################
# STEP 4: Verify Output Files
##############################################################################

echo "=== Verifying Output Files ==="

OUTPUT_FILES=(
    "outputs/top.def"
    "outputs/top_apr.v"
    "outputs/top_apr.spef"
    "outputs/top_apr.sdf"
    "outputs/top_apr.gds"
    "reports/verify_geometry.rpt"
    "reports/power_report.rpt"
    "reports/area_report.rpt"
    "timingReports/timing_postRoute.rpt"
)

MISSING_OUT=0
for file in "${OUTPUT_FILES[@]}"; do
    if [ -f "$file" ]; then
        SIZE=$(du -h "$file" | cut -f1)
        echo "✓ $file ($SIZE)"
    else
        echo "⚠ MISSING: $file"
        MISSING_OUT=$((MISSING_OUT + 1))
    fi
done

echo ""

##############################################################################
# STEP 5: Print Summary
##############################################################################

echo "=== APR Summary ==="
echo ""

if [ -f "reports/area_report.rpt" ]; then
    echo "Area Report Excerpt:"
    grep -A 5 "Total Area" reports/area_report.rpt | head -6
    echo ""
fi

if [ -f "reports/power_report.rpt" ]; then
    echo "Power Report Excerpt:"
    grep -A 3 "Total Power" reports/power_report.rpt | head -4
    echo ""
fi

if [ -f "timingReports/timing_postRoute.rpt" ]; then
    echo "Timing Summary:"
    echo "  Critical path slack:"
    grep "slack" timingReports/timing_postRoute.rpt | head -1
    echo ""
fi

##############################################################################
# STEP 6: Next Steps
##############################################################################

echo "=== Next Steps ==="
echo ""
echo "1. View DEF layout:"
echo "   $ innovus -nowin -execute 'read_def outputs/top.def; fit_image; gui_show all' &"
echo ""
echo "2. Check timing in detail:"
echo "   $ grep -E 'slack|violation|error' timingReports/timing_postRoute.rpt"
echo ""
echo "3. Analyze power breakdown:"
echo "   $ cat reports/power_report.rpt"
echo ""
echo "4. View GDS with Calibre:"
echo "   $ calibredrv outputs/top_apr.gds &"
echo ""
echo "5. Post-layout timing verification (PT):"
echo "   $ cd ../PT"
echo "   $ pt_shell -f pt_script.tcl"
echo ""
echo "6. Check design rules (Calibre DRC):"
echo "   $ calibre -hier -drc top.drc outputs/top_apr.gds"
echo ""
echo "=== APR Complete ==="
echo ""

exit 0
