library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ipdbg_interface_pkg.all;

entity JtagHub is
    generic(
        MFF_LENGTH : natural
    );
    port(
        clk        : in  std_logic;
        ce         : in  std_logic;

        dn_lines_0 : out ipdbg_dn_lines;
        dn_lines_1 : out ipdbg_dn_lines;
        dn_lines_2 : out ipdbg_dn_lines;
        dn_lines_3 : out ipdbg_dn_lines;
        dn_lines_4 : out ipdbg_dn_lines;
        dn_lines_5 : out ipdbg_dn_lines;
        dn_lines_6 : out ipdbg_dn_lines;
        up_lines_0 : in  ipdbg_up_lines := unused_up_lines;
        up_lines_1 : in  ipdbg_up_lines := unused_up_lines;
        up_lines_2 : in  ipdbg_up_lines := unused_up_lines;
        up_lines_3 : in  ipdbg_up_lines := unused_up_lines;
        up_lines_4 : in  ipdbg_up_lines := unused_up_lines;
        up_lines_5 : in  ipdbg_up_lines := unused_up_lines;
        up_lines_6 : in  ipdbg_up_lines := unused_up_lines
    );
end entity;

architecture structure of JtagHub is
    function get_data_from_jtag_host(unused : integer) return integer;
    attribute foreign of get_data_from_jtag_host : function is "VHPIDIRECT get_data_from_jtag_host";
    function get_data_from_jtag_host(unused : integer) return integer is
    begin
        assert false severity failure;
    end get_data_from_jtag_host;

    procedure set_data_to_jtag_host(data : integer);
    attribute foreign of set_data_to_jtag_host : procedure is "VHPIDIRECT set_data_to_jtag_host";
    procedure set_data_to_jtag_host(data : integer) is
    begin
        assert false severity failure;
    end set_data_to_jtag_host;


    signal data_dwn       : std_logic_vector(7 downto 0);
    signal data_dwn_ready : std_logic_vector(6 downto 0);
    signal data_dwn_valid : std_logic_vector(6 downto 0);
    signal data_up_ready  : std_logic_vector(6 downto 0);
    signal data_up_valid  : std_logic_vector(6 downto 0);
    type data_up_t        is array (6 downto 0) of std_logic_vector(7 downto 0);
    signal data_up        : data_up_t;

begin
    data_dwn_ready <= up_lines_6.dnlink_ready &
                      up_lines_5.dnlink_ready &
                      up_lines_4.dnlink_ready &
                      up_lines_3.dnlink_ready &
                      up_lines_2.dnlink_ready &
                      up_lines_1.dnlink_ready &
                      up_lines_0.dnlink_ready;

    data_up_valid  <= up_lines_6.uplink_valid &
                      up_lines_5.uplink_valid &
                      up_lines_4.uplink_valid &
                      up_lines_3.uplink_valid &
                      up_lines_2.uplink_valid &
                      up_lines_1.uplink_valid &
                      up_lines_0.uplink_valid;

    data_up(0)     <= up_lines_0.uplink_data;
    data_up(1)     <= up_lines_1.uplink_data;
    data_up(2)     <= up_lines_2.uplink_data;
    data_up(3)     <= up_lines_3.uplink_data;
    data_up(4)     <= up_lines_4.uplink_data;
    data_up(5)     <= up_lines_5.uplink_data;
    data_up(6)     <= up_lines_6.uplink_data;
    process(clk)
        variable data_temp_dwn : std_logic_vector(15 downto 0);
        variable data_temp_up  : std_logic_vector(15 downto 0);

        variable data_pending  : std_logic_vector(3 downto 0);
    begin
        if rising_edge(clk) then
            if ce = '1' then
                if data_pending = "UUUU" then
                    data_pending := x"0";
                end if;
                if data_pending = x"0" then
                    data_temp_dwn := std_logic_vector(to_unsigned(get_data_from_jtag_host(0), data_temp_dwn'length));

                    data_dwn <= data_temp_dwn(7 downto 0);
                    data_pending := data_temp_dwn(11 downto 8);
                end if;

                data_dwn_valid <= (others => '0');
                if data_pending(3) = '1' then
                    for I in 0 to 6 loop
                        if unsigned(data_pending(2 downto 0)) = to_unsigned(I, 3) then
                            if data_dwn_ready(I) = '1' and data_dwn_valid(I) = '0' then
                                data_dwn_valid(I) <= '1'; data_pending := x"0";
                            end if;
                        end if;
                    end loop;
                    if data_pending = x"f" then
                        -- todo: reset
                        data_pending := x"0";
                    end if;
                end if;

                data_up_ready <= (others => '1');
                for I in 0 to 6 loop
                    if data_up_valid(I) = '1' and data_up_ready(I) = '1' then
                        data_up_ready(I) <= '0';
                        data_temp_up := "00001" & std_logic_vector(to_unsigned(I, 3)) & data_up(I);
                        set_data_to_jtag_host(to_integer(to_01(unsigned(data_temp_up))));
                    end if;
                end loop;
            end if;
        end if;
    end process;
    dn_lines_0.dnlink_valid <= data_dwn_valid(0);
    dn_lines_1.dnlink_valid <= data_dwn_valid(1);
    dn_lines_2.dnlink_valid <= data_dwn_valid(2);
    dn_lines_3.dnlink_valid <= data_dwn_valid(3);
    dn_lines_4.dnlink_valid <= data_dwn_valid(4);
    dn_lines_5.dnlink_valid <= data_dwn_valid(5);
    dn_lines_6.dnlink_valid <= data_dwn_valid(6);
    dn_lines_0.dnlink_data <= data_dwn;
    dn_lines_1.dnlink_data <= data_dwn;
    dn_lines_2.dnlink_data <= data_dwn;
    dn_lines_3.dnlink_data <= data_dwn;
    dn_lines_4.dnlink_data <= data_dwn;
    dn_lines_5.dnlink_data <= data_dwn;
    dn_lines_6.dnlink_data <= data_dwn;

    dn_lines_0.uplink_ready <= data_up_ready(0);
    dn_lines_1.uplink_ready <= data_up_ready(1);
    dn_lines_2.uplink_ready <= data_up_ready(2);
    dn_lines_3.uplink_ready <= data_up_ready(3);
    dn_lines_4.uplink_ready <= data_up_ready(4);
    dn_lines_5.uplink_ready <= data_up_ready(5);
    dn_lines_6.uplink_ready <= data_up_ready(6);

end architecture structure;
