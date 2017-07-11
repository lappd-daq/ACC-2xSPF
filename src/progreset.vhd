---------------------------------------------------------------------------------
-- Univ. of Chicago  
--    --KICP--
--
-- PROJECT:      phased-array trigger board
-- FILE:         progreset.vhd
-- AUTHOR:       e.oberla
-- EMAIL         ejo@uchicago.edu
-- DATE:         1/2016
--
-- DESCRIPTION:  global resets
--               a numver of typical firmware 'good design techniques' are 
--               abandoned here due to the nature of asynch resets
---------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity progreset is
	generic(
		USE_USB		:  std_logic;
		STARTUP_CNT	:	std_logic_vector(20 downto 0));-- := std_logic_vector(to_unsigned(3000000,24))); --(23 downto 0) := x"1FFF0"); 
	Port(
		CLK			:	in		std_logic;  --1 MHz from FPGA PLL
		CLK_RDY		:	in		std_logic;  --FPGA pll lock signal
		PULSE_RES	:	in		std_logic;	--user input, rising edge
		WAKEUP_USB	:  in		std_logic;
		Reset			:	out	std_logic;	--active hi
		Reset_b		:	out	std_logic); --active lo
end progreset;

architecture Behavioral of progreset is

	type 		RESET_STATE is (CLEAR, READY);
	signal	xPOWER_UP		:	RESET_STATE := CLEAR;
	signal	xSIG_RESTART	:	RESET_STATE;
	signal	xUSB_WAKEUP		:	RESET_STATE;

	signal	xSTARTUP_COUNT	:	std_logic_vector(23 downto 0) := (others=>'0');
	signal	xRESET_PWR		:	std_logic := '1';
	signal 	xRESET_USB		:	std_logic := '1';
	signal	xRESET_SIG		:	std_logic_vector(2 downto 0) 	:= (others=>'0');
	
begin

	Reset  <=     xRESET_PWR or xRESET_SIG(2) or (xRESET_USB and USE_USB);
	Reset_b<= not(xRESET_PWR or xRESET_SIG(2) or (xRESET_USB and USE_USB));
	--------------------------------------
	--process to create reset upon startup
	proc_pwrup_reset : process(CLK, CLK_RDY, xSTARTUP_COUNT)
	begin

		if rising_edge(CLK) then --and CLK_RDY = '1' then
			case xPOWER_UP is
				when CLEAR =>
					xRESET_PWR <= '1';
					
					if xSTARTUP_COUNT >=  x"21FFF0" then --STARTUP_CNT then -- 
						xPOWER_UP <= READY;
					else
						xSTARTUP_COUNT <= xSTARTUP_COUNT + 1;
						xPOWER_UP <= CLEAR;
					end if;
					
				when READY =>
					xRESET_PWR <= '0';
				
				when others=>
					xRESET_PWR <= '0';
			end case;
		end if;
	end process;
	--------------------------------------
	--process to create reset upon pugging in USB
	--ignored if generic USE_USB = '0'
	proc_reset_usb : process(WAKEUP_USB, CLK) 
	variable i: integer range 0 to 144000000 :=0;
	begin	
		if WAKEUP_USB = '0' then -- asynchronous reset
			xRESET_USB <= '1';
			xUSB_WAKEUP <= CLEAR;		
		elsif CLK = '1' and CLK'event then		
			case	xUSB_WAKEUP is
				when CLEAR =>
						xRESET_USB <= '1';

						if i > 4000000 then
							i:=0;
							xUSB_WAKEUP <= READY;
						else
							if WAKEUP_USB = '1' then
								i := i + 1;
								xUSB_WAKEUP <= CLEAR;
							else
								xUSB_WAKEUP <= CLEAR;
							end if;
						end if;
				when READY =>
					if WAKEUP_USB = '1' then
						xRESET_USB <= '0';
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
	
	--user-provided reset:
	--xRESET_SIG(0) => de-asserts (1), set active 1-clock cycle after (2) 
	--xRESET_SIG(1) => signal latched on user input
	--xRESET_SIG(2) => registered reset signal
	proc_latch_user : process(CLK, PULSE_RES)
	begin
		if xRESET_SIG(0) = '1' or xRESET_PWR = '1' then
			xRESET_SIG(1) <= '0';
		elsif rising_edge(PULSE_RES) then --latch on user-provided signal
			xRESET_SIG(1) <= '1';		
		end if;
	end process;
	
	
	proc_user_reset : process(CLK, xRESET_SIG(1))
	variable i : integer range 100010 downto 0 := 0;	
	begin
		if xRESET_SIG(1) = '0' then
			xRESET_SIG(2) 	<= '0';
			xRESET_SIG(0) 	<= '0';
			i := 0;
			xSIG_RESTART	<= CLEAR;
		elsif rising_edge(CLK) and xRESET_SIG(1) = '1' then
			case xSIG_RESTART is
				when CLEAR =>
					if i > 100000 then
						i := 0;
						xRESET_SIG(2) <= '0';
						xSIG_RESTART  <= READY;
					else
						i := i + 1;
						xRESET_SIG(2) <= '1';
					end if;
					
				when READY =>
					xRESET_SIG(0) <= '1';
					
				when others =>
					Null;
					
			end case;
		end if;
	end process;
	
end Behavioral;

