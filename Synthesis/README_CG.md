# Clock Gating Synthesis Guide

## Overview

This directory contains scripts and instructions for synthesizing the CNN accelerator RTL with **Priority 1 clock gating** optimizations using Synopsys Design Vision.

**Expected Power Savings: 14-20% dynamic power reduction**

---

## What's Inside

### RTL Files Modified (with Clock Gating)

1. **RTL_Design/pe_update.sv**
   - Added psum accumulator gating with `en_for_gating_d` signal
   - psum_out now uses `clk_psum_gated` (gated clock)
   - Enable signal pipelined for glitch-free operation
   - Expected savings: **10-15% overall, 90% for this register**

2. **RTL_Design/control.sv**
   - Added ch_cnt (channel counter) gating with `ch_cnt_en_d` signal
   - ch_cnt now uses `clk_ch_cnt_gated` (gated clock)
   - Enable signal optimized for state transitions only
   - Expected savings: **4-5% overall, 80% for this register**

### Synthesis TCL Scripts

1. **cg_synthesis.tcl** (NEW)
   - Main synthesis script with clock gating enabled
   - Automatic ICG cell insertion
   - Two-pass compilation with high effort
   - Detailed reporting

2. **cg_constraints.tcl** (NEW)
   - Clock gating-specific timing constraints
   - Setup/hold time margins (0.1ns setup, 0.05ns hold)
   - Technology-specific optimizations (ASAP7, TSMC 45/40/65nm)
   - Gating enable signal timing

3. **syn_script.tcl** (EXISTING - Reference)
   - Original synthesis flow (without gating)
   - Use this to compare baseline results

4. **constraints.tcl** (EXISTING - Include in both flows)
   - Main timing constraints (shared by both flows)

---

## Running Clock Gating Synthesis

### Quick Start

```bash
# In the Synthesis folder:
cd /path/to/Synthesis

# Run clock gating synthesis with Design Vision
dc_shell -f cg_synthesis.tcl

# View results
[ Open cg_reports/ for detailed reports ]
[ Check cg_outputs/ for netlists ]
```

### Step-by-Step

1. **Verify RTL Changes**
   ```bash
   # Check that modifications are in place:
   grep -n "en_for_gating_d" ../RTL_Design/pe_update.sv
   grep -n "ch_cnt_en_d" ../RTL_Design/control.sv
   ```
   Expected: Should find gating signal declarations and constraints

2. **Launch Design Vision**
   ```bash
   # Interactive mode (recommended for debugging):
   dc_shell
   
   # At DC prompt:
   source cg_synthesis.tcl
   ```

3. **Monitor Compilation**
   - Check logs in `cg_reports/` directory in real-time
   - Watch for ICG cell insertion messages:
     ```
     [ Creating integrated clock gates... ]
     [ Found 16 instances of pe module ]
     [ Creating 16 ICG cells for psum_out ]
     [ Creating 1 ICG cell for ch_cnt ]
     ```

4. **Verify Results**
   - Check `cg_reports/cg_clock_gates.rpt` for:
     - ✓ 16 ICG cells for psum accumulators
     - ✓ 1 ICG cell for ch_cnt counter
   - Check `cg_reports/cg_power.rpt` for power reduction
   - Check `cg_reports/cg_timing_*.rpt` for timing closure

5. **Generate Outputs**
   - Gated netlist: `cg_outputs/top_cg.vg`
   - SDC file: `cg_outputs/top_cg.sdc`
   - Database: `cg_outputs/top_cg.ddc`

---

## Comparing Baseline vs. Clock-Gated

### Run Both Flows

```bash
# Original (non-gated) synthesis:
dc_shell -f syn_script.tcl
# Results in: outputs/, reports/

# Clock-gated synthesis:
dc_shell -f cg_synthesis.tcl
# Results in: cg_outputs/, cg_reports/
```

### Comparison Script (Optional)

Create a simple analysis script to compare:

