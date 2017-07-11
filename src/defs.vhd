---------------------------------------------------------------------------------
-- Univ. of Chicago  
--    
-- PROJECT:      ANNIE 
-- FILE:         defs.vhd
-- AUTHOR:       e oberla
-- EMAIL         ejo@uchicago.edu
-- DATE:         
--
-- DESCRIPTION:  definitions
--
---------------------------------------------------------------------------------


library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

package defs is

--system instruction size
constant instruction_size		:	integer := 32;

--number of front-end boards (either 4 or 8, depending on RJ45 port installation)
constant num_front_end_boards	:	integer := 8;

--RAM specifiers for tranceiver block
constant	transceiver_mem_depth	:	integer := 15; --ram address size
constant	transceiver_mem_width	:	integer := 16; --data size
constant	ser_factor				:	integer := 8;
constant num_rx_rams				:	integer := 2; --number of ram event buffers on serdes rx

--defs for the SERDES links
constant STARTWORD				: 	std_logic_vector := x"1234";
constant STARTWORD_8a			: 	std_logic_vector := x"B7";
constant STARTWORD_8b			: 	std_logic_vector := x"34";
constant ENDWORD					: 	std_logic_vector := x"4321";

constant ALIGN_WORD_16 			: 	std_logic_vector := x"FACE";
constant ALIGN_WORD_8 			:  std_logic_vector := x"CE";


type rx_ram_flag_type is array(num_front_end_boards-1 downto 0) of
	std_logic_vector(num_rx_rams-1 downto 0);
type rx_ram_data_type is array(num_front_end_boards-1 downto 0) of
	std_logic_vector(transceiver_mem_width-1 downto 0);

		
end defs;
