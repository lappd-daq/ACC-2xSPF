---------------------------------------------------------------------------------
-- Univ. of Chicago  
--    
--
-- PROJECT:      ANNIE 
-- FILE:         ACC_main.vhd
-- AUTHOR:       e oberla
-- EMAIL         ejo@uchicago.edu
-- DATE:         
--
-- DESCRIPTION:  top level ACC
--
---------------------------------------------------------------------------------

library IEEE; 
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.defs.all;
-------
--wiring of LVDS links as follows:
------------------------------------
--  DCin_x(0)  = serdes rx data (0)	
--  DCin_x(1)  = serdes rx data (1)
--  DCin_x(2)  = dedicated trigger back
--  DCin_x(3)  = dedicated lvds status
--
--  DCout_x(0) = serdes tx data
--  DCout_x(1) = dedicated trigger line
--  DCout_x(2) = dedicated setup lvds line
--  DCout_x(3) = system clk (bypasses FPGA, no FPGA pin assignment)
------------------------------------

entity ACC_main is
	port(	
		xclk_in_0			: in	std_logic;
		xclk_in_1			: in	std_logic;
		xclk_in_2			: in	std_logic;
		xclk_in_3			: in	std_logic;
		
		xDCin_0				: in	std_logic_vector(3 downto 0);
		xDCin_1				: in	std_logic_vector(3 downto 0);
		xDCin_2				: in	std_logic_vector(3 downto 0);
		xDCin_3				: in	std_logic_vector(3 downto 0);
		xDCin_4				: in	std_logic_vector(3 downto 0);
		xDCin_5				: in	std_logic_vector(3 downto 0);
		xDCin_6				: in	std_logic_vector(3 downto 0);
		xDCin_7				: in	std_logic_vector(3 downto 0);
		
		xDCout_0				: out	std_logic_vector(2 downto 0);
		xDCout_1				: out	std_logic_vector(2 downto 0);
		xDCout_2				: out	std_logic_vector(2 downto 0);
		xDCout_3				: out	std_logic_vector(2 downto 0);
		xDCout_4				: out	std_logic_vector(2 downto 0);
		xDCout_5				: out	std_logic_vector(2 downto 0);
		xDCout_6				: out	std_logic_vector(2 downto 0);
		xDCout_7				: out	std_logic_vector(2 downto 0);
		
		xglobal_reset		: out	std_logic;
		xclk_sys				: out	std_logic;
		xclk_1Hz				: out	std_logic;
		xclk_10Hz			: out	std_logic;
		xclk_1kHz			: out	std_logic;
		
		xInstruction		: in	std_logic_vector(instruction_size-1 downto 0);
		xInstruct_Rdy		: in	std_logic;
		xtrig					: in	std_logic_vector(num_front_end_boards-1 downto 0);
		xfe_mask				: in	std_logic_vector(num_front_end_boards-1 downto 0);
		xdone					: in	std_logic_vector(num_front_end_boards-1 downto 0);
		--xready				: in	std_logic_vector(num_front_end_boards-1 downto 0);
		xready				: in	std_logic;
		
		xalign_strobe		: in	std_logic_vector(num_front_end_boards-1 downto 0);
		xalign_good			: out	std_logic_vector(num_front_end_boards-1 downto 0);

		xRxRAM_RdEn 		: in	std_logic_vector(num_front_end_boards-1 downto 0);
		xRxRAM_Address		: in	std_logic_vector(transceiver_mem_depth-1 downto 0);
		xRxRAM_RdClk		: in	std_logic;
		xRxRAM_Full			: out	rx_ram_flag_type;
		xRxData				: out	rx_ram_data_type;	
		xRxRAM_readsel		: in	std_logic_vector(num_rx_rams-1 downto 0);
		xRxRAM_writesel	: in	std_logic_vector(num_rx_rams-1 downto 0);
		
		xclk_sys4X			: out	std_logic;
		xCatchDCpkt			: out std_logic_vector(num_front_end_boards-1 downto 0);
		xDigzFlagACDC		: out std_logic_vector(num_front_end_boards-1 downto 0);
		xsend_reset_flag	: in	std_logic;
		xUSBWakeup			: in	std_logic);

end ACC_main;
	
