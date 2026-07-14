--=============================================================================
-- Module name: UART_Transceiver_TB
-- Description:
-- This testbench verifies the functionality of the UART transceiver design.
--
-- The testbench generates:
--   - A system clock
--   - Reset conditions
--   - Simulated UART serial data frames
--   - Multiple parity configurations
--
-- Test cases include:
--   1. UART transmission with no parity
--   2. Odd parity with incorrect parity bit
--   3. Odd parity with correct parity bit
--   4. Even parity with incorrect parity bit
--   5. Even parity with correct parity bit
--
-- The testbench checks:
--   - UART reception and retransmission
--   - Parity error detection
--   - Restart/error handling
--   - General system timing behaviour
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity UART_Transceiver_TB is
end entity UART_Transceiver_TB;

architecture stimulus of UART_Transceiver_TB is

    -- UART frame configuration
    constant c_data_frame      : integer   := 8;      -- Number of data bits
    constant c_data_packet     : integer   := 10;     -- Total packet size
    constant c_system_clk_freq : integer   := 100e6;  -- 100 MHz system clock
    constant c_baud_rate       : integer   := 9600;   -- UART baud rate
    constant c_idle_state      : std_logic := '1';  -- UART idle level

    signal clk       : std_logic := '0';
    signal async_rst : std_logic := '1'; 
    signal pc_data   : std_logic := '1';  -- Simulated UART RX input

    -- Parity control signals
    signal parity_on   : std_logic := '0';
    signal parity_even : std_logic := '0';

    -- 7-segment display outputs
    signal AN_0 : std_logic;
    signal AN_1 : std_logic;
    signal ca   : std_logic;
    signal cb   : std_logic;
    signal cc   : std_logic;
    signal cd   : std_logic;
    signal ce   : std_logic;
    signal cf   : std_logic;
    signal cg   : std_logic;

    -- UART status + TX outputs
    signal restart_led : std_logic;
    signal tx_data     : std_logic;

    -- UART bit period:
    -- 10 ns = simulated system clock period (100 MHz equivalent timing base)
    constant c_bit_period      : time := (c_system_clk_freq * (10 ns) / c_baud_rate);
    constant c_half_bit_period : time := (c_bit_period / 2);-- Half-bit timing (useful for sampling alignment if needed)

    signal parity_val : std_logic;
    signal pc_frame   : std_logic_vector((c_data_frame-1) downto 0) :=  x"0A"; -- Test data frame = x"0A" = 00001010

    -------------------------------------------------------------------------
    -- UART Frame Generation Procedure
    -------------------------------------------------------------------------
    -- This procedure simulates a UART transmitter by driving the serial
    -- input line (p_pc_data) with:
    --
    --   1. Idle bits
    --   2. Start bit
    --   3. Data bits (LSB first)
    --   4. Optional parity bit
    --   5. Stop bit
    --
    -- Parameters:
    --   p_parity_on     -> Enables parity transmission
    --   p_parity_even   -> Selects even/odd parity
    --   p_parity_bit    -> Injected parity bit value
    --   p_pc_data_frame  -> Data frame to transmit
    --   p_bit_period    -> UART bit timing
    -------------------------------------------------------------------------
    procedure p_pc_data_frame_p (
        signal p_parity_on     : in    std_logic;
        signal p_pc_data       : inout std_logic;

        signal p_parity_even   : in    std_logic;
        signal p_parity_bit    : inout std_logic;
        signal p_pc_data_frame : in    std_logic_vector;

        constant p_lower_limit : in    integer;
        constant p_upper_limit : in    integer;
        constant p_bit_period  : in    time
    ) is
    begin
        ---------------------------------------------------------------------
        -- UART Idle State
        ---------------------------------------------------------------------
        for i in p_lower_limit to p_upper_limit loop
            p_pc_data <= '1';
            wait for p_bit_period;
        end loop;

        ---------------------------------------------------------------------
        -- Start Bit
        ---------------------------------------------------------------------
        p_pc_data <= '0';
        wait for p_bit_period;

        ---------------------------------------------------------------------
        -- Data Transmission (LSB First)
        ---------------------------------------------------------------------
        for i in 0 to (c_data_frame-1) loop
            p_pc_data <= p_pc_data_frame(i);
            wait for p_bit_period;
        end loop;

        ---------------------------------------------------------------------
        -- Optional Parity Bit
        ---------------------------------------------------------------------
        if (p_parity_on = '1') then
            if (p_parity_even = '1') or (p_parity_even = '0') then

                -- Transmit parity bit
                p_pc_data <= p_parity_bit;
                wait for p_bit_period;

                -----------------------------------------------------------------
                -- Stop Bit + Return to Idle
                -----------------------------------------------------------------
                p_pc_data <= '1';

                for i in p_lower_limit to p_upper_limit loop
                    wait for p_bit_period;
                end loop;
            end if;
        else
            -----------------------------------------------------------------
            -- No Parity Mode
            -----------------------------------------------------------------

            -- Stop bit
            p_pc_data <= '1';

            -- Idle state after frame
            for i in p_lower_limit to p_upper_limit loop
                wait for p_bit_period;
            end loop;
        end if;
    end procedure;

