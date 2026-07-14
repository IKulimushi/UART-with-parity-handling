--=============================================================================
-- Module name: UART_TX
-- Description:
-- This module implements the UART transmitter section of the UART
-- transceiver system.
--
-- The transmitter accepts parallel data from the receiver, optionally
-- appends a parity bit, serialises the complete UART frame, and transmits
-- the data using a baud-rate controlled shift operation.
--
-- UART frame format:
--
--   Without parity:
--      Start Bit + Data Bits + Stop Bit
--
--   With parity:
--      Start Bit + Data Bits + Parity Bit + Stop Bit
--
-- Main Features:
-- - Parallel-to-serial UART conversion
-- - Optional odd/even parity support
-- - Baud-rate controlled transmission
-- - Internal transmission state machine
-- - Automatic RX/TX handshake support
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity UART_TX is
    generic (
        G_DATA_FRAME      : integer;  -- Number of UART data bits
        G_DATA_PACKET     : integer;  -- UART packet size without parity
        G_UART_MODE_SEL   : integer;  -- UART timing mode selection
        G_SYSTEM_clk_FREQ : integer;  -- System clock frequency
        G_BAUD_RATE       : integer;  -- UART baud rate
        G_IDLE_STATE      : std_logic -- UART idle state (normally '1')
    );
    port (
        I_CLK        : in  std_logic; -- System clock
        I_ASYNC_RST  : in  std_logic; -- Asynchronous reset
        I_RX_DATA    : in  std_logic_vector((G_DATA_FRAME-1) downto 0); -- Parallel data received from UART_RX
        I_PARITY_ON  : in  std_logic;
        I_PARITY_VAL : in  std_logic;
        I_STORE_DATA : in  std_logic; -- Indicates valid data is ready for transmission

        O_CLEAR_DATA : out std_logic; -- Acknowledges that TX has consumed the RX data
        O_TX_DATA    : out std_logic  -- UART serial transmit output
    );
end entity UART_TX;

architecture rtl of UART_TX is

    signal baud_clk_pulse   : std_logic; -- Baud-rate pulse used to shift serial data
    signal tx_ready         : std_logic; -- Indicates UART transmission complete
    signal rx_data_packet   : std_logic_vector((G_DATA_PACKET-1) downto 0); -- UART frame without parity: stop bit + data bits + start bit
    signal rx_data_packet_p : std_logic_vector(G_DATA_PACKET downto 0);   -- UART frame with parity: stop bit + parity + data bits + start bit
    
    type state_type_tx is (
        s_idle,     -- Waiting for valid data
        s_serialise -- Serialising/transmitting UART frame
    );
    signal s_state_tx : state_type_tx;

begin
    -- UART frame without parity enabled
    rx_data_packet <= ('1' & I_RX_DATA & '0') when (I_PARITY_ON = '0') else 
                      (others => '1');

    -- UART frame with parity enabled
    rx_data_packet_p <= ('1' & I_PARITY_VAL & I_RX_DATA & '0') when (I_PARITY_ON = '1') else 
                        (others => '1');
    
    state_machine_proc : process(I_ASYNC_RST, I_CLK)
    begin
        if (I_ASYNC_RST = '1') then
            s_state_tx <= s_idle;
        elsif rising_edge(I_CLK) then
            case s_state_tx is
                when s_idle =>

                    -- Wait for RX module to provide valid data
                    if (I_STORE_DATA = '1') then
                        s_state_tx <= s_serialise;
                    else
                        s_state_tx <= s_idle;
                    end if;

                when s_serialise =>

                    -- Return to idle once UART transmission is complete
                    if (tx_ready = '1') then
                        s_state_tx <= s_idle;
                    else
                        s_state_tx <= s_serialise;
                    end if;

                when others =>

                    s_state_tx <= s_idle;
                    
            end case;
        end if;
    end process;

    serializer_inst : entity work.Serializer
    generic map(
        G_UART_WIDTH => G_DATA_PACKET,
        G_UART_STATE => G_IDLE_STATE
    )
    port map(
        I_CLK        => I_CLK,
        I_ASYNC_RST  => I_ASYNC_RST,
        I_TX_DATA    => rx_data_packet,  -- UART packet without parity
        I_TX_DATA_P  => rx_data_packet_p, -- UART packet with parity
        I_SHIFT_EN   => baud_clk_pulse,  -- Shift enable from baud generator
        I_STORE_DATA => I_STORE_DATA,  -- Load new UART frame into serializer
        I_PARITY_ON  => I_PARITY_ON,   -- Select parity mode

        O_TX_DATA    => O_TX_DATA,    -- UART serial transmit output
        O_CLEAR_DATA => O_CLEAR_DATA  -- Indicates TX has consumed the RX data
    );

    baud_clock_generator_inst : entity work.Baud_Clock_Generator
    generic map(
        G_TOTAL_BITS      => G_DATA_PACKET,       -- Total UART bits without parity
        G_TOTAL_BITS_P    => (G_DATA_PACKET + 1), -- Total UART bits with parity enabled
        G_SYSTEM_clk_FREQ => G_SYSTEM_clk_FREQ,
        G_BAUD_RATE       => G_BAUD_RATE,
        G_UART_MODE_SEL   => G_UART_MODE_SEL     -- UART operating mode
    )
    port map(
        I_CLK          => I_CLK,
        I_ASYNC_RST    => I_ASYNC_RST,
        I_START        => I_STORE_DATA, -- Starts baud pulse generation
        I_PARITY_ON    => I_PARITY_ON,  -- Select parity mode

        O_BAUD_clk_OUT => baud_clk_pulse, -- Baud-rate shift pulse
        O_READY        => tx_ready       -- Indicates UART transmission complete
    );

end architecture;