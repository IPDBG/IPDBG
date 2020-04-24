library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity tb_JtagCdc is
end entity tb_JtagCdc;

architecture test of tb_JtagCdc is
    component JtagCdc is
        generic(
            MFF_LENGTH       : natural := 3;
            --PORT_ENABLE : std_logic_vector(6 downto 0) := "0000010" -- only iurt has handshaking enabled
            HANDSHAKE_ENABLE : std_logic_vector(6 downto 0) := "0000010" -- only iurt has handshaking enabled
        );
        port(
            clk                   : in  std_logic;
            ce                    : in  std_logic;


            --data_clk              : in  std_logic_vector(6 downto 0);
    -------------------------- to function
            data_dwn_0            : out std_logic_vector(7 downto 0);
            data_dwn_1            : out std_logic_vector(7 downto 0);
            data_dwn_2            : out std_logic_vector(7 downto 0);
            data_dwn_3            : out std_logic_vector(7 downto 0);
            data_dwn_4            : out std_logic_vector(7 downto 0);
            data_dwn_5            : out std_logic_vector(7 downto 0);
            data_dwn_6            : out std_logic_vector(7 downto 0);
            data_dwn_valid        : out std_logic_vector(6 downto 0);
            data_dwn_ready        : in  std_logic_vector(6 downto 0);

    -------------------------- from function
            data_up_ready         : out std_logic_vector(6 downto 0);
            data_up_valid         : in  std_logic_vector(6 downto 0);

            data_up_0             : in  std_logic_vector(7 downto 0);
            data_up_1             : in  std_logic_vector(7 downto 0);
            data_up_2             : in  std_logic_vector(7 downto 0);
            data_up_3             : in  std_logic_vector(7 downto 0);
            data_up_4             : in  std_logic_vector(7 downto 0);
            data_up_5             : in  std_logic_vector(7 downto 0);
            data_up_6             : in  std_logic_vector(7 downto 0);

    -------------------------- BSCAN-Component
            DRCLK                : in  std_logic;
            USER                 : in  std_logic;
            UPDATE               : in  std_logic;
            CAPTURE              : in  std_logic;
            SHIFT                : in  std_logic;
            TDI                  : in  std_logic;
            TDO                  : out std_logic
        );
    end component JtagCdc;

    signal clk                 : std_logic;
    signal ce                  : std_logic;


    signal data_dwn_0          : std_logic_vector(7 downto 0);
    signal data_dwn_1          : std_logic_vector(7 downto 0);
    signal data_dwn_2          : std_logic_vector(7 downto 0);
    signal data_dwn_3          : std_logic_vector(7 downto 0);
    signal data_dwn_4          : std_logic_vector(7 downto 0);
    signal data_dwn_5          : std_logic_vector(7 downto 0);
    signal data_dwn_6          : std_logic_vector(7 downto 0);

    signal data_dwn_valid      : std_logic_vector(6 downto 0);
    signal data_dwn_ready      : std_logic_vector(6 downto 0);

    signal data_up_0           : std_logic_vector(7 downto 0);
    signal data_up_1           : std_logic_vector(7 downto 0);
    signal data_up_2           : std_logic_vector(7 downto 0);
    signal data_up_3           : std_logic_vector(7 downto 0);
    signal data_up_4           : std_logic_vector(7 downto 0);
    signal data_up_5           : std_logic_vector(7 downto 0);
    signal data_up_6           : std_logic_vector(7 downto 0);

    signal data_up_ready       : std_logic_vector(6 downto 0);
    signal data_up_valid       : std_logic_vector(6 downto 0);

    signal DRCLK               : std_logic;
    signal USER                : std_logic;
    signal UPDATE              : std_logic;
    signal CAPTURE             : std_logic;
    signal SHIFT               : std_logic;
    signal TDI                 : std_logic;
    signal TDO                 : std_logic;

    signal dwn_ready           : std_logic;
    signal dwn_valid           : std_logic;
    signal dwn                 : std_logic_vector(7 downto 0);
    signal up_ready            : std_logic;
    signal up_valid            : std_logic;
    signal up                  : std_logic_vector(7 downto 0);

    constant T                 : time := 5 ns;
