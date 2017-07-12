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
	--GROUP 1: Clock signals.
		xclk_in_0			: in	std_logic; --Takes in four different xclk signals. frequencies are unknown...
		xclk_in_1			: in	std_logic;
		xclk_in_2			: in	std_logic;
		xclk_in_3			: in	std_logic;
		--Group 2: Input signals (probably from ACDC cards)
		xDCin_0				: in	std_logic_vector(3 downto 0); --8 DC_in signals. most likely we have one for each ACDC. 
		xDCin_1				: in	std_logic_vector(3 downto 0); --bits 0 and 1 are for receiving data. bit 2 is for trigger back (what this means is unclear)
		xDCin_2				: in	std_logic_vector(3 downto 0); --bit 3 gives lvds_status. 
		xDCin_3				: in	std_logic_vector(3 downto 0);
		xDCin_4				: in	std_logic_vector(3 downto 0);
		xDCin_5				: in	std_logic_vector(3 downto 0);
		xDCin_6				: in	std_logic_vector(3 downto 0);
		xDCin_7				: in	std_logic_vector(3 downto 0);
		--Group 3: Output Signals (Probably goes to ACDC cards)
		xDCout_0				: out	std_logic_vector(2 downto 0); --8 DCout lines. most likely we have on out for each of the 8 ACDC cards. 
		xDCout_1				: out	std_logic_vector(2 downto 0); --bit 0 is for data transmission. bit 1 is a dedicated trigger line. bit 2 is an lvds set up line.
		xDCout_2				: out	std_logic_vector(2 downto 0);
		xDCout_3				: out	std_logic_vector(2 downto 0);
		xDCout_4				: out	std_logic_vector(2 downto 0);
		xDCout_5				: out	std_logic_vector(2 downto 0);
		xDCout_6				: out	std_logic_vector(2 downto 0);
		xDCout_7				: out	std_logic_vector(2 downto 0);
		--Group 4: Output clock signals.
		xglobal_reset		: out	std_logic; --probably is what it sounds like.
		xclk_sys				: out	std_logic; -- system clock output. Goes to the other 2 blocks. 
		xclk_1Hz				: out	std_logic; -- 1Hz clock signal that goes to an LED.
		xclk_10Hz			: out	std_logic; -- 10Hz clock signal that is not connected to anything.
		xclk_1kHz			: out	std_logic; --1kHz clock signal that is not connected to anything.
	
		--Group 5: Information about starting/ending sent from USB_WRAPPER. 
		--num_front_end_boards might be 8.
		xInstruction		: in	std_logic_vector(instruction_size-1 downto 0);  --a std_logic vector that goes from instruction_size-1 down to 0. instruction size might be 32.  
		xInstruct_Rdy		: in	std_logic; --input from from USB wrapper.  
		xtrig					: in	std_logic_vector(num_front_end_boards-1 downto 0); --comes from the trig and time block. It is a vector going from num_front_end_boards-1 down to 0.
		xfe_mask				: in	std_logic_vector(num_front_end_boards-1 downto 0); --same size as the previous vector. Comes from the usb wrapper block. 
		xdone					: in	std_logic_vector(num_front_end_boards-1 downto 0); --same size as the previous. Comes from the usb wrapper.
		--xready				: in	std_logic_vector(num_front_end_boards-1 downto 0);
		xready				: in	std_logic; --regular std_logic input. Also comes from the USB_wrapper. 
		
		--Group 6: Input and output signals for aligning data strobes. Goes to and from USB_wrapper. 
		xalign_strobe		: in	std_logic_vector(num_front_end_boards-1 downto 0); --std_logic vector from num_front_end_boards-1 down to 0. Input that comes from USB wrapper.
		xalign_good			: out	std_logic_vector(num_front_end_boards-1 downto 0); --std_logic vector from num_front_end_boards-1 down to 0. Output that goes to USB wrapper. 

		--Group 7: Ram-related signals (for reading out ram)
		--num_rx_rams is 2
		xRxRAM_RdEn 		: in	std_logic_vector(num_front_end_boards-1 downto 0); --input std_logic vector from num_front_end_boards-1 down to 0. Input that comes from USB_Wrapper. 
		xRxRAM_Address		: in	std_logic_vector(transceiver_mem_depth-1 downto 0);--input std_logic vector from tranceiver_mem_depth-1 down to 0. comes from USB_wrapper.
		xRxRAM_RdClk		: in	std_logic;   --input std_logic from usb_wrapper.
		xRxRAM_Full			: out	rx_ram_flag_type; --output rx_ram_flag_type goes to the USB_wrapper (not sure where the type is defined, possibly in the work_def_all library) (7..0 1..0)
		xRxData				: out	rx_ram_data_type;	--output rx_ram_data_type that goes to the USB_wrapper (the type is possibly defined in the same library as above) 
		--For the previous two data, 7..0 possibly corresponds to the 8 ACDC cards; 2..0 possibly corresponds to whether it's full/not; 15..0 may indicate its voltage
		xRxRAM_readsel		: in	std_logic_vector(num_rx_rams-1 downto 0); --input standard_logic two element vector; the digit 0 comes from VCC and digit 1 comes from GND
		xRxRAM_writesel	: in	std_logic_vector(num_rx_rams-1 downto 0); -- intput std_logic_vector (2 elements); the same as the previous one
		
		--Group 8: we are not sure about this one
		xclk_sys4X			: out	std_logic; --std_logic output that goes to triggerandtime block; its frequency probably is four times that of the system clock
		xCatchDCpkt			: out std_logic_vector(num_front_end_boards-1 downto 0); --std_logic vector (7..0) that goes to usb_wrapper
		xDigzFlagACDC		: out std_logic_vector(num_front_end_boards-1 downto 0); --std_logic vector (7..0) that goes to usb_wrapper
		xsend_reset_flag	: in	std_logic; -- std_logic input that comes from usb-Wrapper
		xUSBWakeup			: in	std_logic); --std_logic input that comes from a vcc (a clock signal from pin). NOTE: the pin is a bidirectional thing on the USB_wrapper

