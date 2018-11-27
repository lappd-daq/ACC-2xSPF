-- Copyright (C) 1991-2015 Altera Corporation. All rights reserved.
-- Your use of Altera Corporation's design tools, logic functions 
-- and other software and tools, and its AMPP partner logic 
-- functions, and any output files from any of the foregoing 
-- (including device programming or simulation files), and any 
-- associated documentation or information are expressly subject 
-- to the terms and conditions of the Altera Program License 
-- Subscription Agreement, the Altera Quartus Prime License Agreement,
-- the Altera MegaCore Function License Agreement, or other 
-- applicable license agreement, including, without limitation, 
-- that your use is for the sole purpose of programming logic 
-- devices manufactured by Altera and sold by Altera or its 
-- authorized distributors.  Please refer to the applicable 
-- agreement for further details.

-- PROGRAM		"Quartus Prime"
-- VERSION		"Version 15.1.0 Build 185 10/21/2015 SJ Standard Edition"
-- CREATED		"Wed Jan 31 15:24:29 2018"

LIBRARY ieee;
USE ieee.std_logic_1164.all; 

LIBRARY work;
use work.defs.all;


ENTITY lvds_transceivers IS 
	PORT
	(
		xCLK 				:  IN  STD_LOGIC;
		xCLR_ALL 		:  IN  STD_LOGIC;
		RX_LVDS_DATA 	:  IN  STD_LOGIC;
		TX_DATA 			:  IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
		TX_DATA_RDY 	:  IN  STD_LOGIC;
		TRIGGER_PREP	:  IN  STD_LOGIC;
		ST_ENABLE_PREP	:  IN  STD_LOGIC;
		TRIGGER			:  IN  STD_LOGIC;
		REMOTE_UP 		:  OUT STD_LOGIC;
		REMOTE_VALID 	:  OUT STD_LOGIC;
		TX_BUF_FULL 	:  OUT STD_LOGIC;
		RX_ERROR 		:  OUT STD_LOGIC;
		TX_LVDS_DATA 	:  OUT STD_LOGIC;
		RX_DATA_RDY		:  OUT STD_LOGIC;
		TRIG_READY		:  OUT STD_LOGIC;
		RX_DATA 			:  OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
		
	);
END lvds_transceivers;

ARCHITECTURE bdf_type OF lvds_transceivers IS 

component tx_fifo
	PORT
	(
		aclr		: IN STD_LOGIC  := '0';
		data		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		rdclk		: IN STD_LOGIC ;
		rdreq		: IN STD_LOGIC ;
		wrclk		: IN STD_LOGIC ;
		wrreq		: IN STD_LOGIC ;
		q		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
		rdempty		: OUT STD_LOGIC ;
		wrfull		: OUT STD_LOGIC 
	);
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


COMPONENT uart
	GENERIC ( BITS	: INTEGER := 8;
				 CLK_HZ : INTEGER := 50000000; 
				 BAUD : INTEGER := 115200; 
				 BAUD_DIVISOR : INTEGER);
	PORT
	(
		clk				:	 IN STD_LOGIC;
		rst				:	 IN STD_LOGIC;
		tx_data			:	 IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		tx_data_valid	:	 IN STD_LOGIC;
		tx_data_ack		:	 OUT STD_LOGIC;
		txd				:	 OUT STD_LOGIC;
		rx_data			:	 OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		rx_data_fresh	:	 OUT STD_LOGIC;
		rxd				:	 IN STD_LOGIC
	);
END COMPONENT;



type LINK_STATE_TYPE is (DOWN, CHECKING, UP, ERROR);
signal LINK_STATE : LINK_STATE_TYPE;
signal REMOTE_LINK_STATE : LINK_STATE_TYPE;

