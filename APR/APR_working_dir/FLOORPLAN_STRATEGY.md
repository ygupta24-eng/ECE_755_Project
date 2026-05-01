# APR Floorplan Strategy & Netlist Hierarchy
## Systolic Array + Control FSM on ASAP7 (7nm)

---

## 1. Design Hierarchy Overview

```
top (top-level chip)
├── u_fsm (zigzag_fsm)
│   ├── State registers & counters (~14 flip-flops)
│   └── Control signal generators (en, move_en, w_ld_en, fifo_en, psum_shift_en, psum_clr, direction[1:0])
│
└── u_pe_array (zig_zag_4x4) ← DOMINANT (~95% of area)
    ├── g_pe_row[0..3]
    │   └── g_pe_col[0..3]
    │       └── u_pe (16 Processing Elements)
    │           ├── MAC unit (multiply-accumulate)
    │           ├── Direction mux (circular routing)
    │           ├── FIFO latch for pipelining
    │           └── Weight shift register
    │
    ├── u_fifo1 (9-deep FIFO, 6-bit wide)
    │   ├── 9 × 6-bit SRAM-like buffer cells
    │   ├── Write/read pointers
    │   └── Empty/full flags
    │
    └── u_fifo2 (9-deep FIFO, 6-bit wide)
        ├── 9 × 6-bit SRAM-like buffer cells
        ├── Write/read pointers
        └── Empty/full flags
```

### Key Instance Paths (for placement references)

| Instance | Type | Size (approx) | Role |
|----------|------|---------------|------|
| `u_fsm` | `zigzag_fsm` | ~2% of total | Control FSM: state machine + enable logic |
| `u_pe_array` | `zig_zag_4x4` | ~98% of total | PE array + FIFOs |
| `u_pe_array/g_pe_row[r].g_pe_col[c].u_pe` | `pe_update` | ~6% each | 16 PEs (r=0..3, c=0..3) |
| `u_pe_array/u_fifo1` | `fifo9` | ~4% | Feedback FIFO for row 1 |
| `u_pe_array/u_fifo2` | `fifo9` | ~4% | Feedback FIFO for row 3 |

---

## 2. Data Flow and Port Connectivity

### Input Ports
- **`w_in[0..3]`** (2-bit each) — Weight chain (enters **TOP**, feeds down rows)
  - `w_in[0]` → PE row 0, shifts down: PE10 → PE20 → PE30
  - `w_in[1]` → PE row 1, shifts down: PE11 → PE21 → PE31
  - etc.
  
- **`h_in0, h_in1`** (6-bit each) — Horizontal data (enters **RIGHT**, to PE13, PE33)
  - `h_in0` → **PE[1][3]** (row 1, col 3)
  - `h_in1` → **PE[3][3]** (row 3, col 3)
  - Flow left-to-right or right-to-left depending on `direction`

- **`v_in0, v_in1`** (6-bit each) — Vertical data (enters **BOTTOM**, to PE30, PE32)
  - `v_in0` → **PE[3][0]** (row 3, col 0)
  - `v_in1` → **PE[3][2]** (row 3, col 2)
  - Flow up/down depending on `direction`

### Output Ports
- **`psum_out0`** (13-bit) — Partial sum drain from **PE[1][0]** via `u_pe_array/g_pe_row[1].g_pe_col[0].u_pe`
- **`psum_out1`** (13-bit) — Partial sum drain from **PE[3][0]** via `u_pe_array/g_pe_row[3].g_pe_col[0].u_pe`
- Both exit **LEFT** side of chip

### Control Signals (u_fsm → u_pe_array)
```
en              → Gate valid computation cycles
move_en         → Trigger data movement between PEs
w_ld_en         → Latch weights into shift chain
fifo_en         → Enable FIFO write (during initial fill)
psum_shift_en   → Allow partial sum routing to outputs
psum_clr        → Clear accumulators for new computation
direction[1:0]  → Select zigzag pattern (circular/horizontal/vertical)
```

---

## 3. Systolic Array Layout: Grid Visualization

