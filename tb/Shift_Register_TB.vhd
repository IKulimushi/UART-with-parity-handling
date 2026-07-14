--=============================================================================
-- Test Bench name: Shift_Register_TB
-- Description:
-- This test bench verifies the functionality of the Shift_Register module.
--
-- The Shift_Register module performs UART receive operations by:
--   - Shifting serial data into a receive register
--   - Extracting received data bytes
--   - Calculating parity values
--   - Verifying parity when enabled
--   - Generating restart/error indications on parity failures
--
-- Test scenarios:
--   1. UART frame reception with parity disabled
--   2. UART frame reception with odd parity (correct parity)
--   3. UART frame reception with odd parity (incorrect parity)
--   4. UART frame reception with even parity (correct parity)
--   5. UART frame reception with even parity (incorrect parity)
--
-- The test bench provides:
--   - Clock generation
--   - UART frame generation procedures
--   - Start, data, parity, and stop bit transmission
--   - Verification of parity handling
--   - Automatic simulation termination
--
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity Shift_Register_TB is
end entity Shift_Register_TB;

architecture stimulus of Shift_Register_TB is

    constant c_data_packet    : integer := 10; -- UART frame size without parity
    -- UART frame length:
    --   No parity  = 10 bits (start + 8 data + stop)
    --   With parity = 11 bits (start + 8 data + parity + stop)

    constant c_data_frame     : integer  := 8;     -- Number of UART data bits
    constant c_baud_rate      : integer  := 9600;  -- UART baud rate
    constant c_bit_period     : time     := (1 sec/c_baud_rate);  -- UART bit period used to observe frame transmission
    constant c_half_bit_period : time     := (c_bit_period/2);     -- Half-bit timing (useful for sampling alignment if needed)
    constant c_packet        : std_logic_vector((c_data_frame-1) downto 0) := x"0A"; -- Test data byte = x"0A" = 00001010

    signal clk           : std_logic := '0';
    signal async_rst    : std_logic;
    signal shift_en       : std_logic;
    signal tx_data        : std_logic := '1';
    signal baud_start     : std_logic := '0';
    signal parity_on      : std_logic := '0';
    signal parity_even    : std_logic := '0';
    signal restart       : std_logic;
    signal parity_val     : std_logic;
    signal rx_data        : std_logic_vector((c_data_frame-1) downto 0);
    signal rx_data_display : std_logic_vector((c_data_frame-1) downto 0);

    --=========================================================================
    -- Procedure: p_data_frame_shift
    --
    -- Shifts an entire UART data field into the DUT.
    -- For each bit:
    --   1. Drive serial input
    --   2. Wait half bit period
    --   3. Generate shift_en pulse
    --   4. Wait remaining half bit period
    --=========================================================================
    procedure p_data_frame_shift (
        signal p_clk               : in  std_logic;
        signal p_tx_data           : out std_logic;
        signal p_shift_en          : out std_logic;

        constant p_packet          : in  std_logic_vector((c_data_frame-1) downto 0);
        constant p_lower_limit     : in  integer;
        constant p_upper_limit     : in  integer;
        constant p_half_bit_period : in  time
    ) is
    begin
        for i in p_lower_limit to p_upper_limit loop

            p_tx_data <= p_packet(i);

            wait for p_half_bit_period;

            wait until rising_edge(p_clk);
            p_shift_en <= '1';

            wait until rising_edge(p_clk);
            p_shift_en <= '0';

            wait for p_half_bit_period;
        end loop;
    end procedure;

    --=========================================================================
    -- Procedure: p_single_bit_tx
    --
    -- Transmits a single UART bit such as:
    --   - Start bit
    --   - Parity bit
    --   - Stop bit
    --
    -- Generates a corresponding shift_en pulse.
    --=========================================================================
    procedure p_single_bit_tx (
        signal p_clk                           : in  std_logic;
        signal p_tx_data                       : out std_logic;
        signal p_shift_en                      : out std_logic;

        constant p_start_or_parity_or_stop_bit : in  std_logic;
        constant p_half_bit_period             : in  time
    ) is
    begin

        p_tx_data <= p_start_or_parity_or_stop_bit;

        wait for p_half_bit_period;

        wait until rising_edge(p_clk);
        p_shift_en <= '1';

        wait until rising_edge(p_clk);
        p_shift_en <= '0';

        wait for p_half_bit_period;

    end procedure;

