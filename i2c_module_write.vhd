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
        i_reset_n : in std_logic;				            -- Active low reset
        i_CLK : in std_logic;				
        i_mode : in std_logic;                              -- READ : 1, WRITE : 0
        i_en : in std_logic;
        i_addr : in std_logic_vector(6 downto 0);
        i_tx_byte : in std_logic_vector(7 downto 0);        -- READ: byte cnt to read, WRITE: byte cnt to send
        i_byte_cnt : in std_logic_vector(7 downto 0); 
        i_SDA : in std_logic;
        i_done_clear : in std_logic;
        o_data : out std_logic_vector(7 downto 0);
        o_buffer_clear : out std_logic := '0'; 
        o_busy : out std_logic := '0';
        o_done : out std_logic := '0';
        o_SCL : out std_logic;
        o_SDA : out std_logic;	
        o_phase_cnt : out std_logic_vector(1 downto 0);
        o_clkdivcnt : out std_logic_vector(7 downto 0);
        o_state_slv : out std_logic_vector(5 downto 0);
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
	type state_type is (IDLE, START, START2, RSTART1, RSTART2,
	                    ADDR, ADDR2, ADDR3, ADDR4, ADDR5, ADDR6, ADDR7,
	                    RW, ACK1, 
	                    DATA1, DATA2, DATA3, DATA4, DATA5, DATA6, DATA7, DATA8,
	                    RDATA1, RDATA2, RDATA3, RDATA4, RDATA5, RDATA6, RDATA7, RDATA8,
	                    ACKN, MNACK, STOP, WAIT_CLEAR, WAIT_BUF_CLEAR);
	                    
	signal current_state : state_type := IDLE;
	signal next_state : state_type := START;
    signal state_slv : std_logic_vector(5 downto 0);

	signal halfcount_int : integer range 0 to 100000 := 0;
	signal delay_count : integer range 0 to 1000000 := 0;
	signal cnt : integer range 0 to 20 := 0;

	signal s_BYTECNT_int : integer range 0 to 10000 := 2; 
	
	signal s_SCL_int : std_logic := '1';
	signal s_SDA_int : std_logic := '1'; 
	signal s_SDA_EN : std_logic := '1';
	signal s_SCL_EN : std_logic := '0';

    signal s_ACK_ok : std_logic := '0'; -- for sampling ACK
	
	signal w_mode : std_logic := '0'; -- READ : 1, WRITE : 0
    signal w_rwbit: std_logic := '0'; -- READ : 1, WRITE : 0 -- for use in setting RW after write ADDR (which uses RW = 0 to write)
        
