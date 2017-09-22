library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_WaveformGeneratorController is
end tb_WaveformGeneratorController;

architecture test of tb_WaveformGeneratorController is
    component WaveformGeneratorController is
        generic(
            DATA_WIDTH : natural;
            ADDR_WIDTH : natural
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
    constant DATA_WIDTH          : natural := 9;
    constant ADDR_WIDTH          : natural := 9;
    signal clk                   : std_logic;
    signal rst                   : std_logic;
    signal ce                    : std_logic;
    signal data_dwn_valid        : std_logic;
    signal data_dwn              : std_logic_vector(7 downto 0);
    signal data_up_ready         : std_logic;
    signal data_up_valid         : std_logic;
    signal data_up               : std_logic_vector(7 downto 0);
    signal data_samples          : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal data_samples_valid    : std_logic;
    signal data_samples_if_reset : std_logic;
    signal enable                : std_logic;
    signal addr_of_last_sample   : std_logic_vector(ADDR_WIDTH-1 downto 0);

    constant T                   : time := 10 ns;
begin
    process begin
        clk <= '0';
        wait for T/2;
        clk <= '1';
        wait for (T-(T/2));-- to avoid rounding differences
    end process;
    process begin
        rst <= '1';
        wait for 3/2*T;
        rst <= '0';
        wait;
    end process;

    ce <= '1';

    process begin
        data_up_ready <= '1';
        wait until rising_edge(clk) and rst = '0';
        wait for T/5;

        while true loop
            data_up_ready <= not data_up_valid;
            wait for T;
        end loop;

        wait;
    end process;


    process begin
        data_dwn_valid <= '0';
        data_dwn <= (others => '0');
        wait until rising_edge(clk) and rst = '0';
        wait for T/5;
        wait for 5*T;

        -- set address of last sample
        data_dwn_valid <= '1';
        data_dwn <= x"f4";
        wait for T;

        data_dwn <= x"00";
        wait for T;

        data_dwn <= x"07";
        wait for T;

        data_dwn_valid <= '0';
        wait for 5*T;

        -- request for data width
        data_dwn_valid <= '1';
        data_dwn <= x"f2";
        wait for T;

        data_dwn_valid <= '0';
        wait for 5*T;

        wait for 20*T;


        -- write samples:
        data_dwn_valid <= '1';
        data_dwn <= x"f3";
        wait for T;

        for k in 0 to 7 loop
            data_dwn_valid <= '1';
            data_dwn <= x"00";
            wait for T;
            data_dwn <= std_logic_vector(to_unsigned(k, data_dwn'length));
            wait for T;
        end loop;

        data_dwn_valid <= '0';
        wait for 5*T;




        -- set start
        data_dwn_valid <= '1';
        data_dwn <= x"f0";
        wait for T;
        data_dwn_valid <= '0';


        wait;
    end process;





    uut : component WaveformGeneratorController
        generic map(
            DATA_WIDTH => DATA_WIDTH,
            ADDR_WIDTH => ADDR_WIDTH
        )
        port map(
            clk                   => clk,
            rst                   => rst,
            ce                    => ce,
            data_dwn_valid        => data_dwn_valid,
            data_dwn              => data_dwn,
            data_up_ready         => data_up_ready,
            data_up_valid         => data_up_valid,
            data_up               => data_up,
            data_samples          => data_samples,
            data_samples_valid    => data_samples_valid,
            data_samples_if_reset => data_samples_if_reset,
            enable                => enable,
            addr_of_last_sample   => addr_of_last_sample
        );
end architecture test;
