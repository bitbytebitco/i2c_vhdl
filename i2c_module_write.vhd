----------------------------------------------------------------------
-- File name   : i2c_module_write.vhd
--
-- Project     : I2C Master (Write)
--
-- Description : I2C Master (Write) 
--
-- Author(s)   : Zachary Becker
--               bitbytebitco@gmail.com
--
-- Note	       : 
----------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
package misc_pkg is
    type DataArray is array (natural range <>) of std_logic_vector(7 downto 0);
end package;
use work.misc_pkg.all;

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

--        i_addr : in std_logic_vector(6 downto 0);

entity i2c_module_write is
    generic(
        g_CLK_RATE : integer := 50_000_000
        --g_CLK_RATE : integer := 1_000
    );
    port(
        i_reset_n : in std_logic;				-- Active low reset
        i_CLK : in std_logic;				
        i_en : in std_logic;
        i_addr : in std_logic_vector(6 downto 0);
        i_tx_byte : in std_logic_vector(7 downto 0);
        i_byte_cnt : in std_logic_vector(7 downto 0);
        i_SDA : in std_logic;
        i_done_clear : in std_logic;
        o_buffer_clear : out std_logic := '0'; 
        o_busy : out std_logic := '0';
        o_done : out std_logic := '0';
        o_SCL : out std_logic;
        o_SDA : out std_logic;	
        o_phase_cnt : out std_logic_vector(1 downto 0);
        o_clkdivcnt : out std_logic_vector(7 downto 0);
        o_state_slv : out std_logic_vector(4 downto 0);
        o_addr_buf : out std_logic_vector(6 downto 0)
    );
end entity;


architecture i2c_module_write_arch of i2c_module_write is

    -- Note: clock_divider_int 
    -- clock needs to be at 100 Khz, and we need to know the number of counts per "phase" (1/4 of the period)
    -- g_CLK_RATE (i.e. 50 MHz) divided by what equals 100 kHz 
    -- x = 50 Mhz / 100 kHz / 4 
    constant clock_divider_int : integer := integer(real(g_CLK_RATE) / real(100000))/4;    -- Count needed to produce 100kHz I2C Clock 
    --constant clock_divider_int : integer := integer(real(g_CLK_RATE) / real(100))/4;    -- Count needed to produce 100kHz I2C Clock 

    --constant clock_divider_int : integer := 1250; 
    --constant clock_divider_int : integer := 120_000; 
    --constant clock_divider_int : integer := 125; 

    --constant clock_divider_int : integer := maximum(1, integer(real(g_CLK_RATE) / real(100000)) / 4); 
    
    
	-- Initializations
	type state_type is (IDLE, START, START2, START3,
	                    ADDR, ADDR2, ADDR3, ADDR4, ADDR5, ADDR6, ADDR7,
	                    RW, ACK1, 
	                    DATA1, DATA2, DATA3, DATA4, DATA5, DATA6, DATA7, DATA8,
	                    ACKN, STOP, STOP2, STOP3, WAIT_CLEAR, WAIT_BUF_CLEAR);
	                    
	signal current_state : state_type := IDLE;
	signal next_state : state_type := START;
    signal state_slv : std_logic_vector(4 downto 0);

	signal halfcount_int : integer range 0 to 100000 := 0;
	signal delay_count : integer range 0 to 1000000 := 0;
	signal cnt : integer range 0 to 20 := 0;

	signal s_BYTECNT_int : integer range 0 to 10000 := 2; 
	
	signal s_SCL_int : std_logic := '1';
	signal s_SDA_int : std_logic := '1'; 
	signal s_SDA_EN : std_logic := '1';
	signal s_SCL_EN : std_logic;

    signal s_ACK_ok : std_logic := '0'; -- for sampling ACK
	
	-- TODO: RW_int values should come from port input
	signal RW_int : std_logic := '0'; -- READ : 1 , WRITE : 0
