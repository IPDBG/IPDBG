library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity WaveformGeneratorMemory is
    generic(
        DATA_WIDTH       : natural := 8;
        ADDR_WIDTH       : natural := 8;
        ASYNC_RESET      : boolean := true
    );
    port(
        clk              : in  std_logic;
        rst              : in  std_logic;
        ce               : in  std_logic;


        -- write
        data_samples            : in  std_logic_vector(DATA_WIDTH-1 downto 0);      -- from controller
        data_samples_valid      : in  std_logic;                                    -- from controller
        data_samples_if_reset   : in  std_logic;                                    -- from controller

        enable                  : in  std_logic;                                   -- not pause      -- from controller
        addr_of_last_sample     : in  std_logic_vector(ADDR_WIDTH-1 downto 0);     -- Length Of Waveform - 1  -- from controller

        data_out                : out std_logic_vector(DATA_WIDTH-1 downto 0);     -- THE output
        first_sample            : out std_logic;                                   -- THE output
        data_out_enable         : in  std_logic := '1'                             -- timing for output

    );
end entity WaveformGeneratorMemory;


architecture behavioral of WaveformGeneratorMemory is

    component PdpRam is
        generic(
            DATA_WIDTH     : natural;
            ADDR_WIDTH     : natural;
            OUTPUT_REG     : boolean
        );
        port(
            clk           : in  std_logic;
            ce            : in  std_logic;
            write_Enable  : in  std_logic;
            write_Address : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
            write_Data    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            read_Address  : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
            read_Data     : out std_logic_vector(DATA_WIDTH-1 downto 0)
        );
    end component PdpRam;

    constant RAM_OUTPUT_REG  : boolean := true;

    signal FirstSample_s     : std_logic;

    signal adr_r             :  unsigned(ADDR_WIDTH-1 downto 0) := (others => '0');
    signal readData          : std_logic_vector(DATA_WIDTH-1 downto 0);

    signal we                : std_logic;
    signal writeData         : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal adr_w             : unsigned(ADDR_WIDTH-1 downto 0) := (others => '0');
    --signal AddrOfLastSample  : std_logic_vector(ADDR_WIDTH-1 downto 0);
    signal arst, srst        : std_logic;

begin
    async_init: if ASYNC_RESET generate begin
        arst <= rst;
        srst <= '0';
    end generate async_init;
    sync_init: if not ASYNC_RESET generate begin
        arst <= '0';
        srst <= rst;
    end generate sync_init;

    writeFsm: process (clk, arst)
        procedure assign_reset is begin
            we <= '0';
            adr_w <= (others => '-');
            writeData <= (others => '-');
        end procedure assign_reset;
    begin
        if arst = '1' then
            assign_reset;
        elsif rising_edge(clk) then
            if srst = '1' then
                assign_reset;
            else
                if ce = '1' then
                    we <= '0';
--                    if we = '1' then
--                        AddrOfLastSample <= std_logic_vector(adr_w);
--                    end if;
                    if data_samples_if_reset = '1' then
                        adr_w <= (others => '0');
                    elsif we = '1' then
                        adr_w <= adr_w + 1;
                    end if;

                    if data_samples_valid = '1' then
                        we <= '1';
                        writeData <= data_samples;
                    end if;
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

        samples : component PdpRam
            generic map(
                DATA_WIDTH     => DATA_WIDTH,
                ADDR_WIDTH     => ADDR_WIDTH,
                OUTPUT_REG     => RAM_OUTPUT_REG
            )
            port map(
                clk           => clk,
                ce            => ce,
                write_enable  => we,
                write_address => Adrw_slv,
                write_data    => writeData,
                read_address  => Adrr_slv,
                read_data     => readData
            );
    end block mem;

    readFsm: block
        signal firstAddressSet   : std_logic;
        signal firstAddressSet_d : std_logic;
    begin
        process (clk, arst)
            procedure assign_reset is begin
                adr_r <= (others => '-');
                FirstSample_s <= '0';
                firstAddressSet <= '0';
                firstAddressSet_d <= '0';
            end procedure assign_reset;
        begin
            if arst = '1' then
                assign_reset;
            elsif rising_edge(clk) then
                 if srst = '1' then
                    assign_reset;
                else
                    if ce = '1' then
                        if data_out_enable = '1' then
                            firstAddressSet <= '0';
                            if adr_r = unsigned(addr_of_last_sample) then
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
            end if;
        end process;
    end block;


    output: process (clk) begin
        if rising_edge(clk) then
            if ce = '1' then
                if enable = '1' then
                    if data_out_enable = '1' then
                        first_sample <= FirstSample_s;
                        data_out <= readData;
                    end if;
                else
                    first_sample <= '0';
                    data_out <= (others => '0');
                end if;
            end if;
        end if;
    end process;

end architecture behavioral;
