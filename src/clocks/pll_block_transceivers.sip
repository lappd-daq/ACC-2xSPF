set_global_assignment -entity "pll_block_transceivers" -library "lib_pll_block_transceivers" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "pll_block_transceivers" -library "lib_pll_block_transceivers" -name IP_TOOL_VERSION "18.0"
set_global_assignment -entity "pll_block_transceivers" -library "lib_pll_block_transceivers" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_pll_block_transceivers" -name SPD_FILE [file join $::quartus(sip_path) "pll_block_transceivers.spd"]

set_global_assignment -library "lib_pll_block_transceivers" -name MISC_FILE [file join $::quartus(sip_path) "pll_block_transceivers_sim/pll_block_transceivers.vho"]