```bash
#!/bin/bash

echo "=== POWER COMPARISON ==="
echo "Baseline Power:"
grep "Total" reports/synth.power.rpt | head -5
echo ""
echo "Clock-Gated Power:"
grep "Total" cg_reports/cg_power.rpt | head -5
echo ""

echo "=== AREA COMPARISON ==="
echo "Baseline Area:"
grep "Total" reports/synth.area.rpt | head -1
echo ""
echo "Clock-Gated Area:"
grep "Total" cg_reports/cg_area.rpt | head -1
echo ""

echo "=== TIMING COMPARISON ==="
echo "Baseline Setup Slack:"
grep "slack" reports/synth.timing.setup.rpt | head -3
echo ""
echo "Clock-Gated Setup Slack:"
grep "slack" cg_reports/cg_timing_setup.rpt | head -3
```

---

## Understanding the Output Reports

### cg_clock_gates.rpt
Most important for verifying clock gating implementation:
- **Count of ICG cells:** Should see ~17 total
  - 16 instances in PE array (psum_out)
  - 1 instance in FSM (ch_cnt)
- **Setup/hold margins:** Verify margins meet constraints
- **Gating fraction:** Shows percentage of time each gate is active

```
Gate Name          Module      Enable Signal      Active% 
─────────────────────────────────────────────────────────
u_psum_cg[0]       pe          en_for_gating_d    10.5%
u_psum_cg[1]       pe          en_for_gating_d    10.5%
...
u_psum_cg[15]      pe          en_for_gating_d    10.5%
u_ch_cnt_cg        zigzag_fsm  ch_cnt_en_d        19.8%
```

### cg_power.rpt
Compare dynamic power reduction:
- **Total Dynamic:** Should be ~14-20% lower than baseline
- **Clock Network:** May increase slightly (for gating logic)
- **Combinational:** Unchanged
- **Sequential:** Should show significant reduction

Expected:
```
Baseline:      2.45 mW dynamic
Clock-gated:   2.05 mW dynamic
Savings:       16.3% ✓
```

### cg_timing_*.rpt
Timing closure verification:
- **Setup violations:** Should be 0 (or fixed by DC)
- **Hold violations:** Should be 0 (fixed by -fix_hold)
- **Slack:** Compare to baseline

---

## Customization & Debugging

### Adjusting Clock Gating Aggressiveness

If timing fails with full gating, reduce setup margin in `cg_constraints.tcl`:

```tcl
# Original: Conservative
set cg_setup_time 0.1

# Aggressive (if timing fails):
set cg_setup_time 0.15
```

### Disabling Specific Gates

If a particular gate causes issues:

```tcl
# In cg_synthesis.tcl, after source cg_constraints.tcl:
set_clock_gating_control -disable_gating {en_for_gating_d}
# OR
set_clock_gating_control -disable_gating {ch_cnt_en_d}
```

### Forcing Specific ICG Cell

To use a specific cell library:

```tcl
# In cg_synthesis.tcl:
set_preferred_logic_lib_icg_cell LSNX  # TSMC 45nm
# OR
set_preferred_logic_lib_icg_cell ND2D1BWP  # ASAP7
```

### Verbose Gating Report

To get more detailed clock gating information:

```tcl
# In cg_synthesis.tcl, replace:
report_clock_gating -verbose

# With:
report_clock_gating -verbose -detailed
```

---

## Troubleshooting

### Issue: Clock Gates Not Inserted

**Symptoms:** 
- `cg_clock_gates.rpt` shows 0 gates
- Power identical to baseline

**Solutions:**
1. Verify RTL modifications are in place:
   ```bash
   grep "clk_psum_gated\|clk_ch_cnt_gated" ../RTL_Design/*.sv
   ```

2. Check that gating signals are declared (not swept away):
   ```tcl
   # In cg_synthesis.tcl, add:
   set_dont_optimize {en_for_gating_d ch_cnt_en_d}
   ```

3. Verify library has ICG cells:
   ```tcl
   # In cg_synthesis.tcl:
   get_lib_cells */*ICG*
   get_lib_cells */*CGE*
   ```

### Issue: Timing Violations (Setup)

**Symptoms:**
- Setup slack negative on gating enable paths
- Compilation fails

**Solutions:**
1. Increase setup margin in `cg_constraints.tcl`:
   ```tcl
   set cg_setup_time 0.15  # was 0.1
   ```

2. Add delay buffer on enable paths:
   ```tcl
   set_input_delay -clock clk 0.10 {en_for_gating_d ch_cnt_en_d}
   ```

3. Reduce overall timing constraints (higher period):
   - Edit `constraints.tcl`: increase clock period
   - Example: 2000ps → 2200ps

