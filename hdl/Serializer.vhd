--=============================================================================
-- Module name: Serializer
-- Description:
-- This module implements a UART transmit serializer.
--
-- It converts parallel UART frame data into a serial bitstream by loading
-- data into an internal shift register and shifting the data out one bit
-- at a time.
--
-- The serializer supports:
--   - Standard UART frames (start + data + stop bits)
--   - UART frames with parity enabled
--
-- Two separate shift registers are used:
--   shift_reg   -> UART transmission without parity
--   shift_reg_p  -> UART transmission with parity
--
-- UART transmission format:
--   - Data is transmitted LSB first
--   - Idle line state is maintained by shifting in logic '1'
--
-- Key features:
-- - Parallel-to-serial conversion
-- - Optional parity support
-- - Shift enable control
-- - Data load control
-- - Asynchronous reset support
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Serializer is
    generic(
        G_UART_WIDTH : integer;  -- Width of UART frame data
        G_UART_STATE : std_logic -- UART idle state (normally '1')
    );
    port (
        I_CLK        : in  std_logic; -- System clock
        I_ASYNC_RST  : in  std_logic; -- Asynchronous reset (active high)
        I_TX_DATA    : in  std_logic_vector((G_UART_WIDTH-1) downto 0); -- Frame without parity
        I_TX_DATA_P  : in  std_logic_vector(G_UART_WIDTH downto 0);   -- Frame with parity
        I_SHIFT_EN   : in  std_logic; -- Enables shifting operation
        I_STORE_DATA : in  std_logic; -- Loads parallel data into shift register
        I_PARITY_ON  : in  std_logic; -- Selects parity mode

        O_TX_DATA    : out std_logic;-- Serial UART output
        O_CLEAR_DATA : out std_logic-- Handshake output
    );
end entity Serializer;

architecture rtl of Serializer is

    signal shift_reg   : std_logic_vector(I_TX_DATA'range);-- shift_reg  : Used when parity is disabled
    signal shift_reg_p : std_logic_vector(I_TX_DATA_P'range);-- shift_reg_p : Used when parity is enabled

begin
    O_TX_DATA    <= shift_reg_p(0) when (I_PARITY_ON = '1') else 
                    shift_reg(0);

    -- ClearData handshake signal
    -- Asserted whenever new data is loaded into the serializer
    -- Used by upstream modules to indicate data has been accepted
    O_CLEAR_DATA <= '1' when (I_STORE_DATA = '1') else 
                    '0';

    shift_PROC : process(I_ASYNC_RST, I_CLK)
    begin
        if (I_ASYNC_RST = '1') then
            -- Reset shift registers to idle state
            shift_reg   <= (others => G_UART_STATE);
            shift_reg_p <= (others => G_UART_STATE);
        elsif rising_edge(I_CLK) then
            if (I_PARITY_ON = '1') then
                -- Load new UART frame into shift register
                if (I_STORE_DATA = '1') then
                    shift_reg_p <= I_TX_DATA_P;
                -- Shift data out serially
                elsif (I_SHIFT_EN = '1') then
                    -- Shift right and insert idle state at MSB
                    shift_reg_p <= '1' & shift_reg_p(shift_reg_p'left downto 1);
                end if;
            else
                -- Load new UART frame into shift register
                if (I_STORE_DATA = '1') then
                    shift_reg <= I_TX_DATA;
                elsif (I_SHIFT_EN = '1') then
                    shift_reg <= G_UART_STATE & shift_reg(shift_reg'left downto 1);-- Shift right and insert idle state at MSB
                end if;
            end if;
        end if;
    end process;

end architecture;