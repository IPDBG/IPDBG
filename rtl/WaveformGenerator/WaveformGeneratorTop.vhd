library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity WaveformGeneratorTop is
    generic(
         DATA_WIDTH : natural := 8;         --! width of a sample
         ADDR_WIDTH : natural := 8          --! 2**ADDR_WIDTH = size if sample memory
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
        dataOut        : out std_logic_vector(DATA_WIDTH-1 downto 0);
        firstsample    : out std_logic;
        sample_enable  : in  std_logic

    );
end entity WaveformGeneratorTop;

architecture structure of WaveformGeneratorTop is
    component ipdbgEscaping is
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
        DATA_WIDTH       : natural := 8;
        ADDR_WIDTH       : natural := 8
        );
        port(
            clk                   : in  std_logic;
            rst                   : in  std_logic;
            ce                    : in  std_logic;
            data_dwn_valid        : in  std_logic;
            data_dwn              : in  std_logic_vector(7 downto 0);
            data_up_ready         : in  std_logic;
            data_up_valid         : out std_logic;
            data_up               : out std_logic_vector(7 downto 0);
            data_samples          : out std_logic_vector(DATA_WIDTH-1 downto 0);
            data_samples_valid    : out std_logic;
            data_samples_if_reset : out std_logic;
            enable                : out std_logic;
            addr_of_last_sample   : out std_logic_vector(ADDR_WIDTH-1 downto 0)
        );
    end component WaveformGeneratorController;

    component WaveformGeneratorMemory is
        generic(
        DATA_WIDTH       : natural := 8;
        ADDR_WIDTH       : natural := 8
        );
        port(
            clk              : in  std_logic;
            rst              : in  std_logic;
            ce               : in  std_logic;
            DataIn           : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            DataValid        : in  std_logic;
            DataIfReset      : in  std_logic;
            Enable           : in  std_logic;
            AddrOfLastSample : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
            DataOut          : out std_logic_vector(DATA_WIDTH-1 downto 0);
            FirstSample      : out std_logic;
            SampleEnable     : in  std_logic
        );
    end component WaveformGeneratorMemory;

    signal data_in_valid_uesc   : std_logic;
    signal reset                : std_logic;
    signal enable_me            : std_logic;
    signal data_valid_me        : std_logic;
    signal dataifreset_me       : std_logic;
    signal data_in_uesc         : std_logic_vector(7 downto 0);
    signal data_me              : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal AddrOfLastSample     : std_logic_vector(ADDR_WIDTH-1 downto 0);

begin

    Controller: component WaveformGeneratorController
        generic map(
            DATA_WIDTH => DATA_WIDTH,
            ADDR_WIDTH => ADDR_WIDTH
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
            addr_of_last_sample    => AddrOfLastSample
        );

    Memory: component WaveformGeneratorMemory
        generic map(
            DATA_WIDTH => DATA_WIDTH,
            ADDR_WIDTH => ADDR_WIDTH
        )
        port map(
            clk              => clk,
            rst              => reset,
            ce               => ce,
            DataIn           => data_me,
            DataValid        => data_valid_me,
            DataIfReset      => dataifreset_me,
            Enable           => enable_me,
            AddrOfLastSample => AddrOfLastSample,
            DataOut          => dataOut,
            FirstSample      => firstsample,
            SampleEnable     => sample_enable

        );

    Escaping: component IpdbgEscaping
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
