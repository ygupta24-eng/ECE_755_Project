# APR Documentation Index
## Quick Navigation Guide

**Created**: 2026-04-26  
**Technology**: ASAP7 7nm  
**Design**: 4×4 Systolic Array + Zigzag FSM Control

---

## 📑 File Quick Reference

| File | Type | Length | Time to Read | Purpose |
|------|------|--------|--------------|---------|
| **README.md** | Markdown | 600 lines | 15–20 min | **START HERE** — Quick-start guide + overview |
| **PACKAGE_SUMMARY.md** | Markdown | 400 lines | 10–15 min | Overview of all files & how to use them |
| **FLOORPLAN_STRATEGY.md** | Markdown | 450 lines | 20–30 min | Deep-dive: design hierarchy & strategy |
| **VISUAL_LAYOUT_GUIDE.md** | Markdown | 550 lines | 15–25 min | ASCII diagrams, dataflow, routing |
| **apr_optimized_floorplan.tcl** | TCL Script | 800 lines | N/A (execute) | **MAIN SCRIPT** — Runs full APR flow |
| **apr_checklist.tcl** | TCL Script | 400 lines | N/A (execute) | Post-APR quality verification |
| **run_apr.sh** | Bash Script | 150 lines | N/A (execute) | Wrapper with pre-flight checks (bonus) |
| **INDEX.md** | Markdown | This file | 5–10 min | Navigation guide (you are here) |

---

## 🚀 Quick Start (5 minutes)

**For impatient users:**

```bash
# 1. Read this first (5 min)
cat README.md

# 2. Run APR (5–10 min)
./run_apr.sh
# OR:
innovus -64 -execute apr_optimized_floorplan.tcl -logFile apr_optimized_floorplan.log

# 3. Check results (5 min)
cat timingReports/timing_postRoute.rpt
cat reports/power_report.rpt
```

**Expected outcome**: Design placed & routed, GDS exported.

---

## 📖 Reading Paths

### **Path A: Beginner (Learning APR)**
1. README.md (sec "Quick Start")
2. VISUAL_LAYOUT_GUIDE.md (sec 1–3, 6–8)
3. FLOORPLAN_STRATEGY.md (sec 1–3)
4. Run: `./run_apr.sh`
5. **Total**: ~1 hour

### **Path B: User (Just Run It)**
1. README.md (sec "Quick Start")
2. Run: `./run_apr.sh`
3. Check results: `timingReports/timing_postRoute.rpt`
4. **Total**: ~20 minutes

### **Path C: Expert (Customize Script)**
1. README.md (entire)
2. FLOORPLAN_STRATEGY.md (entire)
3. apr_optimized_floorplan.tcl (edit as needed)
4. Run: `innovus -64 -execute apr_optimized_floorplan.tcl ...`
5. VISUAL_LAYOUT_GUIDE.md (refer as needed)
6. **Total**: ~2–3 hours

### **Path D: Designer (Understand & Present)**
1. FLOORPLAN_STRATEGY.md (entire)
2. VISUAL_LAYOUT_GUIDE.md (entire)
3. PACKAGE_SUMMARY.md
4. README.md (reference)
5. **Total**: ~1.5 hours

---

## 🎯 Find What You Need

### **"How do I run APR?"**
→ README.md, sec "Quick Start"

### **"What's in the script?"**
→ apr_optimized_floorplan.tcl (read line-by-line with comments)

### **"Why is FSM at the top?"**
→ FLOORPLAN_STRATEGY.md, sec 4 (strategy rationale)

### **"Show me the layout."**
→ VISUAL_LAYOUT_GUIDE.md, sec 2, 11, 12

### **"What's the design hierarchy?"**
→ FLOORPLAN_STRATEGY.md, sec 1
→ VISUAL_LAYOUT_GUIDE.md, sec 13

### **"How do I customize the floorplan?"**
→ README.md, sec "Advanced Customization"
→ FLOORPLAN_STRATEGY.md, sec 5

### **"What outputs does APR produce?"**
→ README.md, sec "Output Files"
→ apr_optimized_floorplan.tcl, lines ~450–480

### **"Is timing met?"**
→ Check: `cat timingReports/timing_postRoute.rpt | grep slack`
→ Expected: ~940 ps setup slack (positive = PASS)

### **"How much power?"**
→ Check: `cat reports/power_report.rpt`
→ Expected: ~0.5–1.0 mW @ 500 MHz

### **"What if it fails?"**
→ README.md, sec "Troubleshooting"
→ PACKAGE_SUMMARY.md, sec "Support & Troubleshooting"

### **"How do I verify the layout?"**
→ README.md, sec "Post-APR Verification"
→ apr_checklist.tcl (run this)

### **"Show me the PE grid."**
→ VISUAL_LAYOUT_GUIDE.md, sec 1–3
→ FLOORPLAN_STRATEGY.md, sec 3

