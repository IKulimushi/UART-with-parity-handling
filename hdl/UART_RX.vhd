--=============================================================================
-- Module name: UART_RX
-- Description:
-- This module implements a complete UART receiver system.
--
-- The receiver accepts asynchronous serial UART data, synchronises it
-- to the system clock domain, detects the UART start bit, samples
-- incoming bits using baud-rate timing, reconstructs the parallel data
-- frame, performs optional parity checking, and outputs the received
-- value to two multiplexed 7-segment displays.
--
-- Internal Structure:
--
--   1. Synchroniser
--        - Synchronises asynchronous UART input
--
--   2. Falling Edge Detector
--        - Detects UART start bit
--
--   3. Baud Clock Generator
--        - Generates UART sampling pulses
--
--   4. Shift Register
--        - Collects serial bits into parallel form
--        - Performs parity validation
--
--   5. State Machine
--        - Controls UART receive operation
--
--   6. 7-Segment Display Drivers
--        - Displays received data
--
-- UART RX Flow:
--
--   Serial Input -> Synchroniser -> Start Bit Detection -> Baud Sampling
--
--   Baud Sampling -> Shift Register -> Parity Check -> Parallel Output + Display
--
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity UART_RX is
    generic (
        ---------------------------------------------------------------------
        -- UART Configuration Parameters
        ---------------------------------------------------------------------
        G_DATA_FRAME      : integer;  -- Number of UART data bits
        G_DATA_PACKET     : integer;  -- UART packet size without parity
        G_UART_MODE_SEL   : integer;  -- UART timing mode selection
        G_SYSTEM_clk_FREQ : integer;  -- System clock frequency
        G_BAUD_RATE       : integer;  -- UART baud rate
        G_IDLE_STATE      : std_logic -- UART idle line state
    );
    port (
        I_CLK         : in  std_logic;
        I_ASYNC_RST   : in  std_logic;
        I_PC_DATA     : in  std_logic; -- Incoming UART serial data
        I_PARITY_ON   : in  std_logic; -- Parity configuration
        I_PARITY_EVEN : in  std_logic;
        I_CLEAR_DATA  : in  std_logic; -- Acknowledgement from UART_TX

        O_AN_0        : out std_logic;
        O_AN_1        : out std_logic;
        O_CA          : out std_logic;
        O_CB          : out std_logic;
        O_CC          : out std_logic;
        O_CD          : out std_logic;
        O_CE          : out std_logic;
        O_CF          : out std_logic;
        O_CG          : out std_logic;
        O_RESTART_LED : out std_logic; -- Indicates parity/reception failure
        O_STORE_DATA  : out std_logic; -- Indicates valid data available
        O_PARITY_VAL  : out std_logic; -- Calculated parity value
        O_RX_DATA     : out std_logic_vector((G_DATA_FRAME-1) downto 0)-- Parallel UART receive data
    );
end entity UART_RX;

architecture rtl of UART_RX is

    constant c_flash_divider : integer   := 2;   -- Clock divider count for display multiplexing
    constant c_flash_speed   : integer   := 1e3; -- Controls display refresh speed
    constant c_active        : std_logic := '1'; -- Active state for display control
    constant c_not_active    : std_logic := '0'; -- Inactive state for display control
    
    signal bin_val : std_logic_vector((G_DATA_FRAME-1) downto 0);-- Binary data used for display
    -------------------------------------------------------------------------
    -- 7-Segment Signals (Digit 1)
    -------------------------------------------------------------------------
    signal ca_1 : std_logic;
    signal cb_1 : std_logic;
    signal cc_1 : std_logic;
    signal cd_1 : std_logic;
    signal ce_1 : std_logic;
    signal cf_1 : std_logic;
    signal cg_1 : std_logic;
    -------------------------------------------------------------------------
    -- 7-Segment Signals (Digit 2)
    -------------------------------------------------------------------------
    signal ca_2 : std_logic;
    signal cb_2 : std_logic;
    signal cc_2 : std_logic;
    signal cd_2 : std_logic;
    signal ce_2 : std_logic;
    signal cf_2 : std_logic;
    signal cg_2 : std_logic;

    signal sync_data       : std_logic; -- Synchronised UART input
    signal start_baud      : std_logic; -- Starts baud clock generation
    signal baud_clk_pulse  : std_logic; -- Baud-rate sampling pulse
    signal rx_ready        : std_logic; -- Indicates complete UART packet received
    signal restart_led     : std_logic; -- Internal parity/reception error signal
    signal clk_count       : integer range 0 to c_flash_speed;-- Display Multiplexing Counter
    signal falling_edge    : std_logic; -- Indicates UART falling edge detected
    signal sync_data_delay : std_logic; -- Delayed synchronised UART input

    type state_type_rx is (
        s_idle,          -- Waiting for UART start bit
        s_collet_data,   -- Sampling incoming UART data
        s_transfer,      -- Holding received data
        s_clear          -- Returning to idle
    );
    signal s_state_rx : state_type_rx;

