library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity WaveformGeneratorTop is
    generic(
        ADDR_WIDTH     : natural := 13;          --! 2**ADDR_WIDTH = size if sample memory
        ASYNC_RESET    : boolean := true;
        DOUBLE_BUFFER  : boolean := false
    );
    port(
        clk            : in  std_logic;
        rst            : in  std_logic;
        ce             : in  std_logic;

        --      host interface (UART or ....)
        data_dwn_ready : out std_logic;
        data_dwn_valid : in  std_logic;
        data_dwn       : in  std_logic_vector(7 downto 0);
        data_up_ready  : in  std_logic;
        data_up_valid  : out std_logic;
        data_up        : out std_logic_vector(7 downto 0);

        -- WaveformGenerator interface
        data_out       : out std_logic_vector;
        first_sample   : out std_logic;
        sample_enable  : in  std_logic;
        output_active  : out std_logic

    );
end entity WaveformGeneratorTop;

architecture structure of WaveformGeneratorTop is
    constant DATA_WIDTH : natural := data_out'length;

    component ipdbgEscaping is
        generic(
            ASYNC_RESET  : boolean
        );
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
    end component ipdbgEscaping;

    component WaveformGeneratorController is
        generic(
            DATA_WIDTH  : natural := 8;
            ADDR_WIDTH  : natural := 8;
            ASYNC_RESET : boolean
        );
        port(
            clk                     : in  std_logic;
            rst                     : in  std_logic;
            ce                      : in  std_logic;
            data_dwn_valid          : in  std_logic;
            data_dwn                : in  std_logic_vector(7 downto 0);
            data_up_ready           : in  std_logic;
            data_up_valid           : out std_logic;
            data_up                 : out std_logic_vector(7 downto 0);
            data_samples            : out std_logic_vector(DATA_WIDTH-1 downto 0);
            data_samples_valid      : out std_logic;
            data_samples_if_reset   : out std_logic;
            data_samples_last       : out std_logic;
            start                   : out std_logic;
            stop                    : out std_logic
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

    signal data_in_valid_uesc      : std_logic;
    signal reset                   : std_logic;
    signal enabled                 : std_logic;
    signal start                   : std_logic;
    signal stop                    : std_logic;
    signal data_samples            : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal data_samples_valid      : std_logic;
    signal data_samples_if_reset   : std_logic;
    signal data_samples_last       : std_logic;
    signal data_in_uesc            : std_logic_vector(7 downto 0);

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
            data_dwn_valid          => data_in_valid_uesc,
            data_dwn                => data_in_uesc,
            data_up_ready           => data_up_ready,
            data_up_valid           => data_up_valid,
            data_up                 => data_up,
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
            clk                     => clk,
            rst                     => rst,
            ce                      => ce,
            data_samples            => data_samples,
            data_samples_valid      => data_samples_valid,
            data_samples_if_reset   => data_samples_if_reset,
            data_samples_last       => data_samples_last,
            start                   => start,
            stop                    => stop,
            enabled                 => enabled,
            data_out                => data_out,
            first_sample            => first_sample,
            data_out_enable         => sample_enable

        );

    data_dwn_ready <= '1';

    Escaping: component IpdbgEscaping
        generic map(
            ASYNC_RESET => ASYNC_RESET
        )
        port map(
            clk            => clk,
            rst            => rst,
            ce             => ce,
            data_in_valid  => data_dwn_valid,
            data_in        => data_dwn,
            data_out_valid => data_in_valid_uesc,
            data_out       => data_in_uesc,
            reset          => reset
        );

end architecture structure;
