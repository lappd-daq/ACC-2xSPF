---------------------------------------------------------------------------------
-- Univ. of Chicago  
--    --KICP--
--
-- PROJECT:      ANNIE
-- FILE:         clock_manager.vhd
-- AUTHOR:       e.oberla
-- EMAIL         ejo@uchicago.edu
-- DATE:         1/2016
--
-- DESCRIPTION:  clocks, top level
--
---------------------------------------------------------------------------------

library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity Clock_Manager is
	Port(
		Reset			:  in		std_logic;
		INCLK0		:	in		std_logic;
		INCLK1		:  in		std_logic;
		INCLK2		:	in		std_logic;
		INCLK3		:  in		std_logic;
		PLL_reset	:  in		std_logic;
		
		CLK_SYS_4x	: 	out	std_logic;
		CLK_SYS		:  out	std_logic; 
		
		CLK_1MHz		:  out	std_logic;
		CLK_1Hz		:  out	std_logic;
		CLK_10Hz		:  out	std_logic;
		CLK_1kHz		:	out	std_logic;
		
		fpgaPLLlock :	out	std_logic);

end Clock_Manager;

architecture Structural of Clock_Manager is

	signal	xCLK_1MHz	:	std_logic;
	signal	xCLK_1kHz	:	std_logic;
	signal	xCLK_1Hz		:	std_logic;
	signal	xCLK_10Hz	:	std_logic;
	
	component pll_block
		port( refclk, rst		: in 	std_logic;
				outclk_0, outclk_1, outclk_2,
				locked			: out	std_logic);
	end component;
	
	component Slow_Clocks
		generic(clk_divide_by   : integer := 500);
		port( IN_CLK, Reset		: in	std_logic;
				OUT_CLK				: out	std_logic);
	end component;	
	
begin

	CLK_1MHz	<=	xCLK_1MHz;
	CLK_1Hz	<=	xCLK_1Hz;
	CLK_10Hz	<=	xCLK_10Hz;
	CLK_1kHz	<=	xCLK_1kHz;

	xPLL_BLOCK : pll_block
		port map(refclk 	=> INCLK0, 
					rst		=> PLL_reset, 
					outclk_0	=> CLK_SYS, 
					outclk_1	=> xCLK_1MHz, 
					outclk_2	=> CLK_SYS_4x, 
					locked	=> fpgaPLLlock);
	

	xCLK_GEN_1kHz : Slow_Clocks
		generic map(clk_divide_by => 500)
		port map(xCLK_1MHz, Reset, xCLK_1kHz);

	xCLK_GEN_1Hz : Slow_Clocks
		generic map(clk_divide_by => 50000)
		port map(xCLK_1MHz, Reset, xCLK_10Hz);

	xCLK_GEN_10Hz : Slow_Clocks
		generic map(clk_divide_by => 500000)
		port map(xCLK_1MHz, Reset, xCLK_1Hz);
		
end Structural;

		
	