begin

    -------------------------------------------------------------------------
    -- 7-Segment Display Multiplexing
    -------------------------------------------------------------------------
    -- Alternates between the two display digits using a clock divider.
    -- Only one display digit is active at a time.
    -------------------------------------------------------------------------

    -- enable lower digit
    O_AN_0 <= c_active when (clk_count >= (c_flash_speed / c_flash_divider)) else 
              c_not_active;

    -- enable upper digit
    O_AN_1 <= c_active when (clk_count < (c_flash_speed / c_flash_divider)) else 
              c_not_active;

    O_CA  <= ca_1 when (clk_count >= (c_flash_speed / c_flash_divider)) else 
             ca_2;
    O_CB  <= cb_1 when (clk_count >= (c_flash_speed / c_flash_divider)) else 
             cb_2;
    O_CC  <= cc_1 when (clk_count >= (c_flash_speed / c_flash_divider)) else 
             cc_2;
    O_CD  <= cd_1 when (clk_count >= (c_flash_speed / c_flash_divider)) else 
             cd_2;
    O_CE  <= ce_1 when (clk_count >= (c_flash_speed / c_flash_divider)) else 
             ce_2;
    O_CF  <= cf_1 when (clk_count >= (c_flash_speed / c_flash_divider)) else 
             cf_2;
    O_CG  <= cg_1 when (clk_count >= (c_flash_speed / c_flash_divider)) else 
             cg_2;
    
    O_RESTART_LED <= restart_led;
    
    -------------------------------------------------------------------------
    -- Display Clock Divider Process:
    -- Generates a slower refresh counter used for multiplexing the
    -- 7-segment displays.
    -------------------------------------------------------------------------
    disp_clk_count_proc : process(I_ASYNC_RST, I_CLK)
    begin
        if (I_ASYNC_RST = '1') then
            clk_count <= 0;
        elsif rising_edge(I_CLK) then
            -- Restart counter once maximum value reached
            if (clk_count = (c_flash_speed - 1)) then
                clk_count <= 0;
            else
                clk_count <= clk_count + 1;
            end if;
        end if;
    end process;

    
    falling_edge_dector_proc : process(I_ASYNC_RST, I_CLK)
    begin
        if (I_ASYNC_RST = '1') then
            falling_edge    <= '0';
            sync_data_delay <= G_IDLE_STATE;
        elsif rising_edge(I_CLK) then
            sync_data_delay <= sync_data; -- Delay synchronised UART input
            -- Detect falling edge (start bit)
            if ((sync_data_delay = '1') and (sync_data = '0')) then
                falling_edge <= '1';
            else
                falling_edge <= '0';
            end if;
        end if;
    end process;

    state_machine_proc : process(I_ASYNC_RST, I_CLK)
    begin
        if (I_ASYNC_RST = '1') then
            start_baud   <= '0';
            O_STORE_DATA <= '0';
            s_state_rx   <= s_idle;
        elsif rising_edge(I_CLK) then
            -----------------------------------------------------------------
            -- Clear stored data once TX acknowledges receipt
            -- or parity/reception error occurs
            -----------------------------------------------------------------
            if ((I_CLEAR_DATA = '1') or (restart_led = '1')) then
                O_STORE_DATA <= '0';
            end if;

            case s_state_rx is
                when s_idle =>

                    if (falling_edge = '1') then-- Wait for UART start bit
                        start_baud <= '1';-- Start baud sampling
                        s_state_rx <= s_collet_data;
                    else
                        start_baud <= '0';
                        s_state_rx <= s_idle;
                    end if;

                when s_collet_data =>

                    start_baud <= '0';-- Start signal only needed for one cycle
                    -- UART packet completely received
                    if (rx_ready = '1') then
                        O_STORE_DATA <= '1';-- Indicate valid data available
                        s_state_rx   <= s_transfer;-- Move to transfer state
                    else
                        s_state_rx <= s_collet_data;
                    end if;

                when s_transfer =>

                    -- Wait until TX consumes data or error occurs
                    if ((I_CLEAR_DATA = '1') or (restart_led = '1')) then
                        s_state_rx <= s_clear;
                    else
                        s_state_rx <= s_transfer;
                    end if;

                when s_clear =>

                    s_state_rx <= s_idle;

                when others =>

                    s_state_rx <= s_idle;

            end case;
        end if;
    end process;

    synchroniser_inst : entity work.Synchroniser
    generic map(
        G_IDLE_STATE => G_IDLE_STATE
    )
    port map(
        I_CLK        => I_CLK,
        I_ASYNC_RST  => I_ASYNC_RST or restart_led,-- Reset synchroniser if reception/parity error occurs
        I_ASYNC_DATA => I_PC_DATA,

        O_SYNC_DATA  => sync_data
    );

    shift_register_inst : entity work.Shift_Register
    generic map(
        G_DATA_FRAME    => G_DATA_FRAME,
        G_DATA_PACKET   => G_DATA_PACKET,      -- Packet size without parity
        G_DATA_PACKET_P => (G_DATA_PACKET + 1) -- Packet size with parity
    )
    port map(
        I_CLK             => I_CLK,
        I_ASYNC_RST       => I_ASYNC_RST,
        I_SHIFT_EN        => baud_clk_pulse,    -- Shift data using baud-rate pulses
        I_TX_DATA         => sync_data,        -- Serial UART input
        I_BAUD_START      => start_baud,       -- Indicates start of UART frame
        I_PARITY_ON       => I_PARITY_ON,
        I_PARITY_EVEN     => I_PARITY_EVEN,
        
        O_RESTART_LED     => restart_led,      -- Error indication
        O_PARITY_VAL      => O_PARITY_VAL,     -- Calculated parity value
        O_RX_DATA         => O_RX_DATA,        -- Parallel UART data
        O_RX_DATA_DISPLAY => bin_val           -- Display data
    );

    -------------------------------------------------------------------------
    -- Baud Clock Generator Instance:
    -- Generates baud-rate sampling pulses for UART bit reception.
    -------------------------------------------------------------------------
    baud_clock_generator_inst : entity work.Baud_Clock_Generator
    generic map(
        G_TOTAL_BITS      => G_DATA_PACKET,        -- Packet size without parity
        G_TOTAL_BITS_P    => (G_DATA_PACKET + 1),  -- Packet size with parity
        G_SYSTEM_clk_FREQ => G_SYSTEM_clk_FREQ,
        G_BAUD_RATE       => G_BAUD_RATE,
        G_UART_MODE_SEL   => G_UART_MODE_SEL       -- UART timing mode
    )
    port map(
        I_CLK          => I_CLK,
        I_ASYNC_RST    => I_ASYNC_RST or restart_led,-- Reset baud generator on parity/reception error
        I_START        => start_baud,           -- Start UART sampling
        I_PARITY_ON    => I_PARITY_ON,          -- Parity configuration

        O_BAUD_clk_OUT => baud_clk_pulse,        -- Baud-rate sample pulse
        O_READY        => rx_ready              -- Indicates UART frame complete
    );

    -------------------------------------------------------------------------
    -- 7-Segment Display Instance (Lower Digit)
    -------------------------------------------------------------------------
    seven_segment_units_inst : entity work.Seven_Segment
    port map(
        I_BIN_NUM => bin_val(((G_DATA_FRAME / 2)-1) downto 0),

        O_CA => ca_1,
        O_CB => cb_1,
        O_CC => cc_1,
        O_CD => cd_1,
        O_CE => ce_1,
        O_CF => cf_1,
        O_CG => cg_1
    );

    -------------------------------------------------------------------------
    -- 7-Segment Display Instance (Upper Digit)
    -------------------------------------------------------------------------
    seven_segment_tens_inst : entity work.Seven_Segment
    port map(
        I_BIN_NUM => bin_val((G_DATA_FRAME-1) downto (G_DATA_FRAME / 2)),

        O_CA => ca_2,
        O_CB => cb_2,
        O_CC => cc_2,
        O_CD => cd_2,
        O_CE => ce_2,
        O_CF => cf_2,
        O_CG => cg_2
    );

end architecture;