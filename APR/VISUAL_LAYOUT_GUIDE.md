# Visual PE Grid Layout & Routing Diagram
## 4×4 Systolic Array on ASAP7 APR

---

## 1. Logical PE Grid (Dataflow)

```
┌─────────────────────────────────────────────────────────────────────┐
│                    WEIGHT CHAIN (from TOP)                          │
│                 w_in[0], w_in[1], w_in[2], w_in[3]                 │
│                            ↓ ↓ ↓ ↓                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  [PE00 w0]──→[PE01 w1]──→[PE02 w2]──→[PE03 w3] ← h_in0, h_in1     │
│      ↓            ↓            ↓            ↓                       │
│      v            v            v            v                       │
│  [PE10 w0]──→[PE11 w1]──→[PE12 w2]──→[PE13 w3]                    │
│      ↓            ↓            ↓            ↓                       │
│      v            v            v            v                       │
│  [PE20 w0]──→[PE21 w1]──→[PE22 w2]──→[PE23 w3]                    │
│      ↓            ↓            ↓            ↓                       │
│      v            v            v            v                       │
│  [PE30 w0]──→[PE31 w1]──→[PE32 w2]──→[PE33 w3] ← v_in0, v_in1    │
│      ↓            ↓            ↓            ↓                       │
│   drain        drain        drain        drain                      │
│  (psum_out0)                 (psum_out1)                            │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Legend
- **PE[row][col]**: Processing element at grid position
- **w0, w1, w2, w3**: Weight shift register in each PE
- **↓**: Data flow between rows (vertical)
- **→**: Data flow between columns (horizontal, when active)
- **drain**: Partial sum (accumulator) output path

---

## 2. Physical Placement Grid (APR Layout)

```
┌──────────────────────────────────────────────────────────────────┐
│                                                                    │
│  ╔═══════════════════════════════════════════════════════════╗  │
│  ║        FSM REGION (16 µm height) — u_fsm placement        ║  │ ← TOP
│  ║    Control: en, move_en, w_ld_en, fifo_en, direction     ║  │
│  ║    Output signals route DOWN to PE array                  ║  │
│  ╚═══════════════════════════════════════════════════════════╝  │
│                                                                    │
│  ┌─ FIFO REGION   ──┬─── PE ARRAY REGION ────────────────────┐  │
│  │ (LEFT MARGIN)   │                                          │  │
│  │                 │                                          │  │
│  │  ┌─────────┐    │  ┌─────┬─────┬─────┬─────┐              │  │
│  │  │ FIFO1   │    │  │PE00 │PE01 │PE02 │PE03 │              │  │
│  │  │ (9×6b)  │    │  ├─────┼─────┼─────┼─────┤              │  │
│  │  │         │    │  │PE10 │PE11 │PE12 │PE13 │              │  │
│  │  ├─────────┤    │  ├─────┼─────┼─────┼─────┤              │  │
│  │  │ FIFO2   │    │  │PE20 │PE21 │PE22 │PE23 │              │  │
│  │  │ (9×6b)  │    │  ├─────┼─────┼─────┼─────┤              │  │
│  │  │         │    │  │PE30 │PE31 │PE32 │PE33 │              │  │
│  │  └─────────┘    │  └─────┴─────┴─────┴─────┘              │  │
│  │                 │  (main 4×4 grid, ~112 µm × ~55 µm)      │  │
│  └─────────────────┴──────────────────────────────────────────┘  │
│                                                                    │
│  Power ring + margin on all sides                                 │
│                                                                    │
└──────────────────────────────────────────────────────────────────┘
     ↑
     LEFT: psum_out0, psum_out1 (output drain)
     RIGHT: h_in0, h_in1 (horizontal inputs)
     BOTTOM: v_in0, v_in1 (vertical inputs)
     TOP: w_in[0..3] (weight chain inputs)
```

### Coordinate Reference

```
Die:         136.64 × 136.64 µm
Core region: 128 × 81 µm (with 2 µm margins on all sides)

FSM_REGION:
  llx = 2.0,  lly = 65.0
  urx = 130.0, ury = 81.0
  → Height: 16 µm, Width: 128 µm

FIFO_REGION:
  llx = 2.0,  lly = 2.0
  urx = 10.0, ury = 65.0
  → Height: 63 µm, Width: 8 µm

PE_ARRAY_REGION:
  llx = 10.0,  lly = 2.0
  urx = 122.0, ury = 65.0
  → Height: 63 µm, Width: 112 µm
  → Allows ~7 µm × 15 µm per PE (4×4 grid)
