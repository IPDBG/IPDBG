library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity JtagCdc is
    generic(
        MFF_LENGTH : natural := 3
    );
    port(
        clk                 : in  std_logic;
        ce                  : in  std_logic;
-------------------------- to Device under Test --------------------------
        DATAOUT             : out std_logic_vector(7 downto 0);

        Enable_LA           : out std_logic;
        Enable_IOVIEW       : out std_logic;
        Enable_GDB          : out std_logic;

-------------------------- from Device under Test ------------------------
        DATAINREADY_LA      : out std_logic;
        DATAINREADY_IOVIEW  : out std_logic;
        DATAINREADY_GDB     : out std_logic;

        --DATAINVALID     : in std_logic;
        DATAINVALID_LA      : in std_logic;
        DATAINVALID_IOVIEW  : in std_logic;
        DATAINVALID_GDB     : in std_logic;

        DATAIN_LA           : in std_logic_vector(7 downto 0);
        DATAIN_IOVIEW       : in std_logic_vector(7 downto 0);
        DATAIN_GDB          : in std_logic_vector(7 downto 0);

-------------------------- BSCAN-Componente (Debugging) ------------------
        DRCLK               : in  std_logic;
        USER                : in  std_logic;
        UPDATE              : in  std_logic;
        CAPTURE             : in  std_logic;
        SHIFT               : in  std_logic;
        TDI                 : in  std_logic;
        TDO                 : out std_logic
    );
end entity;


architecture behavioral of JtagCdc is

---------------------- Datenregister -----------------------------
    signal shift_register         : std_logic_vector(11 downto 0);
    signal la_transfer_register   : std_logic_vector(7 downto 0);
    signal channel_register       : std_logic_vector(2 downto 0);

---------------------- Signale Einlesen --------------------------
    signal update_synced          : std_logic;
    signal update_synced_prev     : std_logic;

---------------------- Signale Ausgabe --------------------------
    signal set_pending            : std_logic;
    signal pending                : std_logic;
    signal pending_synched        : std_logic;
    signal acknowledge            : std_logic;

    signal shift_counter          : natural range 0 to 12;

    signal data_in_ready_ioview_s : std_logic;
    signal data_in_ready_la_s     : std_logic;
    signal data_in_ready_gdb_s    : std_logic;
    signal clear                  : std_logic;

    signal register_la            : std_logic_vector(7 downto 0);
    signal register_gdb           : std_logic_vector(7 downto 0);
    signal register_ioview        : std_logic_vector(7 downto 0);

    type mux_t                    is(GDB_s, LA_s, IOVIEW_s);
    signal ent_mux                : mux_t :=  GDB_s;
    type transfer_t               is (is_active, is_idle);
    signal transfer               : transfer_t;

