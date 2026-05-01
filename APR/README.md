# APR Flow for 4×4 Systolic Array Accelerator
## ASAP7 7nm Technology | 500 MHz | Optimized Floorplan

---

## Overview

This APR (Automated Place & Route) flow optimizes the physical layout of a **4×4 Processing Element (PE) array** with **Zigzag dataflow control** using **Cadence Innovus v21**. The design features:

- **4×4 systolic array** with PE grid topology
- **Zigzag FSM** control unit for instruction sequencing
- **Two FIFOs** for feedback data
- **Clock gating** for power efficiency
- **500 MHz target** with excellent slack (940 ps)
- **ASAP7 7nm technology** with 6 metal layers (M2–M7)

The floorplan strategy places the **grid visually organized**:
- **FSM**: Narrow band at top (16 µm) — control signals
- **PE Array**: Central grid (4 rows × 4 cols) — main computation
- **FIFOs**: Left margin — feedback buffers
- **I/O**: Strategic placement on edges for minimal routing

---

## Files in This Directory

| File | Purpose |
|------|---------|
| **apr_systolic.tcl** | Main APR script (Innovus TCL) — complete flow |
| **FLOORPLAN_STRATEGY.md** | Detailed design documentation & hierarchy |
| **README.md** | This file |

---

## Quick Start

### 1. **Verify Prerequisites**

Ensure these files are present in the APR directory:

```bash
ls -la top_cg.vg top.mmmc top_cg.sdc
ls -la asap7sc7p5t_28/LEF/scaled/asap7sc7p5t_28_R_4x_220121a.lef
ls -la asap7sc7p5t_28/techlef_misc/asap7_tech_4x_201209.lef
```

### 2. **Run APR Flow**



**Option B: Direct Innovus command (RECOMMENDED)**
```bash
innovus -64 -execute apr_systolic.tcl -logFile apr_systolic.log
```

**Option C: Interactive Innovus GUI**
```bash
innovus -64
# Inside Innovus shell:
# source apr_systolic.tcl
```

### 3. **Monitor Progress**

In another terminal:
```bash
tail -f apr_systolic.log
```

Watch for completion (should finish in 2-5 minutes):
- Look for: `APR FLOW COMPLETE!` message
- Or: `Streamout is finished!` for GDS export
- Final: `*** Ending "Innovus"` with runtime stats

### 4. **Check Results**

After APR completes (2–10 minutes on modern hardware):

```bash
# Timing report
cat timingReports/timing_postRoute.rpt

# Power analysis
cat reports/power_report.rpt

# Area breakdown
cat reports/area_report.rpt

# View layout (if Innovus GUI available)
innovus -64 -init outputs/top.def

# View GDS
klayout outputs/top_apr.gds
# or
calibredrv outputs/top_apr.gds
```

---

## Design Hierarchy

```
top
├── u_fsm (zigzag_fsm, ~14 cells)
│   └── Control signals: en, move_en, w_ld_en, fifo_en, psum_shift_en, psum_clr, direction
│
└── u_pe_array (zig_zag_4x4, ~5,300 cells)
    ├── g_pe_row[0..3].g_pe_col[0..3].u_pe (16 PEs, ~6% each)
    │   ├── MAC datapath (multiply-accumulate)
    │   ├── Routing mux (4-direction dataflow)
    │   └── Accumulator (13-bit register)
    │
    ├── u_fifo1 (9-deep FIFO, 6-bit wide, ~4%)
    │   └── Feeds PE[1][*] feedback
    │
    └── u_fifo2 (9-deep FIFO, 6-bit wide, ~4%)
        └── Feeds PE[3][*] feedback
```

### Port Mapping

| Port | Width | Direction | Role |
|------|-------|-----------|------|
| `clk` | 1 | IN | Clock (500 MHz) |
| `rst_n` | 1 | IN | Reset (active low) |
| `start` | 1 | IN | Computation enable |
| `done` | 1 | OUT | Completion flag |
| `w_in[0..3]` | 2 each | IN | Weight chain (top) |
| `h_in0, h_in1` | 6 each | IN | Horizontal data (right) |
| `v_in0, v_in1` | 6 each | IN | Vertical data (bottom) |
| `psum_out0, psum_out1` | 13 each | OUT | Partial sum drain (left) |

