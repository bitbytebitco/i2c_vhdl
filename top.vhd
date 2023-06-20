library IEEE;
use IEEE.std_logic_1164.all;

use work.misc_pkg.all;

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity top is
    port(
        i_CLK : in std_logic;
        i_RESET : in std_logic;
        io_SCL : inout std_logic;
        io_SDA : inout std_logic
    );
end entity;

architecture archi of top is

        -- Signal Declarations
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
        signal w_start : std_logic := '1';
        signal r1_byte_cnt : std_logic_vector(4 downto 0);
        signal r_byte_cnt : std_logic_vector(4 downto 0);
        signal w_clk : std_logic := '0';
        signal delay : std_logic := '0';
        signal first : integer := 0;

        -- I2C component declaration
        component i2c_module_write
            port(
                i_RESET : in std_logic;				-- Active low reset
                i_CLK : in std_logic;				-- ASSUMING: 100 MHz 
                i_start_flag : in std_logic;
                i_data : in std_logic_vector(7 downto 0);
                i_byte_cnt : in std_logic_vector(4 downto 0);
        --        i_addr : in std_logic_vector(6 downto 0);
                o_buffer_clear : out std_logic;
                o_SCL : out std_logic;
                i_SDA : in std_logic;
                o_SDA : out std_logic	
            );
        end component;
    
    begin
        --    i_data(0) <= x"21";
        --    i_data(1) <= x"81"; 
        --    i_data(2) <= x"E8"; -- brightness
        --    i_data(3) <= x"0A"; -- set position
        --    i_data(4) <= x"77";
       
    
        r_data(0) <= x"21";
        r_data(1) <= x"81";
        r_data(2) <= x"E8";
        r_data(3) <= x"00";
        r_data(4) <= x"77";
        r_data(5) <= x"00";
        r_data(6) <= x"00";
        r_data(7) <= x"00";
        r_data(8) <= x"00";
        r_data(9) <= x"00";
        r_data(10) <= x"00";
        r_data(11) <= x"00";
        r_data(12) <= x"00";
        r_data(13) <= x"00";
        r_data(14) <= x"00";
        r_data(15) <= x"00";
        r_data(16) <= x"00";
        r_data(17) <= x"00";
        r_data(18) <= x"00";
        r_data(19) <= x"00";
        
        r1_data(0) <= x"00";
        r1_data(1) <= x"77";
        r1_data(2) <= x"00";
        r1_data(3) <= x"00";
        r1_data(4) <= x"00";
        r1_data(5) <= x"00";
        r1_data(6) <= x"00";
        r1_data(7) <= x"00";
        r1_data(8) <= x"00";
        r1_data(9) <= x"00";
        r1_data(10) <= x"00";
        r1_data(11) <= x"00";
        r1_data(12) <= x"00";
        r1_data(13) <= x"00";
        r1_data(14) <= x"00";
        r1_data(15) <= x"00";
        r1_data(16) <= x"00";
        
    
        -- I2C port mapping
        I2C : i2c_module_write port map (
            i_RESET => i_RESET,
            i_CLK => i_CLK,
            i_start_flag => w_start,
            i_data => r_current_data,
            i_byte_cnt => r_byte_cnt,
            o_buffer_clear => w_buffer_clear,
            o_SCL => io_SCL,
            i_SDA => io_SDA,
            o_SDA => io_SDA
        );
        
        COUNTER : process(i_CLK, delay, w_clk)
          begin
                if(rising_edge(i_CLK)) then
                    cnt2 <= cnt2 + 1;
                    if(cnt2 = 9999) then
                        cnt2 <= 0;
                        
                        w_clk <= not w_clk;
                    end if;
                end if;
                if(delay = '1') then
                    if(rising_edge(w_clk)) then
                        cnt3 <= cnt3 + 1;
                        
                        if(cnt3 = 20) then
                            cnt3 <= 0;
                        end if;
                    end if;
                end if;
        end process;
        
        ITER : process(i_RESET, w_buffer_clear)
            begin
                if(i_RESET = '0') then
                    r_byte_cnt <= std_logic_vector(to_unsigned(0, r_byte_cnt'length)); -- no data
                else
                    if(rising_edge(w_buffer_clear)) then
                        if(first = 0) then
                            r_byte_cnt <= std_logic_vector(to_unsigned(1, r_byte_cnt'length)); -- 0x21
                            r_current_data <= r_data(0);
                            first <= 1;
                        elsif(first = 1) then
                            if(r_i3 = 0) then
                                r_byte_cnt <= std_logic_vector(to_unsigned(17, r_byte_cnt'length)); -- 0x00 (17 times)
                                r_current_data <= x"00";
                                r_i3 <= 1;
                            else 
                                r_current_data <= x"00";
                                r_i3 <= r_i3 + 1;
                                if(r_i3 > 16) then
                                    r_i3 <= 0;
                                    r_current_data <= r_data(1); -- 0x81
                                    first <= 2;
                                end if;
                            end if;
                        elsif(first = 2) then
                            r_byte_cnt <= std_logic_vector(to_unsigned(1, r_byte_cnt'length)); 
                            r_current_data <= r_data(2); -- 0xE8
                            first <= 3;
                        elsif(first = 3) then
                            if(r_i3 = 0) then
                                r_byte_cnt <= std_logic_vector(to_unsigned(r1_data'length, r_byte_cnt'length));
                                --r_current_data <= r1_data(0);
                                r_current_data <= x"00";
                                r_i3 <= r_i3 + 1;    
                            elsif(r_i3 = 3) then 
                                r_current_data <= x"77";    
                                r_i3 <= r_i3 + 1;                          
                            else
                                --r_byte_cnt <= std_logic_vector(to_unsigned(17, r_byte_cnt'length));
                                --r_current_data <= r1_data(r_i3 - 1);
                                r_current_data <= x"00";
                                r_i3 <= r_i3 + 1;
                                if(r_i3 > r1_data'length - 2) then
                                    r_i3 <= 0;
                                    w_start <= '0';
                                end if;
                            end if;
                        end if;
                    end if;
                
--                    if(first = 0) then
--                        if(rising_edge(w_buffer_clear)) then
--                            --r_i <= r_i + 1;
--                            delay <= '1';
--                            first <= 1;
--                        end if;
--                    else
--                        if(cnt3 >= 20) then
                        
--                            if(first < 2) then
--                                delay <= '0';
--                                r_byte_cnt <= std_logic_vector(to_unsigned(1, r_byte_cnt'length));
--                                r_current_data <= r_data(1);
--                                r_i3 <= 1;
--                                first <= 2;
                                
--                            elsif(first = 2) then
--                                if(rising_edge(w_buffer_clear)) then
--                                    r_byte_cnt <= std_logic_vector(to_unsigned(1, r_byte_cnt'length));
--                                    r_current_data <= r_data(2);
--                                    first <= 3;
--                                end if;
--                            elsif(first = 3) then
--                                if(rising_edge(w_buffer_clear)) then
--                                    r_byte_cnt <= std_logic_vector(to_unsigned(1, r_byte_cnt'length));
--                                    r_current_data <= r_data(3);
--                                    w_start <= '0';
--                                end if;
--                            end if;
                        
----                        if(rising_edge(w_buffer_clear)) then
----                            report "test";
----                            r_current_data <= r_data(r_i3);
----                            r_i3 <= r_i3 + 1;
                            
----                            if(r_i3 = 19) then
----                                r_i3 <= 0;
----                                r_i2 <= 0;
----                            end if;
----                        end if;
                            
--                        end if;
--                    end if;
                        
                        
                        
                        
                        
                end if;

        end process;
        
end architecture;