--	signal i_addr : std_logic_vector(6 downto 0) := "1110000"; -- hard coded address 
    signal addr_buf : unsigned(6 downto 0);
	signal data_buf : unsigned(7 downto 0);
	signal current_byte : std_logic_vector(7 downto 0);
	signal byte_cnt : integer range 0 to 100 := 0;
	signal total_bytes : integer range 0 to 100;
	
	
	--- TEMP 
	signal state : std_logic := '1';
	--- END TEMP

    signal phase_tick : std_logic := '1';
    signal phase_cnt : integer range 0 to 3 := 0;
    --signal clk_div_cnt : integer range 0 to 1250 := 0;
    signal clk_div_cnt : integer range 0 to 120_000 := 0;

    begin
    
        total_bytes <= to_integer(unsigned(i_byte_cnt));
          
	
	------------------------------------------------------
    STATE_REG : process(i_CLK, i_reset_n)
    begin
        if(i_reset_n = '0') then
            current_state <= IDLE;
            delay_count <= 0;
        elsif(rising_edge(i_CLK)) then
            if(current_state = IDLE and i_en = '1') then
                delay_count <= delay_count + 1;
            else
                delay_count <= 0;  -- reset when not idle
            end if;
    
            if(phase_cnt = 3 and clk_div_cnt = clock_divider_int - 1) then
                current_state <= next_state;
            end if;
        end if;
    end process;
    -----------------------------------------------------
    PHASE_COUNTER : process(i_CLK, i_reset_n)
    begin
        if(i_reset_n = '0') then
            phase_cnt <= 0;
            clk_div_cnt <= 0;
        elsif(rising_edge(i_CLK)) then
            phase_tick <= '0';  -- default low
            if(clk_div_cnt = clock_divider_int - 1) then
                clk_div_cnt <= 0;
                phase_tick  <= '1';  -- pulse for one cycle at phase boundary
                if(phase_cnt = 3) then
                    phase_cnt <= 0;
                else
                    phase_cnt <= phase_cnt + 1;
                end if;
            else
                clk_div_cnt <= clk_div_cnt + 1;
            end if;
        end if;
    end process;

    -----------------------------------------------------    
    --NEXT_STATE_LOGIC: process(i_en, s_ACK_ok, total_bytes, byte_cnt, i_reset_n, i_done_clear, phase_cnt, current_state, clk_div_cnt, delay_count)
    NEXT_STATE_LOGIC: process(current_state, byte_cnt, total_bytes, s_ACK_ok)
        begin

            -- DEFAULT: stay in current state
            next_state <= current_state;

                case(current_state) is 
                    when IDLE => 
                        --if (i_en = '1') then 
                        --    --next_state <= START;
                        --    if(delay_count >= 20) then  -- adjust for desired delay
                        --        next_state <= START;
                        --    else
                        --        next_state <= IDLE;  -- stay and count
                        --    end if;
                        --else 
                        --    next_state <= IDLE;
                        --end if;
                        next_state <= START;
                        
                    when START => 
                        next_state <= START2;
                    when START2 => next_state <= ADDR;
                    when ADDR => next_state <= ADDR2;
                    when ADDR2 => next_state <= ADDR3;
                    when ADDR3 => next_state <= ADDR4;
                    when ADDR4 => next_state <= ADDR5;
                    when ADDR5 => next_state <= ADDR6;
                    when ADDR6 => next_state <= ADDR7;
                    when ADDR7 => next_state <= RW; 
                    when RW => next_state <= ACK1;
                    when ACK1 =>
                        --if(clk_div_cnt = 0) then
                        --    next_state <= IDLE;
                        --end if;
                        --if((total_bytes>0) and (s_ACK_ok = '1')) then -- real one
                        if((total_bytes>0) and (s_ACK_ok = '1')) then -- testing w/o actual ACK
                            next_state <= DATA1;
                        else 
                            next_state <= STOP;
                        end if;
                    when DATA1 => next_state <= DATA2;
                    when DATA2 => next_state <= DATA3;
                    when DATA3 => next_state <= DATA4;
                    when DATA4 => next_state <= DATA5;
                    when DATA5 => next_state <= DATA6;
                    when DATA6 => next_state <= DATA7;
                    when DATA7 => next_state <= DATA8;
                    when DATA8 => next_state <= ACKN;
                    When ACKN => 
                            --next_state <= STOP;
                        if (byte_cnt < total_bytes) then  -- how multiple bytes are currently handled

                            next_state <= DATA1;
                        else 
                            next_state <= STOP;
                        end if;
                    when WAIT_BUF_CLEAR => 
                        next_state <= DATA1;
                    when STOP => 
                        next_state <= WAIT_CLEAR;
                    when WAIT_CLEAR => 
                        --next_state <= WAIT_CLEAR;
                        --if(clk_div_cnt = 0) then
                        --    next_state <= IDLE;
                        --end if;
                        --if(i_done_clear = '0') then  -- active low
                        --    next_state <= IDLE;
                        --end if;
                    when others => 
                        next_state <= IDLE;
                        --next_state <= STOP;
                end case;
            --end if;
    end process;
        
    ----------------------------------------------------- 
    OUTPUT_LOGIC_SDA : process(i_CLK, i_reset_n, current_state, phase_cnt, byte_cnt)
        begin
                  
            if(i_reset_n = '0') then
                s_SCL_int <= '0';
                s_SDA_int <= '1'; 
                s_SDA_EN <= '1';
                byte_cnt <= 0;
            elsif(rising_edge(i_CLK)) then -- SCL output

                case(current_state) is 
                    when IDLE => 
                        if(phase_cnt = 0) then -- SCL output
                            s_SCL_EN <= '0';    -- SCL to "Z" 
                            s_SDA_EN <= '1';    -- enable SDA output 
                            s_SDA_int <= '1';   -- set SDA
                        end if;
                    when START =>
                        o_busy <= '1';
                        
                        if(phase_cnt = 0) then 
                            s_SDA_EN <= '1';    -- enable SDA output 
                            s_SDA_int <= '1';   -- 
                            s_SCL_int <= '1';
                            
                        end if;
                        if(phase_cnt = 2) then 
                            s_SDA_int <= '1';  
                            s_SCL_int <= '1';
                        end if;
                        if(phase_cnt = 2) then 
                            s_SCL_int <= '1';
                        end if;
                        if(phase_cnt = 2) then 
                            s_SCL_int <= '1';
                        end if;

                    when START2 => 
                        if(phase_cnt = 0) then 
                            s_SCL_int <= '1';
                            s_SDA_int <= '1';
                        end if;
                        if(phase_cnt = 1) then 
                            s_SCL_int <= '1';
                            s_SDA_int <= '0';
                        end if;
                        if(phase_cnt = 2) then 
                            s_SCL_EN <= '1';    -- Drive SCL  
                            s_SCL_int <= '0'; -- pull SCL LOW
                        end if;
                        if(phase_cnt = 3) then 
                            --s_SDA_int <= i_addr(6);  
                            s_SCL_int <= '0';  
                            addr_buf <= unsigned(i_addr); 
                            s_SDA_int <= i_addr(6);
                            s_SDA_EN <= '1';
                        end if;


                    when ADDR | ADDR2 | ADDR3 | ADDR4 | ADDR5 | ADDR6 | ADDR7 | RW => 
                    --when ADDR | ADDR2 | ADDR3 | ADDR4 | ADDR5 | ADDR6 | ADDR7 => 
                        if(phase_cnt = 0) then 
                            s_SCL_int <= '1';
                        end if;
                        if(phase_cnt = 1) then 
                            s_SCL_int <= '1';
                        end if;
                        if(phase_cnt = 2) then 
                            s_SCL_int <= '0';
                        end if;
                        if(phase_cnt = 3) then
                            s_SCL_int <= '0';
                            if(current_state = RW) then
                                s_SDA_EN <= '0';
                            else
                                

                                if(phase_tick = '1') then
                                    s_SDA_int <= addr_buf(5);
                                    addr_buf <= addr_buf(5 downto 0) & '0';
                                    s_SDA_EN <= '1';
                                end if;
                            end if;
                        end if;
                    
                    when DATA1 | DATA2 | DATA3 | DATA4 | DATA5 | DATA6 | DATA7 | DATA8 =>
                        if(phase_cnt = 0) then 
                            s_SCL_int <= '1';


                            if((current_state = DATA1) and (phase_tick = '1')) then
                                byte_cnt <= byte_cnt + 1;

                                
                            end if;
                        end if;
                        if(phase_cnt = 1) then 
                            s_SCL_int <= '1';
                        end if;
                        if(phase_cnt = 2) then 
                            s_SCL_int <= '0';
                        end if;
                        if(phase_cnt = 3) then
                            s_SCL_int <= '0';
                            if(current_state = RW) then
                                s_SDA_EN <= '0';
                            else
                                if(phase_tick = '1') then
                                    --s_SDA_int <= data_buf(6);
                                    --addr_buf <= data_buf(6 downto 0) & '0';
                                    s_SDA_int <= data_buf(7);
                                    data_buf <= shift_left(data_buf, 1);
                                    s_SDA_EN <= '1';
                                end if;
                            end if;
                        end if;

                    when ACK1 | ACKN => 
                        if(phase_cnt = 0) then -- SCL output
                            s_SCL_int <= '1';
                            s_SDA_EN <= '0';
                        end if;
                        if(phase_cnt = 1) then 
                            s_SCL_int <= '1';
                            s_ACK_ok <= not To_X01(i_SDA); -- sample ACK
                        end if;
                        if(phase_cnt = 2) then
                            s_SCL_int <= '0';
                            --s_ACK_ok <= not To_X01(i_SDA); -- sample ACK
                        end if;
                        if(phase_cnt = 3) then -- SDA output
                            s_SCL_int <= '0';
                            s_SDA_EN <= '1';
                        end if;
                        
                        --o_buffer_clear <= '1';     -- set `done`

                        if(byte_cnt = 0) then
                            current_byte <= i_tx_byte;
                        else 
                            current_byte <= x"01";
                        end if;
                        --current_byte <= i_tx_byte;
                        s_SDA_int <= current_byte(7);
                        data_buf <= shift_left(unsigned(current_byte), 1);
                        
                    --when ACKN =>
                    --    
                    --    if(phase_cnt = 0) then -- SCL output
                    --        s_SDA_EN <= '0';
                    --        s_SDA_int <= '0';
                    --    end if;
                    --    if(phase_cnt = 1) then -- SCL output
                    --        s_SDA_int <= '1';
                    --    end if;
                    --    if(phase_cnt = 2) then
                    --        s_ACK_ok <= not To_X01(i_SDA); -- sample ACK
                    --        s_SDA_int <= '0';
                    --        s_SDA_EN <= '1';
                    --    end if;
                    --    if(phase_cnt = 3) then -- SDA output
                    --        
                    --        s_SDA_EN <= '1';
                    --        s_SDA_int <= '0';
                    --        
                    --        if (byte_cnt < total_bytes) then
                    --            --o_buffer_clear <= '0';     -- reset OLD
                    --            current_byte <= i_tx_byte;
                    --            --s_SDA_int <= current_byte(7);
                    --            data_buf <= shift_left(unsigned(current_byte), 1);
                    --        end if;
                    --    end if;

                    -- OLD DATA SECTION
                    --when DATA1 | DATA2 | DATA3 | DATA4 | DATA5 | DATA6 | DATA7 | DATA8 =>
                    --    if(phase_cnt = 0) then
                    --        s_ack_ok <= '0';
                    --    end if;
                    --    if(current_state = DATA1) then
                    --        --o_buffer_clear <= '0';     -- reset OLD
                    --        byte_cnt <= byte_cnt + 1;
                    --    end if;
                    --    
                    --    if(phase_cnt = 0) then -- SCL output