```

---

## 3. I/O Port Placement on Die Boundary

```
                     w_in[0]  w_in[1]  w_in[2]  w_in[3]
                        ↓        ↓        ↓        ↓
     ┌────────────────────────────────────────────────────┐
     │                                                     │
  c  │                                                     │ c
  l  │                     PE ARRAY                        │ l
  k  │                   (main layout)                     │ k
     │                                                     │ /
  r  │                                                     │ h
  s  │                                                     │ i
  t  │                                                     │ n
  _  │                                                     │ 0
  n  │                                                     │ /
     │                                                     │ h
     │                                                     │ i
     │                                                     │ n
  d  │                                                     │ 1
  o  │                                                     │
  n  │                                                     │
  e  │                                                     │
     ├────────────────────────────────────────────────────┤
     │     v_in0           (margin)          v_in1        │
     └────────────────────────────────────────────────────┘
             ↑                                ↑
     psum_out0, psum_out1 (left edge)

KEY:
  • clk, rst_n, start → LEFT or CORNER pins
  • done → RIGHT or CORNER pin
  • w_in[0..3] → TOP (weight chain descent)
  • h_in0, h_in1 → RIGHT (horizontal boundary inputs)
  • v_in0, v_in1 → BOTTOM (vertical boundary inputs)
  • psum_out0, psum_out1 → LEFT (accumulator outputs)
```

---

## 4. Routing Layer Utilization

```
Metal Stack (ASAP7 7nm):

M7 (VDD/VSS stripes)          ═══════════════════════════════════════
   ↑                                     
M6 (signal, horizontal)        ───────────────────────────────────────
   ↑
M5 (signal, vertical)          │││││││││││││││││││││││││││││││││││││││
   ↑
M4 (signal, horizontal)        ───────────────────────────────────────
   ↑
M3 (signal, vertical)          │││││││││││││││││││││││││││││││││││││││
   ↑
M2 (signal/local, horizontal)  ───────────────────────────────────────
   ↑
M1 (contacts, vias) [not routed in this flow]

Routing layers: M2 (bottom) → M7 (top)
Power layer: M7 (VDD/VSS stripes, 56 nm pitch)

Expected utilization:
  M2: 30–40% (local connections)
  M3: 25–35% (local vertical)
  M4: 20–30% (medium-range)
  M5: 20–30% (medium-range vertical)
  M6: 25–35% (long-range, power, clk tree)
  M7: 50–70% (power stripes + global signals)
```

---

## 5. Systolic Array Dataflow Patterns

### Pattern A: Horizontal Zig-Zag (Even Rows L→R, Odd Rows R→L)

```
Row 0: [PE00] ──→ [PE01] ──→ [PE02] ──→ [PE03]
                                              ↓
Row 1: [PE13] ←── [PE12] ←── [PE11] ←── [PE10]
        ↓
Row 2: [PE20] ──→ [PE21] ──→ [PE22] ──→ [PE23]
                                              ↓
Row 3: [PE33] ←── [PE32] ←── [PE31] ←── [PE30]
```

### Pattern B: Vertical Zig-Zag (Even Cols ↓, Odd Cols ↑)

```
Col 0:                    Col 1:                    Col 2:                    Col 3:
[PE00]                   [PE01]                   [PE02]                   [PE03]
  ↓                        ↑                        ↓                        ↑
[PE10]                   [PE11]                   [PE12]                   [PE13]
  ↓                        ↑                        ↓                        ↑
[PE20]                   [PE21]                   [PE22]                   [PE23]
  ↓                        ↑                        ↓                        ↑
[PE30]                   [PE31]                   [PE32]                   [PE33]
```

### Pattern C: Circular Systolic (4-direction rotate)

```
     ┌─────────────────────┐
     │                     │
     → PE[0][0] ─→ ─ ─ ─→ ↓
     ↓                     │
     ← ─ ─ ←PE[1][0]       ↓
     ↑                     │
     ← ─ ←PE[2][0]       ↓
     ↑                   PE[3][0]
     ├────────────────────┘
```

---

## 6. Clock Tree Structure

```
                      clk (input)
                          │
                          ├─── [CK Buffer 0]
                          │        ├─── [CK Buffer 1]
                          │        │    ├─── PE00 DFF
                          │        │    ├─── PE01 DFF
                          │        │    └─── ...
                          │        │
                          │        └─── [CK Buffer 2]
                          │             ├─── PE20 DFF
                          │             └─── ...
                          │
                          ├─── [CK Buffer 3]
                          │    ├─── FSM state DFF
                          │    └─── ICG cells (clock gating)
                          │
                          └─── [CK Buffer 4]
                               └─── FIFO latches

