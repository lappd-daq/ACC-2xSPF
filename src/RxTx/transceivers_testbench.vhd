library IEEE; 
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.defs.all;

entity testbench is
end entity testbench;

architecture BENCH of testbench is
  signal reset_global               : STD_LOGIC;
  signal xalign_strobe, xalign_good : STD_LOGIC;
  signal clock_sys, clocks_rx       : STD_LOGIC;
  signal rx_serdes                  : STD_LOGIC_VECTOR(1 downto 0);
  signal tx_serdes                  : STD_LOGIC;
  signal xInstruction               : STD_LOGIC_VECTOR(31 downto 0);
  signal xInstruct_Rdy              : STD_LOGIC;
  signal xtrig                      : STD_LOGIC;
  signal trigger_to_fe              : STD_LOGIC;
  signal packet_from_fe_rec         : STD_LOGIC;
  signal xdone, xfe_mask            : STD_LOGIC;
  signal clock_FPGA_PLLlock         : STD_LOGIC;
  signal lvds_aligned_tx            : STD_LOGIC;
  signal xready                     : STD_LOGIC;
  signal Stop                       : BOOLEAN;
  
begin
  Stop <= FALSE;
  rx_serdes <= (others => '0');
  xInstruction <= (others => '0');
  xInstruct_Rdy <= '0';
  xtrig <= '0';
  xdone <= '1';
  xfe_mask <= '0';
  clock_FPGA_PLLlock <= '1';
  lvds_aligned_tx <= '1';
  xready <= '1';
  
  reset_gen: process
  begin
    reset_global <= '0';
    wait for 1 NS;
    reset_global <= '1';
    wait for 2 NS;
    reset_global <= '0';
    wait;
  end process;
  
  alginstrobe_gen: process
  begin
    xalign_strobe <= '0';
    wait for 10 NS;
    xalign_strobe <= '1';
    wait for 10 NS;
    xalign_strobe <= '0';
    wait;
  end process;
  
  clocksys_gen: process -- 40mhz
  begin
    while not Stop loop
      clock_sys <= '0';
      wait for 12.5 NS;
      clock_sys <= '1';
      wait for 12.5 NS;
    end loop;
    wait;
  end process;
  clocksrx_gen: process -- 25mhz
  begin
    while not Stop loop
      clocks_rx <= '0';
      wait for 20 NS;
      clocks_rx <= '1';
      wait for 20 NS;
    end loop;
    wait;
  end process;
  
  
  
  
xTRANSCEIVERS : entity work.transceivers(rtl)

port map(
  xCLR_ALL          => reset_global,
  xALIGN_ACTIVE     => xalign_strobe,
  xALIGN_SUCCESS    => xalign_good,

  xCLK              => clock_sys,
  xRX_CLK           => clocks_rx,

  xRX_LVDS_DATA     => rx_serdes,
  xTX_LVDS_DATA     => tx_serdes,

  xCC_INSTRUCTION   => xInstruction,
  xCC_INSTRUCT_RDY  => xInstruct_Rdy,
  xTRIGGER          => xtrig,
  xCC_SEND_TRIGGER  => trigger_to_fe,

  xRAM_RD_EN        => '0',
  xRAM_ADDRESS      => (others => '0'),
  xRAM_CLK          => '0',
  xRAM_FULL_FLAG    => open,
  xRAM_DATA         => open,
  xRAM_SELECT_WR    => (others => '0'),
  xRAM_SELECT_RD    => (others => '0'),

  xALIGN_INFO       => open,
  xCATCH_PKT        => packet_from_fe_rec,

  xDONE             => xdone,
  xDC_MASK          => xfe_mask,
  xPLL_LOCKED       => clock_FPGA_PLLlock,
  xFE_ALIGN_SUCCESS => lvds_aligned_tx,
  xSOFT_RESET       => xready);

end architecture BENCH;