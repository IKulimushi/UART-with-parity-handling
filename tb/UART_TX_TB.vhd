--=============================================================================
-- Testbench name: UART_TX_TB
-- Description:
-- This testbench verifies the functionality of the UART_TX module.
--
-- The transmitter is tested in both parity-disabled and parity-enabled
-- configurations to ensure that received parallel data is correctly
-- serialised into a UART-compatible bitstream.
--
-- Test procedure:
--   1. Apply reset and initialise all inputs.
--   2. Load a test data byte into the transmitter.
--   3. Assert store_data to begin transmission.
--   4. Observe serial output data (o_TxData).
--   5. Verify correct frame generation:
--        - Without parity
--        - With parity bit = '0'
--        - With parity bit = '1'
--   6. Verify clear_data handshake behaviour.
--
-- Expected behaviour:
--   - UART frames are transmitted LSB first.
--   - Start and stop bits are correctly inserted.
--   - Optional parity bit is included when enabled.
--   - clear_data is asserted when data has been accepted.
--   - Transmitter returns to idle state after frame completion.
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity UART_TX_TB is
end entity UART_TX_TB;

architecture stimulus of UART_TX_TB is

    constant c_data_frame      : integer      := 8;        -- Number of UART data bits
    constant c_data_packet     : integer      := 10;       -- UART frame size without parity
    constant c_system_clk_freq : integer      := 100e6;    -- 100 MHz system clock
    constant c_baud_rate       : integer      := 9600;     -- UART baud rate
    constant c_idle_state      : std_logic    := '1';    -- UART idle line state
    constant c_bit_period      : time         := (1 sec / c_baud_rate); -- UART bit period used to observe frame transmission

    signal clk        : std_logic := '0';
    signal async_rst  : std_logic := '1';
    signal rx_data    : std_logic_vector((c_data_frame-1) downto 0);
    signal parity_on  : std_logic;
    signal parity_val : std_logic;
    signal store_data : std_logic;
    signal clear_data : std_logic;
    signal tx_data    : std_logic;
    signal rx_byte    : std_logic_vector((c_data_frame-1) downto 0) := x"0A"; -- Test data byte = x"0A" = 00001010

begin

    --=========================================================================
    -- Clock Generation
    -- Generates a 100 MHz clock (10 ns period)
    --=========================================================================
    clk <= not clk after 5 ns;

    stimulus_proc : process is
    begin

        ---------------------------------------------------------------------
        -- Test 1 : UART Transmission Without Parity
        ---------------------------------------------------------------------

        -- Apply reset and initialise inputs
        store_data   <= '0';
        parity_on    <= '0';
        parity_val   <= '0';
        rx_data      <= (others => '1');

        for i in 0 to 5 loop
            wait until rising_edge(clk);
        end loop;

        -- Release reset
        async_rst <= '0';

        -- Load transmit data
        rx_data    <= rx_byte;
        store_data <= '1';

        wait until rising_edge(clk);

        store_data <= '0';

        -- Wait for transmission to complete
        for i in 0 to c_data_frame loop
            wait for c_bit_period;
        end loop;

        ---------------------------------------------------------------------
        -- Test 2 : UART Transmission With Parity Enabled
        --          Parity Bit = '0'
        ---------------------------------------------------------------------

        -- Apply reset
        async_rst    <= '1';
        store_data   <= '0';
        parity_on    <= '1';
        parity_val   <= '0';
        rx_data      <= (others => '1');

        for i in 0 to 5 loop
            wait until rising_edge(clk);
        end loop;

        -- Release reset
        async_rst <= '0';

        -- Load transmit data
        rx_data    <= rx_byte;
        store_data <= '1';

        wait until rising_edge(clk);

        store_data <= '0';

        -- Wait for parity frame transmission
        for i in 0 to (c_data_frame + 1) loop
            wait for c_bit_period;
        end loop;

        ---------------------------------------------------------------------
        -- Test 3 : UART Transmission With Parity Enabled
        --          Parity Bit = '1'
        ---------------------------------------------------------------------

        -- Apply reset
        async_rst    <= '1';
        store_data   <= '0';
        parity_on    <= '1';
        parity_val   <= '1';
        rx_data      <= (others => '1');

        for i in 0 to 5 loop
            wait until rising_edge(clk);
        end loop;

        async_rst  <= '0';     -- Release reset
        rx_data    <= rx_byte; -- Load transmit data
        store_data <= '1';

        wait until rising_edge(clk);

        store_data <= '0';

        -- Wait for parity frame transmission
        for i in 0 to (c_data_frame + 1) loop
            wait for c_bit_period;
        end loop;
        stop;
    end process;
    
    UUT : entity work.UART_TX
     generic map(
        G_DATA_FRAME      => c_data_frame,
        G_DATA_PACKET     => c_data_packet,
        G_UART_MODE_SEL   => 0,   -- TX mode (full-bitperiod timing)
        G_SYSTEM_clk_FREQ => c_system_clk_freq,
        G_BAUD_RATE       => c_baud_rate,
        G_IDLE_STATE      => c_idle_state
    )
     port map(
        I_CLK        => clk,
        I_ASYNC_RST  => async_rst,
        I_RX_DATA    => rx_data,
        I_PARITY_ON  => parity_on,
        I_PARITY_VAL => parity_val,
        I_STORE_DATA => store_data,

        O_CLEAR_DATA => clear_data,
        O_TX_DATA    => tx_data
    );

end architecture;