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

architecture cycloneiii_arch of IpdbgTap_intel_jtag is
    component cycloneiii_jtag is
        port (
            tms         : in  std_logic;
            tck         : in  std_logic;
            tdi         : in  std_logic;
            tdo         : out std_logic;
            tdouser     : in  std_logic;
            tmsutap     : out std_logic;
            tckutap     : out std_logic;
            tdiutap     : out std_logic;
            shiftuser   : out std_logic;
            clkdruser   : out std_logic;
            updateuser  : out std_logic;
            runidleuser : out std_logic;
            usr1user    : out std_logic
        );
    end component cycloneiii_jtag;
begin
    cyciii_tap_i: component cycloneiii_jtag
        port map(
            tms         => tms,
            tck         => tck,
            tdi         => tdi,
            tdo         => tdo,
            tdouser     => tdouser,
            tmsutap     => tmsutap,
            tckutap     => tckutap,
            tdiutap     => tdiutap,
            shiftuser   => shiftuser,
            clkdruser   => open,
            updateuser  => updateuser,
            runidleuser => runidleuser,
            usr1user    => usr1user
        );
end architecture cycloneiii_arch;
