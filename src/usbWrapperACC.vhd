---------------------------------------------------------------------------------
-- Univ. of Chicago HEP / electronics design group
--    -- + KICP 2015 --
--
-- PROJECT:      ACC
-- FILE:         usbWrapperACC.vhd
-- AUTHOR:       e.oberla
-- EMAIL         ejo@uchicago.edu
-- DATE:         2016 (modified from 2012 version)
--
-- DESCRIPTION:  specific USB interfacing for ACC project
--
---------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.defs.all;

entity usbWrapperACC is
	generic(
		instruct_width			: integer := 32);

	port (
		IFCLK						: 	in		std_logic;        --usb clock
		WAKEUP					:	in 	std_logic;        --plug-in reset
		CTL     					:	in		std_logic_vector(2 downto 0);
		PA							: 	inout std_logic_vector(7 downto 0);
		
		CLKOUT					:	in		std_logic;
		xUSB_START				:	in		std_logic_vector(num_front_end_boards-1 downto 0);
		xRESET					: 	in		std_logic;
		FD							:	inout	std_logic_vector(15 downto 0);
		RDY						:	out	std_logic_vector(1 downto 0);
		xUSB_DONE				:	out	std_logic_vector(num_front_end_boards-1 downto 0);
		xSOFT_TRIG				:	out	std_logic_vector(num_front_end_boards-1 downto 0);
		xALIGN_LVDS				:	out	std_logic_vector(num_front_end_boards-1 downto 0);
		xSET_DC_MASK			:	out	std_logic_vector(num_front_end_boards-1 downto 0);
		xSLWR						:	out	std_logic;
		
		xCLR_ALL					: 	in   	std_logic;
		
		xADC						: 	in   	rx_ram_data_type;
		xLAST_RD_ADR			: 	in	 	rx_ram_data_type;
		xALIGN_STAT 			: 	in		std_logic_vector(num_front_end_boards-1 downto 0);
		
		xCLK_SYS					: 	in		std_logic;  --sytem clock, for time-domain transfers
		xRADDR					: 	out 	std_logic_vector(transceiver_mem_depth-1 downto 0);
		xRAM_EN					: 	out	std_logic_vector(num_front_end_boards-1 downto 0);
		
		xCC_INFO_0				: 	in		std_logic_vector(15 downto 0);
		xCC_INFO_1				: 	in 	std_logic_vector(15 downto 0);
		xCC_INFO_2				: 	in		std_logic_vector(15 downto 0);
		xCC_INFO_3				: 	in 	std_logic_vector(15 downto 0);
		xCC_INFO_4				: 	in 	std_logic_vector(15 downto 0);
		xCC_INFO_5				: 	in		std_logic_vector(15 downto 0);
		xCC_INFO_6				: 	in 	std_logic_vector(15 downto 0);
		xCC_INFO_7				: 	in 	std_logic_vector(15 downto 0);
		xCC_INFO_8				: 	in		std_logic_vector(15 downto 0);
		xCC_INFO_9				: 	in 	std_logic_vector(15 downto 0);
		
		xALIGN_INFO          :  in		std_logic_vector(11 downto 0);
		xDC_PKT					:  in		std_logic_vector(num_front_end_boards-1 downto 0);
		xCC_SYNC_IN				:  in		std_logic;
				
		xDIGITIZING_FLAG  	:  in		std_logic_vector(num_front_end_boards-1 downto 0);
		
		xCC_INSTRUCTION 		: 	out	std_logic_vector(instruct_width-1 downto 0);
		xINSTRUCT_RDY			: 	out	std_logic;
		xCC_READ_MODE			: 	out 	std_logic_vector(2 downto 0);
		xSET_TRIG_MODE			: 	out 	std_logic;
		xCC_SOFT_FIFO_MANAGE : 	out	std_logic;
		
		xUSBUSY					: 	out  	std_logic;
		xTRIG_DELAY 			: 	out  	std_logic_vector(6 downto 0);
		xRESET_TIMESTAMP 		: 	out  	std_logic;
		xSET_TRIG_SOURCE  	:  out 	std_logic_vector(2 downto 0);
		xHARD_RESET       	: 	out 	std_logic;
		xWAKEUP_USB				:  out   std_logic;
		xCC_SYNC_OUT			:  out	std_logic;
		xTRIG_VALID				: 	out	std_logic;
	   xSOFT_TRIG_BIN			:  out	std_logic_vector(2 downto 0));

		
end usbWrapperACC;

architecture behavioral of usbWrapperACC is

	type 	ALIGN_LVDS_TYPE	is (RESETT, RELAXT);
	signal	ALIGN_LVDS_STATE:	ALIGN_LVDS_TYPE;
	
	type 	WAKEUP_USB_STATE_TYPE	is (RESETT, RELAXT);
	signal	WAKEUP_USB_STATE:	WAKEUP_USB_STATE_TYPE;
	
	type State_type is(st1_WAIT, st1_TARGET);
	signal state : State_type;
