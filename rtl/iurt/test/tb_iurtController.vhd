library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_iurtController is
end tb_iurtController;

architecture test of tb_iurtController is
    component IurtController is
        generic(
            ASYNC_RESET : boolean
        );
        port(
            clk            : in  std_logic;
            rst            : in  std_logic;
            ce             : in  std_logic;
            cyc_i          : in  std_logic;
            stb_i          : in  std_logic;
            we_i           : in  std_logic;
            adr_i          : in  std_logic_vector(2 downto 2);
            dat_i          : in  std_logic_vector(31 downto 0);
            dat_o          : out std_logic_vector(31 downto 0);
            ack_o          : out std_logic;
            break_o        : out std_logic;
            data_dwn_ready : out std_logic;
            data_dwn_valid : in  std_logic;
            data_dwn       : in  std_logic_vector(7 downto 0);
            data_up_ready  : in  std_logic;
            data_up_valid  : out std_logic;
            data_up        : out std_logic_vector(7 downto 0)
        );
    end component IurtController;
    signal clk                 : std_logic;
    signal rst                 : std_logic;
    signal ce                  : std_logic;
    signal stbcyc             : std_logic;
    signal cyc_i               : std_logic;
    signal stb_i               : std_logic;
    signal we_i                : std_logic;
    signal adr_i               : std_logic_vector(2 downto 2);
    signal dat_i               : std_logic_vector(31 downto 0);
    signal dat_o               : std_logic_vector(31 downto 0);
    signal ack_o               : std_logic;
    signal break_o             : std_logic;
    signal data_dwn_ready      : std_logic;
    signal data_dwn_valid      : std_logic;
    signal data_dwn            : std_logic_vector(7 downto 0);
    signal data_up_ready       : std_logic;
    signal data_up_valid       : std_logic;
    signal data_up             : std_logic_vector(7 downto 0);
    constant T                 : time := 10 ns;
    signal counter            : natural range 0 to 255;
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

    cyc_i <= stbcyc;
    stb_i <= stbcyc;


    process begin
        adr_i <= "0";
        dat_i <= x"00000080";
        we_i            <= '1';

        stbcyc <= '0';
        wait until rising_edge (clk);
        wait for T/5;
        wait for 5*T;

        for k in 1 to 2 loop
            for i in 1 to 16 loop
                if dat_i(7 downto 0) = x"80" then
                    dat_i <= x"00000001";
                else
                    dat_i <= std_logic_vector(unsigned(dat_i) SLL 1);
                end if;
                stbcyc <= '1';

                wait until rising_edge(clk) and ack_o = '1';

                if i > 8 then
                    stbcyc <= '0';
                    wait for T;
                end if;
            end loop;
            stbcyc <= '0';
            wait for T;
        end loop;

        wait for 10*T;

        stbcyc <= '1';
        we_i <= '0';

        wait;
    end process;


    process begin
        counter <= 0;
        data_up_ready <= '1';
        data_dwn_valid <= '0';
        data_dwn <= x"00";

        wait until rising_edge(clk);
        wait for T/5;
        wait for 5*T;

        for k in 1 to 2 loop
            for i in 1 to 16 loop
                wait until rising_edge(clk) and data_up_valid = '1';
                wait for T/5;

                counter <= counter + 1;

                if k = 2 then
                    data_up_ready <= '0';
                    wait for 5*T;
                    data_up_ready <= '1';
                end if;

            end loop;
        end loop;

        wait for 10*T;

        for i in 1 to 20 loop
            wait until rising_edge(clk) and data_dwn_ready = '1';
            wait for T/5;
            data_dwn_valid <= '1';
            data_dwn <= std_logic_vector(unsigned(data_dwn) + 1);

            wait for T;
            data_dwn_valid <= '0';
        end loop;

        wait;
    end process;





    uut : component IurtController
        generic map(
            ASYNC_RESET => false
        )
        port map(
            clk            => clk,
            rst            => rst,
            ce             => ce,
            cyc_i          => cyc_i,
            stb_i          => stb_i,
            we_i           => we_i,
            adr_i          => adr_i,
            dat_i          => dat_i,
            dat_o          => dat_o,
            ack_o          => ack_o,
            break_o        => break_o,
            data_dwn_ready => data_dwn_ready,
            data_dwn_valid => data_dwn_valid,
            data_dwn       => data_dwn,
            data_up_ready  => data_up_ready,
            data_up_valid  => data_up_valid,
            data_up        => data_up
        );

end architecture test;
