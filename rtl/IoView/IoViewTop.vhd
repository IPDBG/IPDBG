library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity IoViewTop is
    port(
        clk            : in  std_logic;
        rst            : in  std_logic;
        ce             : in  std_logic;

        -- host interface (JtagHub or UART or ....)
        data_in_valid  : in  std_logic;
        data_in        : in  std_logic_vector(7 downto 0);
        data_out_ready : in  std_logic;
        data_out_valid : out std_logic;
        data_out       : out std_logic_vector(7 downto 0);

        --- Input & Ouput--------
        probe_inputs   : in  std_logic_vector;
        probe_outputs  : out std_logic_vector
    );
end entity IoViewTop;

architecture struct of IoViewTop is

    component IoViewController is
        port(
            clk            : in  std_logic;
            rst            : in  std_logic;
            ce             : in  std_logic;
            data_in_valid  : in  std_logic;
            data_in        : in  std_logic_vector(7 downto 0);
            data_out_ready : in  std_logic;
            data_out_valid : out std_logic;
            data_out       : out std_logic_vector(7 downto 0);
            input          : in  std_logic_vector;
            output         : out std_logic_vector
        );
    end component IoViewController;

    component IpdbgEscaping is
        port(
            clk            : in  std_logic;
            rst            : in  std_logic;
            ce             : in  std_logic;
            data_in_valid  : in  std_logic;
            data_in        : in  std_logic_vector(7 downto 0);
            data_out_valid : out std_logic;
            data_out       : out std_logic_vector(7 downto 0);
            reset          : out std_logic
        );
    end component IpdbgEscaping;

    signal data_in_unescaped       : std_logic_vector(7 downto 0);
    signal data_in_valid_unescaped : std_logic;
    signal reset                   : std_logic;
begin

    controller : component IoViewController
        port map(
            clk            => clk,
            rst            => reset,
            ce             => ce,
            data_in_valid  => data_in_valid_unescaped,
            data_in        => data_in_unescaped,
            data_out_ready => data_out_ready,
            data_out_valid => data_out_valid,
            data_out       => data_out,
            input          => probe_inputs,
            output         => probe_outputs
        );

    escaping : component IpdbgEscaping
        port map(
            clk            => clk,
            rst            => rst,
            ce             => ce,
            data_in_valid  => data_in_valid,
            data_in        => data_in,
            data_out_valid => data_in_valid_unescaped,
            data_out       => data_in_unescaped,
            reset          => reset
        );

end architecture struct;