-----signals-----------		
	signal WBUSY							:	std_logic;
	signal RBUSY							:	std_logic;
	signal USB_START						:  std_logic;
	signal USB_START_MASK 				:  std_logic_vector(num_front_end_boards-1 downto 0);
	signal CC_USB_START					:  std_logic;
	signal SLWR								:	std_logic;
	signal FPGA_DATA						:	std_logic_vector(15 downto 0);
	signal usb_done						: 	std_logic;
	signal NUM_USB_SAMPLES_IN_PACKET	:	std_logic_vector(23 downto 0);
	
	signal ALIGN_LVDS_FLAG				: 	std_logic;
	signal ALIGN_LVDS_FROM_SOFTWARE 	: 	std_logic := '0';
	signal ALIGN_LVDS_COUNT				: 	std_logic := '1';
	signal read_cc_buffer				: 	std_logic;		
	signal RESET_USB_FROM_SOFTWARE 	: 	std_logic;
	signal WAKEUP_USB_DONE				: 	std_logic;
	signal SET_TRIG_SOURCE				: 	std_logic_vector(2 downto 0);
		
	signal USB_INSTRUCTION				: std_logic_vector(instruct_width-1 downto 0);
	signal USB_INSTRUCT_RDY				: std_logic;

	--signals for CC 32 bit instructions
	signal cc_only_instruct_rdy		: std_logic;
	signal CC_INSTRUCT_RDY				: std_logic;
	signal CC_INSTRUCT_RDY_GOOD		: std_logic;

	signal CC_INSTRUCTION				: std_logic_vector(instruct_width-1 downto 0);
	signal CC_INSTRUCTION_tmp			: std_logic_vector(instruct_width-1 downto 0);
	signal CC_INSTRUCTION_GOOD			: std_logic_vector(instruct_width-1 downto 0);
	--signals for USB commands: synching, interpreting, etc	
	type handle_cc_instruct_state_type is (get_instruct, check_sync, get_synced, send_instruct, be_done );
	
	signal handle_cc_instruct_state: handle_cc_instruct_state_type;
	signal handle_cc_only_instruct_state: handle_cc_instruct_state_type;
				
	signal CC_READ_MODE		: std_logic_vector(2 downto 0);
	signal TRIG_MODE	   	: std_logic;
	signal TRIG_DELAY			: std_logic_vector (6 downto 0);
	signal RESET_DLL_FLAG	: std_logic;
	signal HARD_RESET       : std_logic := '0';
	signal WAKEUP_USB 		: std_logic := '0';
		
	--USB_instructions: TMP, GOOD => for syncing to master clock
	signal trig_valid					: std_logic;
	signal trig_valid_GOOD			: std_logic;
	signal trig_valid_TMP			: std_logic;
	signal trig_valid_CC_only		: std_logic;
	
	signal SOFT_TRIG					: std_logic;
	signal SOFT_TRIG_TMP				: std_logic;
	signal SOFT_TRIG_GOOD			: std_logic;
	
	signal SOFT_TRIG_MASK			: std_logic_vector(num_front_end_boards-1 downto 0);
	signal SOFT_TRIG_MASK_TMP		: std_logic_vector(num_front_end_boards-1 downto 0);
	signal SOFT_TRIG_MASK_GOOD		: std_logic_vector(num_front_end_boards-1 downto 0);
	
	signal SOFT_TRIG_BIN				: std_logic_vector(2 downto 0);
	signal SOFT_TRIG_BIN_TMP		: std_logic_vector(2 downto 0);
	signal SOFT_TRIG_BIN_GOOD		: std_logic_vector(2 downto 0);
	
	signal RESET_TIME					: std_logic;
	signal RESET_TIME_TMP			: std_logic;
	signal RESET_TIME_GOOD			: std_logic;
	
	signal CC_SOFT_DONE				: std_logic;
	signal CC_SOFT_DONE_TMP			: std_logic;
	signal CC_SOFT_DONE_GOOD		: std_logic;
	
	signal INSTRUCT_MASK				: std_logic_vector(num_front_end_boards-1 downto 0);
	signal INSTRUCT_MASK_TMP		: std_logic_vector(num_front_end_boards-1 downto 0);
	signal INSTRUCT_MASK_GOOD		: std_logic_vector(num_front_end_boards-1 downto 0);

	signal SYNC_TRIG			: std_logic;
	signal SYNC_MODE			: std_logic;
	signal SYNC_TIME			: std_logic;
	signal SYNC_RESET			: std_logic;
	--syncing signals between boards 
	signal CC_SYNC				: std_logic;	--from USB, clocked on 48 MHz
	signal CC_SYNC_REG		: std_logic;  	--registered on SYSclock
	signal CC_SYNC_IN_REG	: std_logic;	--registered on SYSclock
	--
	signal done_with_cc_instruction 			: 	std_logic;
	signal ready_for_instruct   	  			: 	std_logic;
	--
	signal done_with_cc_only_instruction 	: 	std_logic;
	signal ready_for_cc_instruct				: 	std_logic;
	signal soft_trig_ready_good  				:	std_logic;
	
	type 	 RESET_STATE is (CLEAR, READY);
	signal xUSB_WAKEUP		: RESET_STATE;
	signal reset_from_usb	: std_logic;
	
	signal USB_TIMEOUT		: std_logic;
	
	begin	
--------------	
	RDY(1) 	<= SLWR;
	xSLWR 	<= SLWR;
