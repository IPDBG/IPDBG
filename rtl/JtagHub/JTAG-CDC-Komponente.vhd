library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity JTAG_CDC_Komponente is
    generic(
        MFF_LENGTH : natural := 3
    );
    port(
        clk                 : in  std_logic;
        rst                 : in  std_logic;
        ce                  : in  std_logic;
-------------------------- to Device under Test --------------------------
        DATAOUT             : out std_logic_vector(7 downto 0);
        --DATAOUTVALID : out std_logic;

        Enable_LA           : out std_logic;
        Enable_IOVIEW       : out std_logic;
        Enable_GDB          : out std_logic;

-------------------------- from Device under Test ------------------------
        DATAINREADY_LA      : out std_logic:= '1';
        DATAINREADY_IOVIEW  : out std_logic:= '1';
        DATAINREADY_GDB     : out std_logic:= '1';

        --DATAINVALID     : in std_logic;
        DATAINVALID_LA      : in std_logic;
        DATAINVALID_IOVIEW  : in std_logic;
        DATAINVALID_GDB     : in std_logic;

        DATAIN_LA           : in std_logic_vector (7 downto 0);
        DATAIN_IOVIEW       : in std_logic_vector (7 downto 0);
        DATAIN_GDB          : in std_logic_vector (7 downto 0);
-------------------------- BSCAN-Componente (Debugging) ------------------
        DRCLK1       : in  std_logic;
        DRCLK2       : in  std_logic;
        USER1        : in  std_logic;
        USER2        : in  std_logic;
        UPDATE       : in  std_logic;
        CAPTURE      : in  std_logic;
        SHIFT        : in  std_logic;
        TDI          : in  std_logic;
        TDO1         : out std_logic;
        TDO2         : out std_logic
    );
end entity;


architecture behavioral of JTAG_CDC_Komponente is

---------------------- Datenregister -----------------------------
    signal Shiftregister            : std_logic_vector(11 downto 0);
    signal LaTransferRegister       : std_logic_vector(7 downto 0);
    signal ChannelRegister          : std_logic_vector(2 downto 0);

---------------------- Signale Einlesen --------------------------
    signal update_synced             : std_logic := '0';
    signal update_synced_prev        : std_logic := '0';

---------------------- Signale Ausgabe --------------------------
    signal setPending                : std_logic := '0';
    signal pending                   : std_logic := '0';
    signal pending_synched           : std_logic := '0';
    signal acknowledge               : std_logic := '0';

    signal Shiftcounter              : natural := 12;

    signal DATAINREADY_IOVIEW_s      : std_logic := '1';
    signal DATAINREADY_LA_s          : std_logic := '1';
    signal DATAINREADY_GDB_s         : std_logic := '1';



    signal Register_LA          : std_logic_vector(7 downto 0);
    signal Register_GDB         : std_logic_vector(7 downto 0);
    signal Register_IOVIEW      : std_logic_vector(7 downto 0);

     --signal transfer_LA              : std_logic;
     --signal transfer_GDB              : std_logic;
     --signal transfer_IOVIEW            : std_logic;




    type MUX is(GDB_s, LA_s, IOVIEW_s);
    signal ent_mux    : MUX :=  GDB_s;
    type transfer_t is (is_active, is_idle);
    signal transfer : transfer_t;



