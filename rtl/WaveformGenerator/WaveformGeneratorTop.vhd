library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity WaveformGeneratorTop is
    generic(
        ADDR_WIDTH : natural := 13;          --! 2**ADDR_WIDTH = size if sample memory
        ASYNC_RESET : boolean := true
    );
    port(
        clk            : in  std_logic;
        rst            : in  std_logic;
        ce             : in  std_logic;

        --      host interface (UART or ....)
        data_dwn_valid : in  std_logic;
        data_dwn       : in  std_logic_vector(7 downto 0);
        data_up_ready  : in  std_logic;
        data_up_valid  : out std_logic;
        data_up        : out std_logic_vector(7 downto 0);

        -- WaveformGenerator interface
        data_out       : out std_logic_vector;
        first_sample   : out std_logic;
        sample_enable  : in  std_logic

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
            enable                  : out std_logic;
            addr_of_last_sample     : out std_logic_vector(ADDR_WIDTH-1 downto 0)
        );
    end component WaveformGeneratorController;

    component WaveformGeneratorMemory is
        generic(
            DATA_WIDTH  : natural := 8;
            ADDR_WIDTH  : natural := 8;
            ASYNC_RESET : boolean
        );
        port(
            clk                     : in  std_logic;
            rst                     : in  std_logic;
            ce                      : in  std_logic;
            data_samples            : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            data_samples_valid      : in  std_logic;
            data_samples_if_reset   : in  std_logic;
            enable                  : in  std_logic;
            addr_of_last_sample     : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
            data_out                : out std_logic_vector(DATA_WIDTH-1 downto 0);
            first_sample            : out std_logic;
            data_out_enable         : in  std_logic
        );
    end component WaveformGeneratorMemory;

    signal data_in_valid_uesc   : std_logic;
    signal reset                : std_logic;
    signal enable_me            : std_logic;
    signal data_valid_me        : std_logic;
    signal dataifreset_me       : std_logic;
    signal data_in_uesc         : std_logic_vector(7 downto 0);
    signal data_me              : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal addr_of_last_sample  : std_logic_vector(ADDR_WIDTH-1 downto 0);

begin

    Controller: component WaveformGeneratorController
        generic map(
            DATA_WIDTH  => DATA_WIDTH,
            ADDR_WIDTH  => ADDR_WIDTH,
            ASYNC_RESET => ASYNC_RESET
        )
        port map(
            clk                    => clk,
            rst                    => reset,
            ce                     => ce,
            data_dwn_valid         => data_in_valid_uesc,
            data_dwn               => data_in_uesc,
            data_up_ready          => data_up_ready,
            data_up_valid          => data_up_valid,
            data_up                => data_up,
            data_samples           => data_me,
            data_samples_valid     => data_valid_me,
            data_samples_if_reset  => dataifreset_me,
            enable                 => enable_me,
            addr_of_last_sample    => addr_of_last_sample
        );

    Memory: component WaveformGeneratorMemory
        generic map(
            DATA_WIDTH  => DATA_WIDTH,
            ADDR_WIDTH  => ADDR_WIDTH,
            ASYNC_RESET => ASYNC_RESET
        )
        port map(
            clk                     => clk,
            rst                     => reset,
            ce                      => ce,
            data_samples            => data_me,
            data_samples_valid      => data_valid_me,
            data_samples_if_reset   => dataifreset_me,
            enable                  => enable_me,
            addr_of_last_sample     => addr_of_last_sample,
            data_out                => data_out,
            first_sample            => first_sample,
            data_out_enable         => sample_enable

        );

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