architecture Behavioral of	ACC_main is

	signal	reset_global			:	std_logic;
	signal	clock_1MHz				:	std_logic;
	signal	clock_sys				:	std_logic;
	signal	clock_sys4x				:	std_logic;
	signal   clock_rx_1				: 	std_logic;
	signal   clock_rx_2				: 	std_logic;
	signal   clocks_rx				:  std_logic_vector(num_front_end_boards-1 downto 0);
	
	signal 	clock_FPGA_PLLlock	:	std_logic;

	type rx_serdes_type is array(num_front_end_boards-1 downto 0) of
		std_logic_vector(1 downto 0); 
	signal	rx_serdes				: 	rx_serdes_type;
	signal 	tx_serdes				: 	std_logic_vector(num_front_end_boards-1 downto 0);
	signal	trigger_to_fe			: 	std_logic_vector(num_front_end_boards-1 downto 0);
	signal	packet_from_fe_rec	: 	std_logic_vector(num_front_end_boards-1 downto 0);
	signal	lvds_aligned_tx		:	std_logic_vector(num_front_end_boards-1 downto 0);

begin

xglobal_reset <= reset_global;

--map signals to AC/DC serial links
-----------------------------------
--RX:
rx_serdes(0)(0)	<= xDCin_0(0);
rx_serdes(0)(1)	<= xDCin_0(1);
rx_serdes(1)(0)	<= xDCin_1(0);
rx_serdes(1)(1)	<= xDCin_1(1);
rx_serdes(2)(0)	<= xDCin_2(0);
rx_serdes(2)(1)	<= xDCin_2(1);
rx_serdes(3)(0)	<= xDCin_3(0);
rx_serdes(3)(1)	<= xDCin_3(1);
rx_serdes(4)(0)	<= xDCin_4(0);
rx_serdes(4)(1)	<= xDCin_4(1);
rx_serdes(5)(0)	<= xDCin_5(0);
rx_serdes(5)(1)	<= xDCin_5(1);
rx_serdes(6)(0)	<= xDCin_6(0);
rx_serdes(6)(1)	<= xDCin_6(1);
rx_serdes(7)(0)	<= xDCin_7(0);
rx_serdes(7)(1)	<= xDCin_7(1);
xDigzFlagACDC(0)  <= xDCin_0(2);
xDigzFlagACDC(1)	<= xDCin_1(2);
xDigzFlagACDC(2)	<= xDCin_2(2);
xDigzFlagACDC(3)	<= xDCin_3(2);
xDigzFlagACDC(4)	<= xDCin_4(2);
xDigzFlagACDC(5)	<= xDCin_5(2);
xDigzFlagACDC(6)	<= xDCin_6(2);
xDigzFlagACDC(7)	<= xDCin_7(2);
lvds_aligned_tx(0)<= xDCin_0(3);
lvds_aligned_tx(1)<= xDCin_1(3);
lvds_aligned_tx(2)<= xDCin_2(3);
lvds_aligned_tx(3)<= xDCin_3(3);
lvds_aligned_tx(4)<= xDCin_4(3);
lvds_aligned_tx(5)<= xDCin_5(3);
lvds_aligned_tx(6)<= xDCin_6(3);
lvds_aligned_tx(7)<= xDCin_7(3);
--TX:
xDCout_0(0)			<=	tx_serdes(0);
xDCout_1(0)			<=	tx_serdes(1);
xDCout_2(0)			<=	tx_serdes(2);
xDCout_3(0)			<=	tx_serdes(3);
xDCout_4(0)			<=	tx_serdes(4);
xDCout_5(0)			<=	tx_serdes(5);
xDCout_6(0)			<=	tx_serdes(6);
xDCout_7(0)			<=	tx_serdes(7);
xDCout_0(1)			<=	xtrig(0);
xDCout_1(1)			<=	xtrig(1);
xDCout_2(1)			<=	xtrig(2);
xDCout_3(1)			<=	xtrig(3);
xDCout_4(1)			<=	xtrig(4);
xDCout_5(1)			<=	xtrig(5);
xDCout_6(1)			<=	xtrig(6);
xDCout_7(1)			<=	xtrig(7);
xDCout_0(2)			<=	xalign_strobe(0);
xDCout_1(2)			<=	xalign_strobe(1);
xDCout_2(2)			<=	xalign_strobe(2);
xDCout_3(2)			<=	xalign_strobe(3);
xDCout_4(2)			<=	xalign_strobe(4);
xDCout_5(2)			<=	xalign_strobe(5);
xDCout_6(2)			<=	xalign_strobe(6);
xDCout_7(2)			<=	xalign_strobe(7);
-------------------------------------