---

## Floorplan Layout

### Physical Regions

```
┌────────────────────────────────────────────────────────────┐
│  Power Ring + Margin (1–2 µm on all sides)                 │
│ ┌──────────────────────────────────────────────────────┐   │
│ │                                                        │   │
│ │  FSM_REGION (16 µm height)                           │   │ ← TOP
│ │  ├─ u_fsm placed here (control narrow band)          │   │
│ │  │  width: 128 µm, height: 16 µm                     │   │
│ │  └─ signals: en, move_en, w_ld_en, etc. → down      │   │
│ │                                                        │   │
│ ├─ Soft routing spine (1 µm)                           │   │
│ │                                                        │   │
│ │  PE_ARRAY_REGION (65 µm height)                      │   │
│ │  ├─ Main 4×4 grid (120 µm × 55 µm)                  │   │
│ │  ├─ Row 0: PE[0][0] ─ PE[0][1] ─ PE[0][2] ─ PE[0][3]│   │
│ │  ├─ Row 1: PE[1][0] ─ PE[1][1] ─ PE[1][2] ─ PE[1][3]│   │
│ │  ├─ Row 2: PE[2][0] ─ PE[2][1] ─ PE[2][2] ─ PE[2][3]│   │
│ │  └─ Row 3: PE[3][0] ─ PE[3][1] ─ PE[3][2] ─ PE[3][3]│   │
│ │                                                        │   │
│ │  FIFO_REGION (left margin, 8 µm)                     │   │
│ │  └─ u_fifo1, u_fifo2 stacked vertically              │   │
│ │                                                        │   │
│ ├─ Soft routing spine (1 µm)                           │   │
│ │                                                        │   │
│ │  MARGIN (bottom, 2 µm)                               │   │
│ │                                                        │   │
│ └──────────────────────────────────────────────────────┘   │
│                                                              │
└────────────────────────────────────────────────────────────┘

Die Boundary: ~136.64 × 136.64 µm (on 7nm technology)
Core Size:   ~128 × 81 µm
Utilization: ~55%
```

### I/O Port Placement

```
        w_in[0]
         w_in[1]
          w_in[2]
           w_in[3]
              ↓
┌─────────────────────────────────────────┐
│                                          │ → h_in0
│            SYSTOLIC ARRAY                │ → h_in1
│                                          │
├─────────────────────────────────────────┤
│                                          │
└─────────────────────────────────────────┘
         ↑              ↑
       v_in0          v_in1
       
Left margin: psum_out0, psum_out1 (drain outputs)
```

---

## Floorplan Regions (TCL)

```tcl
# FSM region: TOP band
set fsm_region_llx 2.0
set fsm_region_lly 65.0     # (83 - 16 = 65)
set fsm_region_urx 130.0
set fsm_region_ury 81.0

# PE Array region: CENTER grid
set pe_array_llx 10.0       # 8 µm left margin for FIFOs
set pe_array_lly 2.0
set pe_array_urx 122.0
set pe_array_ury 65.0

# FIFO region: LEFT margin
set fifo_region_llx 2.0
set fifo_region_lly 2.0
set fifo_region_urx 10.0
set fifo_region_ury 65.0
```

---

## Key Script Features

### 1. **Placement**

```tcl
# Place design with hierarchical placement regions
place_design
addTieHiLo  # Add tie cells for unused pins
```

### 2. **Clock Tree Synthesis (CTS)**

```tcl
# 500 MHz clock tree optimized for timing
ccopt_design
```

### 3. **Routing**

```tcl
# Route design using M2-M7 (6 metal layers)
routeDesign
```

### 4. **Power Grid**

```tcl
# Power ring with 2.176 µm width, 0.384 µm spacing
# Stripes on M6/M7 for VDD/VSS distribution
set FP_RING_WIDTH   2.176
set FP_RING_SPACE   0.384
```

### 5. **Output Generation**

