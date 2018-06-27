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
		xRX_CLK				: in	std_logic;	--parallel data clock for rx transceiver 
		
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
		xFE_ALIGN_SUCCESS	: in	std_logic;  --single bit front-end aligned success
		xSOFT_RESET			: in	std_logic);	--software reset, done reading to cpu (software done)
		
end transceivers;

architecture rtl of transceivers is

type LINK_STATE_TYPE is (DOWN, CHECKING, UP);
signal LINK_STATE : LINK_STATE_TYPE;

type 	SEND_CC_INSTRUCT_TYPE is (IDLE, SEND_START_WORD, SEND_START_WORD_2, 
											CATCH0, CATCH1, CATCH2, CATCH3, READY);
signal SEND_CC_INSTRUCT_STATE	:	SEND_CC_INSTRUCT_TYPE;

type LVDS_GET_DATA_STATE_TYPE	is (MESS_IDLE, GET_DATA, MESS_END, GND_STATE);
signal LVDS_GET_DATA_STATE		:  LVDS_GET_DATA_STATE_TYPE;		

type RAM_DATA_TYPE is array (num_rx_rams-1 downto 0) of 
	std_logic_vector(transceiver_mem_width-1 downto 0); 
signal temp_RAM_DATA		:	RAM_DATA_TYPE;


signal kin_ena :	std_logic;		-- Data in is a special code, not all are legal.	
signal ein_ena :	std_logic;		-- Data (or code) input enable
signal din_ena :	std_logic;		-- Data (or code) input enable
signal dout_val0 :	std_logic;		-- data out valid LSB
signal dout_val1 :	std_logic;		-- data out valid MSB

signal RX_ALIGN_BITSLIP			:	std_logic_vector(1 downto 0);
signal RX_DATA						:	std_logic_vector(15 downto 0);
signal RX_DATA10						:	std_logic_vector(19 downto 0);
signal CHECK_WORD_1				:	std_logic_vector(7 downto 0);
signal CHECK_WORD_2				:	std_logic_vector(7 downto 0);
signal TX_DATA						: 	std_logic_vector(7 downto 0);
signal TX_DATA10						: 	std_logic_vector(9 downto 0);
signal ALIGN_SUCCESS				:  std_logic_vector(1 downto 0) := "00";
signal ALIGN_SUCCESSES			:  std_logic;
signal GOOD_DATA					:  std_logic_vector(7 downto 0);

signal TX_RDreg							: std_logic;
signal RX_RDcomb						: std_logic;
signal RX_RDreg							: std_logic;

signal INSTRUCT_READY			:	std_logic;

signal RX_OUTCLK					: 	std_logic;

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


component lvds_transceivers
	port (
			TX_DATA			: in	std_logic_vector(9 downto 0);
			TX_CLK			: in	std_logic;
			RX_ALIGN			: in	std_logic_vector(1 downto 0);
			RX_LVDS_DATA	: in	std_logic_vector(1 downto 0);
			RX_DPAhold		: in	std_logic_vector(1 downto 0);
			RX_CLK			: in	std_logic;
			RX_DPAreset		: in	std_logic_vector(1 downto 0);	
			TX_LVDS_DATA	: out	std_logic;
			RX_DPAlock		: out	std_logic_vector(1 downto 0);
			RX_DATA			: out	std_logic_vector(19 downto 0);
			TX_OUTCLK		: out	std_logic;
			RX_OUTCLK		: out std_logic);
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

-- 8b10b components

COMPONENT encoder_8b10b
	GENERIC ( METHOD : INTEGER := 1 );
	PORT
	(
		clk		:	 IN STD_LOGIC;
		rst		:	 IN STD_LOGIC;
		kin_ena		:	 IN STD_LOGIC;		-- Data in is a special code, not all are legal.	
		ein_ena		:	 IN STD_LOGIC;		-- Data (or code) input enable
		ein_dat		:	 IN STD_LOGIC_VECTOR(7 DOWNTO 0);		-- 8b data in
		ein_rd		:	 IN STD_LOGIC;		-- running disparity input
		eout_val		:	 OUT STD_LOGIC;		-- data out is valid
		eout_dat		:	 OUT STD_LOGIC_VECTOR(9 DOWNTO 0);		-- data out
		eout_rdcomb		:	 OUT STD_LOGIC;		-- running disparity output (comb)
		eout_rdreg		:	 OUT STD_LOGIC		-- running disparity output (reg)
	);
END COMPONENT;

