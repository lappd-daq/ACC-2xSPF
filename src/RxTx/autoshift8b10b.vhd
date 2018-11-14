LIBRARY ieee;
USE ieee.std_logic_1164.all; 

LIBRARY work;

entity autoshift8b10b is

	port
	(
		clk		:	 IN STD_LOGIC;
		rst		:	 IN STD_LOGIC;
		din_ena		:	 IN STD_LOGIC;		-- 10b data ready
		din_dat		:	 IN STD_LOGIC_VECTOR(9 DOWNTO 0);		-- 10b data input
		dout_val		:	 OUT STD_LOGIC;		-- data out valid
		dout_dat		:	 OUT STD_LOGIC_VECTOR(7 DOWNTO 0);		-- data out
		dout_k		:	 OUT STD_LOGIC;		-- special code
		dout_kerr		:	 OUT STD_LOGIC;		-- coding mistake detected
		dout_rderr		:	 OUT STD_LOGIC;		-- running disparity mistake detected
	);
end <entity_name>;


architecture rlt of autoshift8b10b is

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
	
	signal last_din_dat 	: std_logic_vector(9 downto 0);
	type indata_array_type is array (9 downto 0) of std_logic_vector(9 downto 0);
	signal indats	: indata_array_type
	signal rdregs	: std_logic_vector(9 downto 0);
	signal vals 	: std_logic_vector(9 downto 0);
	type outdata_array_type is array (9 downto 0) of std_logic_vector(7 downto 0);
	signal outdats	: outdata_array_type;
	signal ks		: std_logic_vector(9 downto 0);
	signal kerrs 	: std_logic_vector(9 downto 0);
	signal rderrs 	: std_logic_vector(9 downto 0);
	type history_type is array(4 downto 0) of std_logic_vector(9 downto 0);
	signal history 	: history_type;


begin
	-- dff
	process (clk, rst) is
	begin
		if rst = '1' then
			last_din_dat <= (others => '0');
		elsif rising_edge(clk) then
			last_din_dat <= din_dat;
		end if;
	end process
	
	-- Barrel shifter
	indats(0) <= din_dat(9 downto 0);
	barrel0	:	 for i in 9 downto 1 generate
		indats(i) <= last_din_dat(i-1 downto 0) & din_dat(9 downto i);
	end generate;
	
	decoders	:	for i in 9 downto 0 generate
		rx_dec : decoder_8b10b
		GENERIC MAP(
			RDERR =>1,
			KERR => 1,
			METHOD => 1)
		PORT MAP(
			clk => clk,
			rst => rst,
			din_ena => din_ena,		-- 10b data ready
			din_dat => indats(i),		-- 10b data input
			din_rd => rdregs(i),		-- running disparity input
			dout_val => vals(i),		-- data out valid
			dout_dat => oudats(i),		-- data out
			dout_k => ks(i),		-- special code
			dout_kerr => kerrs(i),		-- coding mistake detected
			dout_rderr => rderrs(i),		-- running disparity mistake detected
			dout_rdcomb => open,		-- running disparity output (comb)
			dout_rdreg => rdregs(i));		-- running disparity output (reg)
	end generate;
	
	-- save the error history (not error)
	process (clk, rst) is
		variable newhist : hist_type;
	begin
		if rst = '1' then
			newhist := (others => '0');
		elsif rising_edge(clk) then
			newhist(4 downto 1) := history(3 downto 0);
			newhist(0) := not kerrs(9 downto 0);
			history <= newhist;
		end if;
	end process;
	
	-- select a decoder output based on which output is valid

	
	
end rtl;