--	xUSB_DONE <= usb_done;
	xUSBUSY 	<= (WBUSY or RBUSY);
	xCC_READ_MODE <= CC_READ_MODE;

	xALIGN_LVDS(0) <= ALIGN_LVDS_FLAG or ALIGN_LVDS_FROM_SOFTWARE;
	xALIGN_LVDS(1) <= ALIGN_LVDS_FLAG or ALIGN_LVDS_FROM_SOFTWARE;
	xALIGN_LVDS(2) <= ALIGN_LVDS_FLAG or ALIGN_LVDS_FROM_SOFTWARE;
	xALIGN_LVDS(3) <= ALIGN_LVDS_FLAG or ALIGN_LVDS_FROM_SOFTWARE;
	xALIGN_LVDS(4) <= ALIGN_LVDS_FLAG or ALIGN_LVDS_FROM_SOFTWARE;
	xALIGN_LVDS(5) <= ALIGN_LVDS_FLAG or ALIGN_LVDS_FROM_SOFTWARE;
	xALIGN_LVDS(6) <= ALIGN_LVDS_FLAG or ALIGN_LVDS_FROM_SOFTWARE;
	xALIGN_LVDS(7) <= ALIGN_LVDS_FLAG or ALIGN_LVDS_FROM_SOFTWARE;

	xWAKEUP_USB <= not RESET_USB_FROM_SOFTWARE;
	
	xCC_SOFT_FIFO_MANAGE		<= CC_SOFT_DONE;
	--cc instructions
	xCC_INSTRUCTION	<= CC_INSTRUCTION_GOOD;
	xINSTRUCT_RDY		<= CC_INSTRUCT_RDY_GOOD;
	xSET_DC_MASK		<= INSTRUCT_MASK_GOOD;
	--
	xSET_TRIG_MODE		<= TRIG_MODE;
	xSET_TRIG_SOURCE 	<= SET_TRIG_SOURCE;  
	xTRIG_DELAY 		<= TRIG_DELAY;
	xRESET_TIMESTAMP 	<= RESET_DLL_FLAG;
	xHARD_RESET       <= HARD_RESET;
	xCC_SYNC_OUT		<= CC_SYNC_REG;
	xTRIG_VALID			<= trig_valid;
	
	--reset_from_usb		<= xCLR_ALL;
	
	process(usb_done, xUSB_START, CC_READ_MODE)
	begin
	if usb_done = '1' or xCLR_ALL = '1' or USB_TIMEOUT= '1'then	
		USB_START <= '0';
		USB_START_MASK <= (others=>'0');
	elsif (xUSB_START(0) = '1' and CC_READ_MODE = "001") or
			(xUSB_START(1) = '1' and CC_READ_MODE = "010") or
			(xUSB_START(2) = '1' and CC_READ_MODE = "011") or
			(xUSB_START(3) = '1' and CC_READ_MODE = "100") then	
			
				USB_START <= '1';
				
				if CC_READ_MODE = "001" then	
					USB_START_MASK <= "00000001";
				
				elsif CC_READ_MODE = "010" then	
					USB_START_MASK <= "00000010";
				
				elsif CC_READ_MODE = "011" then	
					USB_START_MASK <= "00000100";
				
				elsif CC_READ_MODE = "100" then	
					USB_START_MASK <= "00001000";
				
				else
					USB_START_MASK <= (others=>'0');
				end if;

	else
		USB_START <= '0';
		USB_START_MASK <= (others=>'0');
	end if;
	end process;
		
	
	process(usb_done, CC_READ_MODE)
	begin
		if usb_done = '0' then
			xUSB_DONE <= (others=>'0');
		elsif usb_done = '1' then
			
			case CC_READ_MODE is
				when "001" =>
					xUSB_DONE <= "00000001";
				when "010" =>
					xUSB_DONE <= "00000010";
				when "011" =>
					xUSB_DONE <= "00000100";
				when "100" =>
					xUSB_DONE <= "00001000";
				when "101" =>
					xUSB_DONE <= "00000000";  --CC only read mode, don't reset RAM buffers
				when others=>
					xUSB_DONE <= "00000000";
			end case;
		end if;
	end process;
	
	process(CC_READ_MODE)
		begin
		case CC_READ_MODE is
			when "001" =>
				NUM_USB_SAMPLES_IN_PACKET <= x"001F40";   
			when "010" =>
				NUM_USB_SAMPLES_IN_PACKET <= x"001F40";	 
			when "011" =>
				NUM_USB_SAMPLES_IN_PACKET <= x"001F40";	 
			when "100" =>
				NUM_USB_SAMPLES_IN_PACKET <= x"001F40";		 
			when "101"=>
				NUM_USB_SAMPLES_IN_PACKET <= x"00001F";     --read CC info
			when others=>
				NUM_USB_SAMPLES_IN_PACKET <= x"001F40";
		end case;
	end process;
		
	process(read_cc_buffer, usb_done, xCLR_ALL)
		begin 
			if xCLR_ALL = '1' or usb_done = '1' or USB_TIMEOUT= '1' then
				CC_USB_START <= '0';
			elsif falling_edge(read_cc_buffer) and CC_READ_MODE = "101" then
				CC_USB_START <= '1';
			end if;
	end process;
	
	process(IFCLK, usb_done, CC_USB_START, USB_START)
	variable timeout : integer range 0 to 100000003:=0;	
		begin 
			if xCLR_ALL = '1' or usb_done = '1'  then
				USB_TIMEOUT <= '0';
				timeout := 0;
			elsif rising_edge(IFCLK) and (CC_USB_START = '1' or USB_START = '1') then
				if timeout > 100000000 then
					timeout := 0;
					USB_TIMEOUT <= '1';
				else
					timeout := timeout + 1;
				end if;
			elsif rising_edge(IFCLK) then
				USB_TIMEOUT <= '0';
				timeout := 0;
			end if;
	end process;
	
	process(IFCLK, ALIGN_LVDS_FLAG)
		begin
			if xCLR_ALL = '1' then
				ALIGN_LVDS_FROM_SOFTWARE <= '0';
			elsif falling_edge(IFCLK) and (ALIGN_LVDS_COUNT = '0') then
				ALIGN_LVDS_FROM_SOFTWARE<= '0';
			elsif falling_edge(IFCLK) and ALIGN_LVDS_FLAG = '1' then
				ALIGN_LVDS_FROM_SOFTWARE <= '1';
			end if;
	end process;
	
	process(IFCLK, ALIGN_LVDS_FROM_SOFTWARE)
	variable i : integer range 10000002 downto 0 := 0;
		begin
			if rising_edge(IFCLK) and ALIGN_LVDS_FROM_SOFTWARE = '0' then
				i := 0;
				ALIGN_LVDS_STATE <= RESETT;
				ALIGN_LVDS_COUNT <= '1';
			elsif rising_edge(IFCLK) and ALIGN_LVDS_FROM_SOFTWARE  = '1' then
				case ALIGN_LVDS_STATE is
					when RESETT =>
						i:=i+1;
						if i > 10000000 then
							i := 0;
							ALIGN_LVDS_STATE <= RELAXT;
						end if;
						
					when RELAXT =>
						ALIGN_LVDS_COUNT <= '0';

				end case;
			end if;
	end process;
	
	process(IFCLK, WAKEUP_USB)
		begin
			if xCLR_ALL = '1' then
				RESET_USB_FROM_SOFTWARE <= '0';
			elsif falling_edge(IFCLK) and WAKEUP_USB_DONE = '0' then
				RESET_USB_FROM_SOFTWARE <= '0';
			elsif falling_edge(IFCLK) and WAKEUP_USB = '1' then
				RESET_USB_FROM_SOFTWARE <= '1';
			end if;
	end process;
	
	process(IFCLK, RESET_USB_FROM_SOFTWARE)
	variable i : integer range 100000008 downto 0 := 0;
		begin
			if rising_edge(IFCLK) and RESET_USB_FROM_SOFTWARE = '0' then
				i := 0;
				WAKEUP_USB_STATE <= RESETT;
				WAKEUP_USB_DONE <= '1';
			elsif rising_edge(IFCLK) and RESET_USB_FROM_SOFTWARE  = '1' then
				case WAKEUP_USB_STATE is
					when RESETT =>
						i:=i+1;
						if i > 100000000 then
							i := 0;
							WAKEUP_USB_STATE <= RELAXT;	
						end if;
					
					when RELAXT =>
						WAKEUP_USB_DONE <= '0';

				end case;
			end if;
	end process;
		
	--map custom USB controls to USB 32-bit driver firmware
	xUSB_32bit : entity work.usb_32bit(Behavioral)   
	port map( 
			USB_IFCLK		=> IFCLK,
			USB_RESET    	=> xRESET,	
			USB_BUS  		=>	FD,
			FPGA_DATA		=>	FPGA_DATA,

			--usb write to pc		
         USB_FLAGB    	=> CTL(1),	
         USB_FLAGC    	=> CTL(2),	
			USB_START_WR	=> (USB_START or CC_USB_START),
			USB_NUM_WORDS	=> NUM_USB_SAMPLES_IN_PACKET,
         USB_DONE  		=> usb_done, 	
         USB_PKTEND    	=> PA(6),
         USB_SLWR  		=> SLWR,
         USB_WBUSY 		=> WBUSY,
			
			--usb read from pc	
         USB_FLAGA    	=> CTL(0),
         USB_FIFOADR  	=> PA(5 downto 4),
         USB_SLOE     	=> PA(2),
         USB_SLRD     	=> RDY(0),
         USB_RBUSY 		=> RBUSY,
         USB_INSTRUCTION   => USB_INSTRUCTION,
			USB_INSTRUCT_RDY  => USB_INSTRUCT_RDY);
				
	xMESS	: entity work.packetUSB(Behavioral)
	port map(
			 xSLWR				=> SLWR,
			 xSTART		 		=> USB_START,
			 xRAM_FULL			=> xUSB_START,
			 xSTART_VEC    	=> USB_START_MASK,
			 xCC_ONLY_START	=> CC_USB_START,
			 xALIGN_STATUS 	=> xALIGN_STAT,
			 xALIGN_INFO   	=> xALIGN_INFO,
			 xDONE		 		=> usb_done,
			 xCLR_ALL	 		=> xCLR_ALL,
			 xADC					=> xADC,
			 xCC_READ_MODE		=> CC_READ_MODE,
			 xNUM_USB_SAMPLES	=>	NUM_USB_SAMPLES_IN_PACKET,
			 xCC_INFO_0			=> xCC_INFO_0,	 
			 xCC_INFO_1			=> xCC_INFO_1,		
			 xCC_INFO_2			=> xCC_INFO_2,		
			 xCC_INFO_3			=> xCC_INFO_3,	
			 xCC_INFO_4			=> xCC_INFO_4,			
			 xCC_INFO_5			=> xCC_INFO_5,				
			 xCC_INFO_6			=> xCC_INFO_6,				
			 xCC_INFO_7			=> xCC_INFO_7,				
			 xCC_INFO_8			=> xCC_INFO_8,				
			 xCC_INFO_9			=> xCC_INFO_9, 
			 xDIGITIZING_FLAG => xDIGITIZING_FLAG,
			 xFPGA_DATA    	=> FPGA_DATA,
			 xLAST_RD_ADDR		=> xLAST_RD_ADR,
			 xDC_PKT				=> xDC_PKT,
 			 xTRIG_INFO			=> SET_TRIG_SOURCE,
			 xRADDR				=> xRADDR,
			 xRAM_READ_EN		=> xRAM_EN);
			 
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--Processes to handle USB commands (from PC): synching, interpreting, etc	
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

