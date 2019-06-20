library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity LogicAnalyserTrigger is
    generic(
         DATA_WIDTH  : natural := 8;
         ASYNC_RESET : boolean := true
    );
    port(
        clk             : in  std_logic;
        rst             : in  std_logic;
        ce              : in  std_logic;

        sample_enable   : in  std_logic;
        probe_i         : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        probe_o         : out std_logic_vector(DATA_WIDTH-1 downto 0); -- delayed sample to match timing of trigger output

        mask_curr       : in  std_logic_vector(DATA_WIDTH-1 downto 0); -- masks the relevant bits from current sample
        mask_last       : in  std_logic_vector(DATA_WIDTH-1 downto 0); -- masks the relevant bits from last sample
        value_curr      : in  std_logic_vector(DATA_WIDTH-1 downto 0); -- value which the current sample must have to activate the trigger (bits which are '0' in mask_curr are ignored)
        value_last      : in  std_logic_vector(DATA_WIDTH-1 downto 0); -- value which the last sample must have had to activate the trigger (bits which are '0' in mask_last are ignored)
        mask_edge       : in  std_logic_vector(DATA_WIDTH-1 downto 0);

        trigger         : out std_logic                                -- Trigger output
    );
end entity LogicAnalyserTrigger;


architecture behavioral of LogicAnalyserTrigger is
    signal probe_last  : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal mask_curr_n : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal mask_last_n : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal mask_edge_n : std_logic_vector(DATA_WIDTH-1 downto 0);
    constant all_ones  : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '1');
    signal arst, srst  : std_logic;
begin
    async_init: if ASYNC_RESET generate begin
        arst <= rst;
        srst <= '0';
    end generate async_init;
    sync_init: if not ASYNC_RESET generate begin
        arst <= '0';
        srst <= rst;
    end generate sync_init;

    mask_last_n <= not mask_last;
    mask_curr_n <= not mask_curr;
    mask_edge_n <= not mask_edge;

    process (clk, arst)
        variable current_probe_eq_value       : std_logic_vector(DATA_WIDTH-1 downto 0);
        variable last_probe_match             : std_logic_vector(DATA_WIDTH-1 downto 0);
        variable last_and_current_probe_match : std_logic_vector(DATA_WIDTH-1 downto 0);
        variable last_probe_eq_value          : std_logic_vector(DATA_WIDTH-1 downto 0);
        variable edge_match                   : std_logic_vector(DATA_WIDTH-1 downto 0);
    begin
        if arst = '1' then
            trigger <= '0';
        elsif rising_edge(clk) then
            if srst = '1' then
                trigger <= '0';
            else
                if ce = '1' then
                    if sample_enable = '1' then

                        for idx in 0 to DATA_WIDTH-1 loop
                            probe_last(idx) <= probe_i(idx);

                            current_probe_eq_value(idx) := '0';
                            if probe_i(idx) = value_curr(idx) then
                                current_probe_eq_value(idx) := '1';
                            end if;

                            last_probe_eq_value(idx) := '0';
                            if probe_last(idx) = value_last(idx) then
                                last_probe_eq_value(idx) := '1';
                            end if;

                            last_probe_match(idx):= last_probe_eq_value(idx) or mask_last_n(idx);
                            last_and_current_probe_match(idx) := last_probe_match(idx) and current_probe_eq_value(idx);

                            edge_match(idx) := mask_edge_n(idx) or (probe_last(idx) xor probe_i(idx));

                        end loop;

                        trigger <= '0';
                        if ((last_and_current_probe_match or mask_curr_n) and edge_match) = all_ones then
                            trigger <= '1';
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;
    probe_o <= probe_last;

end architecture behavioral;
