library IEEE;
use IEEE.std_logic_1164.all;

-- synopsys translate_off
library ecp2;
use ecp2.components.all;
-- synopsys translate_on

entity JtagcWrapper is
    port
    (
        JTDO1   : in  std_logic;
        JTDO2   : in  std_logic;
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
--    attribute dont_touch : boolean;
--    attribute dont_touch of JtagcWrapper : entity is true;
end JtagcWrapper;

architecture Structure of JtagcWrapper is


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
            JTDO1   => JTDO1,
            JTDO2   => JTDO2,
            TDO     => open,
            ITDO    => open,
            JTDI    => JTDI,
            JTCK    => JTCK,
            JRTI1   => JRTI1,
            JRTI2   => JRTI2,
            JSHIFT  => JSHIFT,
            JUPDATE => JUPDATE,
            JRSTN   => JRSTN,
            JCE1    => JCE1,
            JCE2    => JCE2
    );

end Structure;
