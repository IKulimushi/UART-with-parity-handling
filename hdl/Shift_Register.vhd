--=============================================================================
-- Module name: Shift_Register
-- Description:
-- This module implements a UART receive shift register with integrated
-- parity checking and data extraction.
--
-- The module converts incoming serial UART data into parallel data by
-- shifting each received bit into an internal register.
--
-- Once a full UART frame has been received, the module:
--   - Extracts the valid data bits
--   - Calculates parity (optional)
--   - Verifies received parity bit
--   - Outputs valid data or an error pattern
--
-- If a parity error occurs:
--   - A restart/error signal is asserted
--   - A predefined failure pattern is output
--
-- Key features:
-- - Serial-to-parallel conversion
-- - Configurable packet sizes
-- - Optional even/odd parity checking
-- - Error detection and restart signalling
-- - Separate display output support
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Shift_Register is
    generic(
        G_DATA_FRAME      : integer; -- Number of valid data bits (e.g. 8-bit data)
        G_DATA_PACKET     : integer; -- Packet size without parity
        G_DATA_PACKET_P   : integer  -- Packet size with parity
    );
    port (
        I_CLK             : in  std_logic; -- System clock
        I_ASYNC_RST       : in  std_logic; -- Active-high asynchronous reset
        I_SHIFT_EN        : in  std_logic; -- Shift enable pulse from baud generator
        I_TX_DATA         : in  std_logic; -- Incoming serial UART data
        I_BAUD_START      : in  std_logic; -- Indicates start of new UART frame
        I_PARITY_ON       : in  std_logic; -- Enables parity checking
        I_PARITY_EVEN     : in  std_logic; -- '1' = even parity, '0' = odd parity

        O_RESTART_LED     : out std_logic; -- Asserted on parity failure
        O_PARITY_VAL      : out std_logic; -- Calculated parity value
        O_RX_DATA         : out std_logic_vector((G_DATA_FRAME-1) downto 0); -- Received parallel data
        O_RX_DATA_DISPLAY : out std_logic_vector((G_DATA_FRAME-1) downto 0)  -- Data for 7-segment display
    );
end Shift_Register;

architecture rtl of Shift_Register is

    --=========================================================================
    -- UART Packet Format Examples
    --=========================================================================
    -- With parity (11 bits total):
    --  start | d0 | d1 | d2 | d3 | d4 | d5 | d6 | d7 | parity | stop
    --
    -- Without parity (10 bits total):
    --  start | d0 | d1 | d2 | d3 | d4 | d5 | d6 | d7 | stop
    --=========================================================================

    signal shift_reg        : std_logic_vector((G_DATA_PACKET-1) downto 0);              -- Shift register without parity
    signal shift_reg_p      : std_logic_vector((G_DATA_PACKET_P-1) downto 0);            -- Shift register with parity
    signal rx_shift_reg     : std_logic_vector((G_DATA_FRAME-1) downto 0);               -- Extracted received data
    signal data_frame_of_sr : std_logic_vector((G_DATA_FRAME-1) downto 0);               -- Data frame used for parity calculations
    signal rx_disp          : std_logic_vector((G_DATA_FRAME-1) downto 0);               -- Data used for display output
    signal fail             : std_logic_vector((G_DATA_FRAME-1) downto 0) := "01000101"; -- Error pattern output ("E")
    signal fail_disp        : std_logic_vector((G_DATA_FRAME-1) downto 0) := "11101110"; -- Error display pattern
    signal shift_count      : integer                                     := 0;          -- Counts number of shifted UART bits
    
    -- Calculated parity signals
    signal odd_p            : std_logic;
    signal even_p           : std_logic;
    signal restart_state    : std_logic; -- Restart/error flag

    --=========================================================================
    -- Procedure: p_parity_checking
    --=========================================================================
    -- Compares received parity bit with calculated parity value.
    --
    -- If parity fails:
    --   - Restart signal is asserted
    --
    -- If parity passes:
    --   - Restart signal remains low
    --=========================================================================
    procedure p_parity_checking (
        constant p_parity_even_or_odd : in  std_logic;
        constant p_vector_bit_val     : in  std_logic;

        signal p_restart_state        : out std_logic
    ) is
    begin
        -- Check if received parity bit matches calculated parity
        if (p_vector_bit_val = p_parity_even_or_odd) then
            p_restart_state <= '0'; -- Valid parity
        else
            p_restart_state <= '1'; -- Parity error detected
        end if;
    end procedure;

    --=========================================================================
    -- Procedure: p_succesful_rx
    --=========================================================================
    -- Extracts valid data bits from the shift register once a full
    -- UART frame has been received.
    --=========================================================================
    procedure p_succesful_rx (
        constant p_data_packet : in  integer;
        constant p_data_frame  : in  integer;
 
        signal p_shift_count   : in  integer;
        signal p_shift_reg     : in  std_logic_vector;

        signal p_rx_shift_reg  : out std_logic_vector;
        signal p_rx_disp       : out std_logic_vector
    ) is
    begin
        --------------------------------------------------------------------------
        if (p_shift_count = p_data_packet) then -- Full UART frame received
            p_rx_shift_reg <= p_shift_reg(p_data_frame downto 1); -- Extract only valid data bits
            p_rx_disp      <= p_shift_reg(p_data_frame downto 1); -- Copy same value for display output
        end if;
    end procedure;