begin

    -------------------------------------------------------------------------
    -- Clock Generation
    -------------------------------------------------------------------------
    -- Generate 100 MHz clock (10 ns period)
    clk <= not clk after 5 ns;

    stimulus_proc : process is
    begin

        ---------------------------------------------------------------------
        -- Test 1: No Parity
        ---------------------------------------------------------------------

        -- Reset already asserted at startup
        pc_data      <= '1';
        parity_on    <= '0';
        parity_even  <= '0';
        parity_val   <= '0';

        wait until rising_edge(clk);

        -- Release reset
        async_rst  <= '0';
        wait until rising_edge(clk);

        -- Send UART frame
        p_pc_data_frame_p(parity_on, pc_data, parity_even, parity_val, pc_frame, 1, c_data_packet, c_bit_period);

        ---------------------------------------------------------------------
        -- Test 2: Odd Parity (Incorrect Parity)
        ---------------------------------------------------------------------
        wait until rising_edge(clk);

        pc_data      <= '1';
        parity_on    <= '1';
        parity_even  <= '0';

        -- Incorrect odd parity bit
        parity_val   <= '0';
        wait until rising_edge(clk);

        p_pc_data_frame_p(parity_on, pc_data, parity_even, parity_val, pc_frame, 1, 1, c_bit_period);

        ---------------------------------------------------------------------
        -- Test 3: Odd Parity (Correct Parity)
        ---------------------------------------------------------------------
        wait until rising_edge(clk);

        -- Re-assert reset before next test
        async_rst    <= '1';
        pc_data      <= '1';
        parity_on    <= '1';
        parity_even  <= '0';

        -- Correct odd parity bit
        parity_val <= '1';
        wait until rising_edge(clk);

        -- Release reset
        async_rst <= '0';
        wait until rising_edge(clk);

        p_pc_data_frame_p(parity_on, pc_data, parity_even, parity_val, pc_frame, 1, 1, c_bit_period);

        ---------------------------------------------------------------------
        -- Test 4: Even Parity (Incorrect Parity)
        ---------------------------------------------------------------------
        wait until rising_edge(clk);

        pc_data      <= '1';
        parity_on    <= '1';
        parity_even  <= '1';

        -- Incorrect even parity bit
        parity_val   <= '1';
        wait until rising_edge(clk);

        p_pc_data_frame_p(parity_on, pc_data, parity_even, parity_val, pc_frame, 1, 1, c_bit_period);

        ---------------------------------------------------------------------
        -- Test 5: Even Parity (Correct Parity)
        ---------------------------------------------------------------------
        wait until rising_edge(clk);

        -- Reset DUT
        async_rst    <= '1';
        pc_data      <= '1';
        parity_on    <= '1';
        parity_even  <= '1';

        -- Correct even parity bit
        parity_val   <= '0';
        wait until rising_edge(clk);

        -- Release reset
        async_rst <= '0';
        wait until rising_edge(clk);

        p_pc_data_frame_p(parity_on, pc_data, parity_even, parity_val, pc_frame, 1, 1, c_bit_period);

        for i in 0 to 10 loop
            wait for c_bit_period;
        end loop;

        stop;
    end process;

    UUT : entity work.Uart_Transceiver
    generic map(
        G_DATA_FRAME      => c_data_frame,
        G_DATA_PACKET     => c_data_packet,
        G_SYSTEM_clk_FREQ => c_system_clk_freq,
        G_BAUD_RATE       => c_baud_rate,
        G_IDLE_STATE      => c_idle_state
    )
    port map(
        I_CLK         => clk,
        I_ASYNC_RST   => async_rst,
        I_PC_DATA     => pc_data,
        I_PARITY_ON   => parity_on,
        I_PARITY_EVEN => parity_even,

        O_AN_0        => AN_0,
        O_AN_1        => AN_1,
        O_CA          => ca,
        O_CB          => cb,
        O_CC          => cc,
        O_CD          => cd,
        O_CE          => ce,
        O_CF          => cf,
        O_CG          => cg,

        O_RESTART_LED => restart_led,
        O_TX_DATA     => tx_data
    );

end architecture;