process(xRESET, xCLK_SYS)
begin
	if xRESET = '0' then
		CC_SYNC_REG 	<= '0';
		CC_SYNC_IN_REG	<= '0';
	elsif rising_edge(xCLK_SYS) then
		CC_SYNC_REG 	<= CC_SYNC;
		CC_SYNC_IN_REG	<= xCC_SYNC_IN;
	end if;
end process;		
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
	process(soft_trig_ready_good, xCLK_SYS, xRESET )
	begin
		if xRESET = '0'  then
			xSOFT_TRIG 		<= (others=>'0');
			xSOFT_TRIG_BIN <= (others=>'0');
			--xTRIG_VALID    <= '0';
		elsif rising_edge(xCLK_SYS) and soft_trig_ready_good = '0'  then
			xSOFT_TRIG 		<= (others=>'0');
			xSOFT_TRIG_BIN <= (others=>'0');
		elsif rising_edge(xCLK_SYS) and soft_trig_ready_good = '1'  then
			xSOFT_TRIG 		<= SOFT_TRIG_MASK_GOOD;
			xSOFT_TRIG_BIN <= SOFT_TRIG_BIN_GOOD;
			--xTRIG_VALID		<= trig_valid_GOOD or trig_valid_CC_only;
		end if;
	end process;

	--xSOFT_TRIG <= SOFT_TRIG_MASK;
	
	process(reset_from_usb, cc_only_instruct_rdy)
	begin
		if reset_from_usb = '1' or done_with_cc_only_instruction= '1' then
			ready_for_cc_instruct <= '0';
		elsif rising_edge(cc_only_instruct_rdy) then
			ready_for_cc_instruct  <= '1';
		end if;
	end process;
	-----
	--sync commands between ACC boards:
	-----
	process(xCLK_SYS, ready_for_cc_instruct, reset_from_usb)
	variable i : integer range 100002 downto 0;	
	begin
		if reset_from_usb = '1' then 
			done_with_cc_only_instruction <= '0';
			i := 0;
			SOFT_TRIG_TMP 			<= '0';	 
			SOFT_TRIG_MASK_TMP 	<= (others=>'0');
			SOFT_TRIG_MASK_GOOD 	<= (others=>'0');
			SOFT_TRIG_BIN_TMP 	<= (others=>'0');
			SOFT_TRIG_BIN_GOOD 	<= (others=>'0');
			CC_SOFT_DONE_TMP     <= '0';
			CC_SOFT_DONE_GOOD		<= '0';
			RESET_TIME_TMP 		<= '0';
			RESET_TIME_GOOD		<= '0';	
			trig_valid_TMP			<= '0';
			trig_valid_GOOD		<= '0';
			handle_cc_only_instruct_state <= get_instruct;
		
		elsif falling_edge(xCLK_SYS) and ready_for_cc_instruct = '0' then
			--same as RESET condition, except for trig_valid flag (only change value when toggled)
			done_with_cc_only_instruction<= '0';
			i := 0;
			SOFT_TRIG_TMP 			<= '0';	 
			SOFT_TRIG_GOOD			<= '0';
			SOFT_TRIG_MASK_TMP 	<= (others=>'0');
			SOFT_TRIG_MASK_GOOD 	<= (others=>'0');
			handle_cc_only_instruct_state <= get_instruct;

		elsif falling_edge(xCLK_SYS) and ready_for_cc_instruct = '1' then
			case handle_cc_only_instruct_state is
			
				when get_instruct=>
					SOFT_TRIG_TMP 			<= SOFT_TRIG;	 
					SOFT_TRIG_MASK_TMP 	<= SOFT_TRIG_MASK;
					SOFT_TRIG_BIN_TMP		<= SOFT_TRIG_BIN;
					trig_valid_TMP			<= trig_valid;
					
					if i > 2 then
						i := 0;
						handle_cc_only_instruct_state <= check_sync;
					else
						i:=i+1;
					end if;

				when check_sync =>			
					if CC_SYNC_REG = '1' or CC_SYNC_IN_REG = '1' then						--
						i:=0;
						handle_cc_only_instruct_state <= get_synced;
						--
					else 
						i:=0;
						handle_cc_only_instruct_state <= send_instruct;
					end if;
		
				when get_synced =>
					if CC_SYNC_REG = '0' and CC_SYNC_IN_REG = '0' then
						i:=0;
						handle_cc_only_instruct_state <= send_instruct;
					elsif i > 50000 then
						i:=0;
						handle_cc_only_instruct_state <= send_instruct;
					else 
						i:=i+1;
						handle_cc_only_instruct_state <= get_synced;
					end if;
					
				when send_instruct =>						
					SOFT_TRIG_GOOD 			<= SOFT_TRIG_TMP;	 
					SOFT_TRIG_MASK_GOOD 		<= SOFT_TRIG_MASK_TMP;
					SOFT_TRIG_BIN_GOOD		<= SOFT_TRIG_BIN_TMP;
					trig_valid_GOOD			<= trig_valid_TMP;
					soft_trig_ready_good    <= '1';							
					if i > 20 then
						i:= 0;
						handle_cc_only_instruct_state <= be_done;
					else
						i:= i+1;

					end if;
					
				when be_done =>
					i:=0;
					SOFT_TRIG_TMP 			<= '0';	 
					SOFT_TRIG_MASK_TMP 	<= (others=>'0');
					SOFT_TRIG_BIN_TMP    <= (others=>'0');
					done_with_cc_only_instruction <= '1';
				when others=>
					handle_cc_only_instruct_state <= get_instruct;
			
			end case;
		end if;
	end process;	