signal ein_dat	:	std_logic;		-- Enconder input data or code
signal kin_ena :	std_logic;		-- Data in is a special code, not all are legal.	
signal ein_ena :	std_logic;		-- Data (or code) input enable
signal eout_val :  std_logic;		-- Encoder data out is valid
signal dout_val :	std_logic;		-- data out valid LSB
signal dout_k :	std_logic;		-- special code
signal dout_kerr		:  std_logic;		-- coding mistake detected
signal dout_rderr		:  std_logic; 		-- running disparity mistake detected
signal dout_error 	:  std_logic;		-- any decoding error on either interface


signal TX_FIFO_EMPTY					:  std_logic;
signal TX_FIFO_Q						:  std_logic;
signal TX_FIFO_WRREQ					:  std_logic;

signal OUT_DATA						:  std_logic_vector(7 downto 0);
signal STATUS_CODE					:  std_logic_vector(7 downto 0);
signal RX_DATA10						:	std_logic_vector(9 downto 0);
signal TX_DATA10						: 	std_logic_vector(9 downto 0);
signal TX_RDreg						: std_logic;
signal RX_RDreg						: std_logic;

signal uart_txd						: std_logic;

TYPE TRIG_STATE_TYPE is (NONE, TRIG_PREP, ST_ENABLE_PREP);
signal TRIG_STATE 	: TRIG_STATE_TYPE;

TYPE TX_STATE_TYPE is (RESET, READY, ST_PREP, ST_ENABLED, TRIG_PREP, TRIG_WAIT, WAITING);
signal TX_STATE		: TX_STATE_TYPE;

TYPE RX_STATE_TYPE is (RESET, WAITING, WAITING_LSB, ERROR);
signal RX_STATE		: RX_STATE_TYPE;

signal tx_data_ack	:  std_logic;		-- data acknowledge from the UART
signal rx_data_fresh :  std_logic;		-- new data from the UART

--signal rx_clk_buf		:  std_logic;


BEGIN 

tx_fifo0 : tx_fifo
	PORT MAP
	(
		aclr		=> xCLR_All,
		data		=> TX_DATA,
		rdclk		=> xCLK,
		rdreq		=> TX_DATA_RDY,
		wrclk		=> xCLK,
		wrreq		=> TX_FIFO_WRREQ,
		q			=> TX_FIFO_Q,
		rdempty	=> TX_FIFO_EMPTY,
		wrfull	=> TX_BUF_FULL
	);


process(xCLK, xCLR_ALL)
variable i : integer range 5 downto 0;	
begin
	if xCLR_ALL = '1' then
		STATUS_CODE <= K28_1;
		i := 0;
	elsif rising_edge(xCLK) then
		if (LINK_STATE /= UP) then
			STATUS_CODE <= K28_1;
			i := 0;
		else 		-- link is up
			if dout_error = '1' then  -- but decoder doesn't see valid data
				STATUS_CODE <= K28_7;
				i := 0;
			else -- link is up and data is valid
				if i < 5 then
					i := i + 1;
				else
					STATUS_CODE <= K28_5;
				end if;
			end if;
		end if;
	end if;
end process;

process(xCLK, xCLR_ALL)
variable counter 	: integer range 200000000 downto 0;
begin
	if xCLR_ALL = '1' or TRIG_STATE_ACK = '1' then
		TRIG_STATE <= NONE;
		counter := 0;
	elsif rising_edge(xCLK) then
		case TRIG_STATE is
			when NONE =>
				counter := 0;
				if TRIGGER_PREP = '1' then
					TRIG_STATE <= TRIG_PREP;
				elsif ST_ENABLE_PREP = '1' then
					TRIG_STATE <= ST_ENABLE;
				else
					TRIG_STATE <= NONE;
				end if;
			when others =>
				counter := counter + 1;
				if counter > 125000000 then -- timeout
					TRIG_STATE <= NONE;
				end if;
		end case;
	end if;
end process;

