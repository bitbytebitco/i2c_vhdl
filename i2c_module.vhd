----------------------------------------------------------------------
-- File name   : i2c_module.vhd
--
-- Project     : I2C Master module
--
-- Description : I2C Master module 
--
-- Author(s)   : Zachary Becker
--               bitbytebitco@gmail.com
--
-- Note	       : 
----------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity i2c_module is
    port(
        i_RESET : in std_logic;				-- Active low reset
        i_CLK : in std_logic;				-- ASSUMING: 100 MHz 
        --i_start_flag : in std_logic;
        io_SCL : inout std_logic;			
        io_SDA : inout std_logic		
    );
end entity;

architecture i2c_module_arch of i2c_module is
	-- Initializations
	type state_type is (IDLE, START, START2, START3,
	                    ADDR, ADDR2, ADDR3, ADDR4, ADDR5, ADDR6, ADDR7,
	                    RW, ACK1, 
	                    DATA1, DATA2, DATA3, DATA4, DATA5, DATA6, DATA7, DATA8,
	                    ACKN, STOP, STOP2, STOP3);
	                    
	signal current_state, next_state : state_type;
	
	signal i_start_flag : std_logic := '1';    -- temporary
	
	signal halfcount_int : integer range 0 to 100000;
	signal delay_count : integer range 0 to 20;
	signal cnt : integer range 0 to 20;
	signal cycle_cnt : integer range 0 to 3;

	signal s_BYTECNT_int : integer range 0 to 10000 := 2; 
	signal s_SENTCNT_int : integer range 0 to 10000;
	
	signal s_SDA_int : std_logic; 
	signal s_SDA_EN : std_logic;
	signal s_SCL_EN : std_logic;
	signal s_SCL_int : std_logic := '1';
	
	signal s_START_int : std_logic;
	signal s_HALFSCL_int : std_logic;
	signal s_OFFSETSCL_int : std_logic;
	
	-- TODO: RW_int values should come from port input
	signal RW_int : std_logic := '0'; -- READ : 1 , WRITE : 0

	signal test_addr : std_logic_vector(7 downto 0) := "11010000"; -- hard coded address of 0x68 w/ 0 for WR
	signal addr_buf : unsigned(7 downto 0);
	signal test_data : std_logic_vector(7 downto 0) := "11101011"; -- 
	signal data_buf : unsigned(7 downto 0);

    begin
    

	-----------------------------------------------------
	-- Process that creates an offset divided clock
    -----------------------------------------------------
	OFFSET_CLK : process(i_CLK, i_RESET) -- generates offset 100 kHz 
	  begin 
	    if(i_RESET = '0') then
            halfcount_int <= 0;
            s_HALFSCL_int <= '0';
            s_OFFSETSCL_int <= not s_HALFSCL_int;
	    elsif(rising_edge(i_CLK)) then
            if(halfcount_int = 10000 - 1) then
                halfcount_int <= 0;
                s_OFFSETSCL_int <= s_HALFSCL_int;
                s_HALFSCL_int <= not s_HALFSCL_int;
            else 
                halfcount_int <= halfcount_int + 1;
            end if;
	    end if;
	end process;
	
	------------------------------------------------------
	process(s_HALFSCL_int, i_RESET)
	    begin
	        if(i_RESET = '0') then
	           cycle_cnt <= 0;
            elsif(rising_edge(s_HALFSCL_int)) then
                if(cycle_cnt = 1) then
                    cycle_cnt <= 0;
                else 
                    cycle_cnt <= cycle_cnt + 1;
                end if;
            end if;     
	end process;
	
    -----------------------------------------------------
    STATE_MEM : process(s_HALFSCL_int, i_RESET, cycle_cnt) 
        begin
            if(i_RESET = '0') then 
                current_state <= IDLE;
                delay_count <= 0;
            elsif(rising_edge(s_HALFSCL_int) and (cycle_cnt = 0)) then
                if((current_state = IDLE) and (delay_count < 5)) then
                    delay_count <= delay_count + 1;
                else 
                    current_state <= next_state;
                    delay_count <= 0;
                end if;
            end if;
    end process;

    -----------------------------------------------------    
    NEXT_STATE_LOGIC: process(s_HALFSCL_int, i_RESET, cycle_cnt, current_state)
        begin
            if(i_RESET = '0') then
                --
            elsif(rising_edge(s_HALFSCL_int) and (cycle_cnt = 1)) then
                case(current_state) is 
                    when IDLE => 
                        if ((i_start_flag = '1')) then 
                            next_state <= START;
                        end if;
                    when START => next_state <= START2;
                    when START2 => next_state <= START3;
                    when START3 => next_state <= ADDR;
                    when ADDR => next_state <= ADDR2;
                    when ADDR2 => next_state <= ADDR3;
                    when ADDR3 => next_state <= ADDR4;
                    when ADDR4 => next_state <= ADDR5;
                    when ADDR5 => next_state <= ADDR6;
                    when ADDR6 => next_state <= ADDR7;
                    when ADDR7 => next_state <= RW;
                    when RW => next_state <= ACK1;
                    when ACK1 => next_state <= DATA1;
                    when DATA1 => next_state <= DATA2;
                    when DATA2 => next_state <= DATA3;
                    when DATA3 => next_state <= DATA4;
                    when DATA4 => next_state <= DATA5;
                    when DATA5 => next_state <= DATA6;
                    when DATA6 => next_state <= DATA7;
                    when DATA7 => next_state <= DATA8;
                    when DATA8 => next_state <= ACKN;
                    When ACKN => next_state <= STOP;
                    when STOP => next_state <= STOP2;
                    when STOP2 => next_state <= STOP3;
                    when others => 
                        next_state <= IDLE;
                end case;
            end if;
    end process;
        
    ----------------------------------------------------- 
    OUTPUT_LOGIC_SDA : process(s_HALFSCL_int, cycle_cnt, current_state, next_state)
        begin
            if(rising_edge(s_HALFSCL_int)) then -- SCL output
                case(current_state) is 
                    when IDLE => 
                        if(cycle_cnt = 0) then -- SCL output
                            s_SCL_EN <= '1';    -- enable SCL output
                            s_SDA_EN <= '1';    -- enable SDA output 
                            s_SDA_int <= '1';   -- set SDA
                            s_SCL_int <= '1';
                        end if;
                    when START =>
                        if(cycle_cnt = 0) then -- SCL output
                            s_SDA_int <= '0';   -- RESET SDA
                        end if;
                    when START2 => 
                        if(cycle_cnt = 0) then -- SCL output
                            s_SCL_int <= '0';
                        end if;
                    when START3 => 
                        if(cycle_cnt = 0) then -- SCL output
                            s_SCL_int <= not s_SCL_int;   
                        end if;
                        if(cycle_cnt = 1) then -- SDA output
                            s_SCL_int <= '0';
                            s_SDA_int <= test_addr(7);  
                            addr_buf <= shift_left(unsigned(test_addr), 1); 
                        end if;
                    when ADDR | ADDR2 | ADDR3 | ADDR4 | ADDR5 | ADDR6 | ADDR7 | RW => 
                        if(cycle_cnt = 0) then -- SCL output
                            s_SCL_int <= not s_SCL_int;   
                        end if;
                        if(cycle_cnt = 1) then -- SDA output
                            s_SCL_int <= not s_SCL_int;
                            s_SDA_int <= addr_buf(7);
                            addr_buf <= shift_left(addr_buf, 1);
                            if(current_state = RW) then
                                s_SDA_EN <= '0';
                            end if;
                        end if;
                    when ACK1 => 
                        if(cycle_cnt = 0) then -- SCL output
                            s_SCL_int <= not s_SCL_int;
                            s_SDA_EN <= '1';
                        end if;
                        if(cycle_cnt = 1) then -- SDA output
                            s_SCL_int <= not s_SCL_int;
                            s_SDA_EN <= '1';
                            
                            s_SCL_int <= not s_SCL_int;
                            s_SDA_int <= test_data(7);
                            data_buf <= shift_left(unsigned(test_data), 1);
                            
                        end if;
