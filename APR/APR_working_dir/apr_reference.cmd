#######################################################
#                                                     
#  Innovus Command Logging File                     
#  Created on Sun Apr 26 14:20:24 2026                
#                                                     
#######################################################

#@(#)CDS: Innovus v21.19-s058_1 (64bit) 04/04/2024 09:59 (Linux 3.10.0-693.el7.x86_64)
#@(#)CDS: NanoRoute 21.19-s058_1 NR231113-0413/21_19-UB (database version 18.20.605) {superthreading v2.17}
#@(#)CDS: AAE 21.19-s004 (64bit) 04/04/2024 (Linux 3.10.0-693.el7.x86_64)
#@(#)CDS: CTE 21.19-s010_1 () Mar 27 2024 01:55:37 ( )
#@(#)CDS: SYNTECH 21.19-s002_1 () Sep  6 2023 22:17:00 ( )
#@(#)CDS: CPE v21.19-s026
#@(#)CDS: IQuantus/TQuantus 21.1.1-s966 (64bit) Wed Mar 8 10:22:20 PST 2023 (Linux 3.10.0-693.el7.x86_64)

set_global _enable_mmmc_by_default_flow      $CTE::mmmc_default
suppressMessage ENCEXT-2799
set init_design_uniquify 1
set init_verilog ./top_cg.vg
set init_design_netlisttype Verilog
set init_design_settop 1
set init_top_cell top
set init_mmmc_file ./top.mmmc
set init_pwr_net VDD
set init_gnd_net VSS
set init_lef_file {./asap7sc7p5t_28/techlef_misc//asap7_tech_4x_201209.lef ./asap7sc7p5t_28/LEF/scaled//asap7sc7p5t_28_R_4x_220121a.lef}
init_design
setDesignMode -process 7 -node N7
setMultiCpuUsage -localCpu 8
setDesignMode -bottomRoutingLayer 2
setDesignMode -topRoutingLayer 7
globalNetConnect VDD -type pgpin -pin VDD -inst *
globalNetConnect VSS -type pgpin -pin VSS -inst *
floorPlan -site asap7sc7p5t -s 124.2 124.2 6.22 6.22 6.22 6.22 -noSnap
addWellTap -cell TAPCELL_ASAP7_75t_R -cellInterval 12.960 -inRowOffset 1.296
add_tracks -snap_m1_track_to_cell_pins
add_tracks -mode replace -offsets {M5 vertical 0}
deleteAllFPObjects
addWellTap -cell TAPCELL_ASAP7_75t_R -cellInterval 12.960 -inRowOffset 1.296
setPinAssignMode -pinEditInBatch true
editPin -fixOverlap 1 -unit MICRON -spreadDirection clockwise -side LEFT -layer 3 -spreadType center -spacing 2.016 -pin {clk rst_n start {h_in0[5]} {h_in0[4]} {h_in0[3]} {h_in0[2]} {h_in0[1]} {h_in0[0]} {h_in1[5]} {h_in1[4]} {h_in1[3]} {h_in1[2]} {h_in1[1]} {h_in1[0]} {v_in0[5]} {v_in0[4]} {v_in0[3]} {v_in0[2]} {v_in0[1]} {v_in0[0]} {v_in1[5]} {v_in1[4]} {v_in1[3]} {v_in1[2]} {v_in1[1]} {v_in1[0]} {w_in[7]} {w_in[6]} {w_in[5]} {w_in[4]} {w_in[3]} {w_in[2]} {w_in[1]} {w_in[0]}}
editPin -fixOverlap 1 -unit MICRON -spreadDirection clockwise -side RIGHT -layer 3 -spreadType center -spacing 2.016 -pin {done {psum_out0[12]} {psum_out0[11]} {psum_out0[10]} {psum_out0[9]} {psum_out0[8]} {psum_out0[7]} {psum_out0[6]} {psum_out0[5]} {psum_out0[4]} {psum_out0[3]} {psum_out0[2]} {psum_out0[1]} {psum_out0[0]} {psum_out1[12]} {psum_out1[11]} {psum_out1[10]} {psum_out1[9]} {psum_out1[8]} {psum_out1[7]} {psum_out1[6]} {psum_out1[5]} {psum_out1[4]} {psum_out1[3]} {psum_out1[2]} {psum_out1[1]} {psum_out1[0]}}
editPin -snap TRACK -pin *
setPinAssignMode -pinEditInBatch false
legalizePin
setAddRingMode -ring_target default -extend_over_row 0 -ignore_rows 0 -avoid_short 0 -skip_crossing_trunks none -stacked_via_top_layer Pad -stacked_via_bottom_layer M1 -via_using_exact_crossover_size 1 -orthogonal_only true -skip_via_on_pin standardcell -skip_via_on_wire_shape noshape
addRing -nets {VDD VSS} -type core_rings -follow core -layer {top M7 bottom M7 left M6 right M6} -width 2.176 -spacing 0.384 -offset 0.384 -center 0 -threshold 0 -jog_distance 0 -snap_wire_center_to_grid None
setSrouteMode -reset
setSrouteMode -viaConnectToShape noshape
sroute -connect corePin -layerChangeRange {M1(1) M7(1)} -blockPinTarget nearestTarget -floatingStripeTarget {blockring padring ring stripe ringpin blockpin followpin} -deleteExistingRoutes -allowJogging 0 -crossoverViaLayerRange {M1(1) Pad(10)} -nets {VDD VSS} -allowLayerChange 0 -targetViaLayerRange {M1(1) Pad(10)}
editPowerVia -add_vias 1 -orthogonal_only 0
verify_drc
setOptMode -holdTargetSlack 0.020
setOptMode -setupTargetSlack 0.020
place_opt_design
setTieHiLoMode -maxFanout 5
addTieHiLo -prefix TIE -cell {TIELOx1_ASAP7_75t_R TIEHIx1_ASAP7_75t_R}
ccopt_design
legalizePin
routeDesign
editPowerVia -delete_vias 1 -top_layer 7 -bottom_layer 6
editPowerVia -delete_vias 1 -top_layer 6 -bottom_layer 5
editPowerVia -delete_vias 1 -top_layer 5 -bottom_layer 4
editPowerVia -delete_vias 1 -top_layer 4 -bottom_layer 3
editPowerVia -delete_vias 1 -top_layer 3 -bottom_layer 2
editPowerVia -delete_vias 1 -top_layer 2 -bottom_layer 1
editPowerVia -add_vias 1
setAnalysisMode -analysisType onChipVariation
setSIMode -enable_glitch_report true
setSIMode -enable_glitch_propagation true
setSIMode -enable_delay_report true
optDesign -postRoute
optDesign -postRoute -hold
verify_drc > ./reports/drc_final.rpt
setStreamOutMode -reset
streamOut outputs/gds/top_apr_cg.gds -mapFile ./asap7sc7p5t_28/GDS/gds2.map -libName DesignLib -uniquifyCellNames -outputMacros
defOut -netlist ./outputs/top_apr_cg_lvs.v
report_timing -max_paths 10 > ./timingReports/top_postRoute_setup.summary
report_timing -max_paths 10 -nworst 100 > ./timingReports/top_postRoute_all_paths.summary
report_timing -max_paths 5 > ./timingReports/icg_timing.rpt
report_power > ./reports/power_postRoute.rpt
report_area > ./reports/area_postRoute.rpt
report_analysis_summary > ./reports/analysis_summary.rpt
set defOutLefVia 1
set defOutLefNDR 1
defOut -netlist -routing -allLayers outputs/top_apr_cg_v21.def
saveNetlist outputs/top_apr_cg.v
saveNetlist outputs/top_apr_cg_pg.v -includePowerGround -excludeLeafCell
rcOut -rc_corner rc_typ_25 -spef outputs/top_apr_cg.spef
saveDesign outputs/top_apr_final.enc
setStreamOutMode -reset
streamOut outputs/top1.gds.gz -mapFile ./asap7sc7p5t_28/GDS/gds2.map -libName DesignLib -uniquifyCellNames -outputMacros -stripes 1 -mode ALL -units 4000 -reportFile ./report/top/gds_stream_out_final.rpt -merge { ./asap7sc7p5t_28/GDS/asap7sc7p5t_28_R_220121a_scaled4x.gds}
