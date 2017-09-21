library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity IpdbgEscaping is
    generic(
         ASYNC_RESET : boolean := true
    );
    port(
        clk            : in  std_logic;
        rst            : in  std_logic;
        ce             : in  std_logic;

        data_in_valid  : in  std_logic;
        data_in        : in  std_logic_vector(7 downto 0);
        data_out_valid : out std_logic;
        data_out       : out std_logic_vector(7 downto 0);

        reset          : out std_logic
    );
end entity IpdbgEscaping;

architecture behavioral of IpdbgEscaping is
    constant escape_symbol : std_logic_vector (7 downto 0) := x"55"; --55
    constant reset_symbol  : std_logic_vector (7 downto 0) := x"EE"; --EE

    type escaping_states_t is(normal_s, escaping_s);
    signal state          : escaping_states_t;
    signal arst, srst     : std_logic;
begin
    async_init: if ASYNC_RESET generate begin
        arst <= rst;
        srst <= '0';
    end generate async_init;
    sync_init: if not ASYNC_RESET generate begin
        arst <= '0';
        srst <= rst;
    end generate sync_init;

    process (clk, arst)
        procedure rst_assignments is begin
            reset <= '1';
            data_out_valid <= '0';
            data_out <= (others => '-');
            state <= normal_s;
        end procedure rst_assignments;
    begin
        if arst = '1' then
            rst_assignments;
        elsif rising_edge(clk) then
            if srst = '1' then
                rst_assignments;
            else
                if ce = '1' then
                    data_out_valid <= '0';
                    reset <= '0';
                    data_out <= data_in;
                    if data_in_valid = '1' then
                        case state is
                        when normal_s =>
                            if data_in = escape_symbol then
                                state <= escaping_s;
                            elsif data_in = reset_symbol  then
                                reset <= '1';
                            else
                                data_out_valid <= '1';
                            end if;
                        when escaping_s =>
                            state <= normal_s;
                            data_out_valid <= '1';
                        end case;
                    end if;
                end if;
            end if;
        end if;
    end process;

end architecture behavioral;