--	signal i_addr : std_logic_vector(6 downto 0) := "1110000"; -- hard coded address 
    signal addr_buf : unsigned(6 downto 0);
	signal data_buf : unsigned(7 downto 0);
	signal rx_buf : unsigned(7 downto 0);
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
    NEXT_STATE_LOGIC: process(current_state, byte_cnt, total_bytes, s_ACK_ok, w_mode)
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

                        w_mode <= i_mode;
                        if (i_en = '1') then 
                            next_state <= START;
                        else 
                            next_state <= IDLE;
                        end if;
                        
                    when RSTART1 => next_state <= RSTART2;
                    when RSTART2 => next_state <= ADDR;
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
                    when RW => 
                        next_state <= ACK1;
                        --if(w_rwbit = '1') then
                        --    next_state <= RACK;
                        --else 
                        --    next_state <= ACK1;
                        --end if;
                    when ACK1 =>
                        if(w_rwbit = '0') then -- if WRITE
                            if((total_bytes>0) and (s_ACK_ok = '1')) then 
                                next_state <= DATA1;
                            else 
                                next_state <= STOP; 
                            end if;
                        else -- if READ
                            if(s_ACK_ok = '1') then -- real one
                            --if(s_ACK_ok = '0') then -- testing
                                next_state <= RDATA1;
                            else 
                                next_state <= STOP; 
                            end if;
                        end if;

                    -- WRITE DATA BITS
                    when DATA1 => next_state <= DATA2;
                    when DATA2 => next_state <= DATA3;
                    when DATA3 => next_state <= DATA4;
                    when DATA4 => next_state <= DATA5;
                    when DATA5 => next_state <= DATA6;
                    when DATA6 => next_state <= DATA7;
                    when DATA7 => next_state <= DATA8;
                    when DATA8 => next_state <= ACKN;

                    -- READ DATA BITS  
                    when RDATA1 => next_state <= RDATA2;
                    when RDATA2 => next_state <= RDATA3;
                    when RDATA3 => next_state <= RDATA4;
                    when RDATA4 => next_state <= RDATA5;
                    when RDATA5 => next_state <= RDATA6;
                    when RDATA6 => next_state <= RDATA7;
                    when RDATA7 => next_state <= RDATA8;
                    when RDATA8 => next_state <= MNACK;
                    when MNACK  => next_state <= STOP;

                    When ACKN => 
                            --next_state <= STOP;
                        if (byte_cnt < total_bytes) then  -- how multiple bytes are currently handled
                            if(w_mode = '1') then -- if WRITE
                                next_state <= DATA1;
                            else -- if READ 
                                next_state <= RSTART1;
                            end if;
                        else 
                            --next_state <= STOP; -- real
                            next_state <= RSTART1; -- testing
                        end if;
                    when WAIT_BUF_CLEAR => 
                        next_state <= DATA1;
                    when STOP => 
                        next_state <= WAIT_CLEAR;
                    when WAIT_CLEAR =>
                        next_state <= IDLE;
 
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
                s_SCL_int <= '1';
                s_SDA_int <= '1'; 
                s_SDA_EN <= '1';
                byte_cnt <= 0;
                o_done <= '0';
                o_busy <= '0';
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
                        o_done <= '0';
                        
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
                            s_sda_int <= i_addr(6);
                            s_sda_en <= '1';

                            -- RW bit to '0' for WRITE
                            w_rwbit <= '0';  
                        end if;

                    when RSTART1 =>
                        if(phase_cnt = 0) then 
                            s_SDA_EN <='1';
                            s_SCL_int <= '0';
                            s_SDA_int <= '1';
                            
                            s_ACK_ok <= '0';
                        end if;
                        if(phase_cnt = 1) then 
                            s_SCL_int <= '1';
                        end if;
                        if(phase_cnt = 2) then 
                            --s_SCL_int <= '0';
                            s_SCL_int <= '1';
                            s_SDA_int <= '0';
                        end if;
                        if(phase_cnt = 3) then 
                            s_SCL_int <= '0';
                            addr_buf <= unsigned(i_addr); 

                            -- set R/W bit to READ i.e. '1' 
                            w_rwbit <= '1'; 

                            --s_SDA_int <= '1';
                        end if;

                    when RSTART2 => 
                        if(phase_cnt = 3) then 
                            s_sda_int <= i_addr(6);
                        end if;
                    
                    when ADDR | ADDR2 | ADDR3 | ADDR4 | ADDR5 | ADDR6 | ADDR7 | RW => 
                    --when ADDR | ADDR2 | ADDR3 | ADDR4 | ADDR5 | ADDR6 | ADDR7 => 
                        if(phase_cnt = 0) then 
                            s_SCL_int <= '1';
                            
                        end if;
                        if(phase_cnt = 1) then 
                            s_SCL_int <= '1';
                            if((current_state = RW) and (w_rwbit = '1')) then
                                s_SDA_EN <= '0'; 
                            end if;
                        end if;
                        if(phase_cnt = 2) then 
                            s_SCL_int <= '0';

                            if(current_state = RW) then
                                s_SDA_EN <= '0'; 
                                if(w_rwbit = '0') then
                                    --s_SDA_int <= w_rwbit;
                                    s_SDA_int <= w_rwbit;
                                else 
                                    s_SDA_EN <= '0'; 
                                    s_SDA_int <= '1';
                                end if;
                            end if;
                        end if;
                        if(phase_cnt = 3) then
                            s_SCL_int <= '0';
                            
                            if(phase_tick = '1') then
                                s_SDA_int <= addr_buf(5);
                                addr_buf <= addr_buf(5 downto 0) & '0';
                                --s_SDA_EN <= '1';
                            end if;

                            if((current_state = ADDR7) and (w_rwbit = '1')) then
                                s_SDA_EN <= '1'; 
                                s_SDA_int <= '1';
                            end if;
                        end if;
                   
                    -- WRITE DATA BITS 
                    when DATA1 | DATA2 | DATA3 | DATA4 | DATA5 | DATA6 | DATA7 | DATA8 =>
                        if(phase_cnt = 0) then 
                            s_SDA_EN <= '1';
                            s_SCL_int <= '1';
                            s_SDA_int <= '0';

                            if((current_state = DATA1) and (phase_tick = '1')) then
                                byte_cnt <= byte_cnt + 1;
                                s_ACK_ok <= '0';
                            end if;
                        end if;
                        if(phase_cnt = 1) then 
                            s_SCL_int <= '1';
                        end if;
                        if(phase_cnt = 2) then 
                            s_SCL_int <= '0';
                            if(current_state = DATA8) then
                                s_SDA_EN <= '0'; -- release SDA for ACK
                            end if;
                        end if;
                        if(phase_cnt = 3) then
                            s_SCL_int <= '0';
                            
                            if(current_state = RW) then
                                --s_SDA_EN <= '0';
                            else
                                if(phase_tick = '1') then
                                    --s_SDA_int <= data_buf(6);
                                    --addr_buf <= data_buf(6 downto 0) & '0';
                                    s_SDA_int <= data_buf(7); -- real
                                    s_SDA_int <= '0'; -- testing
                                    data_buf <= shift_left(data_buf, 1);
                                end if;
                            end if;
                        end if;

                    -- READ DATA BITS
                    when RDATA1 | RDATA2 | RDATA3 | RDATA4 | RDATA5 | RDATA6 | RDATA7 | RDATA8 =>
                        if(phase_cnt = 0) then
                            s_SCL_int <= '1';
                        end if;
                        if(phase_cnt = 1) then
                            s_SCL_int <= '1';
                        end if;
                        if(phase_cnt = 2) then
                            if((phase_tick = '1')) then
                                rx_buf <= rx_buf(6 downto 0) & To_X01(i_SDA); -- sample SDA 
                                --rx_buf <= shift_right(rx_buf, 1);
                            end if;
                            s_SCL_int <= '0';
                        end if;
                        if(phase_cnt = 3) then
                            s_SCL_int <= '0';

                            --if((current_state = RDATA8) and (phase_tick = '1')) then
                            --    o_data <= std_logic_vector(rx_buf);
                            --end if;
                        end if;

                    when ACK1 | ACKN => 
                        if(phase_cnt = 0) then -- SCL output
                            s_SCL_int <= '1';
                            s_SDA_EN <= '0';
                            s_SDA_int <= '0'; --testing
                        end if;
                        if(phase_cnt = 1) then 
                            s_SCL_int <= '1';
                            s_ACK_ok <= not To_X01(i_SDA); -- sample ACK
                        end if;
                        if(phase_cnt = 2) then
                            s_SCL_int <= '0';

                            if(w_rwbit = '0') then
                                s_SDA_int <= '0'; --testing forcing low (issue with SDA pulling up unexpectedly)
                                s_SDA_EN <= '1'; --testing
                            end if;
                            if(byte_cnt = 0) then
                                current_byte <= i_tx_byte;
                            else 
                                current_byte <= x"01";
                            end if;
                            --current_byte <= i_tx_byte;
                            --s_SDA_int <= current_byte(7);
                            data_buf <= shift_left(unsigned(current_byte), 1);
                        end if;
                        if(phase_cnt = 3) then -- SDA output
                            s_SCL_int <= '0';
                            --s_SDA_EN <= '1';
                        end if;
                        
                     
                    when MNACK => 
                        if(phase_cnt = 0) then
                            s_SDA_EN <= '1';
                            s_SDA_int <= '1';
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
                            s_SDA_int <= '1';
                        end if;
                        

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

                    when WAIT_CLEAR => 
                        o_done <= '1';
                        o_busy <= '0';
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
        "000000" when IDLE,
        "000001" when START,
        "000010" when START2,
        "000011" when RSTART1,
        "000100" when ADDR,
        "000101" when ADDR2,
        "000110" when ADDR3,
        "000111" when ADDR4,
        "001000" when ADDR5,
        "001001" when ADDR6,
        "001010" when ADDR7,
        "001011" when RW,
        "001100" when ACK1,
        "001101" when DATA1,
        "001110" when DATA2,
        "001111" when DATA3,
        "010000" when DATA4,
        "010001" when DATA5,
        "010010" when DATA6,
        "010011" when DATA7,
        "010100" when DATA8,
        "010101" when ACKN,
        "010110" when STOP,
        "010111" when RSTART2,
        --"11000" when STOP3,
        --"011001" when WAIT_CLEAR,
        --"011010" when WAIT_BUF_CLEAR,
        "011000" when RDATA1,
        "011001" when RDATA2,
        "011010" when RDATA3,
        "011011" when RDATA4,
        "011100" when RDATA5,
        "011101" when RDATA6,
        "011110" when RDATA7,
        "011111" when RDATA8,
        "100000" when others;

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
    o_data <= std_logic_vector(rx_buf);
    
end architecture;
