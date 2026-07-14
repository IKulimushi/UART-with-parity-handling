--=============================================================================
-- Module name: Baud_Clock_Generator
-- Description:
-- This module generates baud-rate timing pulses for UART transmission
-- and reception.
--
-- The module divides the incoming system clock down to the required
-- UART baud rate and produces a single-cycle pulse once per UART bit
-- period.
--
-- It also tracks the number of bits remaining in the current UART frame
-- and indicates when the transmission/reception process is complete.
--
-- Supported functionality:
--   - Configurable baud rate generation
--   - UART TX and RX timing support
--   - Optional parity frame support
--   - Ready signal generation
--   - Mid-bit sampling support for UART RX mode
--
-- UART RX mode:
--   When G_UART_MODE_SEL = 1, the internal counter starts at half of the
--   bit period during idle operation. This allows sampling to occur in
--   the middle of each received bit, improving UART reception accuracy.
--
-- Key features:
-- - Configurable system clock and baud rate
-- - Bit-period pulse generation
-- - Bit counting for complete UART frames
-- - Optional parity support
-- - Ready indication when transfer completes
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Baud_Clock_Generator is
    generic (
        G_TOTAL_BITS      : integer; -- Total bits without parity
        G_TOTAL_BITS_P    : integer; -- Total bits with parity
        G_SYSTEM_clk_FREQ : integer; -- System clock frequency (Hz)
        G_BAUD_RATE       : integer; -- UART baud rate
        G_UART_MODE_SEL   : integer  -- Mode selection (0 = TX, 1 = RX)
    );
    port (
        I_CLK          : in  std_logic; -- System clock
        I_ASYNC_RST    : in  std_logic; -- Asynchronous reset (active high)
        I_START        : in  std_logic; -- Starts baud timing process
        I_PARITY_ON    : in  std_logic; -- Enables parity mode

        O_BAUD_clk_OUT : out std_logic; -- Single-cycle baud pulse
        O_READY        : out std_logic  -- Indicates transfer complete
    );
end entity Baud_Clock_Generator;

architecture rtl of Baud_Clock_Generator is

    --=========================================================================
    -- Number of system clock cycles required for one UART bit period
    -- Example:
    --   10 MHz clock / 9600 baud ≈ 1041 clock cycles per UART bit
    --=========================================================================
    constant c_bit_period   : integer := (G_SYSTEM_clk_FREQ / G_BAUD_RATE);

    signal bit_period_count : integer range 0 to c_bit_period;-- Counts system clock cycles within one UART bit period
    signal bits_left        : integer range 0 to c_bit_period;-- Tracks remaining bits left to transmit/receive
    signal baud_clk_out     : std_logic;-- Internal baud pulse signal

begin
    O_BAUD_clk_OUT <= baud_clk_out;-- Output baud-rate pulse
    O_READY        <= '1' when ((bits_left = 0) and (I_START = '0')) else 
                      '0';

    bit_transfer_proc : process(I_ASYNC_RST, I_CLK)
    begin
        if (I_ASYNC_RST = '1') then
            bits_left <= 0;
        elsif rising_edge(I_CLK) then
            if (I_PARITY_ON = '1') then
                -- Start new UART frame
                if (I_START = '1') then
                    bits_left <= G_TOTAL_BITS_P;-- Load total frame size including parity bit
                elsif (baud_clk_out = '1') then
                    bits_left <= bits_left - 1;
                end if;
            else
                if (I_START = '1') then-- Start new UART frame
                    bits_left <= G_TOTAL_BITS;-- Load total frame size without parity
                elsif (baud_clk_out = '1') then
                    bits_left <= bits_left - 1;
                end if;
            end if;
        end if;
    end process;

    bit_period_count_proc : process(I_ASYNC_RST, I_CLK)
    begin
        if (I_ASYNC_RST = '1') then
            bit_period_count <= 0;
            baud_clk_out     <= '0';
        elsif rising_edge(I_CLK) then
            --=============================================================
            -- Active UART Transmission / Reception
            --=============================================================
            if (bits_left > 0) then
                if (bit_period_count = c_bit_period) then
                    baud_clk_out     <= '1';
                    bit_period_count <= 0;
                else
                    baud_clk_out     <= '0';
                    bit_period_count <= bit_period_count + 1;

                end if;
            else
                -- UART RX mode:
                -- Initialise counter to half bit period
                -- so sampling occurs in the middle of the bit
                if (G_UART_MODE_SEL = 1) then
                    bit_period_count <= (c_bit_period / 2);
                -- UART TX mode:
                -- Reset counter to beginning of bit period
                else
                    bit_period_count <= 0;
                end if;
            end if;
        end if;
    end process;

end architecture;