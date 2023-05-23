library IEEE;
use IEEE.std_logic_1164.all;

entity top is
    port(
        i_CLK : in std_logic;
        i_RESET : in std_logic;
        io_SCL : inout std_logic;
        io_SDA : inout std_logic
    );
end entity;

architecture archi of top is

        component i2c_module_write
            port(
                i_RESET : in std_logic;				-- Active low reset
                i_CLK : in std_logic;				-- ASSUMING: 100 MHz 
                --i_start_flag : in std_logic;
        --        i_data : in DataArray(0 to 2);
        --        i_addr : in std_logic_vector(6 downto 0);
                o_SCL : out std_logic;
                i_SDA : in std_logic;
                o_SDA : out std_logic	
            );
        end component;
    
    begin
    
        I2C : i2c_module_write port map (
            i_RESET => i_RESET,
            i_CLK => i_CLK,
            o_SCL => io_SCL,
            i_SDA => io_SDA,
            o_SDA => io_SDA
        );


end architecture;
