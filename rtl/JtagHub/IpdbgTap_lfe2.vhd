library IEEE;
use IEEE.std_logic_1164.all;

-- synopsys translate_off
library ecp2;
use ecp2.components.all;
-- synopsys translate_on

entity IpdbgTap is
    port(
        capture         : out std_logic;
        drclk           : out std_logic;
        user            : out std_logic;
        shift           : out std_logic;
        update          : out std_logic;
        tdi             : out std_logic;
        tdo             : in  std_logic
    );
end entity IpdbgTap;

architecture lfe2 of IpdbgTap is
    component jtagc
        generic(
            ER1             : String  := "ENABLED";
            ER2             : string  := "ENABLED"
        );
        port(
            TCK     : in  std_logic;
            TMS     : in  std_logic;
            TDI     : in  std_logic;
            ITCK    : in  std_logic;
            ITMS    : in  std_logic;
            ITDI    : in  std_logic;
            IJTAGEN : in  std_logic;
            JTDO1   : in  std_logic;
            JTDO2   : in  std_logic;
            TDO     : out std_logic;
            ITDO    : out std_logic;
            JTDI    : out std_logic;
            JTCK    : out std_logic;
            JRTI1   : out std_logic;
            JRTI2   : out std_logic;
            JSHIFT  : out std_logic;
            JUPDATE : out std_logic;
            JRSTN   : out std_logic;
            JCE1    : out std_logic;
            JCE2    : out std_logic
        );
    end component;

    signal UPDATE1        : std_logic;
    signal CAPTURE1       : std_logic;
    signal SHIFT_s        : std_logic;
    signal SHIFT1         : std_logic;
    signal wasInShiftDr1  : std_logic;
    signal SHIFT_lfe      : std_logic;
    signal UPDATE_lfe     : std_logic;
    signal JCE1           : std_logic;
    signal JCE1_lfe       : std_logic;
    
    signal drclk_s        : std_logic;
begin

    JtagcInst: JTAGC
        port map (
            TCK     => '0',
            TMS     => '0',
            TDI     => '0',
            ITCK    => '0',
            ITMS    => '0',
            ITDI    => '0',
            IJTAGEN => '1',
            JTDO1   => tdo,
            JTDO2   => '0',
            TDO     => open,
            ITDO    => open,
            JTDI    => tdi,
            JTCK    => drclk_s,
            JRTI1   => open,
            JRTI2   => open,
            JSHIFT  => SHIFT_lfe,
            JUPDATE => UPDATE_lfe,
            JRSTN   => open,
            JCE1    => JCE1_lfe,
            JCE2    => open
    );
    drclk <= drclk_s;
    process(drclk_s)begin
        if falling_edge(drclk_s) then
            update  <= UPDATE_lfe;
            SHIFT_s <= SHIFT_lfe;
            JCE1    <= JCE1_lfe;
        end if;
    end process;

    SHIFT <= SHIFT_s;
    CAPTURE <= CAPTURE1;
    CAPTURE1 <= JCE1 and (not SHIFT_s);
    SHIFT1 <= JCE1 and SHIFT_s;

    USER <= UPDATE1 or CAPTURE1 or SHIFT1;

    process(drclk_s)begin
        if falling_edge(drclk_s) then
            if SHIFT1 = '1' then
                wasInShiftDr1 <= '1';
            elsif UPDATE_lfe = '1' then
                wasInShiftDr1 <= '0';
            end if;
            if wasInShiftDr1 = '1' then
                UPDATE1 <= UPDATE_lfe;
            else
                UPDATE1 <= '0';
            end if;
        end if;
    end process;

end lfe2;
