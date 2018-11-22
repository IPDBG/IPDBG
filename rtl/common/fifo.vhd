library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity Fifo is
    generic
    (
        EXTRA_LEVEL_COUNTER : boolean := false;
        ASYNC_RESET         : boolean := false;
        MEM_DEPTH           : integer := 4
    );
    port
    (
        clk                : in  std_logic;
        rst                : in  std_logic;
        ce                 : in  std_logic;

        full               : out std_logic;
        write_data_enable  : in  std_logic;
        write_data         : in  std_logic_vector;

        empty              : out std_logic;
        read_data_enable   : in  std_logic;
        read_data          : out std_logic_vector
    );
end Fifo;


architecture Behavioral of Fifo is
    component PdpRam is
        generic(
            OUTPUT_REG : boolean
        );
        port(
            clk           : in  std_logic;
            ce            : in  std_logic;
            write_enable  : in  std_logic;
            write_address : in  std_logic_vector;
            write_data    : in  std_logic_vector;
            read_address  : in  std_logic_vector;
            read_data     : out std_logic_vector
        );
    end component PdpRam;

    signal write_position : integer range 0 to 2**MEM_DEPTH -1;
    signal read_position  : integer range 0 to 2**MEM_DEPTH -1;


    signal arst , srst : std_logic;
begin

    assert write_data'length = read_data'length report "read and write port must have the same width" severity failure;

    gen_arst: if ASYNC_RESET generate begin
        arst <= rst;
        srst <= '0';
    end generate gen_arst;
    gen_srst:  if not ASYNC_RESET generate begin
        arst <= '0';
        srst <= rst;
    end generate gen_srst;

    houskeeping: block
        signal empty_local                : std_logic;
        signal full_local                 : std_logic;
    begin
        no_level_counter : if not EXTRA_LEVEL_COUNTER generate begin
            process (clk,arst) begin
                if arst = '1' then
                    empty_local <= '1';
                    full_local  <= '0';
                elsif rising_edge(clk) then
                    if srst = '1' then
                        empty_local <= '1';
                        full_local  <= '0';
                    else
                        if ce = '1' then
                            if write_data_enable = '1' and read_data_enable = '0' then
                                empty_local <= '0';
                            elsif read_data_enable = '1' and write_data_enable = '0' and ((read_position+1) mod 2**MEM_DEPTH) = write_position then
                                empty_local <= '1';
                            end if;

                            if write_data_enable = '0' and read_data_enable = '1' then
                                full_local <= '0';
                            elsif read_data_enable = '0' and write_data_enable = '1' and ((write_position+1) mod 2**MEM_DEPTH) = read_position then
                                full_local <= '1';
                            end if;
                        end if;
                    end if;
                end if;
            end process;
        end generate;

        level_counter : if EXTRA_LEVEL_COUNTER generate
            signal counter : natural range 0 to 2**MEM_DEPTH;
            signal cnt_u   : unsigned(MEM_DEPTH downto 0);
        begin

            cnt_u <= to_unsigned(counter, MEM_DEPTH+1);

            full_local <= cnt_u(cnt_u'left);

            process (clk,arst) begin

                if arst = '1' then
                    empty_local <= '1';
                    counter <= 0;
                elsif rising_edge(clk) then
                    if srst = '1' then
                        empty_local <= '1';
                        counter <= 0;
                    else
                        if ce = '1' then

                            if write_data_enable = '1' and read_data_enable = '0' then
                                counter <= counter +1;
                                empty_local <= '0';
                            elsif write_data_enable = '0' and read_data_enable = '1' then
                                counter <= counter -1;
                                if counter = 1 then
                                    empty_local <= '1';
                                end if;
                            end if;

                        end if;
                    end if;
                end if;
            end process;
        end generate;

        empty <= empty_local;
        full  <= full_local;

        process (clk,arst) begin
            if arst = '1' then
                write_position <= 0;
                read_position <= 0;
            elsif rising_edge(clk) then
                if srst = '1' then
                    write_position <= 0;
                    read_position <= 0;
                else
                    if ce = '1' then
                        if write_data_enable = '1' then
                            if write_position = 2**MEM_DEPTH -1 then
                                write_position <= 0;
                            else
                                write_position <= write_position + 1;
                            end if;
                        end if;
                        if read_data_enable = '1' then
                            if read_position = 2**MEM_DEPTH -1 then
                                read_position <= 0;
                            else
                                read_position <= read_position + 1;
                            end if;
                        end if;
                    end if;
                end if;
            end if;
        end process;
    end block;

    mem: block
        signal write_address : std_logic_vector(MEM_DEPTH-1 downto 0);
        signal read_address  : std_logic_vector(MEM_DEPTH-1 downto 0);
    begin

        write_address <= std_logic_vector(to_01(to_unsigned(write_position, write_address'length)));
        read_address <= std_logic_vector(to_01(to_unsigned(read_position, read_address'length)));

        memory : component PdpRam
            generic map(
                OUTPUT_REG => true
            )
            port map(
                clk           => clk,
                ce            => ce,
                write_enable  => write_data_enable,
                write_address => write_address,
                write_data    => write_data,
                read_address  => read_address,
                read_data     => read_data
            );
    end block;

end Behavioral;