begin

    O_RESTART_LED <= restart_state;-- Restart signal asserted when parity check fails
    
    -- Output currently calculated parity value
    O_PARITY_VAL <= even_p when ((I_PARITY_ON = '1') and (I_PARITY_EVEN = '1')) else 
                    odd_p;
    
    -- Output valid data or failure pattern
    O_RX_DATA <= rx_shift_reg when (restart_state = '0') else 
                 fail         when (restart_state = '1') else 
                 (others => '1');
    
    -- Output display data or display failure pattern
    O_RX_DATA_DISPLAY <= rx_disp   when (restart_state = '0') else 
                         fail_disp when (restart_state = '1') else 
                         (others => '1');

    data_frame_of_sr <= shift_reg_p(G_DATA_FRAME downto 1);-- Extract data frame for parity calculation
    even_p           <= xor (data_frame_of_sr);   -- Even parity = XOR of all data bits
    odd_p            <= not (even_p);             -- Odd parity = inverse of even parity

    shift_counter_proc : process(I_ASYNC_RST, I_CLK)
    begin
        if (I_ASYNC_RST = '1') then
            shift_count <= 0;
        elsif rising_edge(I_CLK) then
            -- Reset counter at beginning/end of frame
            if (I_BAUD_START = '1') or ((shift_count = G_DATA_PACKET) and (I_PARITY_ON = '0')) or ((shift_count = G_DATA_PACKET_P) and (I_PARITY_ON = '1')) then
                shift_count <= 0;
            -- Increment count for each received bit
            elsif (I_SHIFT_EN = '1') then
                shift_count <= shift_count + 1;
            end if;
        end if;
    end process;

    shifting_proc : process(I_ASYNC_RST, I_CLK)
    begin
        if (I_ASYNC_RST = '1') then
            shift_reg   <= (others => '1');
            shift_reg_p <= (others => '1');
        elsif rising_edge(I_CLK) then
            if (I_PARITY_ON = '1') then
                if (I_SHIFT_EN = '1') then
                    shift_reg_p <= I_TX_DATA & shift_reg_p(shift_reg_p'left downto 1);-- Shift received serial bit into parity register
                end if;
            else
                if (I_SHIFT_EN = '1') then
                    shift_reg <= I_TX_DATA & shift_reg(shift_reg'left downto 1);-- Shift received serial bit into normal register
                end if;
            end if;
        end if;
    end process;

    parity_checking_proc : process(I_ASYNC_RST, I_CLK)
    begin
        if (I_ASYNC_RST = '1') then
            rx_shift_reg  <= (others => '0');
            rx_disp       <= (others => '0');
            restart_state <= '0';
        elsif rising_edge(I_CLK) then
            if (I_PARITY_ON = '1') then
                p_succesful_rx(G_DATA_PACKET_P, G_DATA_FRAME, shift_count, shift_reg_p, rx_shift_reg, rx_disp);
                -- Perform parity check before final stop bit
                if (shift_count = (G_DATA_PACKET_P-1)) then
                    -- Even parity mode
                    if (I_PARITY_EVEN = '1') then
                        p_parity_checking(even_p, shift_reg_p((G_DATA_PACKET_P-1)), restart_state);
                    -- Odd parity mode
                    else
                        p_parity_checking(odd_p, shift_reg_p((G_DATA_PACKET_P-1)), restart_state);
                    end if;
                end if;
            else
                p_succesful_rx(G_DATA_PACKET, G_DATA_FRAME, shift_count, shift_reg, rx_shift_reg, rx_disp);
            end if;
        end if;
    end process;

end architecture;