library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ipdbg_interface_pkg.all;

entity IoViewTop is
    generic(
        ASYNC_RESET : boolean := true
    );
    port(
        clk                  : in  std_logic;
        rst                  : in  std_logic;
        ce                   : in  std_logic;

        -- host interface (JtagHub or UART or ....)
        dn_lines             : in  ipdbg_dn_lines;
        up_lines             : out ipdbg_up_lines;

        --- Input & Ouput--------
        probe_inputs         : in  std_logic_vector;
        probe_outputs        : out std_logic_vector;
        probe_outputs_update : out std_logic
    );
end entity IoViewTop;

architecture struct of IoViewTop is

    component IoViewController is
        generic(
            ASYNC_RESET : boolean
        );
        port(
            clk           : in  std_logic;
            rst           : in  std_logic;
            ce            : in  std_logic;
            dn_lines      : in  ipdbg_dn_lines;
            up_lines      : out ipdbg_up_lines;
            input         : in  std_logic_vector;
            output        : out std_logic_vector;
            output_update : out std_logic
        );
    end component IoViewController;

    component IpdbgEscaping is
        generic(
            ASYNC_RESET  : boolean;
            DO_HANDSHAKE : boolean
        );
        port(
            clk          : in  std_logic;
            rst          : in  std_logic;
            ce           : in  std_logic;
            dn_lines_in  : in  ipdbg_dn_lines;
            dn_lines_out : out ipdbg_dn_lines;
            up_lines_out : out ipdbg_up_lines;
            up_lines_in  : in  ipdbg_up_lines;
            reset        : out std_logic
        );
    end component IpdbgEscaping;

    signal dn_lines_unescaped : ipdbg_dn_lines;
    signal up_lines_unescaped : ipdbg_up_lines;
    signal reset              : std_logic;
begin

    controller : component IoViewController
        generic map(
            ASYNC_RESET => ASYNC_RESET
        )
        port map(
            clk           => clk,
            rst           => reset,
            ce            => ce,
            dn_lines      => dn_lines_unescaped,
            up_lines      => up_lines_unescaped,
            input         => probe_inputs,
            output        => probe_outputs,
            output_update => probe_outputs_update
        );

    escaping : component IpdbgEscaping
        generic map(
            ASYNC_RESET  => ASYNC_RESET,
            DO_HANDSHAKE => false
        )
        port map(
            clk          => clk,
            rst          => rst,
            ce           => ce,
            dn_lines_in  => dn_lines,
            dn_lines_out => dn_lines_unescaped,
            up_lines_out => up_lines,
            up_lines_in  => up_lines_unescaped,
            reset        => reset
        );

end architecture struct;