process(xCLK, xCLR_ALL)
begin
	if xCLR_ALL = '1' then
		TX_STATE <= RESET;
		TRIG_STATE_ACK <= '0';
		TRIG_READY <= '0';
	elsif rising_edge(xCLK) then
		case TX_STATE is
			when RESET =>
				TX_STATE <= DATA_READY;
				ein_dat <= (others => '0');
				kin_ena <= '0';
				ein_ena <= '0';
				TRIG_STATE_ACK <= '0';
				TRIG_READY <= '0';
			when READY =>
				if TX_FIFO_EMPTY = '0' then  -- clear FIFO is top priority
					ein_dat <= TX_FIFO_Q;
					kin_ena <= '0';
				else
					case TRIG_STATE is
						when TRIG_PREP =>
							TX_STATE <= TRIG_PREP;
							ein_DAT <= K29_7;
							kin_ena <= '1';
							TRIG_STATE_ACK <= '1';
						when ST_ENABLE =>
							TX_STATE <= ST_PREP;
							ein_dat <= K30_7;
							kin_ena <= '1';
							TRIG_STATE_ACK <= '1';
						when others => -- just send the status code
							ein_dat <= STATUS_CODE;
							kin_ena <= '1';
					end case;
				end if;
				ein_ena <= '1';
				TX_STATE <= WAITING;
				
			-- ST_PREP, ST_ENABLED, TRIG_PREP, TRIG_WAIT
			when TRIG_PREP =>
				TRIG_STATE_ACK <= '0';
				if tx_data_ack = '1' then
					TX_STATE <= TRIG_WAIT;
				end if;
			when TRIG_WAIT =>
				-- wait for tigger
			when ST_PREP =>
				TRIG_STATE_ACK <= '0';
				if tx_data_ack = '1' then
					TX_STATE <= ST_ENABLED;
				end if;
			when ST_ENABLED =>
				-- wait for trigger
			when WAITNG =>
				ein_ena <= '0';
				if tx_data_ack = '1' then
					TX_STATE <= READY;
				end if;
			when OTHERS =>
				TX_STATE <= RESET;
		end case;
	end if;
end process;


with TX_STATE select
	TX_LVDS_DATA 	<= TRIGGER when TRIG_WAIT,
							TRIGGER when ST_ENABLED,
							uart_txd when others;

with TX_STATE select
	TRIG_READY 		<= '1' when TRIG_WAIT,
							'1' when ST_ENABLED,
							'0' when others;



tx_enc : encoder_8b10b
	GENERIC MAP( METHOD => 1 )
	PORT MAP(
		clk => xCLK,
		rst => xCLR_ALL,
		kin_ena => kin_ena,		-- Data in is a special code, not all are legal.	
		ein_ena => ein_ena,		-- Data (or code) input enable
		ein_dat => ein_dat,		-- 8b data in
		ein_rd => TX_RDreg,		-- running disparity input
		eout_val => eout_val,		-- data out is valid
		eout_dat => TX_DATA10,		-- data out
		eout_rdcomb => open,		-- running disparity output (comb)
		eout_rdreg => TX_RDreg);		-- running disparity output (reg)



-- add a state machine to control data in and out of the uart

uart0 : uart
	GENERIC map 
	(	BITS => 10,
		CLK_HZ	=> 125000000,
		BAUD => 10000000)
	PORT map
	(
		clk => xCLK,
		rst => xCLR_ALL,
		tx_data => TX_DATA10,
		tx_data_valid => eout_val,
		tx_data_ack	=> tx_data_ack,
		txd => uart_txd,
		rx_data => RX_DATA10,
		rx_data_fresh => rx_data_fresh,
		rxd => RX_LVDS_DATA
	);

rx_dec0 : decoder_8b10b
	GENERIC MAP(
		RDERR =>1,
		KERR => 1,
		METHOD => 1)
	PORT MAP(
		clk => xCLK,
		rst => xCLR_ALL,
		din_ena => rx_data_fresh,		-- 10b data ready
		din_dat => RX_DATA10(9 downto 0),		-- 10b data input
		din_rd => RX_RDreg,		-- running disparity input
		dout_val => dout_val,		-- data out valid
		dout_dat => RX_DATA(7 downto 0),		-- data out
		dout_k => dout_k,		-- special code
		dout_kerr => dout_kerr,		-- coding mistake detected
		dout_rderr => dout_rderr,		-- running disparity mistake detected
		dout_rdcomb => open,		-- running disparity output (comb)
		dout_rdreg => RX_RDreg);		-- running disparity output (reg)



