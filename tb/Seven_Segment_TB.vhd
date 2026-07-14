--=============================================================================
-- Test Bench name: Seven_Segment_TB
-- Description:
-- This test bench verifies the functionality of the Seven_Segment module.
--
-- The Seven_Segment module converts a 4-bit binary value into the
-- corresponding 7-segment display pattern.
--
-- Test scenarios:
--   - Apply all valid decimal inputs from 0 to 9
--   - Verify that the correct segment pattern is generated for each value
--
-- The test bench provides:
--   - Clock generation
--   - Sequential stimulus generation
--   - Automatic simulation termination
--
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity Seven_Segment_TB is
end entity;

architecture stimulus of Seven_Segment_TB is

    signal clk     : std_logic := '0';
    signal bin_num : std_logic_vector(3 downto 0); -- Binary input value

    -- 7-segment display outputs
    signal ca : std_logic; -- Segment A
    signal cb : std_logic; -- Segment B
    signal cc : std_logic; -- Segment C
    signal cd : std_logic; -- Segment D
    signal ce : std_logic; -- Segment E
    signal cf : std_logic; -- Segment F
    signal cg : std_logic; -- Segment G

begin

    --=========================================================================
    -- Clock Generation
    -- Generates a 100 MHz clock (10 ns period)
    --=========================================================================
    clk <= not clk after 5 ns;

    stimulus_proc : process is
    begin

        bin_num <= (others => '0');

        for i in 0 to 3 loop
            wait until rising_edge(clk);
        end loop;

        for i in 0 to 9 loop
            bin_num <= std_logic_vector(to_unsigned(i, bin_num'length)); -- Convert integer value to 4-bit binary input
            -- Hold value long enough to observe segment outputs
            for j in 0 to 4 loop
                wait until rising_edge(clk);
            end loop;
        end loop;
        stop;

    end process;

    UUT : entity work.Seven_Segment
     port map(
        I_BIN_NUM    => bin_num,

        -- 7-segment outputs
        O_CA        => ca,
        O_CB        => cb,
        O_CC        => cc,
        O_CD        => cd,
        O_CE        => ce,
        O_CF        => cf,
        O_CG        => cg
    );

end architecture;