Target skew: 50 ps across all clock loads
Expected delay: 50–100 ps from clk pad to core logic
```

---

## 7. Power Distribution Network (PDN)

```
VDD Ring (outer perimeter):
┌─────────────────────────────────────────────────────────┐
│  VDD ════════════════════════════════════════════════   │
│   ║                                            ║        │
│   ║                   CORE                     ║        │
│   ║                                            ║        │
│   ╚════════════════════════════════════════════╝        │
└─────────────────────────────────────────────────────────┘

M7 (top metal) stripes:
VDD: ═════  ═════  ═════  ═════  (5 stripes, 56 nm pitch)
VSS: ─────  ─────  ─────  ─────  (5 stripes, 56 nm pitch)

M6 power rails (local distribution):
  Horizontal rails every 50 µm

Decap placement:
  • Distributed throughout core (10 fF per cell)
  • Dense near high-switching blocks (PE array)
  • Sparse near FSM (lower switching)

Current path:
  VDD_pad → VDD_ring → M7_stripes → M6_rails → M2_local → cells
```

---

## 8. FIFO Feedback Routing

```
u_fifo1 (left margin) → PE[1][*] feedback
  ├─ Connected to: PE[1][0].data_out → FIFO in
  ├─ Output from FIFO → PE[1][1].data_in (or PE[1][3] depending on direction)
  └─ Routed via M3/M4 (medium range)

u_fifo2 (left margin) → PE[3][*] feedback
  ├─ Connected to: PE[3][0].data_out → FIFO in
  ├─ Output from FIFO → PE[3][1].data_in
  └─ Routed via M3/M4

Why left margin?
  • Minimizes routing distance
  • Natural cluster with psum drain (both left side)
  • Reduces congestion in PE array center
```

---

## 9. Control Signal Routing (FSM → PE Array)

```
u_fsm (top region) generates:
  ├─ en (1-bit)              → broadcast to all PE clocks
  ├─ move_en (1-bit)         → broadcast to all PE muxes
  ├─ w_ld_en (1-bit)         → broadcast to weight latches
  ├─ fifo_en (1-bit)         → FIFO write gates
  ├─ psum_shift_en (1-bit)   → psum output multiplexer
  ├─ psum_clr (1-bit)        → accumulator reset
  └─ direction[1:0] (2-bit)  → routing mux select

Routing strategy:
  • Clock to all DFFs: M6/M7 (low skew, dedicated clock tree)
  • Control signals: M4/M5 (fan-out to ~100+ receivers)
  • Low fanout per lane to minimize slew

Typical delays:
  FSM output → PE input: 50–100 ps
  Setup time margin: 700+ ps (excellent)
```

---

## 10. Example Placement Timeline

```
Step 1: FLOORPLAN (3 seconds)
  ├─ Define die boundary (136.64 µm)
  ├─ Create core region (128 × 81 µm)
  └─ Add power ring

Step 2: INITIAL PLACEMENT (10–30 seconds)
  ├─ Legalize all cells (no overlaps)
  ├─ Bin-based global placement
  └─ Rough PE array forms a grid

Step 3: CONGESTION OPTIMIZATION (15–45 seconds)
  ├─ Identify congestion hotspots
  ├─ Move cells to reduce overlap
  ├─ FSM clusters at top
  ├─ FIFOs pack left
  └─ PEs spread into 4×4 grid

Step 4: CTS (15–30 seconds)
  ├─ Build clock tree from clk input
  ├─ Insert buffers/gates
  ├─ Balance skew to <50 ps
  └─ Route clock on M6/M7

Step 5: GLOBAL ROUTING (30–60 seconds)
  ├─ Predict routing demand per bin
  ├─ Iteratively refine placement
  └─ May move small cells for routability

Step 6: DETAILED ROUTING (60–180 seconds)
  ├─ Route all signal nets layer-by-layer
  ├─ Resolve conflicts/congestion
  ├─ Insert vias & via stacks
  └─ Route power/ground

Step 7: POST-ROUTE OPTIMIZATION (20–60 seconds)
  ├─ Fix timing violations (rare with 940 ps slack)
  ├─ Optimize power
  └─ Cleanup DRC violations

