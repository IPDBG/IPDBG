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
        DATAINREADY         : out std_logic:= '1';

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
        TDO2         : out std_logic;

------------------------------- Debugging -------------------------------
        LEDS         : out std_logic_vector(7 downto 0)
    );
end entity;


architecture behavioral of JTAG_CDC_Komponente is

---------------------- Datenregister -----------------------------
    signal Shiftregister            : std_logic_vector(11 downto 0);
    signal LaTransferRegister       : std_logic_vector(7 downto 0);

---------------------- Signale Einlesen --------------------------
    signal update_synced             : std_logic := '0';
    signal update_synced_prev        : std_logic := '0';

---------------------- Signale Ausgabe --------------------------
    signal setPending                : std_logic := '0';
    signal pending                   : std_logic := '0';
    signal pending_synched           : std_logic;
    signal acknowledge               : std_logic := '0';

    signal Shiftcounter              : natural := 8;

    signal DATAINREADY_s             : std_logic := '1';

    signal read_GDB                 : std_logic;
    signal read_LA                  : std_logic;
    signal read_IOVIEW              : std_logic;






begin


    TDO1 <= Shiftregister(0);

    process(DRCLK1)begin
        if rising_edge(DRCLK1) then
            if CAPTURE = '1' and USER1 = '1' then
                Shiftregister(8 downto 0) <= '0' & LaTransferRegister;
                Shiftcounter <= 12;
                if read_LA = '1' then
                    Shiftregister (9)  <= '0';
                    Shiftregister (10) <= '0';
                    Shiftregister (11) <= '1';
                end if;
                if read_IOVIEW = '1' then
                    Shiftregister (9)  <= '0';
                    Shiftregister (10) <= '1';
                    Shiftregister (11) <= '0';
                end if;
                if read_GDB = '1' then
                    Shiftregister (9)  <= '1';
                    Shiftregister (10) <= '0';
                    Shiftregister (11) <= '0';
                end if;

            elsif USER1 = '1' and SHIFT = '1' then
                if Shiftcounter /= 0 then
                    Shiftcounter <= Shiftcounter - 1;
                end if;
--                if Shiftcounter = 1 then
--                    acknowledge <= Shiftregister(0);
--                    Shiftregister (9)  <= '0';
--                    Shiftregister (10) <= '0';
--                    Shiftregister (11) <= '0';
--                end if;
--                if Shiftcounter = 5 then
--                    Shiftregister <= TDI & Shiftregister(Shiftregister'left downto 2) & pending_synched;
--                else
--                    Shiftregister <= TDI & Shiftregister(Shiftregister'left downto 1);
--                end if;
                Shiftregister <= TDI & Shiftregister(Shiftregister'left downto 1);
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
                if DataOutRegisterEnable = '1' and Shiftregister(11 downto 9) = "100" and Shiftregister (8) = '1' then
                    Enable_LA <= '1';
                end if;
                if DataOutRegisterEnable = '1' and Shiftregister(11 downto 9) = "010" and Shiftregister (8) = '1' then
                    Enable_IOVIEW <= '1';
                end if;
                if DataOutRegisterEnable = '1' and Shiftregister(11 downto 9) = "001"  and Shiftregister (8) = '1' then
                    Enable_GDB <= '1';
                end if;
            end if;
        end process;

        process(clk) begin
            if rising_edge(clk) then
                --DATAOUTVALID <= '0';
                if DataOutRegisterEnable = '1' then
                    DATAOUT <= Shiftregister(7 downto 0);
                    LEDS <= Shiftregister(7 downto 0);
                    --DATAOUTVALID <= Shiftregister(8);
                end if;
            end if;
        end process;
     end block;

-------------------------------------------Ausgeben-------------------------------------------

    DATAINREADY <= DATAINREADY_s;
    process (clk) begin
        if rising_edge(clk) then
            if setPending = '1' then
                pending <= '1';
            end if;
            setPending <= '0';
            if DATAINREADY_s = '1' then
                if DATAINVALID_LA = '1' then
                    DATAINREADY_s <= '0';
                    read_LA <= '1';
--                    Shiftregister (9) <= '0';
--                    Shiftregister (10) <= '0';
--                    Shiftregister (11) <= '1';
                    LaTransferRegister <= DATAIN_LA;
                    setPending <= '1';
                end if;
                if DATAINVALID_IOVIEW = '1' then
                    DATAINREADY_s <= '0';
                    LaTransferRegister <= DATAIN_IOVIEW;
                    read_IOVIEW <= '1';
--                    Shiftregister (9) <= '0';
--                    Shiftregister (10) <= '1';
--                    Shiftregister (11) <= '0';
                    setPending <= '1';
                end if;
                if DATAINVALID_GDB = '1' then
                    DATAINREADY_s <= '0';
                    LaTransferRegister <= DATAIN_GDB;
                    read_GDB <= '1';
--                    Shiftregister (9) <= '1';
--                    Shiftregister (10) <= '0';
--                    Shiftregister (11) <= '0';
                    setPending <= '1';
                end if;
            elsif update_synced = '1' and update_synced_prev = '0' then
                if acknowledge = '1' then
                    pending <= '0';
                    DATAINREADY_s <= '1';
                    read_GDB <= '0';
                    read_IOVIEW <= '0';
                    read_LA <= '0';
                end if;
            end if;
        end if;
    end process;


    pending_dffp: block
        signal x : std_logic_vector(8 downto 0);
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

        mffx_flops: for K in 0 to 7 generate begin

            MFF : dffp
                port map
                (
                  clk => DRCLK1,
                  ce  => '1',
                  d   => x(K),
                  q   => x(K+1)
                );
        end generate;


        pending_synched <= x(8);
        --pending_synched <= x(7);

    end block;





end architecture behavioral;



