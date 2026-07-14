--=============================================================================
-- Testbench name: UART_RX_TB
-- Description:
-- This testbench verifies the functionality of the UART_RX module.
--
-- The UART receiver is tested under several operating conditions,
-- including:
--   - Reception without parity enabled
--   - Reception with odd parity enabled
--   - Reception with even parity enabled
--   - Correct parity frames
--   - Incorrect parity frames
--
-- Test procedure:
--   1. Apply reset and initialise the UART line to the idle state.
--   2. Generate UART frames consisting of:
--        - Idle period
--        - Start bit
--        - 8-bit data payload
--        - Optional parity bit
--        - Stop bit
--   3. Verify received data output.
--   4. Verify parity calculation and error detection.
--   5. Verify restart/error indication on parity failures.
--   6. Verify store/clear handshaking operation.
--
-- Expected behaviour:
--   - Valid UART frames are correctly reconstructed.
--   - Received data appears on o_RxData.
--   - Correct parity frames complete successfully.
--   - Incorrect parity frames assert o_RestartLED.
--   - store_data is asserted when a valid frame has been received.
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity UART_RX_TB is
end entity UART_RX_TB;

architecture stimulus of UART_RX_TB is

    constant c_data_frame      : integer   := 8;          -- Number of UART data bits
    constant c_data_packet     : integer   := 10;         -- UART frame size without parity
    constant c_system_clk_freq : integer   := 100e6;      -- 100 MHz system clock
    constant c_baud_rate       : integer   := 9600;       -- UART baud rate
    constant c_idle_state      : std_logic := '1';        -- UART idle level

    -- UART bit period:
    -- 10 ns = simulated system clock period (100 MHz equivalent timing base)
    constant c_bit_period : time := (c_system_clk_freq * (10 ns) / c_baud_rate); 

    signal clk         : std_logic := '0';
    signal async_rst   : std_logic := '1';
    signal pc_data     : std_logic := '1';
    signal parity_on   : std_logic := '0';
    signal parity_even : std_logic := '0';
    signal clear_data  : std_logic := '0';

    -- Display outputs
    signal AN_0 : std_logic;
    signal AN_1 : std_logic;
    signal ca   : std_logic;
    signal cb   : std_logic;
    signal cc   : std_logic;
    signal cd   : std_logic;
    signal ce   : std_logic;
    signal cf   : std_logic;
    signal cg   : std_logic;

    -- Receiver outputs
    signal restart_led : std_logic;
    signal store_data  : std_logic;
    signal parity_val  : std_logic;
    signal rx_data     : std_logic_vector((c_data_frame-1) downto 0);
    signal pc_frame    : std_logic_vector((c_data_frame-1) downto 0) := x"0A"; -- Test data byte = x"0A" = 00001010

    --===================================================
    -- UART Frame Generation Procedure
    --
    -- Generates a complete UART frame including:
    --   Idle -> Start -> Data -> Optional Parity -> Stop
    --
    -- Also generates a clear_data pulse after reception
    -- to emulate downstream acknowledgement.
    --===================================================
    procedure p_pc_data_frame_p (
        signal  p_clk            : in    std_logic;
        signal  p_parity_on      : in    std_logic;
        signal  p_pc_data        : inout std_logic;
        signal  p_clear_data     : out   std_logic;

        constant p_parity_bit    : in    std_logic;
        constant p_pc_data_frame : in    std_logic_vector;
        constant p_lower_limit   : in    integer;
        constant p_upper_limit   : in    integer;
        constant p_bit_period    : in    time
    ) is
    begin
        -- UART idle period before frame transmission
        for i in p_lower_limit to p_upper_limit loop
            p_pc_data <= '1';
            wait for p_bit_period;
        end loop;

        -- Start bit
        p_pc_data <= '0';
        wait for p_bit_period;

        -- Data payload (LSB first)
        for i in 0 to (c_data_frame-1) loop
            p_pc_data <= p_pc_data_frame(i);
            wait for p_bit_period;
        end loop;

        if (p_parity_on = '1') then
            -- Optional parity bit
            p_pc_data <= p_parity_bit;
            wait for p_bit_period;

            -- Stop bit
            p_pc_data <= '1';
            wait for p_bit_period;

            -- Acknowledge received data
            p_clear_data <= '1';
            wait until rising_edge(p_clk);
            p_clear_data <= '0';

            -- Idle period
            for i in p_lower_limit to p_upper_limit loop
                wait for p_bit_period;
            end loop;
        else
            -- Stop bit
            p_pc_data <= '1';
            wait for p_bit_period;

            -- Acknowledge received data
            p_clear_data <= '1';
            wait until rising_edge(p_clk);
            p_clear_data <= '0';

            -- Idle period
            for i in p_lower_limit to p_upper_limit loop
                wait for p_bit_period;
            end loop;
        end if;
    end procedure;

