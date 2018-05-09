-- Copyright (C) 2018  Intel Corporation. All rights reserved.
-- Your use of Intel Corporation's design tools, logic functions 
-- and other software and tools, and its AMPP partner logic 
-- functions, and any output files from any of the foregoing 
-- (including device programming or simulation files), and any 
-- associated documentation or information are expressly subject 
-- to the terms and conditions of the Intel Program License 
-- Subscription Agreement, the Intel Quartus Prime License Agreement,
-- the Intel FPGA IP License Agreement, or other applicable license
-- agreement, including, without limitation, that your use is for
-- the sole purpose of programming logic devices manufactured by
-- Intel and sold by Intel or its authorized distributors.  Please
-- refer to the applicable agreement for further details.

-- PROGRAM		"Quartus Prime"
-- VERSION		"Version 18.0.0 Build 614 04/24/2018 SJ Standard Edition"
-- CREATED		"Wed May 09 14:45:42 2018"

LIBRARY ieee;
USE ieee.std_logic_1164.all; 

LIBRARY work;

ENTITY rx_ram IS 
	PORT
	(
		xWR_EN :  IN  STD_LOGIC;
		xRD_EN :  IN  STD_LOGIC;
		xWR_CLK :  IN  STD_LOGIC;
		xRD_CLK :  IN  STD_LOGIC;
		xDATA :  IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
		xRD_ADRS :  IN  STD_LOGIC_VECTOR(14 DOWNTO 0);
		xWR_ADRS :  IN  STD_LOGIC_VECTOR(14 DOWNTO 0);
		xRAM_DATA :  OUT  STD_LOGIC_VECTOR(15 DOWNTO 0)
	);
END rx_ram;

ARCHITECTURE bdf_type OF rx_ram IS 

COMPONENT rx_data_ram
	PORT(wren : IN STD_LOGIC;
		 rden : IN STD_LOGIC;
		 wrclock : IN STD_LOGIC;
		 rdclock : IN STD_LOGIC;
		 rd_aclr : IN STD_LOGIC;
		 data : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		 rdaddress : IN STD_LOGIC_VECTOR(12 DOWNTO 0);
		 wraddress : IN STD_LOGIC_VECTOR(12 DOWNTO 0);
		 q : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
	);
END COMPONENT;

SIGNAL	ra :  STD_LOGIC_VECTOR(14 DOWNTO 0);
SIGNAL	wa :  STD_LOGIC_VECTOR(14 DOWNTO 0);
SIGNAL	SYNTHESIZED_WIRE_0 :  STD_LOGIC;


BEGIN 
SYNTHESIZED_WIRE_0 <= '0';



b2v_inst : rx_data_ram
PORT MAP(wren => xWR_EN,
		 rden => xRD_EN,
		 wrclock => xWR_CLK,
		 rdclock => xRD_CLK,
		 rd_aclr => SYNTHESIZED_WIRE_0,
		 data => xDATA,
		 rdaddress => ra(12 DOWNTO 0),
		 wraddress => wa(12 DOWNTO 0),
		 q => xRAM_DATA);


ra <= xRD_ADRS;
wa <= xWR_ADRS;

END bdf_type;