--                    when DATA1 => 
--                        if(cycle_cnt = 0) then -- SCL output
--                            s_SCL_int <= not s_SCL_int; 
--                            s_SDA_EN <= '1';
--                        end if;
--                        if(cycle_cnt = 1) then -- SDA output
--                            s_SCL_int <= not s_SCL_int;
--                            s_SDA_int <= test_data(7);
--                            data_buf <= shift_left(unsigned(test_data), 1);
--                        end if;
                    when DATA1 | DATA2 | DATA3 | DATA4 | DATA5 | DATA6 | DATA7 | DATA8 =>
                        if(cycle_cnt = 0) then -- SCL output
                            s_SCL_int <= not s_SCL_int; 
                            s_SDA_EN <= '1';
                            if(current_state = DATA8) then
                                s_SDA_EN <= '0';
                            end if;
                        end if;
                        if(cycle_cnt = 1) then -- SDA output
                            s_SCL_int <= not s_SCL_int;
                            s_SDA_int <= data_buf(7);
                            data_buf <= shift_left(data_buf, 1);
                        end if;
                    when ACKN =>
                        if(cycle_cnt = 0) then -- SCL output
                            s_SCL_int <= not s_SCL_int;
                            s_SDA_EN <= '1';
                        end if;
                        if(cycle_cnt = 1) then -- SDA output
                            s_SCL_int <= not s_SCL_int;
                        end if;
                    when STOP => 
                        if(cycle_cnt = 0) then -- SCL output
                            s_SCL_int <= not s_SCL_int;
                            s_SDA_EN <= '1';
                            s_SDA_int <= '0';     -- RESET SDA
                        end if;
                        if(cycle_cnt = 1) then -- SDA output
                            s_SCL_int <= not s_SCL_int;
                        end if;
                    when STOP2 => 
                        if(cycle_cnt = 0) then -- SCL output
                            s_SCL_int <= '1'; -- RESET SCL
                            s_SDA_int <= '1';
                        end if;
                    when STOP3 => 
                        if(cycle_cnt = 0) then -- SCL output
                            s_SDA_int <= '1';
                        end if;
                    when others =>
                        if(cycle_cnt = 0) then -- SCL output
                            s_SDA_EN <= '1';    -- enable SDA output 
                        end if;
                end case;
            end if;
            
    end process;
    
    -- Tri-State buffer control
    io_SCL   <= s_SCL_int when s_SCL_EN = '1' else 'Z';
    io_SDA   <= s_SDA_int when s_SDA_EN = '1' else 'Z';
    
end architecture;