### **"How are signals routed?"**
→ VISUAL_LAYOUT_GUIDE.md, sec 4, 8, 9
→ FLOORPLAN_STRATEGY.md, sec 7

### **"What's the clock tree?"**
→ VISUAL_LAYOUT_GUIDE.md, sec 6
→ FLOORPLAN_STRATEGY.md, sec 6

---

## 📊 Document Hierarchy

```
PACKAGE_SUMMARY.md (overview of all files)
    ├─→ README.md (START HERE for quick-start)
    │   ├─→ FLOORPLAN_STRATEGY.md (for detailed understanding)
    │   │   └─→ VISUAL_LAYOUT_GUIDE.md (for visual reference)
    │   └─→ apr_optimized_floorplan.tcl (main script)
    │
    ├─→ run_apr.sh (easy wrapper)
    │   └─→ apr_optimized_floorplan.tcl (calls this)
    │
    └─→ apr_checklist.tcl (post-APR verification)
        └─→ outputs/ (reads results)

Navigation: INDEX.md ← YOU ARE HERE
```

---

## 🔑 Key Sections by Topic

### **Design Overview**
- README.md → "Design Hierarchy Overview"
- FLOORPLAN_STRATEGY.md → "Design Hierarchy Overview" (sec 1)
- VISUAL_LAYOUT_GUIDE.md → "Netlist Hierarchy Tree (for Placement Reference)" (sec 13)

### **Floorplan Strategy**
- FLOORPLAN_STRATEGY.md → "Floorplan Strategy Details" (sec 4)
- VISUAL_LAYOUT_GUIDE.md → "Physical Placement Grid" (sec 2)
- README.md → "Floorplan Layout"

### **Placement & Routing**
- FLOORPLAN_STRATEGY.md → "Routing Layers & Power Grid" (sec 7)
- VISUAL_LAYOUT_GUIDE.md → "Routing Layer Utilization" (sec 4)
- apr_optimized_floorplan.tcl → lines 300–420

### **Clock & Timing**
- FLOORPLAN_STRATEGY.md → "Clock Tree Synthesis (CTS)" (sec 6)
- VISUAL_LAYOUT_GUIDE.md → "Clock Tree Structure" (sec 6)
- README.md → "Performance Metrics"

### **Power & PDN**
- FLOORPLAN_STRATEGY.md → "Routing Layers & Power Grid" (sec 7)
- VISUAL_LAYOUT_GUIDE.md → "Power Distribution Network (PDN)" (sec 7)
- apr_optimized_floorplan.tcl → lines 115–125

### **Post-APR Verification**
- README.md → "Post-APR Verification" (sec 12)
- apr_checklist.tcl (entire script)
- FLOORPLAN_STRATEGY.md → "Netlist Extraction & Post-APR Files" (sec 8–9)

### **Troubleshooting**
- README.md → "Troubleshooting" (sec 11)
- PACKAGE_SUMMARY.md → "Support & Troubleshooting"
- FLOORPLAN_STRATEGY.md → "Common Issues & Troubleshooting" (sec 11)

---

## ⏱️ Time Estimates

| Activity | Time | Command |
|----------|------|---------|
| Read README.md | 15–20 min | `cat README.md` |
| Read all docs | 60–90 min | See "Reading Paths" |
| Run APR flow | 5–10 min | `./run_apr.sh` |
| Check results | 5–10 min | `cat timingReports/timing_postRoute.rpt` |
| Post-APR verification | 10–15 min | Run apr_checklist.tcl |
| View layout | 5 min | `klayout outputs/top_apr.gds` |
| **Total start-to-finish** | **50–90 min** | All steps above |

---

## 💾 File Sizes

| File | Size | Storage |
|------|------|---------|
| README.md | ~100 KB | Disk |
| FLOORPLAN_STRATEGY.md | ~150 KB | Disk |
| VISUAL_LAYOUT_GUIDE.md | ~180 KB | Disk |
| apr_optimized_floorplan.tcl | ~150 KB | Disk |
| apr_checklist.tcl | ~100 KB | Disk |
| run_apr.sh | ~30 KB | Disk |
| PACKAGE_SUMMARY.md | ~100 KB | Disk |
| INDEX.md (this file) | ~80 KB | Disk |
| **Total docs** | **~890 KB** | Minimal |
| **APR outputs (after run)** | **~50–200 MB** | GDS, DEF, SPEF |

---

## 🏁 Getting Started (Step-by-Step)

### **Step 1: Orientation** (10 min)
```bash
cd APR/
cat README.md                           # Quick overview
cat PACKAGE_SUMMARY.md                  # What's included
cat INDEX.md                            # You are here
```

### **Step 2: Understand Design** (20 min)
```bash
cat FLOORPLAN_STRATEGY.md               # Design details
cat VISUAL_LAYOUT_GUIDE.md | head -100  # Look at diagrams
```

