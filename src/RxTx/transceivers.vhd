---------------------------------------------------------------------------------
-- Univ. of Chicago  
--    
-- PROJECT:      ANNIE 
-- FILE:         tranceivers.vhd
-- AUTHOR:       e oberla
-- EMAIL         ejo@uchicago.edu
-- DATE:         
--
-- DESCRIPTION:  lvds intercom
--
---------------------------------------------------------------------------------

library IEEE; 
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.defs.all;

entity transceivers is
	port(
		xCLR_ALL				: in	std_logic;	--global reset
		xALIGN_SUCCESS 	: out	std_logic;  --successfully aligned
		
		xCLK					: in	std_logic;	--system clock
		
		xRX_LVDS_DATA		: in	std_logic_vector(1 downto 0); --serdes data received (2x)
		xRX_LVDS_CLK		: in	std_logic;  --bytealigned clk for serdes data received
		xTX_LVDS_DATA		: out	std_logic;                    --serdes data transmitted
		xTX_LVDS_CLK	 	: out		std_logic;                  --bytealigned clk for serdes data transmitted
		
		xCC_INSTRUCTION	: in	std_logic_vector(instruction_size-1 downto 0);	--front-end 
		xCC_INSTRUCT_RDY	: in	std_logic;	--intruction ready to send to front-end
		xTRIGGER				: in	std_logic;	--trigger in
		xCC_SEND_TRIGGER	: out	std_logic;	--trigger out to front-end
		 
		xRAM_RD_EN			: in	std_logic; 	--enable reading from RAM block
		xRAM_ADDRESS		: in	std_logic_vector(transceiver_mem_depth-1 downto 0);--ram address
		xRAM_CLK				: in	std_logic;	--slwr from USB	
		xRAM_FULL_FLAG		: out	std_logic_vector(num_rx_rams-1 downto 0);	--event in RAM
		xRAM_DATA			: out	std_logic_vector(transceiver_mem_width-1 downto 0);--data out
		xRAM_SELECT_WR		: in	std_logic_vector(num_rx_rams-1 downto 0); --select ram block, write
		xRAM_SELECT_RD		: in	std_logic_vector(num_rx_rams-1 downto 0); --select ram block, read

		xALIGN_INFO			: out std_logic_vector(2 downto 0); --3 bit, alignment indicator of 3 SERDES links
		xCATCH_PKT			: out std_logic;	--flag that a data packet from front-end was received
		
		xDONE					: in	std_logic;	--done reading from USB/etc (firmware done)
		xDC_MASK				: in	std_logic;	--mask bit for address
		xPLL_LOCKED			: in	std_logic;  --FPGA pll locked
		xSOFT_RESET			: in	std_logic);	--software reset, done reading to cpu (software done)
		
end transceivers;

architecture rtl of transceivers is



type 	SEND_CC_INSTRUCT_TYPE is (IDLE, SEND_START_WORD, SEND_START_WORD_2, 
											CATCH0, CATCH1, CATCH2, CATCH3, READY);
signal SEND_CC_INSTRUCT_STATE	:	SEND_CC_INSTRUCT_TYPE;

type LVDS_GET_DATA_STATE_TYPE	is (MESS_IDLE, GET_DATA, MESS_END, GND_STATE);
signal LVDS_GET_DATA_STATE		:  LVDS_GET_DATA_STATE_TYPE;		

type RAM_DATA_TYPE is array (num_rx_rams-1 downto 0) of 
	std_logic_vector(transceiver_mem_width-1 downto 0); 
signal temp_RAM_DATA		:	RAM_DATA_TYPE;




signal RX_ALIGN_BITSLIP			:	std_logic_vector(1 downto 0);
signal RX_DATA						:	std_logic_vector(15 downto 0);
signal CHECK_WORD_1				:	std_logic_vector(7 downto 0);
signal CHECK_WORD_2				:	std_logic_vector(7 downto 0);
signal TX_DATA						: 	std_logic_vector(7 downto 0);
signal ALIGN_SUCCESS				:  std_logic;
signal FE_ALIGN_SUCCESS		:  std_logic;
signal GOOD_DATA					:  std_logic_vector(7 downto 0);

