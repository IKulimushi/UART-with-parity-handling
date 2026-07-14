--=============================================================================
-- Test Bench name: Serializer_TB
-- Description:
-- This test bench verifies the functionality of the Serializer module.
--
-- The Serializer converts parallel UART data into a serial bit stream by
-- loading data into an internal shift register and shifting it out one bit
-- at a time when enabled.
--
-- Test scenarios:
--   1. UART transmission without parity
--      - Load an 8-bit data value
--      - Shift data out serially
--
--   2. UART transmission with parity enabled
--      - Load a 9-bit value (8 data bits + parity bit)
--      - Shift data out serially
--
-- The test bench provides:
--   - Clock generation
--   - Reset sequencing
--   - Data loading control
--   - Shift enable generation
--   - Simulation stop condition
--
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity Serializer_TB is
end entity Serializer_TB;

architecture stimulus of Serializer_TB is

    constant c_uart_width : INTEGER     := 8;     -- UART data width
    constant c_uart_state : STD_LOGIC   := '1';   -- UART idle line state
    constant c_baud_rate  : INTEGER     := 9600;  -- UART baud rate
    constant c_bit_period : time        := (1 sec/c_baud_rate); -- UART bit period used to observe frame transmission

    signal clk          : std_logic := '0';
    signal async_rst    : std_logic;
    signal tx_data_in   : std_logic_vector((c_UART_Width-1) downto 0);
    signal tx_data_in_p : std_logic_vector(c_UART_Width downto 0);
    signal shift_en     : std_logic; -- Enables serializer shifting
    signal store_data   : std_logic; -- Loads parallel data into serializer
    signal parity_on    : std_logic := '0';
    signal tx_data_out  : std_logic; -- Serial output stream
    signal clear_data   : std_logic; -- Indicates data has been loaded

begin

    --=========================================================================
    -- Clock Generation
    -- Creates a 100 MHz clock (10 ns period)
    --=========================================================================
    clk <= not clk after 5 ns;

    stimulus_proc : process is
    begin

        -----------------------------------------------------------------------
        -- Test 1 : UART transmission without parity
        -----------------------------------------------------------------------

        -- Apply reset and initialise inputs
        async_rst  <= '1';
        shift_en     <= '0';
        store_data   <= '0';
        tx_data_in    <= (others => '0');
        tx_data_in_p   <= (others => '0');

        -- Hold reset for several clock cycles
        for i in 0 to 4 loop
            wait until rising_edge(clk);
        end loop;

        -- Release reset
        async_rst <= '0';

        -- Allow design to settle
        for i in 0 to 4 loop
            wait until rising_edge(clk);
        end loop;

        -- Load test data into serializer
        store_data <= '1';
        tx_data_in <= "00001010";
        wait until rising_edge(clk);

        -- Remove load request
        store_data <= '0';
        tx_data_in <= (others => '0');

        -- Wait one bit period before shifting begins
        wait for c_bit_period;

        -- Shift out all 8 data bits
        for i in 0 to (c_UART_Width-1) loop
            shift_en <= '1';
            wait until rising_edge(clk);

            shift_en <= '0';
            wait for c_bit_period;
        end loop;

        -- Allow final output bit to settle
        wait for c_bit_period;

        -----------------------------------------------------------------------
        -- Test 2 : UART transmission with parity enabled
        -----------------------------------------------------------------------

        -- Re-apply reset
        async_rst    <= '1';
        parity_on    <= '1';
        shift_en     <= '0';
        store_data   <= '0';
        tx_data_in   <= (others => '0');
        tx_data_in_p <= (others => '0');

        -- Hold reset
        for i in 0 to 4 loop
            wait until rising_edge(clk);
        end loop;

        -- Release reset
        async_rst <= '0';

        -- Allow design to settle
        for i in 0 to 4 loop
            wait until rising_edge(clk);
        end loop;

        -- Load data including parity bit
        -- MSB represents the parity bit
        store_data   <= '1';
        tx_data_in_p <= "000001010";
        wait until rising_edge(clk);

        -- Remove load request
        store_data   <= '0';
        tx_data_in_p <= (others => '0');

        -- Wait one bit period before shifting begins
        wait for c_bit_period;

        -- Shift out data plus parity bit
        for i in 0 to (c_UART_Width) loop
            shift_en <= '1';
            wait until rising_edge(clk);
            shift_en <= '0';
            wait for c_bit_period;
        end loop;
        stop;
    end process;

    UUT : entity work.Serializer
     generic map(
        G_UART_WIDTH => c_UART_Width,
        G_UART_STATE => c_UART_State
    )
     port map(
        I_CLK        => clk,
        I_ASYNC_RST  => async_rst,
        I_TX_DATA    => tx_data_in,
        I_TX_DATA_P  => tx_data_in_p,
        I_SHIFT_EN   => shift_en,
        I_STORE_DATA => store_data,
        I_PARITY_ON  => parity_on,

        O_TX_DATA    => tx_data_out,
        O_CLEAR_DATA => clear_data
    );

end architecture;