COMPONENT decoder_8b10b
	GENERIC ( RDERR : INTEGER := 1; KERR : INTEGER := 1; METHOD : INTEGER := 1 );
	PORT
	(
		clk		:	 IN STD_LOGIC;
		rst		:	 IN STD_LOGIC;
		din_ena		:	 IN STD_LOGIC;		-- 10b data ready
		din_dat		:	 IN STD_LOGIC_VECTOR(9 DOWNTO 0);		-- 10b data input
		din_rd		:	 IN STD_LOGIC;		-- running disparity input
		dout_val		:	 OUT STD_LOGIC;		-- data out valid
		dout_dat		:	 OUT STD_LOGIC_VECTOR(7 DOWNTO 0);		-- data out
		dout_k		:	 OUT STD_LOGIC;		-- special code
		dout_kerr		:	 OUT STD_LOGIC;		-- coding mistake detected
		dout_rderr		:	 OUT STD_LOGIC;		-- running disparity mistake detected
		dout_rdcomb		:	 OUT STD_LOGIC;		-- running disparity output (comb)
		dout_rdreg		:	 OUT STD_LOGIC		-- running disparity output (reg)
	);
END COMPONENT;

begin

xALIGN_INFO       <= ALIGN_SUCCESS(0) & ALIGN_SUCCESS(1) & xFE_ALIGN_SUCCESS;
ALIGN_SUCCESSES	<= ALIGN_SUCCESS(0) and ALIGN_SUCCESS(1) and xFE_ALIGN_SUCCESS;
xALIGN_SUCCESS 	<= ALIGN_SUCCESSES;
WRITE_CLOCK			<= RX_OUTCLK;
xRAM_FULL_FLAG		<= RAM_FULL_FLAG;
xCC_SEND_TRIGGER	<= xTRIGGER;
xCATCH_PKT     	<= START_WRITE; 

--Check if Link is disconnected
process(xCLK)
variable i : integer range 5 downto 0;
begin
	if xCLR_ALL = '1' then
		LINK_STATE <= DOWN;
		i := 0;
	elsif rising_edge(xCLK) then
		if (RX_DATA10(19 downto 10) = x"2FF") or (RX_DATA10(9 downto 0) = x"2FF") then
			LINK_STATE <= DOWN;
			i := 0;
		else
			if i < 5 then
				LINK_STATE <= CHECKING;
				i := i + 1;
			else
				LINK_STATE <= UP;
			end if;
		end if;
	end if;
end process;

din_ena <= '1' when LINK_STATE = UP else '0';

process(xCLK, xCLR_ALL)
variable i : integer range 5 downto 0;	
begin
	if xCLR_ALL = '1' then
		TX_DATA <= K28_1;
		kin_ena <= '1';
		ein_ena <= '0';
		ALIGN_SUCCESS <= "00";
		RX_ALIGN_BITSLIP <= "00";
		i := 0;
	elsif falling_edge(xCLK) and xPLL_LOCKED = '1' then
		if (LINK_STATE /= UP) then
			TX_DATA <= K28_1;
			kin_ena <= '1';
			ein_ena <= '0';
			ALIGN_SUCCESS <= "00";
			i := 0;
		else
			if dout_val0 = '0' or dout_val1 = '0' then  -- link is up, but decoder doesn't see valid data
				TX_DATA <= K28_7;
				kin_ena <= '1';
				ein_ena <= '0';
				ALIGN_SUCCESS <= "00";
				i := 0;
			else -- link is up and data is valid
				if i < 5 then
					i := i + 1;
					TX_DATA <= K28_5;
					kin_ena <= '1';
					ein_ena <= '0';
					ALIGN_SUCCESS <= "00";
				else
					TX_DATA <= GOOD_DATA;
					kin_ena <= '0';
					ein_ena <= '1';
					ALIGN_SUCCESS <= "11";
				end if;
			end if;
		end if;
	end if;
end process;


process(xCLK, ALIGN_SUCCESSES, xDC_MASK, xCLR_ALL)
variable i : integer range 50 downto 0;	
begin
	if xCLR_ALL = '1' or xCC_INSTRUCT_RDY = '0' then
		--CC_INSTRUCTION <= (others=>'0');
		INSTRUCT_READY <= '0';
		i := 0;
		GOOD_DATA <= (others=>'0');
		SEND_CC_INSTRUCT_STATE <= IDLE;
		
	elsif rising_edge(xCLK) and ALIGN_SUCCESSES = '1' and xCC_INSTRUCT_RDY = '1' and xDC_MASK = '1' then
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
				GOOD_DATA <= (others=>'0');
				INSTRUCT_READY <= '1';
				--i := i + 1;
				--if i = 10 then
				--	i := 0;
				--	SEND_CC_INSTRUCT_STATE <= IDLE;
				--end if;
		end case;
	end if;
