set_clock_latency -source -early -max -rise  -64.494 [get_ports {clk}] -clock clk 
set_clock_latency -source -early -max -fall  -66.3381 [get_ports {clk}] -clock clk 
set_clock_latency -source -late -max -rise  -64.494 [get_ports {clk}] -clock clk 
set_clock_latency -source -late -max -fall  -66.3381 [get_ports {clk}] -clock clk 
