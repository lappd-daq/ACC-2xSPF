#**************************************************************
# Create Clock
#**************************************************************
derive_pll_clocks -create_base_clocks -use_net_name
derive_clock_uncertainty -add

set_false_path -from *signaltap*
set_false_path -to *signaltap*

create_clock -period "125.0 MHz" [get_ports CLOCKIN]
create_clock -period "125.0 MHz" [get_ports CLOCKIN1]
create_clock -period "125.0 MHz" [get_ports CLOCKIN2]
create_clock -period "125.0 MHz" [get_ports CLOCKIN3]
create_clock -period "48.0 MHz" [get_ports USB_IFCLK]

#Clock Generation for PLL clocks
#create_generated_clock -name   -source [get_nets {inst134|pll_new_inst|altera_pll_i|arriav_pll|divclk[0]}] -divide_by 1 -multiply_by 1 -duty_cycle 50 -phase 0 -offset 0 