begin


    TDO1 <= Shiftregister(0);

    process(DRCLK1)begin
        if rising_edge(DRCLK1) then
            if CAPTURE = '1' and USER1 = '1' then
                --Shiftregister(8 downto 0) <= '0' & LaTransferRegister;
                Shiftregister <= '0' & ChannelRegister & LaTransferRegister;
                Shiftcounter <= 12;

            elsif USER1 = '1' and SHIFT = '1' then
                if Shiftcounter /= 0 then
                    Shiftcounter <= Shiftcounter - 1;
                end if;
                if Shiftcounter = 1 then
                    acknowledge <= Shiftregister(0);
                end if;
                if Shiftcounter = 2 then
                    Shiftregister <= TDI & Shiftregister(Shiftregister'left downto 2) & pending_synched;
                else
                    Shiftregister <= TDI & Shiftregister(Shiftregister'left downto 1);
                end if;
            end if;
        end if;
    end process;

-------------------------------------------Einlesen-------------------------------------------

    cdc: block
        signal x : std_logic_vector(MFF_LENGTH downto 0);
        component dffp is
            port(
                clk : in  std_logic;
                ce  : in  std_logic;
                d   : in  std_logic;
                q   : out std_logic
            );
        end component dffp;

    begin

        x(0) <= UPDATE and USER1;

        mff_flops: for K in 0 to MFF_LENGTH-1 generate begin

            MFF : dffp
                port map
                (
                  clk => clk,
                  ce  => ce,
                  d   => x(K),
                  q   => x(K+1)
                );
        end generate;

        update_synced <= x(MFF_LENGTH);

    end block;




    outputControl : block
        signal DataOutRegisterEnable : std_logic := '0';
    begin
         process (clk) begin
            if rising_edge(clk) then
                DataOutRegisterEnable <= '0';
                update_synced_prev <= update_synced;
                if update_synced = '1' and update_synced_prev = '0' then -- detect 0 -> 1 change
                    DataOutRegisterEnable <= '1';
                end if;
            end if;
        end process;

        process (clk) begin
            if rising_edge (clk) then
                Enable_LA <= '0';
                Enable_IOVIEW <= '0';
                Enable_GDB <= '0';
                if DataOutRegisterEnable = '1' and Shiftregister(10 downto 8) = "100" and Shiftregister (11) = '1' then
                    Enable_LA <= '1';
                end if;
                if DataOutRegisterEnable = '1' and Shiftregister(10 downto 8) = "010" and Shiftregister (11) = '1' then
                    Enable_IOVIEW <= '1';
                end if;
                if DataOutRegisterEnable = '1' and Shiftregister(10 downto 8) = "001"  and Shiftregister (11) = '1' then
                    Enable_GDB <= '1';
                end if;
            end if;
        end process;

        process(clk) begin
            if rising_edge(clk) then
                if DataOutRegisterEnable = '1' then
                    DATAOUT <= Shiftregister(7 downto 0);
                end if;
            end if;
        end process;
     end block;

-------------------------------------------Ausgeben-------------------------------------------

    DATAINREADY_LA <= DATAINREADY_LA_s;
    DATAINREADY_GDB <= DATAINREADY_GDB_s;
    DATAINREADY_IOVIEW <= DATAINREADY_IOVIEW_s;
    process (clk) begin
        if rising_edge(clk) then
            if setPending = '1' then
                pending <= '1';
            end if;
            if DATAINREADY_LA_s = '1' then
                if DATAINVALID_LA = '1' then
                    DATAINREADY_LA_s <= '0';
                    Register_LA <= DATAIN_LA;
                end if;
            end if;

            if DATAINREADY_IOVIEW_s = '1' then
                if DATAINVALID_IOVIEW = '1' then
                    DATAINREADY_IOVIEW_s <= '0';
                    Register_IOVIEW <= DATAIN_IOVIEW;
                end if;
            end if;

            if DATAINREADY_GDB_s = '1' then
                if DATAINVALID_GDB = '1' then
                    DATAINREADY_GDB_s <= '0';
                    Register_GDB <= DATAIN_GDB;
                end if;
            end if;
            if update_synced = '1' and update_synced_prev = '0' then
                if acknowledge = '1' then
                    pending <= '0';
                    if ChannelRegister = "001" then
                        DATAINREADY_GDB_s <= '1';
                    end if;

                    if ChannelRegister = "100" then
                        DATAINREADY_LA_s <= '1';
                    end if;
                    if ChannelRegister = "010" then
                        DATAINREADY_IOVIEW_s <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;


    process (clk) begin
        if rising_edge(clk) then
            setPending <= '0';
            case ent_mux is
                when GDB_s =>
                    if DATAINREADY_GDB_s = '1' then
                        ent_mux <= LA_s;
                        transfer <= is_idle;
                    else
                        LaTransferRegister <= Register_GDB;
                        if transfer = is_idle then
                            setPending <= '1';
                            transfer <= is_active;
                        end if;
                        ChannelRegister <= "001";
                    end if;

                when LA_s =>
                    if DATAINREADY_LA_s = '1' then
                        ent_mux <= IOVIEW_s;
                        transfer <= is_idle;
                    else
                        LaTransferRegister <= Register_LA;
                        if transfer = is_idle then
                            setPending <= '1';
                            transfer <= is_active;
                        end if;
                        ChannelRegister <= "100";
                    end if;

                when IOVIEW_s =>
                    if DATAINREADY_IOVIEW_s = '1' then
                        ent_mux <= GDB_s;
                        transfer <= is_idle;
                    else
                        LaTransferRegister <= Register_IOVIEW;
                        if transfer = is_idle then
                            setPending <= '1';
                            transfer <= is_active;
                        end if;
                        ChannelRegister <= "010";
                    end if;
            end case;




--            IOVIEW <= '0';
--            if zaehler = 0 then
--                if transfer_IOVIEW = '1' then
--                    zaehler <= 1;
--                    --LaTransferRegister <= Register_IOVIEW;
--                    --IOVIEW <= '1';
--                else
--                    zaehler <= 1;
--                end if;
--            end if;
--            if zaehler = 1 then
--                if transfer_LA = '1' then
--                    zaehler <= 2;
--                    --DATAINREADY_LA_s <= '0';
----                    LaTransferRegister <= Register_LA;
--                    LA <= '1';
--                else
--                    zaehler <= 2;
--                end if;
--            end if;
--            if zaehler = 2 then
--                if transfer_GDB = '1' then
--                    zaehler <= 0;
--                    --DATAINREADY_GDB_s <= '0';
----                    LaTransferRegister <= Register_LA;
--                    LA <= '1';
--                else
--                    zaehler <= 0;
--                end if;
--            end if;
        end if;
    end process;





    pending_dffp: block
        signal x : std_logic_vector(11 downto 0);
        component dffp is
            port(
                clk : in  std_logic;
                ce  : in  std_logic;
                d   : in  std_logic;
                q   : out std_logic
            );
        end component dffp;

    begin

        x(0) <= pending and USER1;

        mffx_flops: for K in 0 to 10 generate begin

            MFF : dffp
                port map
                (
                  clk => DRCLK1,
                  ce  => '1',
                  d   => x(K),
                  q   => x(K+1)
                );
        end generate;


        --pending_synched <= x(8);
        pending_synched <= x(11);

    end block;





end architecture behavioral;