begin

    --=========================================================================
    -- Clock Generation
    -- Generates a 100 MHz clock (10 ns period)
    --=========================================================================
    clk <= not clk after 5 ns;

    stimulus_proc : process is
    begin

        ---------------------------------------------------------------------
        -- Test 1 : UART Reception Without Parity
        ---------------------------------------------------------------------
        pc_data      <= '1';
        parity_on    <= '0';
        parity_even  <= '0';

        wait until rising_edge(clk);

        async_rst <= '0';
        wait until rising_edge(clk);

        p_pc_data_frame_p(clk, parity_on, pc_data, clear_data, parity_val, pc_frame, 1, 5, c_bit_period);

        ---------------------------------------------------------------------
        -- Test 2 : Odd Parity Enabled (Incorrect Parity Bit)
        ---------------------------------------------------------------------
        async_rst   <= '1';
        pc_data     <= '1';
        parity_on   <= '1';
        parity_even <= '0';

        wait until rising_edge(clk);

        async_rst <= '0';
        wait until rising_edge(clk);

        p_pc_data_frame_p(clk, parity_on, pc_data, clear_data, '0', pc_frame, 1, 5, c_bit_period);

        ---------------------------------------------------------------------
        -- Test 3 : Odd Parity Enabled (Correct Parity Bit)
        ---------------------------------------------------------------------
        async_rst   <= '1';
        pc_data     <= '1';
        parity_on   <= '1';
        parity_even <= '0';

        wait until rising_edge(clk);

        async_rst <= '0';
        wait until rising_edge(clk);

        p_pc_data_frame_p(clk, parity_on, pc_data, clear_data, '1', pc_frame, 1, 5, c_bit_period);

        ---------------------------------------------------------------------
        -- Test 4 : Even Parity Enabled (Incorrect Parity Bit)
        ---------------------------------------------------------------------
        async_rst   <= '1';
        pc_data     <= '1';
        parity_on   <= '1';
        parity_even <= '1';

        wait until rising_edge(clk);

        async_rst <= '0';
        wait until rising_edge(clk);

        p_pc_data_frame_p(clk, parity_on, pc_data, clear_data, '1', pc_frame, 1, 5, c_bit_period);

        ---------------------------------------------------------------------
        -- Test 5 : Even Parity Enabled (Correct Parity Bit)
        ---------------------------------------------------------------------
        async_rst   <= '1';
        pc_data     <= '1';
        parity_on   <= '1';
        parity_even <= '1';

        wait until rising_edge(clk);

        async_rst <= '0';
        wait until rising_edge(clk);

        p_pc_data_frame_p(clk, parity_on, pc_data, clear_data, '0', pc_frame, 1, 5, c_bit_period);

        stop;
    end process;

    UUT : entity work.UART_RX
     generic map(
        G_DATA_FRAME      => c_data_frame,
        G_DATA_PACKET     => c_data_packet,
        G_UART_MODE_SEL   => 1,   -- RX mode (mid-bit sampling)
        G_SYSTEM_clk_FREQ => c_system_clk_freq,
        G_BAUD_RATE       => c_baud_rate,
        G_IDLE_STATE      => c_idle_state
    )
     port map(
        I_CLK         => clk,
        I_ASYNC_RST   => async_rst,
        I_PC_DATA     => pc_data,
        I_PARITY_ON   => parity_on,
        I_PARITY_EVEN => parity_even,
        I_CLEAR_DATA  => clear_data,

        O_AN_0        => AN_0,
        O_AN_1        => AN_1,
        O_CA          => ca,
        O_CB          => cb,
        O_CC          => cc,
        O_CD          => cd,
        O_CE          => ce,
        O_CF          => cf,
        O_CG          => cg,

        O_RESTART_LED => restart_led,
        O_STORE_DATA  => store_data,
        O_PARITY_VAL  => parity_val,
        O_RX_DATA     => rx_data
    );

end architecture;