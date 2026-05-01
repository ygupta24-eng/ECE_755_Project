lappend search_path "/filespace/v/vsathishkuma/ECE755/ECE_755_Project/RTL_Design"

analyze -library work -format sverilog \
 {/filespace/v/vsathishkuma/ECE755/ECE_755_Project/RTL_Design/top.sv \
	 /filespace/v/vsathishkuma/ECE755/ECE_755_Project/RTL_Design/control.sv \
	 /filespace/v/vsathishkuma/ECE755/ECE_755_Project/RTL_Design/pe_update.sv \
	 /filespace/v/vsathishkuma/ECE755/ECE_755_Project/RTL_Design/zigzag.sv \
	 /filespace/v/vsathishkuma/ECE755/ECE_755_Project/RTL_Design/fifo9.sv
}