```tcl
# DEF (Design Exchange Format)
defOut ./outputs/top.def

# Verilog netlist
saveNetlist ./outputs/top_apr.v

# SPEF (parasitics for timing)
rcOut -spef ./outputs/top_apr.spef

# SDF (standard delay format)
write_sdf ./outputs/top_apr.sdf

# GDS2 (final layout)
streamOut -format stream ./outputs/top_apr.gds -mode ALL
```

---

## Output Files

After APR completes, you'll have:

| File | Size | Purpose |
|------|------|---------|
| `outputs/top.def` | 1–5 MB | Placement & routing in text format |
| `outputs/top_apr.v` | 500 KB | Post-route Verilog netlist |
| `outputs/top_apr.spef` | 5–10 MB | Parasitic RC extraction |
| `outputs/top_apr.sdf` | 2–5 MB | Timing delays (SDF) |
| `outputs/top_apr.gds` | 10–50 MB | GDS2 layout (binary) |
| `reports/verify_geometry.rpt` | <1 MB | DRC checks |
| `reports/power_report.rpt` | <1 MB | Power breakdown |
| `reports/area_report.rpt` | <1 MB | Area utilization |
| `timingReports/timing_postRoute.rpt` | <1 MB | Post-route STA |

---

## Post-APR Verification

### 1. **Post-Layout Timing (PT)**

```bash
cd ../PT
pt_shell -f pt_script.tcl
```

Expected results:
- Setup slack: ~940 ps (positive = met)
- Hold slack: >0 ps (positive = met)
- Critical path: ~60 ps (well under 2 ns period)

### 2. **Power Analysis**

```bash
# From PT or using standalone power analysis
report_power -format full > PT_power.rpt
```

Expected:
- Total power: ~0.5–1.0 mW @ 500 MHz
- Leakage: <1 µW (minimal for 7nm)

### 3. **Design Rule Checks (Calibre)**

```bash
calibre -hier -drc top.drc outputs/top_apr.gds > DRC_report.txt
```

Expected: 0 errors (or only info/warnings about layer densities)

### 4. **Layout vs. Schematic (Calibre LVS)**

```bash
calibre -hier -lvs top.rul outputs/top_apr.gds outputs/top_apr.spice > LVS_report.txt
```

Expected: `CLEAN` (no shorts or opens)

### 5. **View Layout**

**Option A: Klayout (open-source)**
```bash
klayout outputs/top_apr.gds
```

**Option B: Calibre RVE**
```bash
calibredrv outputs/top_apr.gds &
```

**Option C: Innovus DEF viewer**
```bash
innovus -64 -init outputs/top.def
```

---

## Troubleshooting

### Issue: "ERROR during init_design"
**Cause**: Missing or incorrect netlist/library paths
**Solution**:
1. Verify paths in script:
   ```tcl
   file exists "./top_cg.vg"
   file exists "./asap7sc7p5t_28/LEF/scaled/asap7sc7p5t_28_R_4x_220121a.lef"
   ```
2. If using different netlist: update `set init_verilog {./your_netlist.v}`

### Issue: "Placement density violations" (>1.0)
**Cause**: Too many cells in constrained region
**Solution**:
- Reduce `targetDensity` from 0.85 → 0.75
- Expand PE_ARRAY_REGION bounds
- Check for bloated cells in synthesis

### Issue: "Routing congestion" (unrouted nets)
**Cause**: Metal layer saturation
**Solution**:
- Run global routing with SpaceExplore: `setNanoRouteMode -routeSpaceExplore on`
- Use `routeBottomRoutingLayer 1` (M1) if available
- Add more layers or refine placement

### Issue: "CTS failed"
**Cause**: Clock fanout too high or tree construction issue
**Solution**:
- Comment out `clockDesign` line and rely on manual placement
- Or reduce `cts_max_cap` / `cts_max_tran` constraints

### Issue: "GDS export failed"
**Cause**: Missing `gds2map.txt` or layer mismatch
**Solution**:
- Ensure `asap7sc7p5t_28/gds2map.txt` exists (or create minimal version)
- Or skip GDS export and use DEF instead

---

## Performance Metrics

### Expected Results (from Design Metrics Summary)

