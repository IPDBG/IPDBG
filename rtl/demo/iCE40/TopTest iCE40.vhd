
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
--use work.lfsr_pkg.all;

--library ice40;


entity TopTestBplR3x is
    generic(
        MFF_LENGTH : natural := 3;
        DATA_WIDTH : natural := 8;        --! width of a sample
        ADDR_WIDTH : natural := 8
    );
    port(
        RefClk      : in  std_logic; -- 10MHz

--        --Sync1_In  : in  std_logic_vector(12 downto 0);
--        Sync1_In    : in  std_logic;
--        --Sync2_In  : in  std_logic_vector(12 downto 0);
--        Sync2_In    : in  std_logic;
--        --Sync1_Out : out std_logic_vector(12 downto 0);
--        Sync1_Out   : out std_logic;
--        --Sync2_Out : out std_logic_vector(12 downto 0);
--        Sync3_In : in std_logic
        Input_DeviceunderTest_IOVIEW     : in std_logic_vector(7 downto 0);
        Output_DeviceunderTest_IOVIEW    : out std_logic_vector(7 downto 0);

        TMS : in  std_logic;
        TCK : in  std_logic;
        TDI : in  std_logic;
        TDO : out std_logic

        --SyncPwr   : in std_logic
    );
end;

architecture rtl of TopTestBplR3x is
--    component TAP is
--        port(
--            rst     : in  std_logic;
--            Capture : out std_logic;
--            Shift   : out std_logic;
--            Update  : out std_logic;
--            TDI_o   : out std_logic;
--            TDO_i   : in  std_logic;
--            SEL     : out std_logic;
--            DRCK    : out std_logic;
--            TDI     : in  std_logic;
--            TDO     : out std_logic;
--            TMS     : in  std_logic;
--            TCK     : in  std_logic
--        );
--    end component TAP;

    component JTAG_HUB is
        generic(
            MFF_LENGTH        : natural;
            TARGET_TECHNOLOGY : natural
        );
        port(
            clk                : in  std_logic;
            rst                : in  std_logic;
            ce                 : in  std_logic;
            DATAOUT            : out std_logic_vector(7 downto 0);
            Enable_LA          : out std_logic;
            Enable_IOVIEW      : out std_logic;
            Enable_GDB         : out std_logic;
            DATAINREADY_LA     : out std_logic;
            DATAINREADY_IOVIEW : out std_logic;
            DATAINREADY_GDB    : out std_logic;
            DATAINVALID_LA     : in  std_logic;
            DATAINVALID_IOVIEW : in  std_logic;
            DATAINVALID_GDB    : in  std_logic;
            DATAIN_LA          : in  std_logic_vector (7 downto 0);
            DATAIN_IOVIEW      : in  std_logic_vector (7 downto 0);
            DATAIN_GDB         : in  std_logic_vector (7 downto 0);
            TDI                : in  std_logic;
            TMS                : in  std_logic;
            TCK                : in  std_logic;
            TDO                : out std_logic
        );
    end component JTAG_HUB;
    component IO_View is
        port(
            clk                           : in  std_logic;
            rst                           : in  std_logic;
            ce                            : in  std_logic;
            DataInValid                   : in  std_logic;
            DataIn                        : in  std_logic_vector(7 downto 0);
            DataOutReady                  : in  std_logic;
            DataOutValid                  : out std_logic;
            DataOut                       : out std_logic_vector(7 downto 0);
            INPUT_DeviceUnderTest_Ioview  : in  std_logic_vector;
            OUTPUT_DeviceUnderTest_Ioview : out std_logic_vector
        );
    end component IO_View;




    signal Capture                       : std_logic;
    signal Shift                         : std_logic;
    signal Update                        : std_logic;
    signal TDI_o                         : std_logic;
    signal TDO_i                         : std_logic;
    signal SEL                           : std_logic;
    signal DRCK                          : std_logic;
    signal DataInValid                   : std_logic;
    signal DataIn                        : std_logic_vector(7 downto 0);
    signal DataOutReady                  : std_logic;
    signal DataOutValid                  : std_logic;
    signal DataOut                       : std_logic_vector(7 downto 0);


    signal Enable_IOVIEW                 : std_logic;
    signal DATAINREADY_IOVIEW            : std_logic;
    signal DATAINVALID_IOVIEW            : std_logic;
    signal DATAIN_IOVIEW                 : std_logic_vector(7 downto 0);



    --signal INPUT_DeviceUnderTest_Ioview  : std_logic_vector;
    --signal OUTPUT_DeviceUnderTest_Ioview : std_logic_vector;

    --signal TMS                          : std_logic;

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

begin

    clk <= RefClk;

    SB_DFF_inst: SB_DFF
    port map (
        Q => rst_tap_n,     -- Registered Output
        C => TCK,           -- Clock
        D => '1'            -- Data
    );
    rst_tap <= not rst_tap_n;


    jtag : component JTAG_HUB
        generic map(
            MFF_LENGTH => MFF_LENGTH,
            TARGET_TECHNOLOGY => 0 -- ipdbg-tap
        )
        port map(
            clk                => clk,
            rst                => rst_tap,
            ce                 => '1',
            DATAOUT            => DATAOUT,
            Enable_LA          => open,
            Enable_IOVIEW      => Enable_IOVIEW,
            Enable_GDB         => open,
            DATAINREADY_LA     => open,
            DATAINREADY_IOVIEW => DATAINREADY_IOVIEW,
            DATAINREADY_GDB    => open,
            DATAINVALID_LA     => '0',
            DATAINVALID_IOVIEW => DATAINVALID_IOVIEW,
            DATAINVALID_GDB    => '0',
            DATAIN_LA          => (others => '0'),
            DATAIN_IOVIEW      => DATAIN_IOVIEW,
            DATAIN_GDB         => (others => '0'),
            TDI                => TDI,
            TMS                => TMS,
            TCK                => TCK,
            TDO                => TDO
        );
    IO : component IO_View
        port map(
            clk                           => clk,
            rst                           => '0',
            ce                            => '1',
            DataInValid                   => Enable_IOVIEW,
            DataIn                        => DATAOUT,
            DataOutReady                  => DATAINREADY_IOVIEW,
            DataOutValid                  => DATAINVALID_IOVIEW,
            DataOut                       => DATAIN_IOVIEW,
            INPUT_DeviceUnderTest_Ioview  => INPUT_DeviceUnderTest_Ioview,
            OUTPUT_DeviceUnderTest_Ioview => OUTPUT_DeviceUnderTest_Ioview
        );



--end architecture structure;
end;