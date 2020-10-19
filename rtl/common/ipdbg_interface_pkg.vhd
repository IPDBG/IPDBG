library ieee;
use ieee.std_logic_1164.all;

package ipdbg_interface_pkg is
--    generic (
--        N : integer := 2
--    );

--    type ipdbg_link is record
--        ready : std_logic;
--        valid : std_logic;
--        data  : std_logic_vector(7 downto 0);
--    end record;

    type ipdbg_up_lines is record
        dnlink_ready : std_logic;
        uplink_valid : std_logic;
        uplink_data  : std_logic_vector(7 downto 0);
    end record;

    type ipdbg_dn_lines is record
        uplink_ready : std_logic;
        dnlink_valid : std_logic;
        dnlink_data  : std_logic_vector(7 downto 0);
    end record;

    constant unused_up_lines : ipdbg_up_lines := ( dnlink_ready => '1', uplink_valid => '0', uplink_data => (others => '-'));

--    type jtag_hub_interface is array (6 downto 0) of ipdbg_link;


end ipdbg_interface_pkg;
