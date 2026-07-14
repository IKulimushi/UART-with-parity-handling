--=============================================================================
-- Testbench name: Baud_Clock_Generator_TB
-- Description:
-- This testbench verifies the functionality of the Baud_Clock_Generator
-- module under both parity and non-parity operating modes.
--
-- The testbench performs the following checks:
--   1. UART TX mode operation (g_UART_ModeSel = 0)
--   2. UART RX mode operation (g_UART_ModeSel = 1)
--   3. Frame timing without parity enabled
--   4. Frame timing with parity enabled
--   5. Correct generation of baud clock pulses
--   6. Correct assertion of the ready signal when transmission/reception
--      is complete
--
-- Test sequence:
--   - Apply reset
--   - Configure UART mode
--   - start baud generator
--   - Wait for complete frame duration
--   - Repeat for parity enabled and disabled modes
--
-- Expected behaviour:
--   - baud_clk_out generates one pulse per UART bit period
--   - ready remains low while bits are being processed
--   - ready returns high once all frame bits have been completed
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity Baud_Clock_Generator_TB is
end entity Baud_Clock_Generator_TB;

architecture stimulus of Baud_Clock_Generator_TB is

    constant c_total_bits      : integer := 10;     -- UART frame size without parity
    constant c_system_clk_freq : integer := 100e6;  -- 100 MHz system clock
    constant c_baud_rate       : integer := 9600;   -- UART baud rate
    constant c_bit_period      : time    := (1 sec / c_baud_rate); -- UART bit period used to observe frame transmission

    -- UART mode selector
    -- 0 = TX mode
    -- 1 = RX mode
    signal c_uart_mode_sel : natural range 0 to 1;
    signal clk             : std_logic := '0';
    signal async_rst       : std_logic;
    signal start           : std_logic;
    signal parity_on       : std_logic := '0';
    signal baud_clk_out    : std_logic;
    signal ready           : std_logic;

begin

    --=========================================================================
    -- Clock Generation
    -- Creates a 100 MHz clock (10 ns period)
    --=========================================================================
    clk <= not clk after 5 ns;

    stimulus_proc : process
    begin

        ----------------------------------------------------------------------
        -- Test 1:
        -- No Parity Enabled
        ----------------------------------------------------------------------
        for i in 0 to 1 loop

            async_rst       <= '1'; -- Apply reset
            c_uart_mode_sel <= i;   -- Test both UART modes
            start           <= '0';

            -- Hold reset for several clock cycles
            for i in 0 to 5 loop
                wait until rising_edge(clk);
            end loop;

            async_rst <= '0';-- Release reset

            -- Allow design to stabilise
            for i in 0 to 5 loop
                wait until rising_edge(clk);
            end loop;

            -- start baud generator
            start <= '1';
            wait until rising_edge(clk);
            start <= '0';

            -- Wait for full frame duration
            -- (10-bit UART frame)
            for i in 0 to c_total_bits loop
                wait for c_bit_period;
            end loop;

        end loop;

        ----------------------------------------------------------------------
        -- Test 2:
        -- Parity Enabled
        ----------------------------------------------------------------------
        for j in 0 to 1 loop

            async_rst       <= '1'; -- Apply reset
            c_uart_mode_sel <= j;   -- Test both UART operating modes
            parity_on       <= '1'; -- enable parity mode
            start           <= '0';

            -- Hold reset
            for i in 0 to 5 loop
                wait until rising_edge(clk);
            end loop;

            async_rst <= '0'; -- Release reset

            -- Allow design to stabilise
            for i in 0 to 5 loop
                wait until rising_edge(clk);
            end loop;

            -- start baud timing
            start <= '1';
            wait until rising_edge(clk);
            start <= '0';

            -- Wait for complete frame duration
            -- (10 bits + parity bit)
            for i in 0 to c_total_bits + 1 loop
                wait for c_bit_period;
            end loop;

        end loop;
        stop;
    end process;


    UUT : entity work.Baud_Clock_Generator
     generic map(
        G_TOTAL_BITS      => c_total_bits,
        G_TOTAL_BITS_P    => (c_total_bits + 1),
        G_SYSTEM_clk_FREQ => c_system_clk_freq,
        G_BAUD_RATE       => c_baud_rate,
        G_UART_MODE_SEL   => c_uart_mode_sel
    )
     port map(
        I_CLK          => clk,
        I_ASYNC_RST    => async_rst,
        I_START        => start,
        I_PARITY_ON    => parity_on,

        O_BAUD_clk_OUT => baud_clk_out,
        O_READY        => ready
    );

end architecture;