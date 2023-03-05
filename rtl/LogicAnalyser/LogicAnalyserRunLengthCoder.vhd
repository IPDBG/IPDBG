library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity LogicAnalyserRunLengthCoder is
    generic(
        DATA_WIDTH             : natural := 8;
        ASYNC_RESET            : boolean := true;
        RUN_LENGTH_COMPRESSION : natural := 0
    );
    port(
        clk             : in  std_logic;
        rst             : in  std_logic;
        ce              : in  std_logic;

        sample_enable_i : in  std_logic;
        probe_i         : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
        trig_i          : in  std_logic;
        sample_enable_o : out std_logic;
        probe_o         : out std_logic_vector(DATA_WIDTH + RUN_LENGTH_COMPRESSION - 1 downto 0);
        trig_o          : out std_logic
    );
end entity LogicAnalyserRunLengthCoder;


architecture behavioral of LogicAnalyserRunLengthCoder is
begin
    no_rlc: if RUN_LENGTH_COMPRESSION = 0 generate begin
        probe_o <= probe_i;
        trig_o <= trig_i;
        sample_enable_o <= sample_enable_i;
    end generate;

    gen_rlc: if RUN_LENGTH_COMPRESSION > 0 generate
        signal arst, srst  : std_logic;
        signal count       : unsigned(RUN_LENGTH_COMPRESSION - 1 downto 0);
        signal probe_last  : std_logic_vector(DATA_WIDTH - 1 downto 0);
        signal trig_last   : std_logic;
        constant count_max : unsigned(RUN_LENGTH_COMPRESSION - 1 downto 0) := (others => '1');
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
                probe_o <= (others => '-');
                trig_o <= '-';
                sample_enable_o <= '0';
                count <= (others => '0');
                probe_last <= (others => '-');
                trig_last <= '-';
            end procedure;
        begin
            if arst = '1' then
                rst_assignments;
            elsif rising_edge(clk) then
                if srst = '1' then
                    rst_assignments;
                else
                    if ce = '1' then
                        sample_enable_o <= '0';
                        if sample_enable_i = '1' then
                            probe_last <= probe_i;
                            trig_last <= trig_i;
                            -- trigger can be externally generated and don't necessary comes together with a change in the data
                            if trig_last /= trig_i or
                                probe_last /= probe_i or
                                count = count_max
                            then
                                count <= (others => '0');
                                trig_o <= trig_last;
                                probe_o <= probe_last & std_logic_vector(count);
                                sample_enable_o <= '1';
                                --report "adding compressed word runlength = " & integer'image(to_integer(count));
                            else
                                count <= count + 1;
                            end if;
                        end if;
                    end if;
                end if;
            end if;
        end process;
    end generate;

end architecture behavioral;