TOTAL: 3–10 minutes (depending on machine & settings)
```

---

## 11. Key Landmarks on Layout

```
                      136.64 µm (die width)
    ┌────────────────────────────────────────────────────┐
    │                                                     │ 136.64 µm
    │  ╔═══════════════════════════════════════════════╗  │ (die height)
    │  ║  FSM (u_fsm)                  81 µm total     ║  │
    │  ║  16 µm height ──────────────────────────      ║  │
    │  ║     control signals flow downward              ║  │ 
    │  ╚═══════════════════════════════════════════════╝  │
    │  ┌──────────────────────────────────────────────┐   │
    │  │  FIFO1 │  PE00 PE01 PE02 PE03              │   │
    │  │  8 µm  │  PE10 PE11 PE12 PE13    65 µm    │   │
    │  │   wd   │  PE20 PE21 PE22 PE23              │   │
    │  │FIFO2  │  PE30 PE31 PE32 PE33 ← psum drain │   │
    │  └──────────────────────────────────────────────┘   │
    │                                                      │
    └────────────────────────────────────────────────────┘
     0.0                                              136.64

Each PE cell: ~8–10 µm × ~8–10 µm (varies by row/col interconnect)
Routing channels: ~0.5–1 µm between PE rows/columns
```

---

## 12. Predicted Layout Snapshot (Schematic)

```
After placement:

     0 µm          ┌─────────────────────────────────────┐  136.64 µm
                   │ ┃ VDD Ring (2.176 µm)               │
                   │ ┃                                    │
       136.64      │ ║ ┌──────────────────────────────┐  │
        µm     81  │ ║ │ FSM: u_fsm (16 µm height)    │  │ ↑
                   │ ║ │ [control block]              │  │ |
                   │ ║ └──────────────────────────────┘  │ |
                   │ ║                                    │
                   │ ║ ┌─────┬─────┬─────┬─────┐        │ | 81
                   │ ║ │     │     │     │     │        │ | µm
                   │ ║ │ PE  │ PE  │ PE  │ PE  │ ┃      │ | (core
              65   │ ║ │ rows│     │     │     │ ┃ VDD  │ | height)
              µm   │ ║ │  ×  │ 4×4 │     │     │ ┃ rail │ |
                   │ ║ │  4  │grid │     │     │ ┃      │ |
                   │ ║ │     │     │     │     │ ┃      │ |
                   │ ║ │FIFO1│ in  │ center    │ ┃      │ |
       LEFT        │ ║ │FIFO2│ center       ┃ VSS      │ |
       8 µm        │ ║ └─────┴─────┴─────┴─────┘ ┃ rail │ |
                   │ ║ ┃ VSS Ring (2.176 µm)    ┃      │ ↓
                   │ ┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃
                   └─────────────────────────────────────┘ 2 µm margin
                   0 µm                              136.64 µm