signal INSTRUCT_READY			:	std_logic;

signal WRITE_CLOCK				:	std_logic;
signal WRITE_ENABLE				:	std_logic;
signal WRITE_ENABLE_TEMP		:	std_logic;
signal RAM_FULL_FLAG				:	std_logic_vector(num_rx_rams-1 downto 0);
signal CHECK_RX_DATA				:	std_logic_vector(transceiver_mem_width-1 downto 0);
signal RX_DATA_TO_RAM			:	std_logic_vector(transceiver_mem_width-1 downto 0);
signal WRITE_COUNT				: 	std_logic_vector(transceiver_mem_width-1 downto 0);
signal WRITE_ADDRESS				:	std_logic_vector(transceiver_mem_depth-1 downto 0);
signal WRITE_ADDRESS_TEMP		:	std_logic_vector(transceiver_mem_depth-1 downto 0);
signal LAST_WRITE_ADDRESS		:	std_logic_vector(transceiver_mem_depth-1 downto 0); 

signal START_WRITE				:	std_logic;
signal STOP_WRITE					:	std_logic;

signal TX_BUF_FULL				:  std_logic;
signal RX_DATA_RDY				:  std_logic;

component lvds_transceivers
	port (
		xCLK 				:  IN  STD_LOGIC;
		xCLR_ALL 		:  IN  STD_LOGIC;
		RX_LVDS_DATA 	:  IN  STD_LOGIC;
		TX_DATA 			:  IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
		TX_DATA_RDY 	:  IN  STD_LOGIC;
		REMOTE_UP 		:  OUT STD_LOGIC;
		REMOTE_VALID 	:  OUT STD_LOGIC;
		TX_BUF_FULL 	:  OUT STD_LOGIC;
		RX_ERROR 		:  OUT STD_LOGIC;
		TX_LVDS_DATA 	:  OUT STD_LOGIC;
		RX_DATA_RDY		:  OUT STD_LOGIC;
		RX_DATA 			:  OUT STD_LOGIC_VECTOR(15 DOWNTO 0));
end component;

component rx_ram
	port (
			xDATA				: in	std_logic_vector(transceiver_mem_width-1 downto 0);
			xWR_ADRS			: in	std_logic_vector(transceiver_mem_depth-1 downto 0);
			xWR_EN			: in	std_logic;
			xRD_ADRS			: in	std_logic_vector(transceiver_mem_depth-1 downto 0);
			xRD_EN			: in	std_logic;
			xRD_CLK			: in	std_logic;
			xWR_CLK			: in	std_logic;
			xRAM_DATA		: out	std_logic_vector(transceiver_mem_width-1 downto 0));
end component;


begin

xALIGN_INFO       <= ALIGN_SUCCESS & ALIGN_SUCCESS & ALIGN_SUCCESS;
xALIGN_SUCCESS 	<= ALIGN_SUCCESS;
WRITE_CLOCK			<= xCLK;
xRAM_FULL_FLAG		<= RAM_FULL_FLAG;
xCC_SEND_TRIGGER	<= xTRIGGER;
xCATCH_PKT     	<= START_WRITE; 



