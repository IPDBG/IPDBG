library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity IPDBG is
    generic(
        MFF_LENGTH : natural := 3;
        DATA_WIDTH : natural := 8;        --! width of a sample
        ADDR_WIDTH : natural := 8
    );
    port(
        clk                              : in  std_logic;

        Input_DeviceunderTest_IOVIEW     : in std_logic_vector(7 downto 0);
        Output_DeviceunderTest_IOVIEW    : out std_logic_vector(7 downto 0);
-------------------------- Debugging ------------------------
        Leds            : out std_logic_vector (7 downto 0)
    );
end IPDBG;

architecture structure of IPDBG is
    component Zaehler is
        generic(
            DATA_WIDTH : natural
        );
        port(
            clk      : in  std_logic;
            rst      : in  std_logic;
            ce       : in  std_logic;
            DatenOut : out std_logic_vector(DATA_WIDTH-1 downto 0)
        );
    end component Zaehler;
    component JtagHub is
        generic(
            MFF_LENGTH       : natural;
            HANDSHAKE_ENABLE : std_logic_vector(6 downto 0)
        );
        port(
            clk                   : in  std_logic;
            ce                    : in  std_logic;
            data_dwn_ready        : in  std_logic_vector(6 downto 0);
            data_dwn_valid        : out std_logic_vector(6 downto 0);
            data_dwn_0            : out std_logic_vector(7 downto 0);
            data_dwn_1            : out std_logic_vector(7 downto 0);
            data_dwn_2            : out std_logic_vector(7 downto 0);
            data_dwn_3            : out std_logic_vector(7 downto 0);
            data_dwn_4            : out std_logic_vector(7 downto 0);
            data_dwn_5            : out std_logic_vector(7 downto 0);
            data_dwn_6            : out std_logic_vector(7 downto 0);
            data_up_ready         : out std_logic_vector(6 downto 0);
            data_up_valid         : in  std_logic_vector(6 downto 0);
            data_up_0             : in  std_logic_vector(7 downto 0);
            data_up_1             : in  std_logic_vector(7 downto 0);
            data_up_2             : in  std_logic_vector(7 downto 0);
            data_up_3             : in  std_logic_vector(7 downto 0);
            data_up_4             : in  std_logic_vector(7 downto 0);
            data_up_5             : in  std_logic_vector(7 downto 0);
            data_up_6             : in  std_logic_vector(7 downto 0)
        );
    end component JtagHub;


    component IoViewTop is
        generic(
            ASYNC_RESET : boolean
        );
        port(
            clk            : in  std_logic;
            rst            : in  std_logic;
            ce             : in  std_logic;
            data_dwn_ready : out std_logic;
            data_dwn_valid : in  std_logic;
            data_dwn       : in  std_logic_vector(7 downto 0);
            data_up_ready  : in  std_logic;
            data_up_valid  : out std_logic;
            data_up        : out std_logic_vector(7 downto 0);
            probe_inputs   : in  std_logic_vector;
            probe_outputs  : out std_logic_vector
        );
    end component IoViewTop;

    component LogicAnalyserTop is
        generic(
            ADDR_WIDTH  : natural;
            ASYNC_RESET : boolean
        );
        port(
            clk            : in  std_logic;
            rst            : in  std_logic;
            ce             : in  std_logic;
            data_dwn_ready : out std_logic;
            data_dwn_valid : in  std_logic;
            data_dwn       : in  std_logic_vector(7 downto 0);
            data_up_ready  : in  std_logic;
            data_up_valid  : out std_logic;
            data_up        : out std_logic_vector(7 downto 0);
            sample_enable  : in  std_logic;
            probe          : in  std_logic_vector
        );
    end component LogicAnalyserTop;

    signal data_dwn_la           : std_logic_vector(7 downto 0);
    signal data_dwn_ioview       : std_logic_vector(7 downto 0);

    signal data_dwn_ready        : std_logic_vector(6 downto 0);
    signal data_dwn_valid        : std_logic_vector(6 downto 0);
    signal data_dwn_ready_la     : std_logic;
    signal data_dwn_valid_la     : std_logic;
    signal data_dwn_ready_ioview : std_logic;
    signal data_dwn_valid_ioview : std_logic;
    signal data_up_ready_la      : std_logic;
    signal data_up_ready_ioview  : std_logic;
    signal data_up_valid_la      : std_logic;
    signal data_up_valid_ioview  : std_logic;
    signal data_up_la            : std_logic_vector(7 downto 0);
    signal data_up_ioview        : std_logic_vector(7 downto 0);

    signal DataIn_LogicAnalyser  : std_logic_vector(DATA_WIDTH-1 downto 0);

begin

    data_dwn_ready <= "00" & data_dwn_ready_la & '0' & data_dwn_ready_ioview & "00";
    data_up_valid  <= "00" & data_up_valid_la  & '0' & data_up_valid_ioview  & "00";
    data_dwn_valid_la     <= data_dwn_valid(4);
    data_dwn_valid_ioview <= data_dwn_valid(2);
    data_up_ready_la     <= data_up_ready(4);
    data_up_ready_ioview <= data_up_ready(2);

    DUT : component Zaehler
        generic map(
            DATA_WIDTH => DATA_WIDTH
        )
        port map(
            clk      => clk,
            rst      => '0',
            ce       => '1',
            DatenOut => DataIn_LogicAnalyser
        );

    la : component LogicAnalyserTop
        generic map(
            ADDR_WIDTH  => ADDR_WIDTH,
            ASYNC_RESET => false
        )
        port map(
            clk            => clk,
            rst            => '0',
            ce             => '1',
            data_dwn_ready => data_dwn_ready_la,
            data_dwn_valid => data_dwn_valid_la,
            data_dwn       => data_dwn,
            data_up_ready  => data_up_ready_la,
            data_up_valid  => data_up_valid_la,
            data_up        => data_up_la,
            sample_enable  => '1',
            probe          => DataIn_LogicAnalyser
        );

    iov : component IoViewTop
        generic map(
            ASYNC_RESET => false
        )
        port map(
            clk            => clk,
            rst            => '0',
            ce             => '1',
            data_dwn_ready => data_dwn_ready_ioview,
            data_dwn_valid => data_dwn_valid_ioview,
            data_dwn       => data_dwn,
            data_up_ready  => data_up_ready_ioview,
            data_up_valid  => data_up_valid_ioview,
            data_up        => data_up_ioview,
            probe_inputs   => Input_DeviceunderTest_IOVIEW,
            probe_outputs  => Output_DeviceunderTest_IOVIEW
        );


    JH : component JtagHub
        generic map(
            MFF_LENGTH => MFF_LENGTH,
            HANDSHAKE_ENABLE => "0000010"
        )
        port map(
            clk                   => Clk,
            ce                    => '1',
            data_dwn_ready        => data_dwn_ready,
            data_dwn_valid        => data_dwn_valid,

            data_up_ready         => data_up_ready,
            data_up_valid         => data_up_valid,
            data_up_0             => x"00",
            data_up_1             => x"00",
            data_up_2             => data_up_ioview,
            data_up_3             => x"00",
            data_up_4             => data_up_la,
            data_up_5             => x"00",
            data_up_6             => x"00",

            data_dwn_0            => open,
            data_dwn_1            => open,
            data_dwn_2            => data_dwn_ioview,
            data_dwn_3            => open,
            data_dwn_4            => data_dwn_la,
            data_dwn_5            => open,
            data_dwn_6            => open
        );

end architecture structure;