--------------------------------------------------------------------------------
------------------------------------------------------------------------------
--------------------------------------------------------------------------------	
	process(reset_from_usb, CC_INSTRUCT_RDY)
	begin
		if reset_from_usb = '1' or done_with_cc_instruction = '1' then
			ready_for_instruct <= '0';
		elsif rising_edge(CC_INSTRUCT_RDY) then
			ready_for_instruct <= '1';
		end if;
	end process;
	-----
	process(xCLK_SYS, CC_SYNC_IN_REG, reset_from_usb)
	variable i : integer range 50 downto 0;	
	begin
		if reset_from_usb = '1' then 
			CC_INSTRUCTION_GOOD 	<= (others=>'0');
			CC_INSTRUCT_RDY_GOOD	<= '0';
			CC_INSTRUCTION_tmp 	<= (others=>'0');
			INSTRUCT_MASK_GOOD   <= (others=>'0');
			INSTRUCT_MASK_TMP    <= (others=>'0');
			done_with_cc_instruction <= '0';
			i := 0;
			handle_cc_instruct_state <= get_instruct;
		
		elsif falling_edge(xCLK_SYS) and ready_for_instruct = '0' then	
			CC_INSTRUCTION_GOOD 	<= (others=>'0');
			CC_INSTRUCT_RDY_GOOD	<= '0';
			CC_INSTRUCTION_tmp 	<= (others=>'0');
			INSTRUCT_MASK_GOOD   <= (others=>'0');
			INSTRUCT_MASK_TMP    <= (others=>'0');
			done_with_cc_instruction <= '0';
			i := 0;
			handle_cc_instruct_state <= get_instruct;
			
		elsif falling_edge(xCLK_SYS) and ready_for_instruct = '1' then
			case handle_cc_instruct_state is
			
				when get_instruct=>
					CC_INSTRUCTION_tmp 	<= CC_INSTRUCTION;
					INSTRUCT_MASK_TMP		<= INSTRUCT_MASK;
					if i > 2 then
						i := 0;
						handle_cc_instruct_state <= check_sync;
					else
						i:=i+1;
					end if;							
					
				when check_sync =>
					if CC_SYNC_REG = '1' or CC_SYNC_IN_REG = '1' then
						handle_cc_instruct_state <= get_synced;
				
					else 
						handle_cc_instruct_state <= send_instruct;
					end if;
		
				when get_synced =>
					i := 0;
					if CC_SYNC_REG = '0' and CC_SYNC_IN_REG = '0' then
						handle_cc_instruct_state <= send_instruct;
					else
						handle_cc_instruct_state <= get_synced;
					end if;
					
				when send_instruct =>
					INSTRUCT_MASK_GOOD	<= INSTRUCT_MASK_TMP;
					CC_INSTRUCTION_GOOD 	<= CC_INSTRUCTION_tmp;
					CC_INSTRUCT_RDY_GOOD <= '1';
					if i > 20 then
						i:= 0;
						handle_cc_instruct_state <= be_done;
					else
						i:= i+1;
					end if;
					
				when be_done =>
					INSTRUCT_MASK_GOOD	<= (others=>'0');
					CC_INSTRUCTION_GOOD 	<= (others=>'0');
					CC_INSTRUCT_RDY_GOOD <= '0';
					done_with_cc_instruction <= '1';
			
			end case;
		end if;
	end process;