-- process to send data to ACDC
process(xCLK, xCC_INSTRUCT_RDY, xCLR_ALL)
variable i : integer range 50 downto 0;	
begin
	if xCLR_ALL = '1' or xCC_INSTRUCT_RDY = '0' then
		--CC_INSTRUCTION <= (others=>'0');
		INSTRUCT_READY <= '0';
		i := 0;
		GOOD_DATA <= (others=>'0');
		SEND_CC_INSTRUCT_STATE <= IDLE;
		
	elsif rising_edge(xCLK) then
		if ALIGN_SUCCESS = '1' and xCC_INSTRUCT_RDY = '1' 
			and xDC_MASK = '1' and TX_BUF_FULL = '0' then
			case SEND_CC_INSTRUCT_STATE is			
				when IDLE =>
					i := 0;
					INSTRUCT_READY <= '0';
					--if xCC_INSTRUCT_RDY = '1' then
					SEND_CC_INSTRUCT_STATE <= SEND_START_WORD;       
					--end if;
				
				--send 32 bit word 8 bits at a time	
				when SEND_START_WORD =>
					GOOD_DATA <= STARTWORD_8a;
					--SEND_CC_INSTRUCT_STATE <= CATCH0;
					SEND_CC_INSTRUCT_STATE <= SEND_START_WORD_2;
				when SEND_START_WORD_2 =>
					GOOD_DATA <= STARTWORD_8b;
					SEND_CC_INSTRUCT_STATE <= CATCH0;
				when CATCH0 =>
					GOOD_DATA <= xCC_INSTRUCTION(31 downto 24);
					SEND_CC_INSTRUCT_STATE <= CATCH1;
				when CATCH1 =>
					GOOD_DATA <= xCC_INSTRUCTION(23 downto 16);
					SEND_CC_INSTRUCT_STATE <= CATCH2;
				when CATCH2 =>
					GOOD_DATA <= xCC_INSTRUCTION(15 downto 8);  
					SEND_CC_INSTRUCT_STATE <= CATCH3;
				when CATCH3 =>
					GOOD_DATA <= xCC_INSTRUCTION(7 downto 0);
					SEND_CC_INSTRUCT_STATE <= READY;
					
				when READY =>
					GOOD_DATA <= K28_5;
					INSTRUCT_READY <= '1';
					--i := i + 1;
					--if i = 10 then
					--	i := 0;
					--	SEND_CC_INSTRUCT_STATE <= IDLE;
					--end if;
			end case;
		end if;
	end if;
end process;

--look for start/stop word to write lvds data to CC ram.
process(WRITE_CLOCK, xCLR_ALL, xDONE, xSOFT_RESET)
begin
	if xCLR_ALL = '1' or xDONE = '1' or xSOFT_RESET = '1' then
		START_WRITE <= '0';
		STOP_WRITE	<= '0';
	elsif falling_edge(WRITE_CLOCK) then
		if ALIGN_SUCCESS = '1' and RX_DATA_RDY = '1' then -- this is all very strange.
			CHECK_RX_DATA <= RX_DATA;
			if CHECK_RX_DATA = STARTWORD then
				START_WRITE <= '1';
			elsif CHECK_RX_DATA = ENDWORD then
				STOP_WRITE <= '1';
			end if;
		end if;
	end if;
end process;

process(WRITE_CLOCK, xCLR_ALL, ALIGN_SUCCESS, xSOFT_RESET, xDONE)
begin
	if xCLR_ALL ='1'  or ALIGN_SUCCESS = '0' or 
		xSOFT_RESET = '1' or xDONE = '1' then
		
		WRITE_ENABLE_TEMP <= '0';
		WRITE_ENABLE		<= '0';
		WRITE_COUNT			<= (others=>'0');
		WRITE_ADDRESS_TEMP<= (others=>'0');
		WRITE_ADDRESS		<= (others=>'0');
		LAST_WRITE_ADDRESS<= (others=>'0');
		RX_DATA_TO_RAM		<= (others=>'0');
		RAM_FULL_FLAG		<=	(others=>'0');
		LVDS_GET_DATA_STATE <= MESS_IDLE;
	