begin


    TDO <= shift_register(0);

    process(DRCLK)begin
        if rising_edge(DRCLK) then
            if CAPTURE = '1' and USER = '1' then

                shift_register <= '0' & channel_register & la_transfer_register;
                shift_counter <= 12;

            elsif USER = '1' and SHIFT = '1' then
                if shift_counter /= 0 then
                    shift_counter <= shift_counter - 1;
                end if;
                if shift_counter = 1 then
                    acknowledge <= shift_register(0);
                end if;
                if shift_counter = 2 then
                    shift_register <= TDI & shift_register(shift_register'left downto 2) & pending_synched;
                else
                    shift_register <= TDI & shift_register(shift_register'left downto 1);
                end if;
            end if;
        end if;
    end process;

-------------------------------------------Einlesen-------------------------------------------

    cdc: block
        signal x : std_logic_vector(MFF_LENGTH downto 0);
        component dffpc is
            port(
                clk : in  std_logic;
                ce  : in  std_logic;
                d   : in  std_logic;
                q   : out std_logic
            );
        end component dffpc;
    begin

        x(0) <= UPDATE and USER;

        mff_flops: for K in 0 to MFF_LENGTH-1 generate begin

            MFF : dffpc
                port map(
                    clk => clk,
                    ce  => ce,
                    d   => x(K),
                    q   => x(K+1)
                );
        end generate;

        update_synced <= x(MFF_LENGTH);

    end block;

    outputControl : block
        signal data_out_register_enable : std_logic := '0';
    begin
         process (clk) begin
            if rising_edge(clk) then
                data_out_register_enable <= '0';
                update_synced_prev       <= update_synced;
                if update_synced = '1' and update_synced_prev = '0' then -- detect 0 -> 1 change
                    data_out_register_enable <= '1';
                end if;
            end if;
        end process;

        process (clk) begin
            if rising_edge (clk) then
                Enable_LA <= '0';
                Enable_IOVIEW <= '0';
                Enable_GDB <= '0';
                clear <= '0';
                if data_out_register_enable = '1' and shift_register(10 downto 8) = "100" and shift_register (11) = '1' then
                    Enable_LA <= '1';
                end if;
                if data_out_register_enable = '1' and shift_register(10 downto 8) = "010" and shift_register (11) = '1' then
                    Enable_IOVIEW <= '1';
                end if;
                if data_out_register_enable = '1' and shift_register(10 downto 8) = "001"  and shift_register (11) = '1' then
                    Enable_GDB <= '1';
                end if;
                if data_out_register_enable = '1' and shift_register(10 downto 8) = "111"  and shift_register (11) = '1' then
                    clear <= '1';
                end if;
            end if;
        end process;

        process(clk) begin
            if rising_edge(clk) then
                if data_out_register_enable = '1' then
                    DATAOUT <= shift_register(7 downto 0);
                end if;
            end if;
        end process;
     end block;

-------------------------------------------Ausgeben-------------------------------------------

    DATAINREADY_LA <= data_in_ready_la_s;
    DATAINREADY_GDB <= data_in_ready_gdb_s;
    DATAINREADY_IOVIEW <= data_in_ready_ioview_s;
    process (clk) begin
        if rising_edge(clk) then
            if clear = '1' then
                pending <= '0';
                data_in_ready_gdb_s <= '1';
                data_in_ready_la_s <= '1';
                data_in_ready_ioview_s <= '1';
                register_la <= (others => '-');
                register_ioview <= (others => '-');
                register_gdb <= (others => '-');
            else
                if set_pending = '1' then
                    pending <= '1';
                end if;
                if data_in_ready_la_s = '1' then
                    if DATAINVALID_LA = '1' then
                        data_in_ready_la_s <= '0';
                        register_la <= DATAIN_LA;
                    end if;
                end if;

                if data_in_ready_ioview_s = '1' then
                    if DATAINVALID_IOVIEW = '1' then
                        data_in_ready_ioview_s <= '0';
                        register_ioview <= DATAIN_IOVIEW;
                    end if;
                end if;

                if data_in_ready_gdb_s = '1' then
                    if DATAINVALID_GDB = '1' then
                        data_in_ready_gdb_s <= '0';
                        register_gdb <= DATAIN_GDB;
                    end if;
                end if;
                if update_synced = '1' and update_synced_prev = '0' then
                    if acknowledge = '1' then
                        pending <= '0';
                        if channel_register = "001" then
                            data_in_ready_gdb_s <= '1';
                        end if;

                        if channel_register = "100" then
                            data_in_ready_la_s <= '1';
                        end if;
                        if channel_register = "010" then
                            data_in_ready_ioview_s <= '1';
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    process (clk) begin
        if rising_edge(clk) then
            if clear = '1' then
                set_pending <= '0';
                ent_mux <= GDB_s;
                transfer <= is_idle;
                channel_register <= "---";
            else
                set_pending <= '0';
                case ent_mux is
                    when GDB_s =>
                        if data_in_ready_gdb_s = '1' then
                            ent_mux <= LA_s;
                            transfer <= is_idle;
                        else
                            la_transfer_register <= register_gdb;
                            if transfer = is_idle then
                                set_pending <= '1';
                                transfer <= is_active;
                            end if;
                            channel_register <= "001";
                        end if;

                    when LA_s =>
                        if data_in_ready_la_s = '1' then
                            ent_mux <= IOVIEW_s;
                            transfer <= is_idle;
                        else
                            la_transfer_register <= register_la;
                            if transfer = is_idle then
                                set_pending <= '1';
                                transfer <= is_active;
                            end if;
                            channel_register <= "100";
                        end if;

                    when IOVIEW_s =>
                        if data_in_ready_ioview_s = '1' then
                            ent_mux <= GDB_s;
                            transfer <= is_idle;
                        else
                            la_transfer_register <= register_ioview;
                            if transfer = is_idle then
                                set_pending <= '1';
                                transfer <= is_active;
                            end if;
                            channel_register <= "010";
                        end if;
                end case;
            end if;
        end if;
    end process;

    pending_dffpc: block
        signal x : std_logic_vector(11 downto 0);
        component dffpc is
            port(
                clk : in  std_logic;
                ce  : in  std_logic;
                d   : in  std_logic;
                q   : out std_logic
            );
        end component dffpc;
    begin
        x(0) <= pending and USER;

        mffx_flops: for K in 0 to 10 generate begin
            MFF : dffpc
                port map(
                    clk => DRCLK,
                    ce  => '1',
                    d   => x(K),
                    q   => x(K+1)
                );
            end generate;
        pending_synched <= x(11);
    end block;

end architecture behavioral;
