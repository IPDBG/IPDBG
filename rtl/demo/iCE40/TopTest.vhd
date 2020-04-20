
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity TopTestBplR3x is
    generic(
        MFF_LENGTH : natural := 3;
        DATA_WIDTH : natural := 8;        --! width of a sample
        ADDR_WIDTH : natural := 8
    );
    port(
        RefClk      : in  std_logic; -- 10MHz

        Input_DeviceunderTest_IOVIEW     : in std_logic_vector(7 downto 0);
        Output_DeviceunderTest_IOVIEW    : out std_logic_vector(7 downto 0);

        TMS : in  std_logic;
        TCK : in  std_logic;
        TDI : in  std_logic;
        TDO : out std_logic
    );
end;

architecture rtl of TopTestBplR3x is
    component JtagHub is
        generic(
            MFF_LENGTH : natural
        );
        port(
            clk                   : in  std_logic;
            ce                    : in  std_logic;
            data_dwn              : out std_logic_vector(7 downto 0);
            data_dwn_ready_la     : in  std_logic;
            data_dwn_ready_ioview : in  std_logic;
            data_dwn_ready_gdb    : in  std_logic;
            data_dwn_ready_wfg    : in  std_logic;
            data_dwn_valid_la     : out std_logic;
            data_dwn_valid_ioview : out std_logic;
            data_dwn_valid_gdb    : out std_logic;
            data_dwn_valid_wfg    : out std_logic;
            data_up_ready_la      : out std_logic;
            data_up_ready_ioview  : out std_logic;
            data_up_ready_gdb     : out std_logic;
            data_up_ready_wfg     : out std_logic;
            data_up_valid_la      : in  std_logic;
            data_up_valid_ioview  : in  std_logic;
            data_up_valid_gdb     : in  std_logic;
            data_up_valid_wfg     : in  std_logic;
            data_up_la            : in  std_logic_vector(7 downto 0);
            data_up_ioview        : in  std_logic_vector(7 downto 0);
            data_up_gdb           : in  std_logic_vector(7 downto 0);
            data_up_wfg           : in  std_logic_vector(7 downto 0)
        );
    end component JtagHub;
    component IoViewTop is
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

    component TAPExtPins is
        port(
            TDI : in  std_logic;
            TDO : out std_logic;
            TMS : in  std_logic;
            TCK : in  std_logic
        );
    end component TAPExtPins;
    component SB_DFF
        port(
            d : in  std_logic;
            c : in  std_logic;
            q : out std_logic
        );
    end component;
    signal rst_tap   : std_logic;
    signal rst_tap_n : std_logic;
    signal clk : std_logic;

    signal data_dwn              : std_logic_vector(7 downto 0);
    signal data_dwn_ready_ioview : std_logic;
    signal data_dwn_valid_ioview : std_logic;
    signal data_up_ready_ioview  : std_logic;
    signal data_up_valid_ioview  : std_logic;
    signal data_up_ioview        : std_logic_vector(7 downto 0);


begin

    clk <= RefClk;


    JtagExtPins : component TAPExtPins
        port map(
            TDI => TDI,
            TDO => TDO,
            TMS => TMS,
            TCK => TCK
        );

    jh : component JtagHub
        generic map(
            MFF_LENGTH => MFF_LENGTH
        )
        port map(
            clk                   => clk,
            ce                    => '1',
            data_dwn              => data_dwn,
            data_dwn_ready_la     => '0',
            data_dwn_ready_ioview => data_dwn_ready_ioview,
            data_dwn_ready_gdb    => '0',
            data_dwn_ready_wfg    => '0',
            data_dwn_valid_la     => open,
            data_dwn_valid_ioview => data_dwn_valid_ioview,
            data_dwn_valid_gdb    => open,
            data_dwn_valid_wfg    => open,
            data_up_ready_la      => open,
            data_up_ready_ioview  => data_up_ready_ioview,
            data_up_ready_gdb     => open,
            data_up_ready_wfg     => open,
            data_up_valid_la      => '0',
            data_up_valid_ioview  => data_up_valid_ioview,
            data_up_valid_gdb     => '0',
            data_up_valid_wfg     => '0',
            data_up_la            => (others => '-'),
            data_up_ioview        => data_up_ioview,
            data_up_gdb           => (others => '-'),
            data_up_wfg           => (others => '-')
        );

    iov : component IoViewTop
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


end architecture rtl;