end ACC_main;
	
architecture Behavioral of	ACC_main is

	signal	reset_global			:	std_logic; --it later gets mapped to xglobal_reset which is an output to the globe
	signal	clock_1MHz				:	std_logic; --1Mhz clock that is later mapped to some port
	signal	clock_sys				:	std_logic; --system clock that is mapped to xclck_sys (an output to all other modules) and later gets mapped to some port
	signal	clock_sys4x				:	std_logic; --gets mapped to xclk_sys4x (an output to triggerandtime). NOTE: it has four times the frequency of clock_sys
	signal   clock_rx_1				: 	std_logic; --it's mapped to the first four digits of clock_rx
	signal   clock_rx_2				: 	std_logic; --mapped to the last four digits of the clock_rx
	signal   clocks_rx				:  std_logic_vector(num_front_end_boards-1 downto 0); --it's port mapped into a transceiver component (probably used to receive data)
	
	signal 	clock_FPGA_PLLlock	:	std_logic; --port mapped to a lot of components

	type rx_serdes_type is array(num_front_end_boards-1 downto 0) of --defined type: like a 8 by 2 matrix: each signal has 8 elements, each element is made of 2 pieces
		std_logic_vector(1 downto 0);                                 --NOTE: similar to line 85~86 (types possibly defined in the work library)
	signal	rx_serdes				: 	rx_serdes_type;  --1. port mapped to a transceiver component; 2. mapped to xDCin_x() (possibly, the xDCin_x comes from ACDC; if this is the case
																		--then rx_serdes functions to receive data from ACDC)
	signal 	tx_serdes				: 	std_logic_vector(num_front_end_boards-1 downto 0); --1. port mapped to a transceiver component; 2. mapped to xDCout_x() (similar to the previous signal)
	signal	trigger_to_fe			: 	std_logic_vector(num_front_end_boards-1 downto 0); --only port mapped to a CC_send_trig in the transceiver component
	signal	packet_from_fe_rec	: 	std_logic_vector(num_front_end_boards-1 downto 0); --1. port mapped to the transceiver component; 2. mapped to xCatchDCpkt (output 8-vector to usbwrapper)
	signal	lvds_aligned_tx		:	std_logic_vector(num_front_end_boards-1 downto 0); --1. port mapped to transceiver component; 2. mapped to the (3) digit of xDCin

begin

xglobal_reset <= reset_global;