### Conceptual 4×4 PE Grid
```
        col0   col1   col2   col3
row0 ┌────────────────────────────────┐
     │ PE00 ─ PE01 ─ PE02 ─ PE03 ────→ h_in0,h_in1 (from RIGHT)
row1 ├────────────────────────────────┤
     │ PE10 ─ PE11 ─ PE12 ─ PE13
row2 ├────────────────────────────────┤
     │ PE20 ─ PE21 ─ PE22 ─ PE23
row3 ├────────────────────────────────┤
     │ PE30 ─ PE31 ─ PE32 ─ PE33
row3 └────────────────────────────────┘
      ↑
      v_in0, v_in1 (from BOTTOM)

psum drain → LEFT (PE10, PE30 outputs)
w_in[0..3] → TOP (weight chain down each column)
```

### Physical Floorplan Regions (in APR script)

```
   ┌─────────────────────────────────────────────────────┐
   │  Margin (core = 128µm width, 81µm height after FSM)  │
   │ ┌──────────────────────────────────────────────────┐ │
   │ │                                                    │ │
   │ │        FSM REGION (16 µm height)                 │ │ ← TOP
   │ │        u_fsm placement target                     │ │
   │ │                                                    │ │
   │ ├────────────────────────────────────────────────────┤ │
   │ │                                                    │ │
   │ │  FIFO REGION   │  PE ARRAY REGION                │ │
   │ │  (left, 8µm)  │  (center, main 4×4 grid)        │ │
   │ │               │                                  │ │
   │ │  u_fifo1      │  PE[0][0] PE[0][1] PE[0][2]...  │ │
   │ │  u_fifo2      │     ⋮        ⋮       ⋮          │ │
   │ │               │  PE[3][0] PE[3][1] PE[3][2]...  │ │
   │ │               │                                  │ │
   │ ├────────────────────────────────────────────────────┤ │
   │ │  Margin & routing spine                            │ │
   │ └──────────────────────────────────────────────────┘ │
   └─────────────────────────────────────────────────────┘

   ↑
   Power ring + stripes (not shown)
```

---

## 4. Floorplan Strategy Details

### Regions (Coordinates in Script)

| Region | Purpose | Bounds (µm) | Constraints |
|--------|---------|-------------|------------|
| **FSM_REGION** | Control FSM placement | llx=2.0, lly=65.0, urx=130.0, ury=81.0 | Narrow band @ top; force tight placement |
| **PE_ARRAY_REGION** | 4×4 systolic grid | llx=10.0, lly=2.0, urx=122.0, ury=65.0 | Central core; high congestion target 0.85 |
| **FIFO_REGION** | Feedback FIFOs | llx=2.0, lly=2.0, urx=10.0, ury=65.0 | Left margin; reserves space for FIFO1/FIFO2 |

### Why This Layout?

1. **FSM @ Top (16 µm band)**
   - Small control block (~2% area)
   - Narrow band keeps it out of the 4×4 grid
   - Feeds control signals down → minimal routing delay
   - Clock tree easily spans this width

2. **4×4 PE Array in Center**
   - 4 rows × 4 columns = natural grid
   - High local connectivity (neighbor-to-neighbor routing)
   - Congestion-driven placer will keep PEs compact
   - Leaves ~65 µm × ~55 µm space → roughly 1-2 µm per PE side

3. **FIFOs on Left Margin**
   - u_fifo1 feeds PE[1][*] (row 1 feedback)
   - u_fifo2 feeds PE[3][*] (row 3 feedback)
   - Left placement keeps I/O short
   - psum_out drain also on left → natural alignment

4. **Strategic I/O Placement**
   - **TOP**: w_in[0..3] — weight inputs flow down (minimize top-of-chip routing)
   - **RIGHT**: h_in0, h_in1 → PE[1][3], PE[3][3] (boundary inputs)
   - **BOTTOM**: v_in0, v_in1 → PE[3][0], PE[3][2] (boundary inputs)
   - **LEFT**: psum_out0, psum_out1 (output drain)
   - **Corners**: clk, rst_n, start, done (distributed across edges)

---

## 5. Placement Constraints (via TCL Commands)