xclk_sys4X  <= clock_sys4x;
xclk_sys  	<= clock_sys;
	
xCatchDCpkt <= packet_from_fe_rec;

xCLOCKS : entity work.Clock_Manager(Structural)
	port map(
		Reset			=> reset_global,
		INCLK0		=> xclk_in_0,
		INCLK1		=> xclk_in_1,
		INCLK2		=> xclk_in_2,
		INCLK3		=> xclk_in_3,
		PLL_reset	=>	'0',
		CLK_SYS_4x	=> clock_sys4x, 		
		CLK_SYS		=> clock_sys,
		CLK_SYS_1rx	=> clock_rx_1,
		CLK_SYS_2rx	=> clock_rx_2,
		CLK_1MHz		=> clock_1MHz,		
		CLK_1Hz		=> xclk_1Hz,
		CLK_10Hz		=> xclk_10Hz,
		CLK_1kHz		=> xclk_1kHz,		
		fpgaPLLlock => clock_FPGA_PLLlock);
		
xRESET_BLOCK : entity work.progreset(Behavioral)
	generic map(
		USE_USB		=> '0',
		STARTUP_CNT => (others=>'0'))
	port map(
		CLK			=> clock_1MHz,
		CLK_RDY		=> clock_FPGA_PLLlock,
		PULSE_RES	=> xsend_reset_flag,
		WAKEUP_USB	=> xUSBWakeup,
		Reset			=> reset_global,
		Reset_b		=> open);

--clocks for transceiver channels come from 2 PLL's
--partitioned in 2 banks:
clocks_rx(0)	<= clock_rx_1;
clocks_rx(1)	<= clock_rx_1;
clocks_rx(2)	<= clock_rx_1;
clocks_rx(3)	<= clock_rx_1;
clocks_rx(4)	<= clock_rx_2;
clocks_rx(5)	<= clock_rx_2;
clocks_rx(6)	<= clock_rx_2;
clocks_rx(7)	<= clock_rx_2;

ACDCintercom0	:	 for i in num_front_end_boards-1 downto 0 generate
	xTRANSCEIVERS : entity work.transceivers(rtl)
	
	port map(
		xCLR_ALL				=> reset_global,
		xALIGN_ACTIVE		=> xalign_strobe(i),
		xALIGN_SUCCESS 	=> xalign_good(i),
		
		xCLK					=> clock_sys,
		xRX_CLK				=> clocks_rx(i),
		
		xRX_LVDS_DATA		=> rx_serdes(i),
		xTX_LVDS_DATA		=>	tx_serdes(i),
		
		xCC_INSTRUCTION	=>	xInstruction,
		xCC_INSTRUCT_RDY	=> xInstruct_Rdy,
		xTRIGGER				=> xtrig(i),
		xCC_SEND_TRIGGER	=> trigger_to_fe(i),
		 
		xRAM_RD_EN			=> xRxRAM_RdEn(i),
		xRAM_ADDRESS		=> xRxRAM_Address,
		xRAM_CLK				=> xRxRAM_RdClk,
		xRAM_FULL_FLAG		=> xRxRAM_Full(i),
		xRAM_DATA			=> xRxData(i),
		xRAM_SELECT_WR		=> xRxRAM_writesel,
		xRAM_SELECT_RD		=> xRxRAM_readsel,

		xALIGN_INFO			=> open,
		xCATCH_PKT			=> packet_from_fe_rec(i),
		
		xDONE					=> xdone(i),
		xDC_MASK				=> xfe_mask(i),
		xPLL_LOCKED			=>	clock_FPGA_PLLlock,
		xFE_ALIGN_SUCCESS	=> lvds_aligned_tx(i),
		xSOFT_RESET			=> xready);
	end generate;
	

		

end Behavioral;