--                  --          s_SDA_EN <= '1';
                    --    end if;
                    --    if(phase_cnt = 3) then -- SDA output
                    --        if(current_state = DATA8) then
--                  --              s_SDA_int <= 'Z';
                    --            --s_SDA_EN <= '0';
                    --            
                    --            if (byte_cnt < total_bytes)  then
                    --                current_byte <= i_tx_byte;
                    --            end if;
                    --            o_buffer_clear <= '1';     -- set `done`
                    --            
                    --        else 
                    --            s_SDA_int <= data_buf(7);
                    --            data_buf <= shift_left(data_buf, 1);
                    --        end if;
                    --    end if;

                    when STOP => 
                        if(phase_cnt = 0) then 
                            --
                            --o_buffer_clear <= '0';     -- reset
                            s_SCL_int <= '1';

                            s_SDA_EN <= '1';
                            --s_SDA_int <= '1';
                        end if;
                        if(phase_cnt = 1) then 
                            s_SCL_int <= '1';
                            --s_SDA_int <= '1';
                        end if;
                        if(phase_cnt = 2) then 
                            s_SCL_int <= '1';
                            s_SDA_int <= '1';
                        end if;
                        if(phase_cnt = 3) then 
                            s_SCL_int <= '1';
                        end if;

                    --when STOP2 => 
                    --    if(phase_cnt = 0) then -- SCL output
                    --        s_SDA_int <= '1';
                    --    end if;
                    --when STOP3 => 
                    --    if(phase_cnt = 0) then -- SCL output
                    --        s_SDA_int <= '1';
                    --    end if;
                    --    
                    --    o_busy <= '0';
                    when WAIT_CLEAR => 
                        o_done <= '1';
                        --if(i_done_clear = '1') then
                        --    o_done <= '0';
                        --end if;
                    when others =>
                        if(phase_cnt = 0) then -- SCL output
                            --s_SDA_EN <= '1';    -- enable SDA output 
                            --s_SCL_int <= '1';
                            --s_SDA_int <= '1';
                        end if;
                end case;
            end if;
            
    end process;

    with current_state select state_slv <=
        "00000" when IDLE,
        "00001" when START,
        "00010" when START2,
        "00011" when START3,
        "00100" when ADDR,
        "00101" when ADDR2,
        "00110" when ADDR3,
        "00111" when ADDR4,
        "01000" when ADDR5,
        "01001" when ADDR6,
        "01010" when ADDR7,
        "01011" when RW,
        "01100" when ACK1,
        "01101" when DATA1,
        "01110" when DATA2,
        "01111" when DATA3,
        "10000" when DATA4,
        "10001" when DATA5,
        "10010" when DATA6,
        "10011" when DATA7,
        "10100" when DATA8,
        "10101" when ACKN,
        "10110" when STOP,
        "10111" when STOP2,
        "11000" when STOP3,
        "11001" when WAIT_CLEAR,
        "11010" when WAIT_BUF_CLEAR,
        "11111" when others;

        o_state_slv <= state_slv;    
   
      
     --s_SCL_int <= '1' when (current_state = START2 and (phase_cnt = 0 or phase_cnt = 1 or phase_cnt = 2)) else  -- START condition
     --             '1' when (current_state = STOP and ( phase_cnt = 2 or phase_cnt = 3)) else  -- STOP condition
     --             '1' when (
     --               current_state = IDLE or
     --               current_state = START or  
     --               current_state = STOP2 or 
     --               current_state = STOP3 or 
     --               current_state = WAIT_CLEAR 
     --             ) else 
     --             '1' when (phase_cnt = 1 or phase_cnt = 2) else 
     --             '0'; -- SCL transitions

    -- Tri-State buffer control
     --o_SCL   <= s_SCL_int when s_SCL_EN = '1' else 'Z';
     o_SCL   <= s_SCL_int;
     o_SDA   <= s_SDA_int when s_SDA_EN = '1' else 'Z';

    -- debug
    o_phase_cnt <= std_logic_vector(to_unsigned(phase_cnt,2));     
    --o_clkdivcnt <= std_logic_vector(to_unsigned(clk_div_cnt, 24))(23 downto 16); 

    o_addr_buf <= std_logic_vector(addr_buf);

    
end architecture;
