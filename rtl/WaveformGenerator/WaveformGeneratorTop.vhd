library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ipdbg_interface_pkg.all;

entity WaveformGeneratorTop is
    generic(
        ADDR_WIDTH    : natural := 13;          --! 2**ADDR_WIDTH = size if sample memory
        ASYNC_RESET   : boolean := true;
        DOUBLE_BUFFER : boolean := false
    );
    port(
        clk           : in  std_logic;
        rst           : in  std_logic;
        ce            : in  std_logic;

        --      host interface (UART or ....)
        dn_lines      : in  ipdbg_dn_lines;
        up_lines      : out ipdbg_up_lines;

        -- WaveformGenerator interface
        data_out      : out std_logic_vector;
        first_sample  : out std_logic;
        sample_enable : in  std_logic;
        output_active : out std_logic
    );
end entity WaveformGeneratorTop;

architecture structure of WaveformGeneratorTop is
    constant DATA_WIDTH : natural := data_out'length;

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

    component WaveformGeneratorController is
        generic(
            DATA_WIDTH  : natural := 8;
            ADDR_WIDTH  : natural := 8;
            ASYNC_RESET : boolean
        );
        port(
            clk                   : in  std_logic;
            rst                   : in  std_logic;
            ce                    : in  std_logic;
            dn_lines              : in  ipdbg_dn_lines;
            up_lines              : out ipdbg_up_lines;
            data_samples          : out std_logic_vector(DATA_WIDTH-1 downto 0);
            data_samples_valid    : out std_logic;
            data_samples_if_reset : out std_logic;
            data_samples_last     : out std_logic;
            start                 : out std_logic;
            stop                  : out std_logic
        );
    end component WaveformGeneratorController;

    component WaveformGeneratorMemory is
        generic(
            DATA_WIDTH    : natural := 8;
            ADDR_WIDTH    : natural := 8;
            ASYNC_RESET   : boolean;
            DOUBLE_BUFFER : boolean
        );
        port(
            clk                     : in  std_logic;
            rst                     : in  std_logic;
            ce                      : in  std_logic;
            data_samples            : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            data_samples_valid      : in  std_logic;
            data_samples_if_reset   : in  std_logic;
            data_samples_last       : in  std_logic;
            start                   : in  std_logic;
            stop                    : in  std_logic;
            enabled                 : out std_logic;
            data_out                : out std_logic_vector(DATA_WIDTH-1 downto 0);
            first_sample            : out std_logic;
            data_out_enable         : in  std_logic
        );
    end component WaveformGeneratorMemory;

    signal dn_lines_unescaped    : ipdbg_dn_lines;
    signal up_lines_unescaped    : ipdbg_up_lines;
    signal reset                 : std_logic;
    signal enabled               : std_logic;
    signal start                 : std_logic;
    signal stop                  : std_logic;
    signal data_samples          : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal data_samples_valid    : std_logic;
    signal data_samples_if_reset : std_logic;
    signal data_samples_last     : std_logic;

begin

    Controller: component WaveformGeneratorController
        generic map(
            DATA_WIDTH  => DATA_WIDTH,
            ADDR_WIDTH  => ADDR_WIDTH,
            ASYNC_RESET => ASYNC_RESET
        )
        port map(
            clk                     => clk,
            rst                     => reset,
            ce                      => ce,
            dn_lines                => dn_lines_unescaped,
            up_lines                => up_lines_unescaped,
            data_samples            => data_samples,
            data_samples_valid      => data_samples_valid,
            data_samples_if_reset   => data_samples_if_reset,
            data_samples_last       => data_samples_last,
            start                   => start,
            stop                    => stop
        );

    output_active <= enabled;

    Memory: component WaveformGeneratorMemory
        generic map(
            DATA_WIDTH    => DATA_WIDTH,
            ADDR_WIDTH    => ADDR_WIDTH,
            ASYNC_RESET   => ASYNC_RESET,
            DOUBLE_BUFFER => DOUBLE_BUFFER
        )
        port map(
            clk                   => clk,
            rst                   => rst,
            ce                    => ce,
            data_samples          => data_samples,
            data_samples_valid    => data_samples_valid,
            data_samples_if_reset => data_samples_if_reset,
            data_samples_last     => data_samples_last,
            start                 => start,
            stop                  => stop,
            enabled               => enabled,
            data_out              => data_out,
            first_sample          => first_sample,
            data_out_enable       => sample_enable
        );

    Escaping: component IpdbgEscaping
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
            up_lines_in  => up_lines_unescaped,
            up_lines_out => up_lines,
            reset        => reset
        );

end architecture structure;
