library ieee;
use ieee.std_logic_1164.all;

entity IpdbgTap_intel_jtag is
    port(
        tms         : in  std_logic;
        tck         : in  std_logic;
        tdi         : in  std_logic;
        tdo         : out std_logic;
        tdouser     : in  std_logic;
        tmsutap     : out std_logic;
        tckutap     : out std_logic;
        tdiutap     : out std_logic;
        shiftuser   : out std_logic;
        updateuser  : out std_logic;
        runidleuser : out std_logic;
        usr1user    : out std_logic
    );
end entity;

architecture max10_arch of IpdbgTap_intel_jtag is
    component fiftyfivenm_jtag is
        port (
            tms         : in  std_logic;
            tck         : in  std_logic;
            tdi         : in  std_logic;
            tdo         : out std_logic;
            --tdoutap     : in  std_logic;
            tdouser     : in  std_logic;
            tmscore     : in  std_logic;
            tckcore     : in  std_logic;
            tdicore     : in  std_logic;
            corectl     : in  std_logic;
            --ntdopinena  : in  std_logic;
            tmsutap     : out std_logic;
            tckutap     : out std_logic;
            tdiutap     : out std_logic;
            shiftuser   : out std_logic;
            clkdruser   : out std_logic;
            updateuser  : out std_logic;
            runidleuser : out std_logic;
            usr1user    : out std_logic;
            tdocore     : out std_logic
        );
    end component fiftyfivenm_jtag;
begin
    fiftyfive_tap_i: component fiftyfivenm_jtag
        port map(
            tms         => tms,
            tck         => tck,
            tdi         => tdi,
            tdo         => tdo,
            tdouser     => tdouser,
            corectl     => '0',
            tmscore     => '0',
            tckcore     => '0',
            tdicore     => '0',
            tdocore     => open,
            tmsutap     => tmsutap,
            tckutap     => tckutap,
            tdiutap     => tdiutap,
            shiftuser   => shiftuser,
            clkdruser   => open,
            updateuser  => updateuser,
            runidleuser => runidleuser,
            usr1user    => usr1user
        );
end architecture max10_arch;