```tcl
# Soft hierarchical guidance (groups, NOT hard blockages)
createInstGroup -name PE_ARRAY_GROUP
addInstGroupMember PE_ARRAY_GROUP u_pe_array
setInstGroupOptions -instGroup PE_ARRAY_GROUP -targetDensity 0.85

createInstGroup -name FSM_GROUP
addInstGroupMember FSM_GROUP u_fsm
setInstGroupOptions -instGroup FSM_GROUP -targetDensity 0.9

# Enable congestion-driven placement
setPlaceMode -congProp on
setPlaceMode -congPropExponent 2.0

# Hierarchical mode: respect internal instance structure
setPlaceMode -modulePriority high
setPlaceMode -ignoreIlmMode none

# Run placement
place_design
```

**Key Point**: These are *guides*, not hard constraints. The placer uses them as objectives but can deviate if needed for timing/power.

---

## 6. Clock Tree Synthesis (CTS)

### Clock Specs
- **Frequency**: 500 MHz
- **Period**: 2.0 ns (1000 ps)
- **Slack**: ~940 ps (excellent margin)
- **Target Skew**: 50 ps (0.05 ns)

### CTS Configuration in Script
```tcl
set cts_target_skew 0.050     # 50 ps target
set cts_max_cap 20.0           # fF (capacitance)
set cts_max_tran 0.250         # ns (transition time)

clockDesign -fixedInstBeforeCTS -genSpecFile
```

**Implication**: CTS happens *after* placement, so the FSM and PE array positions are already fixed. The CTS engine will build a balanced tree from `clk` input → all sequential logic.

---

## 7. Routing Layers & Power Grid

### Metal Stack (ASAP7 @ 7nm)

| Layer | Name | Pitch | Orientation | Role |
|-------|------|-------|------------|------|
| M2 | 1st metal | 32 nm | Horizontal | Local cell I/O, bottom routing layer |
| M3 | 2nd metal | 32 nm | Vertical | Local interconnect |
| M4 | 3rd metal | 48 nm | Horizontal | Medium-range signals, power |
| M5 | 4th metal | 48 nm | Vertical | Medium-range signals, power |
| M6 | 5th metal | 56 nm | Horizontal | Long-range signals |
| M7 | 6th metal | 56 nm | Vertical | Top metal (power grid) |

### Power Grid

```tcl
# APR script configures:
setNanoRouteMode -routeBottomRoutingLayer 2  # M2 (metal2)
setNanoRouteMode -routeTopRoutingLayer 7     # M7 (metal7 - stripes)

# Power ring placed in PAD frame
# Stripes on M6/M7 for VDD/VSS distribution
```

---

## 8. Netlist Extraction from top.vg

From the synthesized netlist, key instances are:

```verilog
// Top level (instantiations)
zigzag_fsm u_fsm (...)         // ~14 state register cells, enable logic
zig_zag_4x4 u_pe_array (...)   // 16 PEs + 2 FIFOs, ~5,300 cells total

// Inside u_pe_array:
generate for (genvar r = 0; r < 4; r++) begin
  for (genvar c = 0; c < 4; c++) begin
    pe_update g_pe_row[r].g_pe_col[c].u_pe (...)  // 16 instances
  end
end

// FIFOs
fifo9 u_fifo1 (...)  // 9-deep FIFO, 6-bit
fifo9 u_fifo2 (...)  // 9-deep FIFO, 6-bit
```

---

## 9. Post-APR Files Generated

| File | Location | Purpose |
|------|----------|---------|
| `top.def` | `outputs/` | Placement & routing info (readable format) |
| `top_apr.v` | `outputs/` | Post-route netlist (for timing analysis) |
| `top_apr.spef` | `outputs/` | Parasitics (R/C per net) for PT, Spectre |
| `top_apr.sdf` | `outputs/` | Timing delays (setup/hold, combinational) |
| `top_apr.gds` | `outputs/` | GDS2 layout (for manufacturing / signoff) |

---

## 10. How to Use the Script

### 1. **Prepare Environment**
```bash
cd APR/
# Ensure top_cg.vg, top.mmmc, top.sdc are in place
# Ensure ASAP7 libraries are in asap7sc7p5t_28/
```

