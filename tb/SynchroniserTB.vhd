--=============================================================================
-- Testbench name: SynchroniserTB
-- Description:
-- This testbench verifies the operation of the Synchroniser module.
--
-- The Synchroniser is designed to safely transfer an asynchronous input
-- signal into the system clock domain using a two-stage flip-flop structure.
--
-- Test procedure:
--   1. Apply reset and initialise the asynchronous input to the idle state.
--   2. Release reset and allow the synchroniser to settle.
--   3. Apply a sequence of asynchronous data transitions.
--   4. Observe the synchronised output and verify that:
--        - Input transitions are captured correctly.
--        - Output changes only on clock edges.
--        - The two-stage synchronisation delay is present.
--
-- Expected behaviour:
--   - o_SyncData follows i_AsyncData after passing through two clocked stages.
--   - Reset forces the synchroniser outputs to the configured idle state.
--   - Metastability risk is reduced by the two-stage synchroniser structure.
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity SynchroniserTB is
end entity SynchroniserTB;

architecture stimulus of SynchroniserTB is

    constant c_idle_state : std_logic := '1';                  -- uart idle line state
    constant c_data_frame : integer   := 8;                    -- number of test bits
    constant c_baud_rate  : integer   := 9600;                 -- uart baud rate
    constant c_bit_period : time      := (1 sec/c_baud_rate);  -- uart bit period used to observe frame transmission
    constant c_packet     : std_logic_vector((c_data_frame-1) downto 0) := x"0A"; -- test data byte = x"0A" = 00001010

    signal clk            : std_logic := '0';
    signal async_rst      : std_logic;
    signal async_data     : std_logic;
    signal sync_data      : std_logic;

begin

    --=========================================================================
    -- Clock Generation
    -- Generates a 100 MHz clock (10 ns period)
    --=========================================================================
    clk <= not clk after 5 ns;

    stimulus_proc : process is
    begin
        -- Initial reset
        async_rst  <= '1';
        async_data <= c_idle_state;

        for i in 0 to 4 loop
            wait until rising_edge(clk);
        end loop;

        -- Release reset
        async_rst <= '0';

        for i in 0 to 4 loop
            wait until rising_edge(clk);
        end loop;

        -- Apply asynchronous data pattern
        -- Small delay intentionally offsets transitions
        -- from clock edges to emulate asynchronous input.
        for i in 0 to (c_data_frame-1) loop
            wait for 2 ns;
            async_data <= c_packet(i);
            wait for c_bit_period;
        end loop;
        stop;
    end process;

    UUT : entity work.Synchroniser
     generic map(
        G_IDLE_STATE => c_idle_state
    )
     port map(
        I_CLK        => clk,
        I_ASYNC_RST  => async_rst,
        I_ASYNC_DATA => async_data,

        O_SYNC_DATA  => sync_data
    );

end architecture;