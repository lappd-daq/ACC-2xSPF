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
		
		CLK_RX 		: 	out std_logic_vector(7 downto 0);
		CLK_RX_LOCKED 			:  out	std_logic;
		CLK_RX_PHASE_EN 		:  in		std_logic;
		CLK_RX_PHASE_UPDN 	:  in 	std_logic;
		CLK_RX_PHASE_SEL 		:  in  std_logic_vector(4 downto 0);
		CLK_RX_PHASE_DONE 	:  out 	std_logic;
		
		CLK_1MHz		:  out	std_logic;
		CLK_1Hz		:  out	std_logic;
		CLK_10Hz		:  out	std_logic;
		CLK_1kHz		:	out	std_logic;
		
		fpgaPLLlock :	out	std_logic;
		fpgaPLL2lock :	out	std_logic;
		fpgaPLL3lock :	out	std_logic);

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


	component pll_block_transceivers is
		port (
			refclk     : in  std_logic                    := 'X';             -- clk
			rst        : in  std_logic                    := 'X';             -- reset
			outclk_0   : out std_logic;                                       -- clk
			outclk_1   : out std_logic;                                       -- clk
			outclk_2   : out std_logic;                                       -- clk
			outclk_3   : out std_logic;                                       -- clk
			outclk_4   : out std_logic;                                       -- clk
			outclk_5   : out std_logic;                                       -- clk
			outclk_6   : out std_logic;                                       -- clk
			outclk_7   : out std_logic;                                       -- clk
			locked     : out std_logic;                                       -- export
			phase_en   : in  std_logic                    := 'X';             -- phase_en
			scanclk    : in  std_logic                    := 'X';             -- scanclk
			updn       : in  std_logic                    := 'X';             -- updn
			cntsel     : in  std_logic_vector(4 downto 0) := (others => 'X'); -- cntsel
			phase_done : out std_logic                                        -- phase_done
		);
	end component pll_block_transceivers;
	
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
		port map(INCLK0, PLL_reset, CLK_SYS, 
					xCLK_1MHz, CLK_SYS_4x, fpgaPLLlock);
	
	xPLL_BLOCK_2 : pll_block_transceivers
		port map(
			refclk => INCLK0,						-- clk
			rst    => PLL_reset,					-- reset
			outclk_0   => CLK_RX(0),
			outclk_1   => CLK_RX(1),
			outclk_2   => CLK_RX(2),
			outclk_3   => CLK_RX(3),
			outclk_4   => open,
			outclk_5   => open,
			outclk_6   => open,
			outclk_7   => open,
			locked     => CLK_RX_LOCKED,       -- export
			phase_en   => CLK_RX_PHASE_EN,     -- phase_en
			scanclk    => INCLK0,              -- scanclk  REPLACE THIS!!
			updn       => CLK_RX_PHASE_UPDN,   -- updn
			cntsel     => CLK_RX_PHASE_SEL,    -- cntsel
			phase_done => CLK_RX_PHASE_DONE); 
			
	xPLL_BLOCK_3 : pll_block_transceivers
		port map(
			refclk => INCLK0,						-- clk
			rst    => PLL_reset,					-- reset
			outclk_0   => open,
			outclk_1   => open,
			outclk_2   => open,
			outclk_3   => open,
			outclk_4   => CLK_RX(4),
			outclk_5   => CLK_RX(5),
			outclk_6   => CLK_RX(6),
			outclk_7   => CLK_RX(7),
			locked     => open,       -- export
			phase_en   => CLK_RX_PHASE_EN,     -- phase_en
			scanclk    => INCLK0,              -- scanclk  REPLACE THIS!!
			updn       => CLK_RX_PHASE_UPDN,   -- updn
			cntsel     => CLK_RX_PHASE_SEL,    -- cntsel
			phase_done => open); 
			
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

		
	