begin

    process begin
        clk <= '0';
        wait for T;
        clk <= '1';
        wait for T;
    end process;
    ce <= '1';

    dwn_valid <= data_dwn_valid(1);
    data_dwn_ready <= "00000" & dwn_ready & '0';
    dwn <= data_dwn_1;

    up_ready <= data_up_ready(1);
    data_up_valid <= "00000" & up_valid & '0';
    data_up_1 <= up;
    data_up_0 <= x"00";
    data_up_2 <= x"00";
    data_up_3 <= x"00";
    data_up_4 <= x"00";
    data_up_5 <= x"00";
    data_up_6 <= x"00";



    USER      <= '1';
    jtag_transfers: process
        constant TH : time := 98 ns;
        constant TL : time := 100 ns;
        constant TD : time := 2 ns;
        procedure trx(
            constant v  : in std_logic;
            constant ch : in std_logic_vector(2 downto 0);
            constant d  : in std_logic_vector(7 downto 0))
        is
            variable sr : std_logic_vector(12 downto 0) := v & '0' & ch & d;
        begin

            DRCLK <= '0';
            CAPTURE <= '0';
            UPDATE <= '0';
            wait for TL;
            wait for TD;
            CAPTURE <= '1';
            wait for TH;
            wait for TL;

            for i in 1 to 13 loop
                DRCLK   <= '1';
                wait for TD;
                CAPTURE <= '0';
                SHIFT <= '1';
                TDI <= sr(0);
                wait for TH;

                DRCLK   <= '0';
                sr := '-' & sr(12 downto 1);
                wait for TL;
            end loop;

            DRCLK   <= '1';
            wait for TD;
            SHIFT <= '0';
            UPDATE <= '1';
            wait for TH;
            DRCLK   <= '0';
            wait for TL;

            DRCLK   <= '1';
            wait for TD;
            UPDATE <= '0';
            wait for TH;
            DRCLK   <= '0';
            wait for TL;

        end procedure;
    begin
        DRCLK     <= '0';

        UPDATE    <= '0';
        CAPTURE   <= '0';
        SHIFT     <= '0';
        TDI       <= '0';
        wait for 100*T;
        trx('1', "111", x"00");  -- reset


        wait for 100*T;
        trx('1', "001", x"42");
        wait for 100*T;
        trx('1', "001", x"43");
        wait for 100*T;
        trx('1', "001", x"44");

        wait for 100*T;
        trx('1', "001", x"52");
        wait for 100*T;
        trx('1', "001", x"53");
        wait for 100*T;
        trx('0', "000", x"00");

        for I in 1 to 10 loop
            wait for 100*T;
            trx('0', "000", x"00");
        end loop;
        wait;
    end process;


    process begin
        dwn_ready <= '1';
        for i in 1 to 3 loop
            wait until dwn_valid'event and dwn_valid = '1';
        end loop;
        wait until rising_edge(clk);
        wait for T/5;

        dwn_ready <= '0';

        wait for 15 us;
        wait until rising_edge(clk);
        wait for T/5;

        dwn_ready <= '1';
        wait;
    end process;


    process begin

        up_valid <= '0';
        up <= x"32";

        wait for 50 us;
        wait until rising_edge(clk);
        wait for T/5;
        up_valid <= '1';
        wait for 2*T;
        up_valid <= '0';
        wait for T;


        wait;
    end process;


    uut: component JtagCdc
        generic map (
            MFF_LENGTH       => 3,
            HANDSHAKE_ENABLE => "0000010" -- only iurt has handshaking enabled
        )
        port map(
            clk            => clk,
            ce             => ce,
            data_dwn_valid => data_dwn_valid,
            data_dwn_ready => data_dwn_ready,
            data_dwn_0     => data_dwn_0,
            data_dwn_1     => data_dwn_1,
            data_dwn_2     => data_dwn_2,
            data_dwn_3     => data_dwn_3,
            data_dwn_4     => data_dwn_4,
            data_dwn_5     => data_dwn_5,
            data_dwn_6     => data_dwn_6,
            data_up_valid  => data_up_valid,
            data_up_ready  => data_up_ready,
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

end architecture test;