end process;

--look for start/stop word to write lvds data to CC ram.
process(WRITE_CLOCK, xCLR_ALL, RX_DATA)
begin
	if xCLR_ALL = '1' or xDONE = '1' or xSOFT_RESET = '1' then
		START_WRITE <= '0';
		STOP_WRITE	<= '0';
	elsif falling_edge(WRITE_CLOCK) and ALIGN_SUCCESSES = '1' then
		CHECK_RX_DATA <= RX_DATA;
		if CHECK_RX_DATA = STARTWORD then
			START_WRITE <= '1';
		elsif CHECK_RX_DATA = ENDWORD then
			STOP_WRITE <= '1';
		end if;
	end if;
end process;

process(WRITE_CLOCK, xCLR_ALL, xDONE)
begin
	if xCLR_ALL ='1'  or ALIGN_SUCCESSES = '0' or 
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
	
	elsif rising_edge(WRITE_CLOCK) and START_WRITE = '1' then
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
					
	elsif falling_edge(WRITE_CLOCK) and START_WRITE = '1' 
						and STOP_WRITE = '0' then
		WRITE_ADDRESS 	<= WRITE_ADDRESS_TEMP;
		WRITE_ENABLE 	<= WRITE_ENABLE_TEMP;	
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

tx_enc : encoder_8b10b
	GENERIC MAP( METHOD => 1 )
	PORT MAP(
		clk => xCLK,
		rst => xCLR_ALL,
		kin_ena => kin_ena,		-- Data in is a special code, not all are legal.	
		ein_ena => ein_ena,		-- Data (or code) input enable
		ein_dat => TX_DATA,		-- 8b data in
		ein_rd => TX_RDreg,		-- running disparity input
		eout_val => open,		-- data out is valid
		eout_dat => TX_DATA10,		-- data out
		eout_rdcomb => open,		-- running disparity output (comb)
		eout_rdreg => TX_RDreg);		-- running disparity output (reg)

rx_dec0 : decoder_8b10b
	GENERIC MAP(
		RDERR =>1,
		KERR => 1,
		METHOD => 1)
	PORT MAP(
		clk => RX_OUTCLK,
		rst => xCLR_ALL,
		din_ena => din_ena,		-- 10b data ready
		din_dat => RX_DATA10(9 downto 0),		-- 10b data input
		din_rd => RX_RDreg,		-- running disparity input
		dout_val => dout_val0,		-- data out valid
		dout_dat => RX_DATA(7 downto 0),		-- data out
		dout_k => open,		-- special code
		dout_kerr => open,		-- coding mistake detected
		dout_rderr => open,		-- running disparity mistake detected
		dout_rdcomb => RX_RDcomb,		-- running disparity output (comb)
		dout_rdreg => open);		-- running disparity output (reg)
		
rx_dec1 : decoder_8b10b
	GENERIC MAP(
		RDERR =>1,
		KERR => 1,
		METHOD => 1)
	PORT MAP(
		clk => RX_OUTCLK,
		rst => xCLR_ALL,
		din_ena => din_ena,		-- 10b data ready
		din_dat => RX_DATA10(19 downto 10),		-- 10b data input
		din_rd => RX_RDcomb,		-- running disparity input
		dout_val => dout_val1,		-- data out valid
		dout_dat => RX_DATA(15 downto 8),		-- data out
		dout_k => open,		-- special code
		dout_kerr => open,		-- coding mistake detected
		dout_rderr => open,		-- running disparity mistake detected
		dout_rdcomb => open,		-- running disparity output (comb)
		dout_rdreg => RX_RDreg);		-- running disparity output (reg)


xlvds_transceivers : lvds_transceivers
port map(
			RX_CLK			=>		xRX_LVDS_CLK,
			TX_CLK			=>		xCLK,
			TX_DATA			=>		TX_DATA10,
			RX_ALIGN			=>		RX_ALIGN_BITSLIP,
			RX_LVDS_DATA	=>		xRX_LVDS_DATA,
			
			RX_DPAhold		=>		'1' & '1',
			RX_DPAreset		=>		xCLR_ALL & xCLR_ALL,  -- To simulate this line, compile with 1076-2008
			TX_LVDS_DATA	=>		xTX_LVDS_DATA,
			RX_DPAlock		=>    open,
			RX_DATA			=>		RX_DATA10,
			TX_OUTCLK		=>		xTX_LVDS_CLK,
			RX_OUTCLK		=>		RX_OUTCLK);	
			
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