--	elsif xDONE = '1'then
--		WRITE_ENABLE_TEMP <= '0';
--		WRITE_ENABLE		<= '0';
--		WRITE_COUNT			<= (others=>'0');
--		WRITE_ADDRESS_TEMP<= (others=>'0');
--		WRITE_ADDRESS		<= (others=>'0');
--		LAST_WRITE_ADDRESS<= (others=>'0');
--		RX_DATA_TO_RAM		<= (others=>'0');
--		RAM_FULL_FLAG		<=	RAM_FULL_FLAG;
--		LVDS_GET_DATA_STATE <= MESS_IDLE;
	
	elsif rising_edge(WRITE_CLOCK) then
		if START_WRITE = '1' and RX_DATA_RDY = '1' then
			case LVDS_GET_DATA_STATE is
				
				when MESS_IDLE =>
					WRITE_ENABLE_TEMP <= '1';
					LVDS_GET_DATA_STATE <= GET_DATA;
					
				when GET_DATA =>
					RX_DATA_TO_RAM <= RX_DATA;
					WRITE_COUNT		<= WRITE_COUNT + 1;
					WRITE_ADDRESS_TEMP <= WRITE_ADDRESS_TEMP + 1;
					--if STOP_WRITE = '1' or WRITE_COUNT > 4094 then
					if WRITE_COUNT > 7998 then
						WRITE_ENABLE_TEMP <= '0';
						LAST_WRITE_ADDRESS <= WRITE_ADDRESS_TEMP;
						LVDS_GET_DATA_STATE<= MESS_END;
					end if;
				
				when MESS_END =>
					for i in num_rx_rams-1 downto 0 loop
						RAM_FULL_FLAG(i) <= RAM_FULL_FLAG(i) or xRAM_SELECT_WR(i);
					end loop;
					LVDS_GET_DATA_STATE<= GND_STATE;
					
				when GND_STATE =>
					WRITE_ADDRESS_TEMP <= (others=>'0');
			end case;
		end if;				
	elsif falling_edge(WRITE_CLOCK) then -- No idea why this is being done.
		if START_WRITE = '1' and STOP_WRITE = '0' then
			WRITE_ADDRESS 	<= WRITE_ADDRESS_TEMP;
			WRITE_ENABLE 	<= WRITE_ENABLE_TEMP;
		end if;
	end if;
end process;


process(xCLR_ALL, xRAM_SELECT_RD)
begin
	if xCLR_ALL = '1' then
		xRAM_DATA <= (others=>'0');
	else
		case xRAM_SELECT_RD is
			when "01" =>
				xRAM_DATA <= temp_RAM_DATA(0);
				
			when "10" =>
				xRAM_DATA <= temp_RAM_DATA(1);
				
			when others =>
				Null;
		end case;
	end if;
end process;





xlvds_transceivers : lvds_transceivers
port map(
			xCLK 				=>		xCLK,
			xCLR_ALL			=>		xCLR_ALL,
			RX_LVDS_DATA	=>		xRX_LVDS_DATA(0),
			TX_DATA			=>		TX_DATA,
			TX_DATA_RDY 	=>		'0',
			REMOTE_UP 		=>    open,
			REMOTE_VALID 	=>    ALIGN_SUCCESS,
			TX_BUF_FULL 	=>    TX_BUF_FULL,
			RX_ERROR 		=>    open,
			TX_LVDS_DATA	=>		xTX_LVDS_DATA,
			RX_DATA_RDY		=>    RX_DATA_RDY,
			RX_DATA			=>		RX_DATA
);	
			
xrx_RAM_0	:	rx_RAM
port map(
			xDATA				=>		RX_DATA_TO_RAM,
			xWR_ADRS			=>		WRITE_ADDRESS,
			xWR_EN			=>		WRITE_ENABLE and xRAM_SELECT_WR(0),
			xRD_ADRS			=>		xRAM_ADDRESS,
			xRD_EN			=>		xRAM_RD_EN and xRAM_SELECT_RD(0),
			xRD_CLK			=>		xRAM_CLK,
			xWR_CLK			=>		WRITE_CLOCK,
			xRAM_DATA		=>		temp_RAM_DATA(0));
			
xrx_RAM_1	:	rx_RAM
port map(
			xDATA				=>		RX_DATA_TO_RAM,
			xWR_ADRS			=>		WRITE_ADDRESS,
			xWR_EN			=>		WRITE_ENABLE and xRAM_SELECT_WR(1),
			xRD_ADRS			=>		xRAM_ADDRESS,
			xRD_EN			=>		xRAM_RD_EN and xRAM_SELECT_RD(1),
			xRD_CLK			=>		xRAM_CLK,
			xWR_CLK			=>		WRITE_CLOCK,
			xRAM_DATA		=>		temp_RAM_DATA(1));
			
end rtl;
