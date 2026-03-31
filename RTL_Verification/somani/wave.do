onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -radix decimal /top_tb/clk
add wave -noupdate -radix decimal /top_tb/rst_n
add wave -noupdate -radix decimal /top_tb/start
add wave -noupdate -radix decimal /top_tb/done
add wave -noupdate -radix unsigned /top_tb/h_in0
add wave -noupdate -radix unsigned /top_tb/h_in1
add wave -noupdate -radix decimal /top_tb/v_in0
add wave -noupdate -radix decimal /top_tb/v_in1
add wave -noupdate -radix decimal /top_tb/w_in
add wave -noupdate -radix decimal /top_tb/psum_out0
add wave -noupdate -radix decimal /top_tb/psum_out1
add wave -noupdate -divider enables
add wave -noupdate -radix binary /top_tb/iDUT/en
add wave -noupdate -radix binary /top_tb/iDUT/move_en
add wave -noupdate -radix binary /top_tb/iDUT/w_ld_en
add wave -noupdate -radix binary /top_tb/iDUT/fifo_en
add wave -noupdate -radix binary /top_tb/iDUT/psum_shift_en
add wave -noupdate -radix binary /top_tb/iDUT/psum_clr
add wave -noupdate -radix binary /top_tb/iDUT/direction
add wave -noupdate /top_tb/iDUT/u_fsm/state
add wave -noupdate -divider activations
add wave -noupdate -radix unsigned {/top_tb/iDUT/u_pe_array/g_pe_row[3]/g_pe_col[3]/u_pe/act_val}
add wave -noupdate -radix unsigned {/top_tb/iDUT/u_pe_array/g_pe_row[2]/g_pe_col[3]/u_pe/act_val}
add wave -noupdate -radix unsigned {/top_tb/iDUT/u_pe_array/g_pe_row[2]/g_pe_col[2]/u_pe/act_val}
add wave -noupdate -radix unsigned {/top_tb/iDUT/u_pe_array/g_pe_row[3]/g_pe_col[2]/u_pe/act_val}
add wave -noupdate -radix unsigned {/top_tb/iDUT/u_pe_array/g_pe_row[3]/g_pe_col[1]/u_pe/act_val}
add wave -noupdate -radix unsigned {/top_tb/iDUT/u_pe_array/g_pe_row[2]/g_pe_col[1]/u_pe/act_val}
add wave -noupdate -radix unsigned {/top_tb/iDUT/u_pe_array/g_pe_row[2]/g_pe_col[0]/u_pe/act_val}
add wave -noupdate -radix unsigned {/top_tb/iDUT/u_pe_array/g_pe_row[3]/g_pe_col[0]/u_pe/act_val}
add wave -noupdate -radix unsigned {/top_tb/iDUT/u_pe_array/g_pe_row[1]/g_pe_col[3]/u_pe/act_val}
add wave -noupdate -radix unsigned {/top_tb/iDUT/u_pe_array/g_pe_row[0]/g_pe_col[3]/u_pe/act_val}
add wave -noupdate -radix unsigned {/top_tb/iDUT/u_pe_array/g_pe_row[0]/g_pe_col[2]/u_pe/act_val}
add wave -noupdate -radix unsigned {/top_tb/iDUT/u_pe_array/g_pe_row[1]/g_pe_col[2]/u_pe/act_val}
add wave -noupdate -radix unsigned {/top_tb/iDUT/u_pe_array/g_pe_row[1]/g_pe_col[1]/u_pe/act_val}
add wave -noupdate -radix unsigned {/top_tb/iDUT/u_pe_array/g_pe_row[0]/g_pe_col[1]/u_pe/act_val}
add wave -noupdate -radix unsigned {/top_tb/iDUT/u_pe_array/g_pe_row[0]/g_pe_col[0]/u_pe/act_val}
add wave -noupdate -radix unsigned {/top_tb/iDUT/u_pe_array/g_pe_row[1]/g_pe_col[0]/u_pe/act_val}
add wave -noupdate -divider product
add wave -noupdate -radix decimal {/top_tb/iDUT/u_pe_array/g_pe_row[3]/g_pe_col[3]/u_pe/psum_out}
add wave -noupdate -radix decimal {/top_tb/iDUT/u_pe_array/g_pe_row[3]/g_pe_col[2]/u_pe/psum_out}
add wave -noupdate -radix decimal {/top_tb/iDUT/u_pe_array/g_pe_row[3]/g_pe_col[1]/u_pe/psum_out}
add wave -noupdate -radix decimal {/top_tb/iDUT/u_pe_array/g_pe_row[3]/g_pe_col[0]/u_pe/psum_out}
add wave -noupdate -radix decimal {/top_tb/iDUT/u_pe_array/g_pe_row[2]/g_pe_col[3]/u_pe/psum_out}
add wave -noupdate -radix decimal {/top_tb/iDUT/u_pe_array/g_pe_row[2]/g_pe_col[2]/u_pe/psum_out}
add wave -noupdate -radix decimal {/top_tb/iDUT/u_pe_array/g_pe_row[2]/g_pe_col[1]/u_pe/psum_out}
add wave -noupdate -radix decimal {/top_tb/iDUT/u_pe_array/g_pe_row[2]/g_pe_col[0]/u_pe/psum_out}
add wave -noupdate -radix decimal {/top_tb/iDUT/u_pe_array/g_pe_row[3]/g_pe_col[3]/u_pe/product}
add wave -noupdate -radix decimal {/top_tb/iDUT/u_pe_array/g_pe_row[3]/g_pe_col[2]/u_pe/product}
add wave -noupdate -radix decimal {/top_tb/iDUT/u_pe_array/g_pe_row[3]/g_pe_col[1]/u_pe/product}
add wave -noupdate -radix decimal {/top_tb/iDUT/u_pe_array/g_pe_row[3]/g_pe_col[0]/u_pe/product}
add wave -noupdate -radix decimal {/top_tb/iDUT/u_pe_array/g_pe_row[2]/g_pe_col[3]/u_pe/product}
add wave -noupdate -radix decimal {/top_tb/iDUT/u_pe_array/g_pe_row[2]/g_pe_col[2]/u_pe/product}
add wave -noupdate -radix decimal {/top_tb/iDUT/u_pe_array/g_pe_row[2]/g_pe_col[1]/u_pe/product}
add wave -noupdate -radix decimal {/top_tb/iDUT/u_pe_array/g_pe_row[2]/g_pe_col[0]/u_pe/product}
add wave -noupdate -divider {upper product}
add wave -noupdate -radix decimal {/top_tb/iDUT/u_pe_array/g_pe_row[1]/g_pe_col[3]/u_pe/psum_out}
add wave -noupdate -radix decimal {/top_tb/iDUT/u_pe_array/g_pe_row[1]/g_pe_col[2]/u_pe/psum_out}
add wave -noupdate -radix decimal {/top_tb/iDUT/u_pe_array/g_pe_row[1]/g_pe_col[1]/u_pe/psum_out}
add wave -noupdate -radix decimal {/top_tb/iDUT/u_pe_array/g_pe_row[1]/g_pe_col[0]/u_pe/psum_out}
add wave -noupdate -radix decimal {/top_tb/iDUT/u_pe_array/g_pe_row[0]/g_pe_col[3]/u_pe/psum_out}
add wave -noupdate -radix decimal {/top_tb/iDUT/u_pe_array/g_pe_row[0]/g_pe_col[2]/u_pe/psum_out}
add wave -noupdate -radix decimal {/top_tb/iDUT/u_pe_array/g_pe_row[0]/g_pe_col[1]/u_pe/psum_out}
add wave -noupdate -radix decimal {/top_tb/iDUT/u_pe_array/g_pe_row[0]/g_pe_col[0]/u_pe/psum_out}
add wave -noupdate -radix decimal {/top_tb/iDUT/u_pe_array/g_pe_row[1]/g_pe_col[3]/u_pe/product}
add wave -noupdate -radix decimal {/top_tb/iDUT/u_pe_array/g_pe_row[1]/g_pe_col[2]/u_pe/product}
add wave -noupdate -radix decimal {/top_tb/iDUT/u_pe_array/g_pe_row[1]/g_pe_col[1]/u_pe/product}
add wave -noupdate -radix decimal {/top_tb/iDUT/u_pe_array/g_pe_row[1]/g_pe_col[0]/u_pe/product}
add wave -noupdate -radix decimal {/top_tb/iDUT/u_pe_array/g_pe_row[0]/g_pe_col[3]/u_pe/product}
add wave -noupdate -radix decimal {/top_tb/iDUT/u_pe_array/g_pe_row[0]/g_pe_col[2]/u_pe/product}
add wave -noupdate -radix decimal {/top_tb/iDUT/u_pe_array/g_pe_row[0]/g_pe_col[1]/u_pe/product}
add wave -noupdate -radix decimal {/top_tb/iDUT/u_pe_array/g_pe_row[0]/g_pe_col[0]/u_pe/product}
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {1559 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 412
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {0 ps} {247 ps}
