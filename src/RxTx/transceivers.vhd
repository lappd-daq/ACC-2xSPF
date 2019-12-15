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
		xCLK_COMs			: in  std_logic;  --clock for communications
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
signal ALIGN_SUCCESS				:  std_logic;
signal FE_ALIGN_SUCCESS		:  std_logic;
signal GOOD_DATA					:  std_logic_vector(7 downto 0);
signal GOOD_DATA_WRREQ		:  std_logic;

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

signal TX_BUF_FULL				:  std_logic;
signal RX_DATA_RDY				:  std_logic;

component lvds_transceivers
	port (
		xCLK 				:  IN  STD_LOGIC;
		xCLK_COMs		:  IN  STD_LOGIC;
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
--WRITE_CLOCK			<= xCLK; --EJO edit 12/14/19
WRITE_CLOCK			<= xCLK_COMs; --EJO edit 12/14/19

xRAM_FULL_FLAG		<= RAM_FULL_FLAG;
xCC_SEND_TRIGGER	<= xTRIGGER;
--xCATCH_PKT     	<= START_WRITE; 


-- FIXME This is a mess.  xCC_INSTRUCT_RDY should only need to be high for one clock cycle.
-- The FIFO could could be modified to accept the 32-bit commands, and insert the headers as needed.

-- process to send data to ACDC
process(xCLK, xCC_INSTRUCT_RDY, xCLR_ALL)
variable i : integer range 50 downto 0;	
begin
	if xCLR_ALL = '1' or xCC_INSTRUCT_RDY = '0' then
		--CC_INSTRUCTION <= (others=>'0');
		INSTRUCT_READY <= '0';
		i := 0;
		GOOD_DATA <= (others=>'0');
		GOOD_DATA_WRREQ <= '0';
		SEND_CC_INSTRUCT_STATE <= IDLE;
		
	elsif rising_edge(xCLK) then
		if ALIGN_SUCCESS = '1' and xCC_INSTRUCT_RDY = '1' 
			and xDC_MASK = '1' and TX_BUF_FULL = '0' then
			case SEND_CC_INSTRUCT_STATE is			
				when IDLE =>
					i := 0;
					GOOD_DATA_WRREQ <= '0';
					INSTRUCT_READY <= '0';
					--if xCC_INSTRUCT_RDY = '1' then
					SEND_CC_INSTRUCT_STATE <= SEND_START_WORD;       
					--end if;
				
				--send 32 bit word 8 bits at a time	
				when SEND_START_WORD =>
					GOOD_DATA <= STARTWORD_8a;
					GOOD_DATA_WRREQ <= '1';
					--SEND_CC_INSTRUCT_STATE <= CATCH0;
					SEND_CC_INSTRUCT_STATE <= SEND_START_WORD_2;
				when SEND_START_WORD_2 =>
					GOOD_DATA <= STARTWORD_8b;
					GOOD_DATA_WRREQ <= '1';
					SEND_CC_INSTRUCT_STATE <= CATCH0;
				when CATCH0 =>
					GOOD_DATA <= xCC_INSTRUCTION(31 downto 24);
					GOOD_DATA_WRREQ <= '1';
					SEND_CC_INSTRUCT_STATE <= CATCH1;
				when CATCH1 =>
					GOOD_DATA <= xCC_INSTRUCTION(23 downto 16);
					GOOD_DATA_WRREQ <= '1';
					SEND_CC_INSTRUCT_STATE <= CATCH2;
				when CATCH2 =>
					GOOD_DATA <= xCC_INSTRUCTION(15 downto 8);  
					GOOD_DATA_WRREQ <= '1';
					SEND_CC_INSTRUCT_STATE <= CATCH3;
				when CATCH3 =>
					GOOD_DATA <= xCC_INSTRUCTION(7 downto 0);
					GOOD_DATA_WRREQ <= '1';
					SEND_CC_INSTRUCT_STATE <= READY;
					
				when READY =>
					GOOD_DATA <= (others => '0');
					GOOD_DATA_WRREQ <= '0';
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

--//------------------------------------------------------------------------------------
proc_rx_data: process(WRITE_CLOCK, xCLR_ALL, ALIGN_SUCCESS, xSOFT_RESET, xDONE)
begin
	if xCLR_ALL ='1' then
		
		xCATCH_PKT			<= '0';
		WRITE_ENABLE_TEMP <= '0';
		WRITE_ENABLE		<= '0';
		WRITE_COUNT			<= (others=>'0');
		WRITE_ADDRESS_TEMP<= (others=>'0');
		WRITE_ADDRESS		<= (others=>'0');
		LAST_WRITE_ADDRESS<= (others=>'0');
		RX_DATA_TO_RAM		<= (others=>'0');
		RAM_FULL_FLAG		<=	(others=>'0');
		LVDS_GET_DATA_STATE <= MESS_IDLE;
	
	--the conditional signals here (xDONE, etc) are on a different clock, eventually need to be flag synced to WRITE_CLOCK
	-- however, WRITE_CLOCK is now assigned to the fastest clock [160MHz, as of 12/14/2019], so no chance of missing 
	-- these signals [though still will raise timing errors]
	elsif rising_edge(WRITE_CLOCK) and (xDONE = '1' or ALIGN_SUCCESS = '0' or xSOFT_RESET = '1') then
		
		xCATCH_PKT			<= '0';
		WRITE_ENABLE_TEMP <= '0';
		WRITE_ENABLE		<= '0';
		WRITE_COUNT			<= (others=>'0');
		WRITE_ADDRESS_TEMP<= (others=>'0');
		WRITE_ADDRESS		<= (others=>'0');
		LAST_WRITE_ADDRESS<= (others=>'0');
		RX_DATA_TO_RAM		<= (others=>'0');
		RAM_FULL_FLAG		<=	(others=>'0');
		LVDS_GET_DATA_STATE <= MESS_IDLE;
	
	elsif rising_edge(WRITE_CLOCK) then

			case LVDS_GET_DATA_STATE is
				when MESS_IDLE =>
					xCATCH_PKT		<= xCATCH_PKT;
					
					WRITE_ENABLE   <= '0';
					WRITE_COUNT <= WRITE_COUNT;
					WRITE_ADDRESS <= WRITE_ADDRESS;

					RX_DATA_TO_RAM <= RX_DATA_TO_RAM;
					
					-- RX_DATA_RDY is flag from lvds_transceivers data-parallelization process
					if RX_DATA_RDY = '1' then
						LVDS_GET_DATA_STATE <= GET_DATA;
					else
						LVDS_GET_DATA_STATE <= MESS_IDLE;
					end if;
				
				when GET_DATA =>
					xCATCH_PKT		<= '1'; 	--this signal used to be 'START_WRITE', some flag that
													-- was went high while data was being written to RAM. 
													-- Don't recall why/how this was used in sw...maybe just in case there
													-- was a USB read while data was being written, so sw could wait until
													-- the data was fully written and not save a corrupted event?
													--
													-- UPDATE: looking at old CC firmware, I think the sw probably looked 
													-- for both xCATCH_PKT = '1' and RAM_FULL = '1' to indicate that
													-- good data from a trigger was available to read. should confirm.
					
					RX_DATA_TO_RAM <= RX_DATA; -- assign data to RAM input bus here
					
					WRITE_ENABLE   <= '1';
					WRITE_COUNT		<= WRITE_COUNT + 1;
					WRITE_ADDRESS <= WRITE_ADDRESS + 1;

					if WRITE_COUNT > 7998 or RX_DATA = ENDWORD then
						WRITE_ENABLE <= '0';
						LAST_WRITE_ADDRESS <= WRITE_ADDRESS; 
						LVDS_GET_DATA_STATE<= MESS_END;
						
					else
						LVDS_GET_DATA_STATE <= MESS_IDLE;
					end if;
				
				when MESS_END =>
					xCATCH_PKT		<= '1';
					
					WRITE_ENABLE   <= '0';
					WRITE_COUNT <= WRITE_COUNT;
					WRITE_ADDRESS <= WRITE_ADDRESS;
					
					RX_DATA_TO_RAM		<= x"5757"; --made up error code, should never see this data
					
					--I don' know why there are multiple RAMs, maybe something was meant
					--to be implemented at some point. Clearly the full control necessary
					--for this is not here yet. If still readout issues, we should remove this complication
					--and go back to a single RAM per ACDC
					for i in num_rx_rams-1 downto 0 loop
						RAM_FULL_FLAG(i) <= RAM_FULL_FLAG(i) or xRAM_SELECT_WR(i);
					end loop;
					LVDS_GET_DATA_STATE<= GND_STATE;
					
				when GND_STATE =>
					xCATCH_PKT		<= '1';
					WRITE_ENABLE   <= '0';
					WRITE_ADDRESS <= (others=>'0');
					WRITE_COUNT <= WRITE_COUNT;
					
					RX_DATA_TO_RAM		<= (others=>'0');

			end case;			
			
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
			xCLK_COMs		=>		xCLK_COMs,
			xCLR_ALL			=>		xCLR_ALL,
			RX_LVDS_DATA	=>		xRX_LVDS_DATA(0),
			TX_DATA			=>		GOOD_DATA,
			TX_DATA_RDY 	=>		GOOD_DATA_WRREQ,
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
