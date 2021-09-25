library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity JtagAdapter is
    generic(
        MIN_PERIOD : time := 100 ns
    );
    port(
        TMS     : out std_logic;
        TCK     : out std_logic;
        TDI     : out std_logic;
        TDO     : in  std_logic;
        TRST    : out std_logic;
        SRST    : out std_logic
    );
end entity JtagAdapter;

architecture structure of JtagAdapter is

    function get_bitbang_function return integer;
    attribute foreign of get_bitbang_function : function is "VHPIDIRECT get_bitbang_function";
    function get_bitbang_function return integer is
    begin
        assert false severity failure;
    end get_bitbang_function;

    procedure set_binbang_readresponse(data : integer);
    attribute foreign of set_binbang_readresponse : procedure is "VHPIDIRECT set_binbang_readresponse";
    procedure set_binbang_readresponse(data : integer) is
    begin
        assert false severity failure;
    end set_binbang_readresponse;

    constant HALF_PERIOD : time := MIN_PERIOD / 2;

    signal blink         : std_logic;

begin

    process
        variable command  : character;
        variable response : character;
    begin
        TMS   <= '0';
        TCK   <= '0';
        TDI   <= '0';
        TRST  <= '0';
        SRST  <= '0';
        blink <= '0';
        wait for 10 * MIN_PERIOD;
        while true loop
            command := character'val(get_bitbang_function);
            case command is
            when 'Q' => -- exit;                             -- Quit request
            when 'B' => blink <= '1'; next;                  -- Blink on
            when 'b' => blink <= '0'; next;                  -- Blink off
            when 'R' =>                                      -- Read request
                if TDO = '1' then
                    response := '1';
                else
                    response := '0';
                end if;
                set_binbang_readresponse(character'pos(response));
                next;
            when '0' => TCK <= '0'; TMS <= '0'; TDI <= '0';  -- Write
            when '1' => TCK <= '0'; TMS <= '0'; TDI <= '1';  -- Write
            when '2' => TCK <= '0'; TMS <= '1'; TDI <= '0';  -- Write
            when '3' => TCK <= '0'; TMS <= '1'; TDI <= '1';  -- Write
            when '4' => TCK <= '1'; TMS <= '0'; TDI <= '0';  -- Write
            when '5' => TCK <= '1'; TMS <= '0'; TDI <= '1';  -- Write
            when '6' => TCK <= '1'; TMS <= '1'; TDI <= '0';  -- Write
            when '7' => TCK <= '1'; TMS <= '1'; TDI <= '1';  -- Write
            when 'r' => TRST <= '0'; SRST <= '0';            -- Reset
            when 's' => TRST <= '0'; SRST <= '1';            -- Reset
            when 't' => TRST <= '1'; SRST <= '0';            -- Reset
            when 'u' => TRST <= '1'; SRST <= '1';            -- Reset
            when others => next;
            end case;
            wait for HALF_PERIOD;
        end loop;
        wait;
    end process;

end architecture structure;