--map signals to AC/DC serial links
-----------------------------------
--RX: 
--Note: for rx_serdes(c)(r): c refers to the "column" number and r refers to the "row" number
--Fill up the serdes matrix with serdes rx data.
rx_serdes(0)(0)	<= xDCin_0(0); --rx_serdes(y)(z) is assigned to xDCin_y(z)
rx_serdes(0)(1)	<= xDCin_0(1); --each column of rx_serdes is assigned to the rx_data of one of the ACDC cards. 
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

xDigzFlagACDC(0)  <= xDCin_0(2); --xDigzFlagACDC(y) = xDCin_y(2) for y = 0..7. 
xDigzFlagACDC(1)	<= xDCin_1(2); --assigns xDigzFlagACDC to the trigger back. 
xDigzFlagACDC(2)	<= xDCin_2(2); --might be telling us whether or not the ACDC card 
xDigzFlagACDC(3)	<= xDCin_3(2); --is digitizing data. 
xDigzFlagACDC(4)	<= xDCin_4(2);
xDigzFlagACDC(5)	<= xDCin_5(2);
xDigzFlagACDC(6)	<= xDCin_6(2);
xDigzFlagACDC(7)	<= xDCin_7(2);


lvds_aligned_tx(0)<= xDCin_0(3); --assigns lvds_aligned_tx(y) to xDCin_y(3).  
lvds_aligned_tx(1)<= xDCin_1(3); --possibly is telling us whether or not things are aligned.
lvds_aligned_tx(2)<= xDCin_2(3);
lvds_aligned_tx(3)<= xDCin_3(3);
lvds_aligned_tx(4)<= xDCin_4(3);
lvds_aligned_tx(5)<= xDCin_5(3);
lvds_aligned_tx(6)<= xDCin_6(3);
lvds_aligned_tx(7)<= xDCin_7(3);
--TX:
xDCout_0(0)			<=	tx_serdes(0); -- assigns xDCout_y(0) = tx_serdes(y). 
xDCout_1(0)			<=	tx_serdes(1); --similar to what we did with rx_data. 
xDCout_2(0)			<=	tx_serdes(2);
xDCout_3(0)			<=	tx_serdes(3);
xDCout_4(0)			<=	tx_serdes(4);
xDCout_5(0)			<=	tx_serdes(5);
xDCout_6(0)			<=	tx_serdes(6);
xDCout_7(0)			<=	tx_serdes(7);
xDCout_0(1)			<=	xtrig(0); --assigns xDCout_y(1) to xtrig(y). 
xDCout_1(1)			<=	xtrig(1); --a line for sending triggers to the ACDC cards?
xDCout_2(1)			<=	xtrig(2);
xDCout_3(1)			<=	xtrig(3);
xDCout_4(1)			<=	xtrig(4);
xDCout_5(1)			<=	xtrig(5);
xDCout_6(1)			<=	xtrig(6);
xDCout_7(1)			<=	xtrig(7);
xDCout_0(2)			<=	xalign_strobe(0); --assigns xDCout_y(2) to xalign_strobe(y). 
xDCout_1(2)			<=	xalign_strobe(1); --sets up lvds for each ACDC card. 
xDCout_2(2)			<=	xalign_strobe(2);
xDCout_3(2)			<=	xalign_strobe(3);
xDCout_4(2)			<=	xalign_strobe(4);
xDCout_5(2)			<=	xalign_strobe(5);
xDCout_6(2)			<=	xalign_strobe(6);
xDCout_7(2)			<=	xalign_strobe(7);
-------------------------------------

xclk_sys4X  <= clock_sys4x; --maps some external signals to internal signals. 
xclk_sys  	<= clock_sys;
	
xCatchDCpkt <= packet_from_fe_rec;
--This clock takes the four different clock signals as inputs, and gives new clock signals as outputs. 
xCLOCKS : entity work.Clock_Manager(Structural) --All inputs and outputs are standard logic. 
	port map(
		Reset			=> reset_global, --input to clock_manager. 
		INCLK0		=> xclk_in_0, --input to clock_manager.
		INCLK1		=> xclk_in_1, --input to clock_manager.
		INCLK2		=> xclk_in_2, --input to clock_manager.
		INCLK3		=> xclk_in_3, --input to clock_manager. 
		PLL_reset	=>	'0', --input which is always 0.
		CLK_SYS_4x	=> clock_sys4x, --outputs of the Clock_Manager from here on down to fpgaPLLlock. 
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