--Interpretation:
	
	process(IFCLK, USB_INSTRUCT_RDY, USB_INSTRUCTION, reset_from_usb)
	variable delay 	: integer range 0 to 50;
	variable delay2 	: integer range 0 to 5;

	begin
	if reset_from_usb = '1' then
			--signals:
			SOFT_TRIG			<= '0';		
			CC_INSTRUCTION 	<=(others=>'0');
			SOFT_TRIG_MASK 	<=(others=>'0');
			SOFT_TRIG_BIN  	<=(others=>'0');
			CC_SOFT_DONE 		<= '0';
			CC_READ_MODE 		<= "000";
			ALIGN_LVDS_FLAG	<= '1';
			TRIG_MODE 			<= '0';
			TRIG_DELAY 			<= (others => '0');
			INSTRUCT_MASK	   <= (others => '0');
			delay 				:= 0;	
			delay2 				:= 0;	
			RESET_DLL_FLAG 	<= '0';
			read_cc_buffer 	<= '0';
			CC_INSTRUCT_RDY	<= '0';	
			HARD_RESET     	<= '0';
			WAKEUP_USB     	<= '0';
			CC_SYNC        	<= '0';
			trig_valid			<= '0';
			SYNC_TRIG			<= '0';
			SYNC_MODE			<= '0';
			SYNC_TIME			<= '0';
			SYNC_RESET			<= '0';
			state       		<= st1_WAIT;