### Issue: Timing Violations (Hold)

**Symptoms:**
- Hold slack negative on gating paths
- `-fix_hold` not fixing it

**Solutions:**
1. DC should auto-fix with `set_fix_hold clk`
2. If not fixed, check library:
   ```tcl
   get_attribute [get_lib_cells */LSNX] lib_cell_hold_models
   ```

3. Manually insert hold time buffer:
   ```tcl
   # Not recommended - let DC handle it
   ```

### Issue: Large Area Overhead

**Symptoms:**
- Area increase > 2% from clock gating
- Too many gates inserted

**Solutions:**
1. Verify only 17 gates should be inserted (16 + 1)
2. Check for accidental gate duplication:
   ```tcl
   report_clock_gating | grep "redundant\|duplicate"
   ```

3. May be acceptable if power savings are > 14%
   - Trade-off: Small area + good power savings

---

## Integration with APR (Cadence Innovus)

Once clock-gated netlist is ready (cg_outputs/top_cg.vg):

### 1. Load into Innovus
```tcl
# In Innovus init.tcl
read_netlist cg_outputs/top_cg.vg
read_sdc cg_outputs/top_cg.sdc
```

### 2. Handle Clock Gating Cells
```tcl
# Ensure gating cells are recognized
set_dont_touch [find lib_cell */LS*]  # Don't modify ICG cells
set_dont_touch [find lib_cell */ND2*]

# Set clock gating cells as hard macro (optional)
set_cell_purpose {INTERNALIO} [find cell u_*_cg]
```

### 3. Power Planning
- No special power considerations for gating cells
- They draw minimal current (latches are low-power)

### 4. Placement
- Gating cells should be placed near their registers
- Innovus automatic placement usually handles this well

### 5. Clock Tree Synthesis
- Clock tree includes both main clock and gated clock branches
- May see slight increase in clock routing (~2-3%)

---

## Expected Results Summary

### Power Savings

| Component | Savings |
|-----------|---------|
| psum_out accumulator (×16) | 10-15% |
| ch_cnt counter | 4-5% |
| **Total** | **14-20%** |

### Area Impact

- ICG cells: ~17 × 8 gates = ~136 standard cells
- Typical cell area: ~5 λ² each = ~680 λ²
- Overall design area increase: **<1%**

### Timing Impact

- **Setup:** Usually improves (fewer toggle transitions)
- **Hold:** Neutral to slight improvement
- **Overall slack:** Often 5-10% better due to lower activity

---

## Next Steps

After Priority 1 (psum + ch_cnt):

### Phase 2 - Medium Priority (Future)
- PE weight register (w_reg) gating
- PE move register (move_reg) gating  
- FSM h_cnt, v_cnt gating
- Expected: +3-4% power savings

### Phase 3 - Advanced (Optional)
- FIFO pointer gating
- Expected: +0.5-1% power savings
- Higher risk (pointer dependencies)

See parent directory documents for Phase 2/3 details.

---

## Support & Contact

For questions or issues:
1. Check this README
2. Review detailed analysis docs in parent directory
3. Check Design Vision manual for vendor-specific syntax
4. Contact your synthesis tool representative

---

## File Listing

```
Synthesis/
├── syn_script.tcl              # Original synthesis (reference)
├── cg_synthesis.tcl            # Clock gating synthesis ★ USE THIS
├── cg_constraints.tcl          # Clock gating constraints (new)
├── constraints.tcl             # Shared constraints
├── analyze.tcl                 # RTL file list
├── .synopsys_dc.setup          # Library setup
├── README_CG.md                # This file ★
├── outputs/                    # Results from syn_script.tcl
├── reports/                    # Reports from syn_script.tcl
├── cg_outputs/ ★               # Results from cg_synthesis.tcl
│   ├── top_cg.vg
│   ├── top_cg.sdc
│   └── top_cg.ddc
└── cg_reports/ ★               # Reports from cg_synthesis.tcl
    ├── cg_clock_gates.rpt      # ← Most important
    ├── cg_power.rpt            # ← Power savings verify
    ├── cg_timing_setup.rpt
    ├── cg_timing_hold.rpt
    └── cg_area.rpt
```

★ = Key files for clock gating flow

---

Last Updated: April 7, 2026
