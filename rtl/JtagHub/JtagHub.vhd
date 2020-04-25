library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity JtagHub is
    generic(
        MFF_LENGTH       : natural := 3;
        HANDSHAKE_ENABLE : std_logic_vector(6 downto 0) := "0000010"
    );
    port(
        clk                   : in  std_logic;
        ce                    : in  std_logic;
-------------------------- to function
        data_dwn_ready        : in  std_logic_vector(6 downto 0);
        data_dwn_valid        : out std_logic_vector(6 downto 0);
        data_dwn_0            : out std_logic_vector(7 downto 0);
        data_dwn_1            : out std_logic_vector(7 downto 0);
        data_dwn_2            : out std_logic_vector(7 downto 0);
        data_dwn_3            : out std_logic_vector(7 downto 0);
        data_dwn_4            : out std_logic_vector(7 downto 0);
        data_dwn_5            : out std_logic_vector(7 downto 0);
        data_dwn_6            : out std_logic_vector(7 downto 0);

-------------------------- from function
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
end entity JtagHub;

architecture structure of JtagHub is
    component JtagCdc is
        generic(
            MFF_LENGTH : natural
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

            DRCLK                 : in  std_logic;
            USER                  : in  std_logic;
            UPDATE                : in  std_logic;
            CAPTURE               : in  std_logic;
            SHIFT                 : in  std_logic;
            TDI                   : in  std_logic;
            TDO                   : out std_logic
        );
    end component JtagCdc;
    component IpdbgTap is
        port(
            capture         : out std_logic;
            drclk           : out std_logic;
            user            : out std_logic;
            shift           : out std_logic;
            update          : out std_logic;
            tdi             : out std_logic;
            tdo             : in  std_logic
        );
    end component IpdbgTap;

    signal DRCLK        : std_logic;
    signal USER         : std_logic;
    signal UPDATE       : std_logic;
    signal CAPTURE      : std_logic;
    signal SHIFT        : std_logic;
    signal TDI          : std_logic;
    signal TDO          : std_logic;

begin

    TT: component IpdbgTap
        port map (
            capture => CAPTURE,
            drclk   => DRCLK,
            user    => USER,
            shift   => SHIFT,
            update  => UPDATE,
            tdi     => TDI,
            tdo     => TDO
        );

    CDC : component JtagCdc
        generic map(
            MFF_LENGTH => MFF_LENGTH
        )
        port map(
            clk            => clk,
            ce             => ce,
            data_dwn_ready => data_dwn_ready,
            data_dwn_valid => data_dwn_valid,
            data_dwn_0     => data_dwn_0,
            data_dwn_1     => data_dwn_1,
            data_dwn_2     => data_dwn_2,
            data_dwn_3     => data_dwn_3,
            data_dwn_4     => data_dwn_4,
            data_dwn_5     => data_dwn_5,
            data_dwn_6     => data_dwn_6,
            data_up_ready  => data_up_ready,
            data_up_valid  => data_up_valid,
            data_up_0      => data_up_0,
            data_up_1      => data_up_1,
            data_up_2      => data_up_2,
            data_up_3      => data_up_3,
            data_up_4      => data_up_4,
            data_up_5      => data_up_5,
            data_up_6      => data_up_6,
            DRCLK          => DRCLK,
            USER           => USER,
            UPDATE         => UPDATE,
            CAPTURE        => CAPTURE,
            SHIFT          => SHIFT,
            TDI            => TDI,
            TDO            => TDO
        );

end architecture structure;
