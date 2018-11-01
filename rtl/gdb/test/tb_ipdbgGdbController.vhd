library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_ipdbgGdbController is
    generic(
        output_wb_boolean : boolean := false
        break_test        : boolean := false
    );
end tb_ipdbgGdbController;

architecture test of tb_ipdbgGdbController is
    component IpdbgGdbController is
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
            break          : out std_logic;
            data_dwn_valid : in  std_logic;
            data_dwn       : in  std_logic_vector(7 downto 0);
            data_up_ready  : in  std_logic;
            data_up_valid  : out std_logic;
            data_up        : out std_logic_vector(7 downto 0)
        );
    end component IpdbgGdbController;
    constant input_wb_boolean  : boolean := not output_wb_boolean;
    signal clk                 : std_logic;
    signal rst                 : std_logic;
    signal ce                  : std_logic;
    signal cyc_i               : std_logic;
    signal stb_i               : std_logic;
    signal we_i                : std_logic;
    signal adr_i               : std_logic_vector(2 downto 2);
    signal dat_i               : std_logic_vector(31 downto 0);
    signal dat_o               : std_logic_vector(31 downto 0);
    signal ack_o               : std_logic;
    signal break               : std_logic;
    signal data_dwn_valid      : std_logic;
    signal data_dwn            : std_logic_vector(7 downto 0);
    signal data_up_ready       : std_logic;
    signal data_up_valid       : std_logic;
    signal data_up             : std_logic_vector(7 downto 0);
    constant T                 : time := 10 ns;
    signal data                : std_logic_vector(7 downto 0);
    signal count               : natural :=0 ;
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

    counter : process begin
        wait until rising_edge (clk);

        if count <= 10 then
            count <= count +1;
        else
            count <= 0 ;
        end if;

    end process;

    handshake : process begin
            wait for T;
            if count <= 5 then
                stb_i <= '1';
            else
                stb_i <= '0';
            end if;

            if count <= 8 then
                cyc_i <= '1';
            else
                cyc_i <= '0';
            end if;

    end process;


    output : if  output_wb_boolean generate begin
        process begin
            data_dwn <=  x"01";
            data_dwn_valid <= '0';
            we_i  <= '0';
            adr_i <= "0";

            wait until rising_edge(clk);
            wait for T/7;
            for i in 1 to 20 loop
                if count = 0 then
                    data_dwn <= x"01";
                end if;
                wait for T;
                if count <= 10 then
                    data_dwn <= std_logic_vector(unsigned(data_dwn) SLL 1);
                    data_dwn_valid <= '1';
                else
                    data_dwn_valid <= '0';
                end if;

            end loop;
        end process;
    end generate;

    input : if input_wb_boolean generate begin

        process begin
            adr_i <= "0";
            dat_i <= x"00000001";
            we_i            <= '1';
            data_up_ready   <= '1';
            while true loop
                wait until rising_edge(clk);
                    if count = 0 then
                        dat_i <= x"00000001";
                    end if;

                    if count <= 10 then
                        wait for 1*T;
                        dat_i <= std_logic_vector(unsigned(dat_i) SLL 1);
                    end if;

                end loop;
        end process;
    end generate;
    break_gen : if  break_test generate begin

    end generate;




    uut : component IpdbgGdbController
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
            break          => break,
            data_dwn_valid => data_dwn_valid,
            data_dwn       => data_dwn,
            data_up_ready  => data_up_ready,
            data_up_valid  => data_up_valid,
            data_up        => data_up
        );

end architecture test;
