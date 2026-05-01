###################################################################

# Created by write_sdc on Mon Apr 27 17:13:06 2026

###################################################################
set sdc_version 2.2

set_units -time ps -resistance kOhm -capacitance fF -voltage V -current mA
set_wire_load_mode segmented
set_load -pin_load 0.01 [get_ports uart_tx]
set_load -pin_load 0.01 [get_ports led_running]
set_load -pin_load 0.01 [get_ports led_done]
set_load -pin_load 0.01 [get_ports led_uart_rx]
set_load -pin_load 0.01 [get_ports led_uart_tx]
create_clock [get_ports clk]  -period 10  -waveform {0 5}
set_clock_uncertainty 0.01  [get_clocks clk]
set_clock_transition -min -fall 32 [get_clocks clk]
set_clock_transition -min -rise 32 [get_clocks clk]
set_clock_transition -max -fall 32 [get_clocks clk]
set_clock_transition -max -rise 32 [get_clocks clk]
set_input_delay -clock clk  25  [get_ports rst_n]
set_input_delay -clock clk  25  [get_ports uart_rx]
set_output_delay -clock clk  0.1  [get_ports uart_tx]
set_output_delay -clock clk  0.1  [get_ports led_running]
set_output_delay -clock clk  0.1  [get_ports led_done]
set_output_delay -clock clk  0.1  [get_ports led_uart_rx]
set_output_delay -clock clk  0.1  [get_ports led_uart_tx]