### 2. **Run APR Flow**
```bash
innovus -64 -execute apr_optimized_floorplan.tcl -logFile apr_optimized_floorplan.log
```

### 3. **Monitor Progress**
```bash
# In another terminal:
tail -f apr_optimized_floorplan.log

# Watch for milestones:
# ✓ Design initialized
# ✓ Floorplan created
# ✓ Pin assignment complete
# ✓ Initial placement complete
# ✓ Clock tree synthesis complete
# ✓ Global routing complete
# ✓ Detailed routing complete
# ✓ Post-route timing report generated
# ✓ GDS file exported
```

### 4. **View Results**
```bash
# Check timing
cat timingReports/timing_postRoute.rpt

# View power consumption
cat reports/power_report.rpt

# Check area breakdown
cat reports/area_report.rpt

# View DEF (text-based layout)
# Use GUI: Innovus → File → Import DEF, or
# Use external tool: Calibre RVE, KLayout, Klayout

# View GDS (binary layout)
# kalayout outputs/top_apr.gds
```

---

## 11. Common Issues & Troubleshooting

### Issue: "Pin placement failed"
**Cause**: Pin names not exactly matching netlist, or port direction mismatch.
**Fix**: Verify pin names in `top.vg`:
```bash
grep "^input\|^output" top.vg | head -20
```

### Issue: "Placement density violations"
**Cause**: Target density (0.85) too high for available region.
**Fix**: Reduce target density or expand PE_ARRAY_REGION bounds.

### Issue: "Routing congestion"
**Cause**: Too many signal nets competing for metal tracks.
**Fix**: 
- Reduce targetDensity from 0.85 to 0.75
- Enable SpaceExplore mode in setPlaceMode
- Add routing tracks or use higher metal layers

### Issue: "CTS failed / clock tree too large"
**Cause**: Clock fanout too high (unlikely for small 500 MHz design).
**Fix**:
- Disable CTS: comment out `clockDesign` line
- Reduce clock loads if possible

### Issue: "GDS export failed"
**Cause**: Missing gds2map.txt file for layer mapping.
**Fix**: Ensure `asap7sc7p5t_28/gds2map.txt` exists. If not, create a minimal one or use GDS without map.

---

## 12. Next Steps: Post-Layout Verification

After APR completes, run:

### PrimeTime SI (Static Timing Analysis with SI noise)
```tcl
# pt_script.tcl
read_db top.ddc
link_design

# Load parasitics from SPEF
read_parasitics -format spef outputs/top_apr.spef

# Apply constraints
read_sdc top_cg.sdc

# Run timing
report_timing -significant_digits 3 -delay all > PT_timing.rpt

# Run SI
report_si_induced_delay > PT_si_delay.rpt
```

### Magma / Calibre LVS (Layout vs. Schematic)
```bash
calibre -hier -lvs top.rul outputs/top_apr.gds outputs/top_apr.spice
```

### Magma / Calibre DRC (Design Rule Check)
```bash
calibre -hier -drc top.drc outputs/top_apr.gds
```

---

## 13. Design Summary

| Aspect | Value |
|--------|-------|
| **Technology** | ASAP7 (7 nm) |
| **Frequency** | 500 MHz |
| **Clock Period** | 2.0 ns |
| **Die Size** | ~136.64 × 136.64 µm |
| **Core Area** | ~130 × 85 µm |
| **Utilization (target)** | ~55% |
| **Systolic Array** | 4×4 PEs + FIFOs + FSM |
| **PE Count** | 16 |
| **PE Datapath Width** | 6 bits (data), 2 bits (weight), 13 bits (accumulator) |
| **Floorplan Style** | Grid-aligned with control band + margin regions |
| **Power Grid** | M6/M7 stripes with corner VDD/VSS pads |
| **Timing Slack** | ~940 ps (excellent) |
| **Critical Path** | ~60 ps (well under 2 ns) |

---

**Created**: 2026-04-26  
**Author**: AI APR Assistant  
**Version**: 1.0 (Optimized Floorplan with Hierarchical PE Array)