### **Step 3: Prepare Environment** (5 min)
```bash
ls -la top_cg.vg top.mmmc top.sdc                          # Verify inputs
ls -la asap7sc7p5t_28/LEF/scaled/asap7sc7p5t_28_R_4x*      # Verify libs
which innovus                                               # Verify tool
```

### **Step 4: Run APR** (5–10 min)
```bash
./run_apr.sh                            # Automatic with checks
# OR manually:
innovus -64 -execute apr_optimized_floorplan.tcl -logFile apr.log
```

### **Step 5: Monitor** (in another terminal)
```bash
tail -f apr_optimized_floorplan.log     # Watch progress
# Look for: ✓ markers (success), ❌ or ERROR (problems)
```

### **Step 6: Check Results** (10 min)
```bash
cat timingReports/timing_postRoute.rpt  # Timing OK?
cat reports/power_report.rpt            # Power OK?
cat reports/area_report.rpt             # Area OK?
ls -lah outputs/                        # Files generated?
```

### **Step 7: Verify Quality** (5–10 min)
```bash
innovus -64 -init outputs/top.def -execute apr_checklist.tcl
# Look for: ✓ PASS indicators
```

### **Step 8: Inspect Layout** (5 min, optional)
```bash
klayout outputs/top_apr.gds &           # Visual check
# Or: calibredrv outputs/top_apr.gds &
```

---

## 📝 Common Tasks

### **I want to understand the floorplan strategy**
→ Read: FLOORPLAN_STRATEGY.md (sec 4) + VISUAL_LAYOUT_GUIDE.md (sec 2)
→ Time: 20–30 min

### **I want to modify the FSM band height**
→ Edit: apr_optimized_floorplan.tcl, line ~160
→ Consult: README.md (sec "Advanced Customization")
→ Time: 5–10 min

### **I want to see the PE grid layout**
→ Read: VISUAL_LAYOUT_GUIDE.md (sec 1–3, 13)
→ Time: 10–15 min

### **I want to debug a failed run**
→ Read: README.md (sec "Troubleshooting")
→ Check: apr_optimized_floorplan.log (tail -100)
→ Time: 10–20 min

### **I want to present this design**
→ Use: VISUAL_LAYOUT_GUIDE.md + FLOORPLAN_STRATEGY.md diagrams
→ Reference: README.md (sec "Performance Metrics")
→ Time: 30–60 min (preparation)

---

## ✅ Verification Checklist

Before running APR:
- [ ] All input files present (top_cg.vg, top.mmmc, top.sdc)
- [ ] ASAP7 libraries available
- [ ] Innovus v19+ installed
- [ ] Read README.md
- [ ] ~1 hour free time

After APR completes:
- [ ] outputs/ directory has 5+ files (DEF, Verilog, SPEF, SDF, GDS)
- [ ] timingReports/timing_postRoute.rpt exists with slack info
- [ ] reports/ directory has 3+ files (area, power, DRC)
- [ ] Setup slack is positive (~940 ps expected)
- [ ] Power is reasonable (<1.5 mW expected)
- [ ] Utilization 50–60%
- [ ] No ERROR messages in log

---

## 🔗 Cross-References

**File A references**:
- apr_optimized_floorplan.tcl → Lines 95–125 (floorplan regions)
- README.md → "Floorplan Layout" (explains coordinates)
- FLOORPLAN_STRATEGY.md → Section 4 (rationale)
- VISUAL_LAYOUT_GUIDE.md → Section 2 (diagrams)

**File B references**:
- FLOORPLAN_STRATEGY.md → Section 1 (hierarchy)
- VISUAL_LAYOUT_GUIDE.md → Section 13 (tree)
- apr_optimized_floorplan.tcl → Lines 35–40 (netlist input)
- README.md → "Design Hierarchy Overview" (summary)

**File C references**:
- apr_checklist.tcl → All sections depend on APR output
- README.md → Section 12 (post-APR verification)
- FLOORPLAN_STRATEGY.md → Section 12 (expected results)

---

## 📞 Help Resources

**Inside this package**:
1. README.md — General questions
2. FLOORPLAN_STRATEGY.md — Design questions
3. VISUAL_LAYOUT_GUIDE.md — Layout questions
4. apr_optimized_floorplan.tcl — Script technical details

**External resources**:
- Cadence Innovus manual (online portal)
- ASAP7 PDK docs (http://asap.asu.edu/asap7/)
- Design metrics (../DESIGN_METRICS_SUMMARY.md)
- RTL design (../RTL_Design/)

---

## 🎯 Next Steps

1. **Now**: Read README.md (15 min)
2. **Next**: Run APR using run_apr.sh (5–10 min)
3. **Then**: Check results (5–10 min)
4. **Finally**: Post-layout verification in PT/ directory

---

**Last Updated**: 2026-04-26  
**Version**: 1.0  
**Status**: Ready to Use

---

🚀 **Ready to start?** → `cat README.md` (START HERE)
