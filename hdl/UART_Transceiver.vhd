--=============================================================================
-- Module name: Uart_Transceiver
-- Description:
-- This module implements a complete UART transceiver system by combining
-- both UART receiver (UART_RX) and UART transmitter (UART_TX) modules.
--
-- The receiver accepts serial UART data, converts it into parallel data,
-- performs optional parity checking, and displays the received value on
-- two 7-segment displays.
--
-- The received data is then passed directly to the transmitter module,
-- which serialises the data and retransmits it through the TX line.
--
-- Overall data flow:
--
--   UART RX Serial Input -> UART_RX -> Parallel Data + Parity -> UART_TX
--
--   UART_RX -> UART TX Serial Output
--
-- Key Features:
-- - Full UART receiver and transmitter integration
-- - Optional odd/even parity support
-- - Internal handshake control between RX and TX
-- - Real-time 7-segment display output
-- - Loopback-style UART communication
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Uart_Transceiver is
    generic (
        G_DATA_FRAME      : integer;  -- Number of UART data bits
        G_DATA_PACKET     : integer;  -- Total UART packet size
        G_SYSTEM_clk_FREQ : integer;  -- FPGA/system clock frequency
        G_BAUD_RATE       : integer;  -- UART baud rate
        G_IDLE_STATE      : std_logic -- UART idle state (normally '1')
    );
    port (
        I_CLK         : in  std_logic; -- System clock
        I_ASYNC_RST   : in  std_logic; -- Asynchronous reset
        I_PC_DATA     : in  std_logic; -- Incoming UART serial data
        I_PARITY_ON   : in  std_logic; -- Enables parity checking
        I_PARITY_EVEN : in  std_logic; -- '1' = even parity, '0' = odd parity

        O_AN_0        : out std_logic;
        O_AN_1        : out std_logic;
        O_CA          : out std_logic;
        O_CB          : out std_logic;
        O_CC          : out std_logic;
        O_CD          : out std_logic;
        O_CE          : out std_logic;
        O_CF          : out std_logic;
        O_CG          : out std_logic;
        O_RESTART_LED : out std_logic; -- Indicates parity or reception failure
        O_TX_DATA     : out std_logic  -- UART transmit serial output
    );
end entity Uart_Transceiver;

architecture rtl of Uart_Transceiver is
    
    signal parity_val     : std_logic; -- Parity value calculated by the receiver
    signal store_data     : std_logic; -- RX asserts when valid data is ready for transmission
    signal clear_data     : std_logic; -- TX asserts when transmitted data has been consumed
    signal rx_data_packet : std_logic_vector((G_DATA_FRAME-1) downto 0); -- Parallel data transferred between RX and TX

begin

    uart_rx_inst : entity work.UART_RX
    generic map(
        G_DATA_FRAME      => G_DATA_FRAME,
        G_DATA_PACKET     => G_DATA_PACKET,
        G_UART_MODE_SEL   => 1, -- RX operating mode: typically enables mid-bit sampling behaviour
        G_SYSTEM_clk_FREQ => G_SYSTEM_clk_FREQ,
        G_BAUD_RATE       => G_BAUD_RATE,
        G_IDLE_STATE      => G_IDLE_STATE
    )
    port map(
        I_CLK         => I_CLK,
        I_ASYNC_RST   => I_ASYNC_RST,
        I_PC_DATA     => I_PC_DATA,
        I_PARITY_ON   => I_PARITY_ON,
        I_PARITY_EVEN => I_PARITY_EVEN,
        I_CLEAR_DATA  => clear_data,     -- TX acknowledges that RX data has been transmitted

        O_AN_0        => O_AN_0,       
        O_AN_1        => O_AN_1,       
        O_CA          => O_CA,
        O_CB          => O_CB,
        O_CC          => O_CC,
        O_CD          => O_CD,
        O_CE          => O_CE,
        O_CF          => O_CF,
        O_CG          => O_CG,
        O_RESTART_LED => O_RESTART_LED,  -- Indicates parity/reception error
        O_STORE_DATA  => store_data,     -- Signals transmitter that valid data is available
        O_PARITY_VAL  => parity_val,     -- Calculated parity value
        O_RX_DATA     => rx_data_packet  -- Received parallel data
    );

    uart_tx_inst : entity work.UART_TX
    generic map(
        G_DATA_FRAME      => G_DATA_FRAME,
        G_DATA_PACKET     => G_DATA_PACKET,
        G_UART_MODE_SEL   => 0, -- TX operating mode
        G_SYSTEM_clk_FREQ => G_SYSTEM_clk_FREQ,
        G_BAUD_RATE       => G_BAUD_RATE,
        G_IDLE_STATE      => G_IDLE_STATE
    )
    port map(
        I_CLK        => I_CLK,
        I_ASYNC_RST  => I_ASYNC_RST,
        I_RX_DATA    => rx_data_packet, -- Parallel data received from UART_RX
        I_PARITY_ON  => I_PARITY_ON,
        I_PARITY_VAL => parity_val,     -- Calculated parity bit from receiver
        I_STORE_DATA => store_data,     -- RX indicates valid data is available

        O_CLEAR_DATA => clear_data,     -- TX indicates transmission/data consumption complete
        O_TX_DATA    => O_TX_DATA       -- UART serial output
    );

end architecture;