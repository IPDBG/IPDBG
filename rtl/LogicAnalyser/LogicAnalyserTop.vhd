library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ipdbg_interface_pkg.all;

entity LogicAnalyserTop is
    generic(
         ADDR_WIDTH      : natural := 4;         --! 2**ADDR_WIDTH = size if sample memory
         ASYNC_RESET     : boolean := true;
         USE_EXT_TRIGGER : boolean := false
    );
    port(
        clk            : in  std_logic;
        rst            : in  std_logic;
        ce             : in  std_logic;

        --      host interface (UART or ....)
        dn_lines       : in  ipdbg_dn_lines;
        up_lines       : out ipdbg_up_lines;

        -- LA interface
        sample_enable  : in  std_logic;
        ext_trigger    : in  std_logic := '1';
        probe          : in  std_logic_vector
    );
end entity LogicAnalyserTop;

architecture structure of LogicAnalyserTop is
    constant DATA_WIDTH : natural := probe'length;

    component LogicAnalyserMemory is
        generic(
            DATA_WIDTH  : natural;
            ADDR_WIDTH  : natural;
            ASYNC_RESET : boolean
        );
        port(
            clk               : in  std_logic;
            rst               : in  std_logic;
            ce                : in  std_logic;
            sample_enable     : in  std_logic;
            probe             : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            trigger_active    : in  std_logic;
            trigger           : in  std_logic;
            full              : out std_logic;
            delay             : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
            data              : out std_logic_vector(DATA_WIDTH-1 downto 0);
            data_valid        : out std_logic;
            data_request_next : in  std_logic;
            finish            : out std_logic
        );
    end component LogicAnalyserMemory;

    component LogicAnalyserTrigger is
        generic(
            DATA_WIDTH  : natural;
            ASYNC_RESET : boolean
        );
        port(
            clk           : in  std_logic;
            rst           : in  std_logic;
            ce            : in  std_logic;
            sample_enable : in  std_logic;
            probe_i       : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            probe_o       : out std_logic_vector(DATA_WIDTH-1 downto 0);
            mask_curr     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            mask_last     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            value_curr    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            value_last    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            mask_edge     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            Trigger       : out std_logic
        );
    end component LogicAnalyserTrigger;

    component LogicAnalyserController is
        generic(
            DATA_WIDTH  : natural;
            ADDR_WIDTH  : natural;
            ASYNC_RESET : boolean
        );
        port(
            clk               : in  std_logic;
            rst               : in  std_logic;
            ce                : in  std_logic;
            dn_lines          : in  ipdbg_dn_lines;
            up_lines          : out ipdbg_up_lines;
            mask_curr         : out std_logic_vector(DATA_WIDTH-1 downto 0);
            value_curr        : out std_logic_vector(DATA_WIDTH-1 downto 0);
            mask_last         : out std_logic_vector(DATA_WIDTH-1 downto 0);
            value_last        : out std_logic_vector(DATA_WIDTH-1 downto 0);
            mask_edge         : out std_logic_vector(DATA_WIDTH-1 downto 0);
            delay             : out std_logic_vector(ADDR_WIDTH-1 downto 0);
            trigger_active    : out std_logic;
            fire_trigger      : out std_logic;
            full              : in  std_logic;
            data              : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            data_request_next : out std_logic;
            data_valid        : in  std_logic;
            finish            : in  std_logic
        );
    end component LogicAnalyserController;

    component IpdbgEscaping is
        generic(
            ASYNC_RESET  : boolean;
            DO_HANDSHAKE : boolean
        );
        port(
            clk          : in  std_logic;
            rst          : in  std_logic;
            ce           : in  std_logic;
            dn_lines_in  : in  ipdbg_dn_lines;
            dn_lines_out : out ipdbg_dn_lines;
            up_lines_out : out ipdbg_up_lines;
            up_lines_in  : in  ipdbg_up_lines;
            reset        : out std_logic
        );
    end component IpdbgEscaping;

    signal mask_curr          : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal value_curr         : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal mask_last          : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal value_last         : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal mask_edge          : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal delay              : std_logic_vector(ADDR_WIDTH-1 downto 0);
    signal trigger_active     : std_logic;
    signal full               : std_logic;
    signal data               : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal data_request_next  : std_logic;
    signal data_valid         : std_logic;
    signal finish             : std_logic;

    signal fire_trigger_cltrl : std_logic;
    signal trigger_logic      : std_logic;

    signal dn_lines_unescaped : ipdbg_dn_lines;
    signal up_lines_unescaped : ipdbg_up_lines;
    signal reset              : std_logic;

    signal sample             : std_logic_vector(DATA_WIDTH-1 downto 0);
