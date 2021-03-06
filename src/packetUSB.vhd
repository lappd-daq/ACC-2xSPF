----------------------------------------------------------------------------------
-- Univ. of Chicago HEP / electronics design group
--    -- + KICP 2015 --
--
-- PROJECT:      ACC
-- FILE:         packetUSB.vhd
-- AUTHOR:       e.oberla
-- EMAIL         ejo@uchicago.edu
-- DATE:         2016 (modified from 2012 version)
--
-- DESCRIPTION:  
--
------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.defs.all;


entity packetUSB is

   port ( 
			 xSLWR					: in  std_logic;    --'Signal-Low WRite'    
			 xSTART		 			: in  std_logic;    --'Start flag'
			 xRAM_FULL				: in 	std_logic_vector(num_front_end_boards-1 downto 0);
			 xSTART_VEC				: in	std_logic_vector(num_front_end_boards-1 downto 0);
			 xCC_ONLY_START		: in	std_logic;
			 xALIGN_STATUS			: in	std_logic_vector(num_front_end_boards-1 downto 0);
			 xALIGN_INFO   		: in  std_logic_vector(11 downto 0);
			 
			 xDONE		 			: in  std_logic;
			 xCLR_ALL	 			: in  std_logic;
			 xADC						: in  rx_ram_data_type;
			 xCC_READ_MODE			: in	std_logic_vector (2 downto 0);
			 xNUM_USB_SAMPLES		: in	std_logic_vector(23 downto 0);
			 
			 xCC_INFO_0				: in	std_logic_vector(15 downto 0);
			 xCC_INFO_1				: in 	std_logic_vector(15 downto 0);
			 xCC_INFO_2				: in	std_logic_vector(15 downto 0);
			 xCC_INFO_3				: in 	std_logic_vector(15 downto 0);
			 xCC_INFO_4				: in 	std_logic_vector(15 downto 0);
			 xCC_INFO_5				: in	std_logic_vector(15 downto 0);
			 xCC_INFO_6				: in 	std_logic_vector(15 downto 0);
			 xCC_INFO_7				: in 	std_logic_vector(15 downto 0);
			 xCC_INFO_8				: in	std_logic_vector(15 downto 0);
			 xCC_INFO_9				: in 	std_logic_vector(15 downto 0);
			 
			 xDIGITIZING_FLAG  	: in	std_logic_vector(num_front_end_boards-1 downto 0);
	
			 xFPGA_DATA     		: out std_logic_vector (15 downto 0);
			 xLAST_RD_ADDR			: in	rx_ram_data_type;
			 xDC_PKT					: in	std_logic_vector(num_front_end_boards-1 downto 0);
			 xTRIG_INFO				: in	std_logic_vector(2 downto 0);
			 xRADDR					: out std_logic_vector (14 downto 0);
			 xRAM_READ_EN			: out	std_logic_vector(num_front_end_boards-1 downto 0));
end packetUSB; 

architecture Behavioral of packetUSB is
	type STATE_TYPE is ( HDR_START,INIT, INFO1, INFO2, INFO3, INFO4, INFO5, 
								ADC, DC_END, HDR_END,GND_STATE);
	signal STATE 			: STATE_TYPE;

	type CC_STATE_TYPE is ( CC_HDR_START,CC_INIT, INFO1, INFO2, INFO3, INFO4, 
									INFO5, INFO6, INFO7, INFO8, INFO9,
									CC_CLOSE, CC_HDR_END,CC_GND_STATE);
	signal CC_STATE 			: CC_STATE_TYPE;
	
	type READ_CC_BUFF_STATE_TYPE is (IDLE, READOUT, DONE);
	signal READ_CC_BUFF_STATE : READ_CC_BUFF_STATE_TYPE;
	signal RADDR				: std_logic_vector(transceiver_mem_depth-1 downto 0);
	signal FPGA_DATA			: std_logic_vector(15 downto 0);
	signal RAM_CNT				: std_logic_vector(num_front_end_boards-1 downto 0);
	signal RAM_CNT_TEMP		: std_logic_vector(num_front_end_boards-1 downto 0);
	signal RAM_READ_EN		: std_logic_vector(num_front_end_boards-1 downto 0);
	signal RAM_READ_EN_TEMP : std_logic_vector(num_front_end_boards-1 downto 0);
	signal USB_START_OR		: std_logic;
	signal mask_count 		: integer range num_front_end_boards downto 0 := 0;
	signal MESS_DONE			: std_logic;
	signal read_out_cc_buffer_flag : std_logic;
--------------------------------------------------------------------------------
begin
--------------------------------------------------------------------------------
	xFPGA_DATA 		<= FPGA_DATA;
	xRADDR 			<= RADDR;
	xRAM_READ_EN 	<= RAM_READ_EN;
--------------------------------------------------------------------------------
process(xSTART_VEC)   
begin
	case xSTART_VEC is
	when "00000001" =>
		RAM_READ_EN_TEMP <= "00000001";
		mask_count <= 0;
	when "00000010" =>
		RAM_READ_EN_TEMP <= "00000010";
		mask_count <= 1;
	when "00000100" =>
		RAM_READ_EN_TEMP <= "00000100";
		mask_count <= 2;
	when "00001000" =>
		RAM_READ_EN_TEMP <= "00001000";
		mask_count  <= 3;
	when "00010000" =>
		RAM_READ_EN_TEMP <= "00010000";
		mask_count  <= 4;
	when "00100000" =>
		RAM_READ_EN_TEMP <= "00100000";
		mask_count  <= 5;
	when "01000000" =>
		RAM_READ_EN_TEMP <= "01000000";
		mask_count  <= 6;
	when "10000000" =>
		RAM_READ_EN_TEMP <= "10000000";
		mask_count  <= 7;		
	when others =>
		RAM_READ_EN_TEMP <= (others=>'0');
		mask_count <= 8;
	end case;
