--=============================================================================
-- Module name: Synchroniser
-- Description:
-- This module implements a 2-stage synchroniser used to safely transfer
-- an asynchronous signal into the local system clock domain.
--
-- External asynchronous signals (such as UART RX data) can cause
-- metastability if sampled directly by synchronous logic. To minimise
-- this risk, the input signal is passed through two sequential flip-flops.
--
-- Synchronisation stages:
--   1. First flip-flop captures the asynchronous input
--   2. Second flip-flop outputs a stabilised synchronous signal
--
-- This design is commonly used in UART receivers and FPGA designs when
-- interfacing external signals with synchronous logic.
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Synchroniser is
    generic(
        G_IDLE_STATE : std_logic  -- Default/reset value of synchronised output
    );
    port (
        I_CLK        : in  std_logic; -- System clock
        I_ASYNC_RST  : in  std_logic; -- Active-high asynchronous reset
        I_ASYNC_DATA : in  std_logic; -- External asynchronous input signal

        O_SYNC_DATA  : out std_logic -- Stable synchronised output signal
    );
end entity Synchroniser;

architecture rtl of Synchroniser is

    signal sync_data     : std_logic; -- First synchronisation stage
    signal sync_data_out : std_logic; -- Second synchronisation stage (final stable output)

begin
    O_SYNC_DATA <= sync_data_out;

    sync_data_proc : process(I_ASYNC_RST, I_CLK)
    begin
        if (I_ASYNC_RST = '1') then
            sync_data     <= G_IDLE_STATE;
            sync_data_out <= G_IDLE_STATE;
        elsif rising_edge(I_CLK) then
            sync_data     <= I_ASYNC_DATA;
            sync_data_out <= sync_data;
        end if;
    end process;

end architecture;