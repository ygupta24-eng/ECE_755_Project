# ============================================================
# dnn.sdc — Timing constraints for zigzag accelerator (Sky130)
# Single source of truth for all timing constraints.
# ============================================================

# ---------- Clock definition ----------
set CLK_NAME  clk
set CLK_PORT  [get_ports clk]
set CLK_PERIOD 16.0

create_clock -name $CLK_NAME -period $CLK_PERIOD $CLK_PORT

# ---------- Clock uncertainty ----------
# Model jitter + skew conservatively for Sky130
set_clock_uncertainty -setup 0.5 [get_clocks $CLK_NAME]
set_clock_uncertainty -hold  0.25 [get_clocks $CLK_NAME]

# ---------- Clock transition ----------
set_clock_transition 0.15 [get_clocks $CLK_NAME]

# ---------- Input delays ----------
# Assume inputs arrive 20% into the clock period from external logic
set INPUT_DELAY [expr {$CLK_PERIOD * 0.20}]
set_input_delay  -clock $CLK_NAME $INPUT_DELAY [all_inputs]
# Override: clock itself has no input delay
set_input_delay  -clock $CLK_NAME 0 [get_ports clk]

# ---------- Output delays ----------
# Assume outputs must be stable 20% before next rising edge
set OUTPUT_DELAY [expr {$CLK_PERIOD * 0.20}]
set_output_delay -clock $CLK_NAME $OUTPUT_DELAY [all_outputs]

# ---------- Driving cell ----------
# Approximate external driver strength
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin X [all_inputs]

# ---------- Output load ----------
# Moderate fanout load assumption for boundary IOs
set_load 0.05 [all_outputs]

# ---------- False paths ----------
# rst_n is async — no timing path needed from it
set_false_path -from [get_ports rst_n]

# ---------- Multi-cycle paths ----------
# None required for this design
