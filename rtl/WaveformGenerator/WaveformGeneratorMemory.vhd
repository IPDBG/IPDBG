library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity WaveformGeneratorMemory is
    generic(
        DATA_WIDTH       : natural := 8;
        ADDR_WIDTH       : natural := 8
    );
    port(
        clk              : in  std_logic;
        rst              : in  std_logic;
        ce               : in  std_logic := '1';

        Enable           : in  std_logic;
        SampleEnable     : in  std_logic := '1';
        AddrOfLastSample : in  std_logic_vector(ADDR_WIDTH-1 downto 0); -- Length Of Waveform - 1
        DataOut          : out std_logic_vector(DATA_WIDTH-1 downto 0);
        FirstSample      : out std_logic;

        -- write
        DataIn           : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        DataValid        : in  std_logic;
        DataIfReset      : in  std_logic
    );
end entity WaveformGeneratorMemory;


architecture behavioral of WaveformGeneratorMemory is

    component pdpRam is
        generic(
            DATA_WIDTH     : natural;
            ADDR_WIDTH     : natural;
            INIT_FILE_NAME : string;
            OUTPUT_REG     : boolean
        );
        port(
            clk          : in  std_logic;
            ce           : in  std_logic;
            writeEnable  : in  std_logic;
            writeAddress : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
            writeData    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            readAddress  : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
            readData     : out std_logic_vector(DATA_WIDTH-1 downto 0)
        );
    end component pdpRam;

    constant RAM_OUTPUT_REG  : boolean := true;

    signal FirstSample_s     : std_logic;

    signal adr_r             :  unsigned(ADDR_WIDTH-1 downto 0) := (others => '0');
    signal readData          : std_logic_vector(DATA_WIDTH-1 downto 0);

    signal we                : std_logic;
    signal writeData         : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal adr_w             : unsigned(ADDR_WIDTH-1 downto 0) := (others => '0');

begin

    writeFsm: process (clk, rst) begin
        if rst = '1' then
            we <= '0';
            adr_w <= (others => '0');---
            writeData <= (others => '-');
        elsif rising_edge(clk) then
            if ce = '1' then
                we <= '0';
                if DataIfReset = '1' then
                    adr_w <= (others => '0');
                elsif we = '1' then
                    adr_w <= adr_w + 1;
                end if;

                if DataValid = '1' then
                    we <= '1';
                    writeData <= DataIn;
                end if;
            end if;
        end if;
    end process;

    mem: block
        signal Adrw_slv     : std_logic_vector(ADDR_WIDTH-1 downto 0);
        signal Adrr_slv     : std_logic_vector(ADDR_WIDTH-1 downto 0);
    begin

        Adrw_slv <= std_logic_vector(adr_w);
        Adrr_slv <= std_logic_vector(adr_r);

        samples : component pdpRam
            generic map(
                DATA_WIDTH     => DATA_WIDTH,
                ADDR_WIDTH     => ADDR_WIDTH,
                INIT_FILE_NAME => "",
                OUTPUT_REG     => RAM_OUTPUT_REG
            )
            port map(
                clk          => clk,
                ce           => ce,
                writeEnable  => we,
                writeAddress => Adrw_slv,
                writeData    => writeData,
                readAddress  => Adrr_slv,
                readData     => readData
            );
    end block mem;

    readFsm: block
        signal firstAddressSet   : std_logic;
        signal firstAddressSet_d : std_logic;
    begin
        process (clk, rst) begin
            if rst = '1' then
                adr_r <= (others => '0');---
                FirstSample_s <= '0';
                firstAddressSet <= '0';
                firstAddressSet_d <= '0';
            elsif rising_edge(clk) then
                if ce = '1' then
                    if SampleEnable = '1' then
                        firstAddressSet <= '0';
                        if adr_r = unsigned(AddrOfLastSample) then
                            adr_r <= (others => '0');
                            firstAddressSet <= '1';
                        else
                            adr_r <= adr_r + 1;
                        end if;
                    end if;

                    -- This is depending on the timing of the pdpRam. (i.e. we have a strong coupling to the pdpRam)
                    -- An alternative solution was to spend an additional bit of the waveform - a big waste.
                    -- So we live with this coupling.
                    firstAddressSet_d <= firstAddressSet;
                    if RAM_OUTPUT_REG then
                        FirstSample_s <= firstAddressSet_d;
                    else
                        FirstSample_s <= firstAddressSet;
                    end if;
                end if;
            end if;
        end process;
    end block;


    output: process (clk) begin
        if rising_edge(clk) then
            if ce = '1' then
                if Enable = '1' then
                    if SampleEnable = '1' then
                        FirstSample <= FirstSample_s;
                        DataOut <= readData;
                    end if;
                else
                    FirstSample <= '0';
                    DataOut <= (others => '0');
                end if;
            end if;
        end if;
    end process;

end architecture behavioral;
