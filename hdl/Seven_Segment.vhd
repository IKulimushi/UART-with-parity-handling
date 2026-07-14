--=============================================================================
-- Module name: Seven_Segment
-- Description:
-- This module converts a 4-bit binary input into the corresponding
-- 7-segment display pattern.
--
-- The module is intended for driving a single hexadecimal-style
-- 7-segment display digit.
--
-- Each output controls one segment of the display:
--   o_CA -> Segment A
--   o_CB -> Segment B
--   o_CC -> Segment C
--   o_CD -> Segment D
--   o_CE -> Segment E
--   o_CF -> Segment F
--   o_CG -> Segment G
--
-- The module currently supports decimal values 0–9.
-- Any undefined input value displays a fallback pattern.
--
-- NOTE:
-- Segment encoding assumes a common-anode display:
--   '0' = segment ON
--   '1' = segment OFF
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Seven_Segment is
    port (
        I_BIN_NUM : in  std_logic_vector(3 downto 0); -- 4-bit binary input
        
        O_CA      : out std_logic; -- Segment A
        O_CB      : out std_logic; -- Segment B
        O_CC      : out std_logic; -- Segment C
        O_CD      : out std_logic; -- Segment D
        O_CE      : out std_logic; -- Segment E
        O_CF      : out std_logic; -- Segment F
        O_CG      : out std_logic  -- Segment G
    );
end entity Seven_Segment;

architecture rtl of Seven_Segment is
    
    signal seg_val : std_logic_vector(6 downto 0); -- Internal signal storing the full 7-segment pattern

begin
    -- Encoding format:
    --   '0' = segment ON
    --   '1' = segment OFF

    O_CA <= seg_val(6);
    O_CB <= seg_val(5);
    O_CC <= seg_val(4);
    O_CD <= seg_val(3);
    O_CE <= seg_val(2);
    O_CF <= seg_val(1);
    O_CG <= seg_val(0);

    BCD_to_7Seg_PROC : process(I_BIN_NUM)
    begin
        case I_BIN_NUM is
            when "0000" => seg_val <= "0000001"; -- Decimal 0
            when "0001" => seg_val <= "1001111"; -- Decimal 1
            when "0010" => seg_val <= "0010010"; -- Decimal 2
            when "0011" => seg_val <= "0000110"; -- Decimal 3
            when "0100" => seg_val <= "1001100"; -- Decimal 4
            when "0101" => seg_val <= "0100100"; -- Decimal 5
            when "0110" => seg_val <= "0100000"; -- Decimal 6
            when "0111" => seg_val <= "0001111"; -- Decimal 7
            when "1000" => seg_val <= "0000000"; -- Decimal 8
            when "1001" => seg_val <= "0001100"; -- Decimal 9
            when others => seg_val <= "0110000"; -- Displays fallback pattern (E-like shape)
        end case;
    end process;

end architecture;