| Metric | Value | Unit |
|--------|-------|------|
| Frequency | 500 | MHz |
| Clock Period | 2.0 | ns |
| Critical Path | ~60 | ps |
| Setup Slack | ~940 | ps ✓ |
| Die Size | 136.64 × 136.64 | µm |
| Core Area | ~10,287 | µm² |
| Utilization | ~55% | % |
| Power (Total) | 0.5–1.0 | mW |
| Power/MHz | 1–2 | µW/MHz |
| EDAP | 140K–184K | pJ·µm² |

---

## Advanced Customization

### Adjust FSM Band Height

If FSM placement is too congested:

```tcl
# Increase FSM region height from 16 µm → 20 µm
set fsm_height 20.0
set fsm_region_lly [expr {$core_ury - $fsm_height}]
```

### Adjust PE Array Dimensions

To pack PEs tighter or looser:

```tcl
# Reduce left margin from 8 µm → 5 µm
set pe_margin_left 5.0

# Expand overall core
set fpxdim 140.0     ;# wider core
set fpydim 90.0      ;# taller core
```

### Enable Placement Debugging

Add verbose logging:

```tcl
setPlaceMode -verbose true
setPlaceMode -debug 5
place_design
```

### Manual Placement Constraints

For specific instances (e.g., force FIFO near left edge):

```tcl
# Hard constraint (use sparingly!)
set_place_constraint -region {2.0 2.0 10.0 65.0} u_pe_array/u_fifo1
```

---

## Performance Tips

1. **Faster APR (5–10 min instead of 30+ min)**:
   - Reduce placement iterations: `setPlaceMode -maxDensityIterations 3`
   - Skip detailed DRC: `setNanoRouteMode -skipPostRouteDRC true`

2. **Better Timing (lower slack margin)**:
   - Tighten CTS skew: `set cts_target_skew 0.025`
   - Use `timeDesign -preCTS -slackOnly` to guide placement

3. **Lower Power**:
   - Enable clock gating (already in netlist)
   - Reduce voltage if not 0.7V: adjust `.mmmc` file
   - Optimize placement density: increase from 0.85 → 0.90 (more compact = less wiring)

---

## References

- **Innovus TCL Guide**: `help <command>` inside Innovus shell
- **ASAP7 PDK**: http://asap.asu.edu/asap7/
- **Cadence Innovus Manual**: Online at Cadence support portal
- **Design Metrics**: See [DESIGN_METRICS_SUMMARY.md](../DESIGN_METRICS_SUMMARY.md)
- **Floorplan Details**: See [FLOORPLAN_STRATEGY.md](./FLOORPLAN_STRATEGY.md)

---

## Flow Diagram

```
top_cg.vg (Synthesized netlist with clock gating)
    ↓
top.mmmc (MMMC timing corner file)
    ↓
top.sdc (Timing constraints)
    ↓
    └─→ [APR Flow: apr_optimized_floorplan.tcl]
        ├─→ init_design (load netlist + libraries)
        ├─→ floorPlan (create core boundary)
        ├─→ place_design (place cells hierarchically)
        ├─→ clockDesign (synthesize clock tree)
        ├─→ globalDetailRoute (GR + DR)
        ├─→ detailedRoute (fine-tune routing)
        ├─→ timeDesign (post-route timing analysis)
        ├─→ reportPower (power breakdown)
        ├─→ defOut (save DEF)
        ├─→ streamOut (save GDS)
        └─→ verilogOut, rcOut, sdfOut (save other formats)
            ↓
        outputs/
        ├── top.def (DEF layout)
        ├── top_apr.v (Verilog netlist)
        ├── top_apr.spef (Parasitics)
        ├── top_apr.sdf (Timing)
        └── top_apr.gds (GDS layout)
            ↓
        [Post-Layout Verification]
        ├─→ PT (timing + power)
        ├─→ Calibre DRC/LVS
        └─→ Klayout/Calibre (visual inspection)
```

---

## Contact & Support

For issues or questions:

1. **Check the log file**: `tail -100 apr_optimized_floorplan.log`
2. **Review FLOORPLAN_STRATEGY.md**: Detailed design documentation
3. **Run apr_checklist.tcl**: Post-APR quality verification
4. **Innovus help**: `help <command>` inside Innovus shell

---

**Last Updated**: 2026-04-26  
**Version**: 1.0  
**Status**: Production-ready