--Check if Link is disconnected
process(xCLK)
variable counter 	: integer range 200000000 downto 0;
variable dff1,dff2,dff3		: std_logic;
variable edge		: std_logic;
begin
	if xCLR_ALL = '1' then
		dff1		:= '0';
		dff2		:= '0';
		dff3		:= '0';
		edge		:= dff2 xor dff3;
		counter	:= 0;
		LINK_STATE <= DOWN;
	elsif rising_edge(xCLK) then
		edge 	:= dff2 xor dff3;
		dff3  := dff2;
		dff2	:= dff1;
		dff1  := RX_LVDS_DATA;
		case LINK_STATE is
			when DOWN =>
				if edge = '1' then
					counter := 0;
					LINK_STATE <= CHECKING;
				end if;
			when CHECKING =>
				if dout_val = '1' then
					counter := 0;
					LINK_STATE <= UP;
				else
					counter := counter + 1;
					if counter > 125000000 then -- check if we're past timeout
						LINK_STATE <= DOWN;
						counter := 0;
					end if;
				end if;
			when UP =>
				if dout_val = '1' then
					counter := 0;
				else
					counter := counter + 1;
					if counter > 125000000 then
						LINK_STATE <= CHECKING;
						counter := 0;
					end if;
				end if;
			when others =>
				LINK_STATE <= DOWN;
		end case;
		LINK_STATE <= DOWN;
	end if;
end process;

REMOTE_UP <= '1' when LINK_STATE /= DOWN else '0';
REMOTE_VALID <= '1' when LINK_STATE = UP else '0';

--TYPE RX_STATE_TYPE is (RESET, WAITING, CODE_READY, WAITING_LSB, ERROR, DATA_READY);
--signal RX_STATE		: RX_STATE_TYPE;

-- pick output  RESET, DATA_READY, WAITING
process(xCLK, xCLR_ALL)
	variable temp_data : std_logic_vector(7 downto 0) := (others => '0');
begin
	if xCLR_ALL = '1' then
		RX_STATE 		<= RESET;
		RX_ERROR 		<= '1';
		RX_DATA_RDY		<= '0';
		RX_DATA 			<= (others => '0');
		temp_data		:= (others => '0');
		REMOTE_LINK_STATE <= DOWN;
	elsif rising_edge(xCLK) then
		case RX_STATE is
			when RESET =>
				RX_ERROR 		<= '0';
				RX_DATA_RDY		<= '0';
				RX_DATA 			<= (others => '0');
				temp_data		:= (others => '0');
				RX_state 		<= WAITING;
			when WAITING =>
				RX_ERROR <= '0';
				RX_DATA_RDY <= '0';
				RX_DATA <= '0';
				if dout_kerr = '1' then
					RX_STATE <= ERROR;
				elsif dout_val = '1' then
					if dout_k = '1' then
						if dout_dat = K28_1 then
							REMOTE_LINK_STATE <= DOWN;
						elsif dout_dat = K28_7 then
							REMOTE_LINK_STATE <= CHECKING;
						elsif dout_dat = K28_5 then
							REMOTE_LINK_STATE <= UP;
						end if;
						RX_STATE <= WAITING;
					else
						temp_data := dout_dat;
						RX_STATE <= WAITING_LSB;
					end if;
				else
					RX_STATE <= WAITING;
				end if;
			when WAITING_LSB =>
				if dout_kerr = '1' then
					RX_STATE <= ERROR;
				elsif dout_val = '1' then
					RX_DATA <= temp_data & dout_dat;
					RX_DATA_RDY <= '1';
					RX_STATE <= WAITING;
				end if;
			when ERROR =>
				--handle error
				RX_STATE <= RESET;
			when OTHERS =>
				RX_STATE <= RESET;
		end case;
	end if;
end process;
		

dout_error <= dout_kerr or dout_rderr;




END bdf_type;