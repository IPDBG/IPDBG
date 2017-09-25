library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity tb_top is

end entity tb_top;

architecture structure of tb_top is

    component LogicAnalyserTop is
        generic(
            DATA_WIDTH  : natural;
            ADDR_WIDTH  : natural;
            ASYNC_RESET : boolean
        );
        port(
            clk            : in  std_logic;
            rst            : in  std_logic;
            ce             : in  std_logic;
            data_dwn_valid : in  std_logic;
            data_dwn       : in  std_logic_vector(7 downto 0);
            data_up_ready  : in  std_logic;
            data_up_valid  : out std_logic;
            data_up        : out std_logic_vector(7 downto 0);

            sample_enable  : in  std_logic;
            probe          : in  std_logic_vector(DATA_WIDTH-1 downto 0)
        );
    end component LogicAnalyserTop;


    component JtagHub is
        generic(
            MFF_LENGTH : natural
        );
        port(
            clk                  : in  std_logic;
            ce                   : in  std_logic;
            data_dwn             : out std_logic_vector(7 downto 0);
            data_dwn_valid_la    : out std_logic;
            data_dwn_valid_ioview: out std_logic;
            data_dwn_valid_gdb   : out std_logic;
            data_dwn_valid_wfg   : out std_logic;
            data_up_ready_la     : out std_logic;
            data_up_ready_ioview : out std_logic;
            data_up_ready_gdb    : out std_logic;
            data_up_ready_wfg    : out std_logic;
            data_up_valid_la     : in  std_logic;
            data_up_valid_ioview : in  std_logic;
            data_up_valid_gdb    : in  std_logic;
            data_up_valid_wfg    : in  std_logic;
            data_up_la           : in  std_logic_vector(7 downto 0);
            data_up_ioview       : in  std_logic_vector(7 downto 0);
            data_up_wfg          : in  std_logic_vector(7 downto 0);
            data_up_gdb          : in  std_logic_vector(7 downto 0)
        );
    end component JtagHub;

    signal clk, rst, ce  : std_logic;


    constant DATA_WIDTH  : natural := 12;
    constant ADDR_WIDTH  : natural := 10;
    constant ASYNC_RESET : boolean := true;

    signal data_dwn              : std_logic_vector(7 downto 0);
    signal data_dwn_valid_la     : std_logic;
    signal data_up_ready_la      : std_logic;
    signal data_up_valid_la      : std_logic;
    signal data_up_la            : std_logic_vector(7 downto 0);

    constant T           : time := 10 ns;

    signal count         : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal count_max     : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '1');
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
    process(clk, rst)begin
        if rst = '1' then
            count <= (others => '0');
        elsif rising_edge(clk) then
            if count = count_max then
                count <= (others => '0');
            else
                count <= std_logic_vector(unsigned(count) + 1);
            end if;
        end if;
    end process;


    jh: component JtagHub
        generic map(
            MFF_LENGTH => 3
        )
        port map(
            clk                   => clk,
            ce                    => ce,
            data_dwn              => data_dwn,
            data_dwn_valid_la     => data_dwn_valid_la,
            data_dwn_valid_ioview => open,
            data_dwn_valid_gdb    => open,
            data_dwn_valid_wfg    => open,
            data_up_ready_la      => data_up_ready_la,
            data_up_ready_ioview  => open,
            data_up_ready_gdb     => open,
            data_up_ready_wfg     => open,
            data_up_valid_la      => data_up_valid_la,
            data_up_valid_ioview  => '0',
            data_up_valid_gdb     => '0',
            data_up_valid_wfg     => '0',
            data_up_la            => data_up_la,
            data_up_ioview        => (others => '-'),
            data_up_wfg           => (others => '-'),
            data_up_gdb           => (others => '-')
        );

    la: component LogicAnalyserTop
        generic map(
            DATA_WIDTH  => DATA_WIDTH,
            ADDR_WIDTH  => ADDR_WIDTH,
            ASYNC_RESET => ASYNC_RESET
        )
        port map(
            clk            => clk,
            rst            => rst,
            ce             => ce,
            data_dwn_valid => data_dwn_valid_la,
            data_dwn       => data_dwn,
            data_up_ready  => data_up_ready_la,
            data_up_valid  => data_up_valid_la,
            data_up        => data_up_la,
            sample_enable  => '1',
            probe          => count
        );


end architecture structure;