--------------------------------------------------------------------------------				
	elsif rising_edge(IFCLK) then
--------------------------------------------------------------------------------				
			case	state is	
--------------------------------------------------------------------------------
				when st1_WAIT=>
--------------------------------------------------------------------------------					
					ALIGN_LVDS_FLAG  	<= '0';
					RESET_DLL_FLAG 	<= '0';
					CC_SOFT_DONE   	<= '0';
					CC_INSTRUCT_RDY	<= '0';
					cc_only_instruct_rdy <= '0';
					read_cc_buffer 	<= '0';
					SOFT_TRIG	   	<= '0';
					HARD_RESET     	<= '0';
					WAKEUP_USB     	<= '0';
					SOFT_TRIG_MASK		<= (others=>'0');
					SOFT_TRIG_BIN  	<= (others=>'0');
					SYNC_TRIG			<= '0';
					SYNC_MODE			<= '0';
					SYNC_TIME			<= '0';
					SYNC_RESET			<= '0';
					delay 				:= 0;	

					if USB_INSTRUCT_RDY = '1' then --instruction is ready to be interpreted
						if delay2 > 0 then
							delay2 := 0;
							state <= st1_TARGET;
						else
							delay2 := delay + 1;
						end if;		
					end if;
--------------------------------------------------------------------------------				
				when st1_TARGET=>
--------------------------------------------------------------------------------
					--specifies which board(s) to send instruction
					INSTRUCT_MASK(3 downto 0) <= USB_INSTRUCTION(28 downto 25);
					delay2 := 0;
--------------------------------------------------------------------------------
					case USB_INSTRUCTION(19 downto 16) is