begin

    --=========================================================================
    -- Clock Generation
    -- Generates a 100 MHz clock (10 ns period)
    --=========================================================================
    clk <= not clk after 5 ns;

    stimulus_proc : process is
    begin

        -----------------------------------------------------------------------
        -- Test 1 : No Parity Mode
        -----------------------------------------------------------------------
        async_rst   <= '1';
        parity_on   <= '0';
        parity_even <= '0';
        shift_en    <= '0';

        for i in 0 to 4 loop
            wait until rising_edge(clk);
        end loop;

        async_rst <= '0';

        for i in 0 to 5 loop
            wait for c_bit_period;
        end loop;

        -- Begin UART frame reception
        baud_start <= '1';
        wait until rising_edge(clk);
        baud_start <= '0';

        -- Start bit
        p_single_bit_tx(clk, tx_data, shift_en, '0', c_half_bit_period);

        -- Data bits
        p_data_frame_shift(clk, tx_data, shift_en, c_packet, 0, (c_data_frame-1), c_half_bit_period);

        -- Stop bit
        p_single_bit_tx(clk, tx_data, shift_en, '1', c_half_bit_period);

        tx_data <= '1';

        for i in 0 to 5 loop
            wait for c_bit_period;
        end loop;

        -----------------------------------------------------------------------
        -- Test 2 : Odd Parity Mode (Expected Pass)
        -----------------------------------------------------------------------
        async_rst   <= '1';
        parity_on   <= '1';
        parity_even <= '0';
        shift_en    <= '0';

        for i in 0 to 4 loop
            wait until rising_edge(clk);
        end loop;

        async_rst <= '0';

        for i in 0 to 5 loop
            wait for c_bit_period;
        end loop;

        baud_start <= '1';
        wait until rising_edge(clk);
        baud_start <= '0';

        p_single_bit_tx(clk, tx_data, shift_en, '0', c_half_bit_period);

        p_data_frame_shift(clk, tx_data,shift_en, c_packet, 0, (c_data_frame-1), c_half_bit_period);

        -- Correct odd parity bit
        p_single_bit_tx(clk, tx_data, shift_en, '1', c_half_bit_period);

        -- Stop bit
        p_single_bit_tx(clk, tx_data, shift_en, '1', c_half_bit_period);

        for i in 0 to 5 loop
            wait for c_bit_period;
        end loop;

        -----------------------------------------------------------------------
        -- Test 3 : Odd Parity Mode (Expected Failure)
        -----------------------------------------------------------------------
        baud_start <= '1';
        wait until rising_edge(clk);
        baud_start <= '0';

        p_single_bit_tx(clk, tx_data, shift_en, '0', c_half_bit_period);

        p_data_frame_shift(clk, tx_data,shift_en,c_packet,0,(c_data_frame-1),c_half_bit_period);

        -- Incorrect odd parity bit
        p_single_bit_tx(clk, tx_data, shift_en, '0', c_half_bit_period);

        -- Stop bit
        p_single_bit_tx(clk, tx_data, shift_en, '1', c_half_bit_period);

        for i in 0 to 5 loop
            wait for c_bit_period;
        end loop;

        -----------------------------------------------------------------------
        -- Test 4 : Even Parity Mode (Expected Pass)
        -----------------------------------------------------------------------
        async_rst   <= '1';
        parity_on   <= '1';
        parity_even <= '1';
        shift_en    <= '0';

        for i in 0 to 4 loop
            wait until rising_edge(clk);
        end loop;

        async_rst <= '0';

        for i in 0 to 5 loop
            wait for c_bit_period;
        end loop;

        baud_start <= '1';
        wait until rising_edge(clk);
        baud_start <= '0';

        p_single_bit_tx(clk, tx_data, shift_en, '0', c_half_bit_period);

        p_data_frame_shift(clk, tx_data,shift_en, c_packet, 0, (c_data_frame-1), c_half_bit_period);

        -- Correct even parity bit
        p_single_bit_tx(clk, tx_data, shift_en, '0', c_half_bit_period);

        -- Stop bit
        p_single_bit_tx(clk, tx_data, shift_en, '1', c_half_bit_period);

        for i in 0 to 5 loop
            wait for c_bit_period;
        end loop;

        -----------------------------------------------------------------------
        -- Test 5 : Even Parity Mode (Expected Failure)
        -----------------------------------------------------------------------
        baud_start <= '1';
        wait until rising_edge(clk);
        baud_start <= '0';

        p_single_bit_tx(clk, tx_data, shift_en, '0', c_half_bit_period);

        p_data_frame_shift(clk, tx_data, shift_en, c_packet, 0, (c_data_frame-1), c_half_bit_period);

        -- Incorrect even parity bit
        p_single_bit_tx(clk, tx_data, shift_en, '1', c_half_bit_period);

        -- Stop bit
        p_single_bit_tx(clk, tx_data, shift_en, '1', c_half_bit_period);

        for i in 0 to 5 loop
            wait for c_bit_period;
        end loop;
        stop;

    end process;

    UUT : entity work.Shift_Register
     generic map(
        G_DATA_FRAME    => c_data_frame,
        G_DATA_PACKET   => c_data_packet,
        G_DATA_PACKET_P => (c_data_packet+1)
    )
     port map(
        I_CLK             => clk,
        I_ASYNC_RST       => async_rst or baud_start,
        I_SHIFT_EN        => shift_en,
        I_TX_DATA         => tx_data,
        I_BAUD_START      => baud_start,
        I_PARITY_ON       => parity_on,
        I_PARITY_EVEN     => parity_even,
 
        O_RESTART_LED     => restart,
        O_PARITY_VAL      => parity_val,
        O_RX_DATA         => rx_data,
        O_RX_DATA_DISPLAY => rx_data_display
    );

end architecture;