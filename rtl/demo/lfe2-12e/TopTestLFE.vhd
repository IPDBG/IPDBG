
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity TopTestLFE is
    generic(
        MFF_LENGTH : natural             := 3;
        DATA_WIDTH : natural             := 8;        --! width of a sample
        ADDR_WIDTH : natural             := 8
    );
    port(
        RefClk                           : in  std_logic; -- 10MHz

        Input_DeviceunderTest_IOVIEW     : in  std_logic_vector(7 downto 0);
        Output_DeviceunderTest_IOVIEW    : out std_logic_vector(7 downto 0);

        Leds                             : out std_logic_vector(7 downto 0);

        debug                            : out std_logic_vector(3 downto 0)



    );
end TopTestLFE;

architecture structure of TopTestLFE is

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
            --debug              : out std_logic_vector(7 downto 0)
            debug              : out std_logic_vector(3 downto 0);
            Leds               : out std_logic_vector(7 downto 0)

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
            OUTPUT_DeviceUnderTest_Ioview : out std_logic_vector;
            debug                         : out std_logic_vector(7 downto 0)
        );
    end component IO_View;

	component pll0
		port (CLK: in std_logic; CLKOP: out std_logic; LOCK: out std_logic);
	end component;



    --signal Capture                       : std_logic;
    --signal Shift                         : std_logic;
    --signal Update                        : std_logic;
    --signal TDI_o                         : std_logic;
    --signal TDO_i                         : std_logic;
    --signal SEL                           : std_logic;
    --signal DRCK                          : std_logic;
    --signal DataInValid                   : std_logic;
    --signal DataIn                        : std_logic_vector(7 downto 0);
    --signal DataOutReady                  : std_logic;
    --signal DataOutValid                  : std_logic;
    signal DataOut                       : std_logic_vector(7 downto 0);


    signal Enable_IOVIEW                 : std_logic;
    signal DATAINREADY_IOVIEW            : std_logic;
    signal DATAINVALID_IOVIEW            : std_logic;
    signal DATAIN_IOVIEW                 : std_logic_vector(7 downto 0);

    signal clk                           : std_logic;
	signal rst, rst_n                    : std_logic;
    --signal LEDS_s                        : std_logic_vector(7 downto 0) := "00000001";
    -- signal x                            :  unsigned(15 downto 0) := (others => '0');
    signal debug_s                        : std_logic_vector(7 downto 0);
    signal OUTPUT_DeviceUnderTest_Ioview_s : std_logic_vector(7 downto 0);
begin

    --clk <= RefClk;
--    Leds <= LEDS_s;
--
	ourPll : pll0
    port map (CLK=>RefClk, CLKOP=>clk, LOCK=>rst_n);

	rst <= not rst_n;


--    process (clk, rst) begin
--	    if rst = '1' then
--			debug_s <= (others => '0');
--        elsif rising_edge(clk) then
--            debug_s <= std_logic_vector(unsigned(debug_s)+1);
--        end if;
--    end process;



    --debug <= debug_s(0) & debug_s(6) & debug_s(6) & debug_s(4);
    --leds <= debug_s;
    leds <= OUTPUT_DeviceUnderTest_Ioview_s;



    jtag : component JTAG_HUB
        generic map(
            MFF_LENGTH => MFF_LENGTH,
            TARGET_TECHNOLOGY => 2 -- Lattice LFE2
        )
        port map(
            clk                => clk,
            rst                => rst,
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

            debug              => debug,--debug_s
            Leds               => open--leds
        );
    IO : component IO_View
        port map(
            clk                           => clk,
            rst                           => rst,
            ce                            => '1',

            DataInValid                   => Enable_IOVIEW,
            DataIn                        => DATAOUT,

            DataOutReady                  => DATAINREADY_IOVIEW,
            DataOutValid                  => DATAINVALID_IOVIEW,
            DataOut                       => DATAIN_IOVIEW,

            INPUT_DeviceUnderTest_Ioview  => INPUT_DeviceUnderTest_Ioview,
            OUTPUT_DeviceUnderTest_Ioview => OUTPUT_DeviceUnderTest_Ioview_s,
            debug                         => open
        );
    OUTPUT_DeviceUnderTest_Ioview <= OUTPUT_DeviceUnderTest_Ioview_s;
end;
