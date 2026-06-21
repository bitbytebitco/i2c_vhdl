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

use work.misc_pkg.all;

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


entity i2c_module_write_TB is
end entity;

architecture i2c_module_write_TB_arch of i2c_module_write_TB is
	-- Initializations
	constant t_clk_per : time := 10 ns;  -- Period of a 100 MHz Clock

    -- Signal declarations
	signal s_CLK_TB : std_logic;
	signal s_sda_TB : std_logic;
	signal w_scl_TB : std_logic;
	signal test_addr : std_logic_vector(6 downto 0) := "1101000"; -- hard coded address of 0x68 w/ 0 for WR
    signal test_data : DataArray(0 to 3);

    -- Signal Declarations
    signal i_reset_n : std_logic;
    signal io_SCL : std_logic;
    signal r_addr : std_logic_vector(6 downto 0) := "1110000"; -- hard coded address 
    signal r1_data : DataArray(0 to 16);
    signal r_data : DataArray(0 to 19);
    signal r_i : integer := 0;
    signal r_i2 : integer := 0;
    signal r_i3 : integer := 0;
    signal cnt2 : integer := 0;
    signal cnt3 : integer := 0;
    signal r_current_data : std_logic_vector(7 downto 0);
    signal w_buffer_clear : std_logic := '0';
    signal w_start : std_logic := '0';
    signal w_mode : std_logic := '0'; -- '0': READ, '1': WRITE
    signal r1_byte_cnt : std_logic_vector(4 downto 0);
    signal r_byte_cnt : std_logic_vector(7 downto 0);
    signal w_clk : std_logic := '0';
    signal delay : std_logic := '0';
    signal first : integer := 0;
    signal w_busy : std_logic := '0'; 
    signal w_done : std_logic := '0';
    signal w_done_clear : std_logic := '0';
    signal w_rindex : integer := 0;
    
	signal w_sda_TB : std_logic;

    signal dut_SDA  : std_logic := 'H';  -- DUT drives this
    signal tb_SDA   : std_logic := 'H';  -- testbench slave drives this
    signal io_SDA   : std_logic;         -- resolved bus 

    signal o_state_slv  : std_logic_vector(5 downto 0);          

    begin
    
    test_data(0) <= "11010111";
    test_data(1) <= "11110000";
    test_data(2) <= "10100100";
    test_data(3) <= "00001110";
    
	DUT : entity work.i2c_module_write port map(
	    i_reset_n => i_reset_n,
        i_CLK => s_CLK_TB,
        i_mode => w_mode,
        i_en => w_start,
        i_addr => "1101000", 
        i_tx_byte => r_current_data,
        i_byte_cnt => r_byte_cnt,
        o_buffer_clear => w_buffer_clear,
        i_done_clear => w_done_clear,
        o_busy => w_busy,
        o_done => w_done,
        o_SCL => io_SCL,
        i_SDA => io_SDA,
        o_SDA => dut_SDA,
        o_phase_cnt => open,
        o_clkdivcnt => open,	
        o_state_slv => o_state_slv,
        o_addr_buf => open
	);

    io_SDA <= '0' when (dut_SDA = '0' or tb_SDA = '0') else 'H';
 
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
    --ACK : process
    --begin
    --    tb_SDA <= 'H';
    --    
    --    -- wait until we're in the RW state
    --    wait until (o_state_slv = "001100");  -- RW = 11 = 0b
    --    -- pull low before SCL rises for ACK sample
    --    tb_SDA <= '0';
    --    -- hold through SCL high (master samples here)
    --    wait until rising_edge(io_SCL);
    --    wait until falling_edge(io_SCL);
    --    -- release
    --    tb_SDA <= 'H';

    --    -- ACKN - loop for however many data bytes
    --    loop
    --       wait until (o_state_slv = "010101" or
    --            o_state_slv = "010110");
    --            
    --        if(o_state_slv = "010110") then  -- STOP
    --            exit;
    --        end if;
    --        
    --        -- we're at phase 0 of ACKN, pull low immediately
    --        tb_SDA <= '0';
    --        
    --        -- hold through phase 1 (SCL rises) and phase 2 (sample point)
    --        wait until rising_edge(io_SCL);
    --        wait until falling_edge(io_SCL);
    --        
    --        -- release at phase 2->3, after sampling
    --        tb_SDA <= 'H'; 
    --    end loop; 
    --    
    --end process; 

    ACK : process
    begin
        tb_SDA <= 'H';
        
        loop
            -- wait for any ACK state (ACK1 or ACKN) or STOP
            wait until (o_state_slv = "001100" or   -- ACK1 (address ACK, happens twice)
                        o_state_slv = "010101" or    -- ACKN (data ACK)
                        o_state_slv = "010110");      -- STOP
            
            if(o_state_slv = "010110") then  -- STOP, done
                exit;
            end if;
            
            -- pull low for the ACK
            tb_SDA <= '0';
            wait until rising_edge(io_SCL);
            wait until falling_edge(io_SCL);
            tb_SDA <= 'H';
        end loop;
        
    end process;
	------------------------------------------------------------------
	START_STIM : process
	    begin
	    
        w_done_clear <= '1';
	    w_sda_TB <= 'Z';
        wait for 2*t_clk_per;

        w_start <= '1';
        r_current_data <= x"06";	
        r_byte_cnt <= std_logic_vector(to_unsigned(2, r_byte_cnt'length));
        wait until rising_edge(w_done);
        w_start <= '0';
        --w_done_clear <= '1';
        
        --r_current_data <= x"44";	
        --r_byte_cnt <= std_logic_vector(to_unsigned(1, r_byte_cnt'length));
        --w_done_clear <= '1';

	    --w_sda_TB <= '1';
	    --wait for 15000*t_clk_per;
	    w_sda_TB <= 'Z';
	    wait; 
	    
	end process; 
	------------------------------------------------------------------
        RESET_STIM : process
        begin
            i_reset_n <= '1'; wait for 1*t_clk_per; 
	        i_reset_n <= '0'; wait for 1*t_clk_per; 
            i_reset_n <= '1'; wait; 
        end process;
	----------------------------------------------- 

end architecture;