begin

    combine_trigger: block
        signal trg : std_logic;
        signal prb : std_logic_vector(DATA_WIDTH-1 downto 0);
    begin
        int_tirgger_logic: if not USE_EXT_TRIGGER generate begin
            process (clk) begin --! combines "manual" and configurable trigger
                if rising_edge(clk) then
                    if ce = '1' then
                        if sample_enable = '1' then
                            prb <= sample;
                            trg <= fire_trigger_cltrl or trigger_logic;
                        end if;
                    end if;
                end if;
            end process;
        end generate;
        ext_trigger_logic: if USE_EXT_TRIGGER generate begin
            process (clk) begin --! combines "manual" and configurable trigger
                if rising_edge(clk) then
                    if ce = '1' then
                        if sample_enable = '1' then
                            prb <= probe;
                            trg <= fire_trigger_cltrl or ext_trigger;
                        end if;
                    end if;
                end if;
            end process;
        end generate;

        memory : component LogicAnalyserMemory
            generic map(
                DATA_WIDTH  => DATA_WIDTH,
                ADDR_WIDTH  => ADDR_WIDTH,
                ASYNC_RESET => ASYNC_RESET
            )
            port map(
                clk               => clk,
                rst               => reset,
                ce                => ce,
                sample_enable     => sample_enable,
                probe             => prb,
                trigger_active    => trigger_active,
                trigger           => trg,
                full              => full,
                delay             => delay,
                data              => data,
                data_valid        => data_valid,
                data_request_next => data_request_next,
                finish            => finish
            );
    end block;

    triggerLogic : component LogicAnalyserTrigger
        generic map(
            DATA_WIDTH  => DATA_WIDTH,
            ASYNC_RESET => ASYNC_RESET
        )
        port map(
            clk           => clk,
            rst           => reset,
            ce            => ce,
            sample_enable => sample_enable,
            probe_i       => probe,
            probe_o       => sample,
            mask_curr     => mask_curr,
            mask_last     => mask_last,
            value_curr    => value_curr,
            value_last    => value_last,
            mask_edge     => mask_edge,
            trigger       => trigger_logic
        );

    controller : component LogicAnalyserController
        generic map(
            DATA_WIDTH  => DATA_WIDTH,
            ADDR_WIDTH  => ADDR_WIDTH,
            ASYNC_RESET => ASYNC_RESET
        )
        port map(
            clk               => clk,
            rst               => reset,
            ce                => ce,
            dn_lines          => dn_lines_unescaped,
            up_lines          => up_lines_unescaped,
            mask_curr         => mask_curr,
            value_curr        => value_curr,
            mask_last         => mask_last,
            value_last        => value_last,
            mask_edge         => mask_edge,
            delay             => delay,
            trigger_active    => trigger_active,
            fire_trigger      => fire_trigger_cltrl,
            full              => full,
            data              => data,
            data_request_next => data_request_next,
            data_valid        => data_valid,
            finish            => finish
        );

    Escaping : component IpdbgEscaping
        generic map(
            ASYNC_RESET  => ASYNC_RESET,
            DO_HANDSHAKE => false
        )
        port map(
            clk          => clk,
            rst          => rst,
            ce           => ce,
            dn_lines_in  => dn_lines,
            dn_lines_out => dn_lines_unescaped,
            up_lines_out => up_lines,
            up_lines_in  => up_lines_unescaped,
            reset        => reset
        );

end architecture structure;
