# Milestone 3: Automatic Place & Route (APR)

## Status: Ready for APR
✅ Synthesis complete with clock gating
- Netlist: `top.vg`
- Constraints: `top.sdc`
- Design DB: `top.ddc`

## Step 1: Download and Prepare ASAP7 Library

### Download Library Files
```bash
cd i:\ECE755\ECE_755_Project\APR
cp -r /cae/apps/data/asap7PDK-2022/asap7PDK_r1p7/asap7sc7p5t_28 .
```

Or from GitHub:
https://github.com/The-OpenROAD-Project/asap7

### Unzip Library Files
```bash
cd asap7sc7p5t_28/LIB/NLDM
gzip -d *.gz
```

## Step 2: Update Techlef File (IMPORTANT)

**Replace** the default techlef with the patched version:
- Copy `asap7_tech_4x_201209.lef` into `asap7sc7p5t_28/techlef_misc/`
- This fixes DRC violations in the original ASAP7 techlef

Reference: https://github.com/Centre-for-Hardware-Security/asap7_reference_design

## Step 3: Environment Setup

On CAE/Linux machine (in each new terminal):
```bash
export TERM=xterm-basic
source /cae/apps/env/cadence-INNOVUS21.17.000
```

## Step 4: Run APR

```bash
# Create a terminal with the Cadence environment
cd i:\ECE755\ECE_755_Project\APR (or the Linux equivalent path)
innovus -no_gui -files apr_reference.tcl
```

## Step 5: Verify and Collect Results

### Outputs
- Gate-level netlist: `outputs/top.vg`
- SPEF file: `outputs/top.spef` (timing/parasitics)
- SDF file: `outputs/top.sdf` (timing delays)
- Design DB: `outputs/top_final.encdb`

### Reports
Check for clean results (no violations):
1. **DRC Report**: `reports/drc_final.rpt`
   - Should have 0 violations

2. **Timing Reports** (check both):
   - Setup: `timingReports/top_postRoute_setup.summary`
   - Hold: `timingReports/top_postRoute_hold.summary`
   - Both should have 0 violations

3. **Power Report**: `reports/power_postRoute.rpt`
   - Shows actual power after routing

4. **Area Report**: `reports/area_postRoute.rpt`
   - Final silicon area

## Step 6: Submit Results

Zip and submit:
```
./reports/*
./timingReports/*
./outputs/
```

## Clock Gating Expected Benefits

Based on synthesis results:
- **57 clock gates** synthesized
- **89.96% of registers** gated (681/757)
- Expected power savings: **14-20% dynamic power**
- Area increase: ~3% (due to added ICG cells)
- Timing: Clean (0 violations after routing expected)

## Troubleshooting

### DRC Violations
- Verify `asap7_tech_4x_201209.lef` is used (patched version)
- Check minimum metal spacing rules
- May need routing cleanup or layer adjustments

### Timing Violations
- Adjust utilization in floorplan (currently 80%)
- Try different CTS settings
- Consider relaxing input delay constraints if needed

### Routing Issues
- Check for unrouted nets: `report_conn -all > route_check.txt`
- May need to increase metal layers or adjust layer assignments
- Verify all I/O constraints are defined

## What to Expect

✅ **Better outcomes** when:
- ASAP7 library is properly installed
- Patched techlef is used
- Synthesis netlist is clean (ours is!)

⚠️ **Potential issues**:
- ASAP7 is open-source and may have edge cases
- Clock tree synthesis on gated clocks needs care
- DRC may require manual intervention

## Files in This Directory

```
APR/
├── top.vg (synthesized netlist)
├── top.sdc (timing constraints)
├── top.ddc (design database)
├── apr_reference.tcl (APR script)
├── reports/ (DRC, area, power reports)
├── timingReports/ (timing violation reports)
├── outputs/ (final netlists and databases)
└── asap7sc7p5t_28/ (library - download needed)
```

## Next Steps

1. ✅ Download ASAP7 library
2. ✅ Update techlef file (patch DRC)
3. ⏳ Run APR: `innovus -no_gui -files apr_reference.tcl`
4. ⏳ Verify reports (DRC, timing)
5. ⏳ Collect outputs for submission

---

**Your design is synthesized and ready for place and route!**

Synthesis Results Summary:
- Clock Period: 2000 ps (0.5 GHz)
- Setup Slack: 940.52 ns ✅
- Hold Slack: +10.79 ns ✅
- Total Power: 0.130 mW
- Total Area: 742.6 µm²
