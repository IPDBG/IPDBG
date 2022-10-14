library ieee;
use ieee.std_logic_1164.all;

-- synopsys translate_off
library ecp2;
use ecp2.components.all;
-- synopsys translate_on

entity IpdbgTap is
    port(
		TCK     : in  std_logic;
		TMS     : in  std_logic;
		TDI     : in  std_logic;
		TDO     : out std_logic;
        capture : out std_logic;
        drclk   : out std_logic;
        user    : out std_logic;
        shift   : out std_logic;
        update  : out std_logic;
        tdi_o   : out std_logic;
        tdo_i   : in  std_logic
    );
end entity IpdbgTap;

architecture ecp2_arch of IpdbgTap is
    component JTAGC
        generic(
            ER1 : string := "ENABLED";
            ER2 : string := "DISABLED"
        );
        port(
            TCK     : in  std_logic;
            TMS     : in  std_logic;
            TDI     : in  std_logic;
            TDO     : out std_logic;
            ITCK    : in  std_logic;
            ITMS    : in  std_logic;
            ITDI    : in  std_logic;
            IJTAGEN : in  std_logic;
            JTDO1   : in  std_logic;
            JTDO2   : in  std_logic;
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

    signal UPDATE1       : std_logic;
    signal CAPTURE1      : std_logic;
    signal SHIFT_s       : std_logic;
    signal SHIFT1        : std_logic;
    signal wasInShiftDr1 : std_logic;
    signal JSHIFT        : std_logic;
    signal JUPDATE       : std_logic;
    signal JCE1          : std_logic;
    signal JCE1_s        : std_logic;
    signal drclk_s       : std_logic;
begin

    JtagcInst: JTAGC
        port map (
            TCK     => TCK,
            TMS     => TMS,
            TDI     => TDI,
            TDO     => TDO,
            ITCK    => '0',
            ITMS    => '0',
            ITDI    => '0',
            IJTAGEN => '1',
            JTDO1   => tdo_i,
            JTDO2   => '0',
            ITDO    => open,
            JTDI    => tdi_o,
            JTCK    => drclk_s,
            JRTI1   => open,
            JRTI2   => open,
            JSHIFT  => JSHIFT,
            JUPDATE => JUPDATE,
            JRSTN   => open,
            JCE1    => JCE1,
            JCE2    => open
    );
    drclk <= drclk_s;
    process(drclk_s)begin
        if falling_edge(drclk_s) then
            update  <= JUPDATE;
            SHIFT_s <= JSHIFT;
            JCE1_s  <= JCE1;
        end if;
    end process;

    SHIFT <= SHIFT_s;
    CAPTURE <= CAPTURE1;
    CAPTURE1 <= JCE1_s and (not SHIFT_s);
    SHIFT1 <= JCE1_s and SHIFT_s;

    USER <= UPDATE1 or CAPTURE1 or SHIFT1;

    process(drclk_s)begin
        if falling_edge(drclk_s) then
            if SHIFT1 = '1' then
                wasInShiftDr1 <= '1';
            elsif JUPDATE = '1' then
                wasInShiftDr1 <= '0';
            end if;
            if wasInShiftDr1 = '1' then
                UPDATE1 <= JUPDATE;
            else
                UPDATE1 <= '0';
            end if;
        end if;
    end process;

end ecp2_arch;