end process;

process(xCLR_ALL, xCC_ONLY_START, xDONE, xCC_READ_MODE)
variable i : integer range 50 downto 0;	
begin
	if xCLR_ALL = '1' or xDONE = '1'  then
		read_out_cc_buffer_flag <= '0';
	elsif rising_edge(xCC_ONLY_START) and xCC_READ_MODE = "101" then
		read_out_cc_buffer_flag <= '1';
	end if;
end process;

--------------------------------------------------------------------------------
process(xSLWR,xSTART,xDONE,xCLR_ALL,read_out_cc_buffer_flag)
variable i : integer range 50 downto 0;	
--variable mask_count : integer range 4 downto 0 := 0;	
	begin
		if xCLR_ALL = '1' or xDONE = '1' then
			RADDR 		<= (others=>'0');--"00000000001"; --(others=>'0');
			FPGA_DATA 	<= (others=>'0');
			RAM_CNT		<= (others=>'0');
			RAM_CNT_TEMP<= (others=>'0');
			RAM_READ_EN <= (others=>'0');
			MESS_DONE   <= '0';
			i:=0;
			--mask_count:=0;
			STATE 		<= HDR_START;
			CC_STATE    <= CC_HDR_START;
		elsif falling_edge(xSLWR) and xSTART = '1' then 
			case STATE is	
				
				when HDR_START =>	
					FPGA_DATA <= x"1234";
					STATE <= INIT;	
				
				when INIT =>
					--FPGA_DATA <= xLAST_RD_ADDR(mask_count);
					FPGA_DATA <=  xCC_INFO_0;
					STATE <= INFO1;
					
				when INFO1 =>	
					FPGA_DATA <= xCC_INFO_1;
					STATE <= INFO2;
				when INFO2 =>	
					FPGA_DATA <= xCC_INFO_2;
					STATE <= INFO3;
				when INFO3 =>	
					FPGA_DATA <= xCC_INFO_3;
					STATE <= INFO4;
				when INFO4 =>	
					FPGA_DATA <= xCC_INFO_4;
					STATE <= INFO5;
				when INFO5 =>	
					FPGA_DATA <= xCC_INFO_5;
					RAM_READ_EN <= RAM_READ_EN_TEMP;
					STATE <= ADC;				
				when ADC =>	

					if  RADDR > 7820 then       --256
					--if RADDR = 265 then       --256
						RADDR <= (others=>'0');
						RAM_READ_EN <= (others=>'0');
						RAM_CNT_TEMP <= RAM_CNT + 1;
						STATE <= DC_END;	
					else
						FPGA_DATA <= xADC(mask_count);
						RADDR <= RADDR + 1;
					end if;		
				
				when DC_END => 
					RAM_CNT <= (others=> '0');
					FPGA_DATA <= (others=>'0');
					--mask_count := mask_count + 1;
					--STATE <= INIT;
					STATE <= HDR_END;
				
				when HDR_END =>	
					FPGA_DATA <= x"4321";	
					STATE <= GND_STATE;
				
				when GND_STATE =>	
					MESS_DONE <= '1';
					FPGA_DATA <= (others=>'0');
				
				when others =>	STATE<=HDR_START;																
			end case;

		elsif falling_edge(xSLWR) and read_out_cc_buffer_flag = '1' then
			case CC_STATE is
				when CC_HDR_START =>	
					FPGA_DATA <= x"1234";
					CC_STATE <= CC_INIT;	
				when CC_INIT => 
					FPGA_DATA <= x"DEAD";
					CC_STATE <= INFO1;
				
				when INFO1 =>
					FPGA_DATA <= xALIGN_INFO(7 downto 0) & xALIGN_STATUS;
					CC_STATE <= INFO2;
				
				when INFO2 =>
					FPGA_DATA <= xCC_INFO_0;
					CC_STATE <= INFO3;
				
				when INFO3 =>  
					FPGA_DATA <= 	xCC_INFO_1(0) & xTRIG_INFO(2 downto 0) &
										xDIGITIZING_FLAG(3 downto 0) &
										xDC_PKT(3 downto 0) & xRAM_FULL(3 downto 0);
					CC_STATE <= INFO4;
				
				when INFO4 => 
					FPGA_DATA <= xCC_INFO_2;
					CC_STATE <= INFO5;
		
				when INFO5 =>
					FPGA_DATA <= xCC_INFO_3;
					CC_STATE <= INFO6;
				
				when INFO6 =>  
					FPGA_DATA <= xCC_INFO_4;
					CC_STATE <= INFO7;
				
				when INFO7 => 
					FPGA_DATA <= xCC_INFO_5;
					CC_STATE <= INFO8;
			
				when INFO8 => 
					FPGA_DATA <= xCC_INFO_6;
					CC_STATE <= INFO9;
					
				when INFO9 => 
					FPGA_DATA <= xCC_INFO_7;
					CC_STATE <= CC_CLOSE;	
					
				when CC_CLOSE =>
					FPGA_DATA <= x"BEEF";
					CC_STATE <= CC_HDR_END;
					
				when CC_HDR_END =>
					FPGA_DATA <= x"4321";
					CC_STATE <= CC_GND_STATE;
				when CC_GND_STATE =>
					FPGA_DATA <= (others=> '0');
				when others =>
					CC_STATE <= CC_HDR_START;
				end case;
		end if;
	end process;		
--------------------------------------------------------------------------------		
end Behavioral;