```

---

## 13. Netlist Hierarchy Tree (for Placement Reference)

```
top
├── PORTS:
│   ├─ IN:  clk, rst_n, start, h_in0, h_in1, v_in0, v_in1, w_in[0..3]
│   └─ OUT: done, psum_out0, psum_out1
│
├── INSTANCES (2 top-level):
│   │
│   ├─ u_fsm (zigzag_fsm)
│   │   ├─ Type: Verilog module / ~14 cells (DFF, AND, OR, MUX)
│   │   ├─ Size: ~1–2% of total area
│   │   ├─ Placement target: FSM_REGION (top, 16 µm height)
│   │   ├─ Inputs: clk, rst_n, start
│   │   ├─ Outputs: en, move_en, w_ld_en, fifo_en, psum_shift_en, psum_clr, direction[1:0]
│   │   └─ Timing: ~10 ns (FSM period, slow but no critical path)
│   │
│   └─ u_pe_array (zig_zag_4x4) ← DOMINANT (~95% area)
│       ├─ Type: Parametric Verilog module
│       ├─ Size: ~5,300 cells
│       ├─ Placement target: PE_ARRAY_REGION + FIFO_REGION (center + left)
│       │
│       ├─ INTERNALS (generated):
│       │   │
│       │   ├─ g_pe_row[0..3] (genvar generate blocks)
│       │   │   └─ g_pe_col[0..3] (nested genvar)
│       │   │       └─ u_pe[r][c] (16 instances, one per (r,c))
│       │   │           ├─ Type: pe_update (datapath module)
│       │   │           ├─ Size: ~320 cells per PE
│       │   │           ├─ Contains:
│       │   │           │   ├─ MAC datapath (multiplier, adder tree)
│       │   │           │   ├─ 13-bit accumulator register (DFF chain)
│       │   │           │   ├─ 4-mux for direction routing
│       │   │           │   ├─ 2-bit weight shift register
│       │   │           │   └─ Latch for pipeline stage
│       │   │           │
│       │   │           ├─ PLACEMENT HINT:
│       │   │           │   • Arrange in grid: row-major order
│       │   │           │   • Spacing: ~8–10 µm × ~8–10 µm per cell
│       │   │           │   • Neighbor connectivity: prioritize adjacent mux connections
│       │   │           │
│       │   │           └─ PORTS (example PE[1][2]):
│       │   │               ├─ IN:  h_in, v_in, w_in, psum_in, ctrl
│       │   │               └─ OUT: h_out, v_out, w_out, psum_out
│       │   │
│       │   ├─ u_fifo1 (FIFO)
│       │   │   ├─ Type: fifo9 (9-deep, 6-bit wide)
│       │   │   ├─ Size: ~200–300 cells (SRAM-like + control logic)
│       │   │   ├─ Placement target: FIFO_REGION (left, bottom part)
│       │   │   ├─ Purpose: Buffer feedback for row 1 (PE[1][*])
│       │   │   ├─ Connectivity:
│       │   │   │   ├─ Write: psum_out from PE[1][0] or PE[1][3]
│       │   │   │   └─ Read:  Data to PE[1][0] or PE[1][3] (depends on direction)
│       │   │   │
│       │   │   └─ PORTS:
│       │   │       ├─ IN:  clk, rst_n, wr_en, wr_data[5:0]
│       │   │       ├─ OUT: rd_data[5:0], empty, full
│       │   │       └─ INTERNAL: buffer[0..8][5:0] (72 bits × 9 = 648 bits total)
│       │   │
│       │   └─ u_fifo2 (FIFO)
│       │       ├─ Type: fifo9 (9-deep, 6-bit wide)
│       │       ├─ Size: ~200–300 cells
│       │       ├─ Placement target: FIFO_REGION (left, upper part, stacked above FIFO1)
│       │       ├─ Purpose: Buffer feedback for row 3 (PE[3][*])
│       │       └─ PORTS: (same as u_fifo1)
│       │
│       └─ GLOBAL SIGNALS (routed from u_fsm):
│           ├─ en, move_en, w_ld_en, fifo_en → broadcast to all PEs
│           ├─ psum_shift_en, psum_clr → routed to accumulators
│           └─ direction[1:0] → routed to all 4-muxes
│
└── POWER/GND:
    ├─ VDD_ring (around die perimeter)
    ├─ VSS_ring (around die perimeter)
    ├─ M7 stripes (VDD/VSS across top metal)
    └─ M6 rails (local distribution in core)
```

---

## 14. Congestion Hotspot Analysis

### Predicted Congestion Zones

```
Highest congestion: CENTER PE ARRAY
  Reason: 4×4 grid densely packed, many inter-PE routes
  Mitigation: Placed at 0.85 target density (leaves 15% slack)

Medium congestion: FSM OUTPUT SIGNALS
  Reason: 8 control signals broadcast to 16 PEs
  Mitigation: Placed at top as narrow band, signals fan out downward

Low congestion: FIFO REGION
  Reason: Isolated left margin, only connects to adjacent PEs
  Mitigation: Ample space (8 µm width), can relax placement

Routing layer pressure:
  • M5/M6: Highest (carry long signals across PE array)
  • M3/M4: Medium (local PE-to-PE + FIFO feedback)
  • M2: Low (mostly local cell connections)
  • M7: High (power stripes, but dedicated)
```

---

## 15. Post-APR Verification Checklist

```
□ All cells placed (no floating instances)
□ No cell overlaps (check dbGet top.insts.overlaps)
□ All nets routed (check routed_nets == total_nets)
□ No routing shorts (check verify_geometry.rpt)
□ Timing met (setup slack > 0, hold slack > 0)
□ Power reasonable (~0.5–1 mW @ 500 MHz)
□ Area utilized ~55% (10,287 µm² core / 18,667 µm² die)
□ Clock skew < 50 ps
□ Congestion < 1.0 on all layers
□ DRC clean (or only layer density warnings)
□ LVS clean (no shorts/opens)
□ GDS exportable (all layers mapped)
```

---

**Version**: 1.0  
**Created**: 2026-04-26  
**Purpose**: Visual reference for APR floorplan + dataflow
