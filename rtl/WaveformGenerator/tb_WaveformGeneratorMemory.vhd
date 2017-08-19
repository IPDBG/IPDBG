library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity tb_WaveformGeneratorMemory is
end entity tb_WaveformGeneratorMemory;


architecture test of tb_WaveformGeneratorMemory is

    component WaveformGeneratorMemory is
        generic(
            DATA_WIDTH       : natural := 8;
            ADDR_WIDTH       : natural := 8
        );
        port(
            clk              : in  std_logic;
            rst              : in  std_logic;
            ce               : in  std_logic := '1';

            Enable           : in  std_logic;
            SampleEnable     : in  std_logic := '1';
            AddrOfLastSample : in  std_logic_vector(ADDR_WIDTH-1 downto 0); -- Length Of Waveform - 1
            DataOut          : out std_logic_vector(DATA_WIDTH-1 downto 0);
            FirstSample      : out std_logic;

            -- write
            DataIn           : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            DataValid        : in  std_logic;
            DataIfReset      : in  std_logic
        );
    end component WaveformGeneratorMemory;

    constant DATA_WIDTH     : natural := 8;
    constant ADDR_WIDTH     : natural := 8;

    signal clk              : std_logic;
    signal rst              : std_logic;
    signal ce               : std_logic;
    signal Enable           : std_logic;
    signal SampleEnable     : std_logic;
    signal AddrOfLastSample : std_logic_vector(ADDR_WIDTH-1 downto 0); -- Length Of Waveform - 1
    signal DataOut          : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal FirstSample      : std_logic;
    -- write
    signal DataIn           : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal DataValid        : std_logic;
    signal DataIfReset      : std_logic;

    constant T : time := 10 ns;
    constant LastSampleAddr : natural := 13;

begin

    process begin
        rst <= '1';
        wait for T*1.2;
        rst <= '0';
        wait;
    end process;

    process begin
        while true loop
            clk <= '1';
            wait for T/2;
            clk <= '0';
            wait for T-T/2;
        end loop;
        wait;
    end process;

    ce <= '1';

    configuring: process begin
        DataIfReset <= '0';
        DataValid   <= '0';
        DataIn      <= x"00";
        wait until rising_edge(clk) and rst = '0';
        wait for T/5;
        DataIfReset <= '1';
        wait for T;
        DataIfReset <= '0';

        DataValid   <= '1';
        for K in 0 to LastSampleAddr loop
            DataIn <= std_logic_vector(to_unsigned(K, DATA_WIDTH));
            wait for T;
        end loop;
        DataValid   <= '0';

        wait;
    end process;


    AddrOfLastSample <= std_logic_vector(to_unsigned(LastSampleAddr, DATA_WIDTH));
    enableGenerator: process begin
        Enable <= '0';
        SampleEnable <= '0';

        wait until rising_edge(clk) and rst = '0';
        wait for 32.2 * T;
        Enable <= '1';

        for I in 1 to 5 loop
            for K in 0 to 100 loop
                SampleEnable <= '1';
                wait for T;
                if I > 1 then
                    sampleEnable <= '0';
                    wait for (I-1)*T;
                end if;
            end loop;
        end loop;

        wait;
    end process;

    uut: component WaveformGeneratorMemory
        generic map(
            DATA_WIDTH     => DATA_WIDTH,
            ADDR_WIDTH     => ADDR_WIDTH
        )
        port map(
            clk              => clk,
            rst              => rst,
            ce               => ce,
            Enable           => Enable,
            SampleEnable     => SampleEnable,
            AddrOfLastSample => AddrOfLastSample,
            DataOut          => DataOut,
            FirstSample      => FirstSample,
            DataIn           => DataIn,
            DataValid        => DataValid,
            DataIfReset      => DataIfReset
        );

end architecture test;