--------------------------------------------------------------------------------
						--when x"F" =>	--USE SYNC signal (defunct)
						--	SYNC_USB <= USB_INSTRUCTION(0); 
						--	state <= st1_WAIT;		
			
						when x"E" =>	--SOFT_TRIG
							cc_only_instruct_rdy <= '1';
							SYNC_TRIG <= '1';
							SOFT_TRIG <= '1';	 
							SOFT_TRIG_MASK(3 downto 0) <= USB_INSTRUCTION(3 downto 0);
							--SOFT_TRIG_MASK <= (others=>'1');  --trigger every AC/DC
							SOFT_TRIG_BIN	<= USB_INSTRUCTION(6 downto 4);
							if delay > 8 then
								delay := 0;
								state <= st1_WAIT;
							else
								delay := delay + 1;
							end if;		
		
						when x"D" =>
							ALIGN_LVDS_FLAG <= '1';	 		
							state <= st1_WAIT;		
			
						when x"C" =>
							CC_READ_MODE <= USB_INSTRUCTION(2 downto 0);
							if USB_INSTRUCTION(4) = '1' then
								TRIG_MODE <= USB_INSTRUCTION(3);
								TRIG_DELAY  (6 downto 0) <= USB_INSTRUCTION(11 downto 5);
								SET_TRIG_SOURCE (2 downto 0) <= USB_INSTRUCTION(14 downto 12);
							end if;
	
							if delay > 10 then
								delay := 0;
								state <= st1_WAIT;
			
							--this is a hack:
							-- basically, only want to send along to AC/DC if certain conditions apply
							-- also want to only read CC info buffer if read mode = 0b101
							else
								delay := delay + 1;
								if delay > 1 then
									case CC_READ_MODE is
										when "101" =>
											read_cc_buffer <= '1';
											CC_INSTRUCTION <= (others=>'0');
											CC_INSTRUCT_RDY<= '0';
										when "110" =>
											read_cc_buffer <= '0';
											CC_INSTRUCTION <= (others=>'0');
											CC_INSTRUCT_RDY<= '0';
										---only send-along data to AC/DC cards when 111 or 000
										when "111" =>	
											--cc_only_instruct_rdy <= '1';
											trig_valid_CC_only <= '1';
											read_cc_buffer <= '0';
											CC_INSTRUCTION <= (others=>'0');
											CC_INSTRUCT_RDY<= '0';
										when "000" =>
											trig_valid_CC_only <= '0';
											read_cc_buffer <= '0';
											CC_INSTRUCTION <= USB_INSTRUCTION;
											CC_INSTRUCT_RDY<= '1';
										------
										when others =>
											read_cc_buffer <= '0';
											CC_INSTRUCTION <= (others=>'0');
											CC_INSTRUCT_RDY<= '0';
									end case;
								end if;
							end if;
		
						
						when x"B" =>
							if USB_INSTRUCTION(2) = '1' then
								cc_only_instruct_rdy <= '1';
								trig_valid <= USB_INSTRUCTION(1);
								CC_INSTRUCTION <= USB_INSTRUCTION;
								CC_INSTRUCT_RDY<= '1';
								SYNC_MODE <= '1';
							elsif USB_INSTRUCTION(4) = '1' then
								cc_only_instruct_rdy <= '0';
								trig_valid <= trig_valid;
								CC_SYNC <= USB_INSTRUCTION(3);
								CC_INSTRUCTION <= (others=>'0');
								CC_INSTRUCT_RDY<= '0';
							else
								cc_only_instruct_rdy <= '0';
								trig_valid <= trig_valid;
								CC_SOFT_DONE <= USB_INSTRUCTION(0);
								CC_INSTRUCTION <= USB_INSTRUCTION;
								CC_INSTRUCT_RDY<= '1';
							end if;

							if delay > 10 then
								delay := 0;
								state <= st1_WAIT;
							else
								delay := delay + 1;
							end if;					
		
						when x"4" =>
							--hard reset conditions
							case USB_INSTRUCTION(11 downto 0) is
								when x"FFF" =>
									cc_only_instruct_rdy <= '1';
									--SYNC_TRIG  <= '1';
									ALIGN_LVDS_FLAG 		<= '1';
									SOFT_TRIG  				<= '1';
									SOFT_TRIG_MASK 		<= (others=>'1');
									HARD_RESET 				<= '1';
									WAKEUP_USB 				<= '0';
								when x"EFF" =>
									cc_only_instruct_rdy <= '0';
									--SYNC_TRIG  <= '0';
									ALIGN_LVDS_FLAG 		<= '0'; 
									SOFT_TRIG  				<= '0';
									SOFT_TRIG_MASK 		<= (others=>'0');
									HARD_RESET 				<= '0';
									WAKEUP_USB 				<= '1';
								when others=>
									--SYNC_TRIG  <= '0';
									cc_only_instruct_rdy <= '0';
									ALIGN_LVDS_FLAG 		<= '0';
									SOFT_TRIG  				<= '0';
									SOFT_TRIG_MASK 		<= (others=>'0');
									HARD_RESET 				<= '0';
									WAKEUP_USB 				<= '0';
							end case;
			
							--otherwise, send instructions over SERDES
							case USB_INSTRUCTION(15 downto 12) is
								when x"1" =>
									--cc_only_instruct_rdy <= '1';
									--SYNC_TIME <= '1';
									RESET_DLL_FLAG <= '1';
								when x"3" => 
									--cc_only_instruct_rdy <= '1';
									--SYNC_TIME <= '1';
									RESET_DLL_FLAG <= '1';
								when x"F" =>
									--cc_only_instruct_rdy <= '1';
									--SYNC_TIME <= '1';
									RESET_DLL_FLAG <= '1';
								when others =>
									--SYNC_TIME <= '0';
									RESET_DLL_FLAG <= '0';
							end case;	
			
							CC_INSTRUCTION <= USB_INSTRUCTION;
							CC_INSTRUCT_RDY<= '1';
			
							if delay > 20 then
								delay := 0;
								state <= st1_WAIT;
							else
								delay := delay + 1;
							end if;	

						when others =>
							CC_INSTRUCTION <= USB_INSTRUCTION;
							CC_INSTRUCT_RDY<= '1';
							if delay > 8 then
								delay := 0;
								state <= st1_WAIT;
							else
								delay := delay + 1;
							end if;
							
					end case;
			end case;
	end if;
end process;

--reset USB block upon plugging-in
proc_reset_usb : process(WAKEUP, IFCLK, xCLR_ALL) 
	variable i: integer range 0 to 1440000000 :=0;
	begin
		if xCLR_ALL = '1' then
			i := 0;
			reset_from_usb <= '1';
			xUSB_WAKEUP <= CLEAR;
		elsif IFCLK = '1' and IFCLK'event then		
			case	xUSB_WAKEUP is
				when CLEAR =>
						reset_from_usb <= '1';
								  
						if i > 500000000 then
							i:=0;
							xUSB_WAKEUP <= READY;
						else
							if WAKEUP = '1' then
								i := i + 1;
								xUSB_WAKEUP <= CLEAR;
							else
								xUSB_WAKEUP <= CLEAR;
							end if;
						end if;
				when READY =>
					i:=0;
					if WAKEUP = '1' then
						reset_from_usb <= '0';
						xUSB_WAKEUP <= READY;
					else
						xUSB_WAKEUP <= CLEAR;
					end if;
				when others =>
					xUSB_WAKEUP <= CLEAR;
			end case;	
		end if;
	end process;
	--------------------------------------				
end BEHAVIORAL;