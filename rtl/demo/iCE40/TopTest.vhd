
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

    signal data_dwn_ioview       : std_logic_vector(7 downto 0);

    signal data_dwn_ready        : std_logic_vector(6 downto 0);
    signal data_dwn_valid        : std_logic_vector(6 downto 0);
    signal data_up_ready         : std_logic_vector(6 downto 0);
    signal data_up_valid         : std_logic_vector(6 downto 0);
    signal data_dwn_ready_ioview : std_logic;
    signal data_dwn_valid_ioview : std_logic;
    signal data_up_ready_ioview  : std_logic;
    signal data_up_valid_ioview  : std_logic;
    signal data_up_ioview        : std_logic_vector(7 downto 0);


begin
    data_dwn_ready <= "0000" & data_dwn_ready_ioview & "00";
    data_up_valid  <= "0000" & data_up_valid_ioview  & "00";
    data_dwn_valid_ioview <= data_dwn_valid(2);
    data_up_ready_ioview <= data_up_ready(2);

    clk <= RefClk;


    JtagExtPins : component TAPExtPins
        port map(
            TDI => TDI,
            TDO => TDO,
            TMS => TMS,
            TCK => TCK
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
            data_up_4             => x"00",
            data_up_5             => x"00",
            data_up_6             => x"00",

            data_dwn_0            => open,
            data_dwn_1            => open,
            data_dwn_2            => data_dwn_ioview,
            data_dwn_3            => open,
            data_dwn_4            => open,
            data_dwn_5            => open,
            data_dwn_6            => open
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
