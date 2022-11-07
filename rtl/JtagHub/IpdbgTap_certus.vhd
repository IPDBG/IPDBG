library ieee;
use ieee.std_logic_1164.all;

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

architecture certus_arch of IpdbgTap is
    component JTAG
        generic(
            MCER1EXIST : string := "EXIST";
            MCER2EXIST : string := "NEXIST"
        );
        port(
            TCK     : in  std_logic;
            TMS     : in  std_logic;
            TDI     : in  std_logic;
            TDO     : out std_logic;
            JTDO1   : in  std_logic;
            JTDO2   : in  std_logic;
			SMCLK   : in  std_logic;
            JTCK    : out std_logic;
            JTDI    : out std_logic;
            JRTI1   : out std_logic;
            JRTI2   : out std_logic;
            JSHIFT  : out std_logic;
            JUPDATE : out std_logic;
            JRSTN   : out std_logic;
            JCE1    : out std_logic;
            JCE2    : out std_logic;
			TDO_OEN : out std_logic
        );
    end component;

    signal UPDATE1          : std_logic;
    signal CAPTURE1         : std_logic;
    signal SHIFT1           : std_logic;
    signal JSHIFT           : std_logic;
    signal JUPDATE          : std_logic;
    signal JCE1             : std_logic;
    signal JRTI1            : std_logic;
    signal drclk_s          : std_logic;
    signal was_in_capture_1 : std_logic;
begin

    JtagInst: JTAG
        port map (
            TCK     => TCK,
            TMS     => TMS,
            TDI     => TDI,
            TDO     => TDO,
			SMCLK   => '0',
            JTDO1   => tdo_i,
            JTDO2   => '0',
            JTCK    => drclk_s,
            JTDI    => tdi_o,
            JRTI1   => JRTI1,
            JRTI2   => open,
            JSHIFT  => JSHIFT,
            JUPDATE => JUPDATE,
            JRSTN   => open,
            JCE1    => JCE1,
            JCE2    => open,
			TDO_OEN => open
    );

    drclk <= drclk_s;
    CAPTURE1 <= JCE1 and (not JSHIFT);
    SHIFT1 <= JCE1 and JSHIFT;
    UPDATE1 <= was_in_capture_1 and JUPDATE;

    user <= CAPTURE1 or SHIFT1 or UPDATE1;
    capture <= CAPTURE1;
    shift <= SHIFT1;
    update <= UPDATE1;

    process (drclk_s) begin
        if rising_edge(drclk_s) then
            if JRTI1 = '1' or JUPDATE = '1' then
                was_in_capture_1 <= '0';
            elsif CAPTURE1 = '1' then
                was_in_capture_1 <= '1';
            end if;
        end if;
    end process;
end certus_arch;
