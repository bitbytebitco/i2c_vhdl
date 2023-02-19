----------------------------------------------------------------------
-- File name   : i2c_module_TB.vhd
--
-- Project     : I2C module 
--
-- Description : VHDL testbench
--
-- Author(s)   : Zachary Becker
--               bitbytebitco@gmail.com
--
-- Note	       : 
----------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;

entity i2c_module_TB is
end entity;

architecture i2c_module_TB_arch of i2c_module_TB is
	-- Initializations
	constant t_clk_per : time := 10 ns;  -- Period of a 100 MHz Clock

	-- Component Declaration
	component i2c_module 
	    port(
		i_RESET : in std_logic;
		i_CLK : in std_logic;
--		i_start_flag : in std_logic;
		io_SCL : inout std_logic;
		io_SDA : inout std_logic
	    );
	end component;

	-- Signal declarations
	signal s_CLK_TB : std_logic;
	signal s_sda_TB : std_logic;
	signal s_scl_TB : std_logic;
	signal s_reset_TB : std_logic;
--	signal io_SDA_TB : std_logic;

    begin
	DUT : i2c_module 
	    port map(
		i_RESET => s_reset_TB,
--		i_start_flag => s_sda_TB,
		io_SCL => s_scl_TB,
		i_CLK => s_CLK_TB
--		io_SDA => io_SDA_TB
	);

	------------------------------------------------------------------
	HEADER : process 
	    begin
		report "I2C testbench initializing..." severity NOTE;
		wait;
	end process;
	------------------------------------------------------------------
	CLOCK_STIM : process
	    begin
		s_CLK_TB <= '1'; wait for 0.5*t_clk_per;
		s_CLK_TB <= '0'; wait for 0.5*t_clk_per;
	end process; 
	------------------------------------------------------------------
--	START_STIM : process
--	    begin
--		io_SDA_TB <= 'Z'; wait for 1000*t_clk_per; 
--		s_sda_TB <= '0'; wait for 1000*t_clk_per; 
--		s_sda_TB <= '1'; wait for 2000*t_clk_per;
--		s_sda_TB <= '0'; wait for 17000*t_clk_per; 
--		io_SDA_TB <= '1'; wait for 2000*t_clk_per; -- ACK1
--		io_SDA_TB <= 'Z'; wait;
		--s_scl_TB <= '1'; wait;
--		s_sda_TB <= '1';
--		wait;
--	end process; 
	------------------------------------------------------------------
        RESET_STIM : process
        begin
            s_reset_TB <= '1'; wait for 2*t_clk_per; 
	       s_reset_TB <= '0'; wait for 2*t_clk_per; 
            s_reset_TB <= '1'; wait; 
        end process;
	----------------------------------------------- 

end architecture;

