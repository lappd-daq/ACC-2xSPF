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

ENTITY lvds_transceivers IS 
	PORT
	(
		RX_CLK :  IN  STD_LOGIC;  
		TX_CLK :  IN  STD_LOGIC;
		RX_ALIGN :  IN  STD_LOGIC_VECTOR(1 DOWNTO 0);
		RX_DPAhold :  IN  STD_LOGIC_VECTOR(1 DOWNTO 0);
		RX_DPAreset :  IN  STD_LOGIC_VECTOR(1 DOWNTO 0);
		RX_LVDS_DATA :  IN  STD_LOGIC_VECTOR(1 DOWNTO 0);
		TX_DATA :  IN  STD_LOGIC_VECTOR(9 DOWNTO 0);
		RX_OUTCLK :  OUT  STD_LOGIC;
		TX_OUTCLK :  OUT  STD_LOGIC;
		TX_LVDS_DATA :  OUT  STD_LOGIC;
		RX_DATA :  OUT  STD_LOGIC_VECTOR(19 DOWNTO 0);
		RX_DPAlock :  OUT  STD_LOGIC_VECTOR(1 DOWNTO 0)
	);
END lvds_transceivers;

ARCHITECTURE bdf_type OF lvds_transceivers IS 

component altlvds_rx0
	PORT
	(
		rx_channel_data_align		: IN STD_LOGIC_VECTOR (1 DOWNTO 0);
		rx_in		: IN STD_LOGIC_VECTOR (1 DOWNTO 0);
		rx_inclock		: IN STD_LOGIC ;
		rx_reset		: IN STD_LOGIC_VECTOR (1 DOWNTO 0);
		rx_dpa_locked		: OUT STD_LOGIC_VECTOR (1 DOWNTO 0);
		rx_out		: OUT STD_LOGIC_VECTOR (19 DOWNTO 0);
		rx_outclock		: OUT STD_LOGIC 
	);
end component;

COMPONENT altlvds_tx0
	PORT(tx_inclock : IN STD_LOGIC;
		 tx_in : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
		 tx_outclock : OUT STD_LOGIC;
		 tx_out : OUT STD_LOGIC_VECTOR(0 TO 0)
	);
END COMPONENT;

component lvds_rx_clockbuffer is
	port (
		inclk  : in  std_logic := 'X'; -- inclk
		outclk : out std_logic         -- outclk
	);
end component lvds_rx_clockbuffer;

--signal rx_clk_buf		:  std_logic;


BEGIN 

--rx_clk_buffer : lvds_rx_clockbuffer
--port map(inclk => RX_CLK,
--			outclk => rx_clk_buf);



lvds_rx : altlvds_rx0
PORT MAP(rx_inclock => RX_CLK,
		 rx_channel_data_align => RX_ALIGN(1 downto 0),
--		 rx_dpll_hold => RX_DPAhold(0 downto 0),
		 rx_in => RX_LVDS_DATA(1 downto 0),
		 rx_reset => RX_DPAreset(1 downto 0),
		 rx_outclock => RX_OUTCLK,
		 rx_dpa_locked => RX_DPAlock(1 downto 0),
		 rx_out => RX_DATA(19 downto 0));

lvds_tx : altlvds_tx0
PORT MAP(tx_inclock => TX_CLK,
		 tx_in => TX_DATA,
		 tx_outclock => TX_OUTCLK,
		 tx_out(0) => TX_LVDS_DATA);


END bdf_type;