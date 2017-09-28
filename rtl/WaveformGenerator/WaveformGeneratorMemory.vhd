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
        data_samples            : in  std_logic_vector(DATA_WIDTH-1 downto 0);     -- from controller
        data_samples_valid      : in  std_logic;                                   -- from controller
        data_samples_if_reset   : in  std_logic;                                   -- from controller

        enable                  : in  std_logic;                                   -- from controller
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

    signal first_sample_s    : std_logic;

    signal read_address      : unsigned(ADDR_WIDTH-1 downto 0);
    signal read_data         : std_logic_vector(DATA_WIDTH-1 downto 0);

    signal write_enable      : std_logic;
    signal write_data        : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal write_address     : unsigned(ADDR_WIDTH-1 downto 0);
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
            write_enable <= '0';
            write_address <= (others => '-');
            write_data <= (others => '-');
        end procedure assign_reset;
    begin
        if arst = '1' then
            assign_reset;
        elsif rising_edge(clk) then
            if srst = '1' then
                assign_reset;
            else
                if ce = '1' then
                    write_enable <= '0';
                    if data_samples_if_reset = '1' then
                        write_address <= (others => '0');
                    elsif write_enable = '1' then
                        write_address <= write_address + 1;
                    end if;

                    if data_samples_valid = '1' then
                        write_enable <= '1';
                    end if;
                    write_data <= data_samples;
                end if;
            end if;
        end if;
    end process;



    mem: block
        signal write_address_slv : std_logic_vector(ADDR_WIDTH-1 downto 0);
        signal read_address_slv  : std_logic_vector(ADDR_WIDTH-1 downto 0);
    begin

        write_address_slv <= std_logic_vector(write_address);
        read_address_slv <= std_logic_vector(read_address);

        samples : component PdpRam
            generic map(
                DATA_WIDTH     => DATA_WIDTH,
                ADDR_WIDTH     => ADDR_WIDTH,
                OUTPUT_REG     => RAM_OUTPUT_REG
            )
            port map(
                clk           => clk,
                ce            => ce,
                write_enable  => write_enable,
                write_address => write_address_slv,
                write_data    => write_data,
                read_address  => read_address_slv,
                read_data     => read_data
            );
    end block mem;

    readFsm: block
        signal fisrt_address_set   : std_logic;
        signal fisrt_address_set_d : std_logic;
    begin
        process (clk, arst)
            procedure assign_reset is begin
                read_address <= (others => '-');
                first_sample_s <= '0';
                fisrt_address_set <= '0';
                fisrt_address_set_d <= '0';
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
                            fisrt_address_set <= '0';
                            if read_address = unsigned(addr_of_last_sample) then
                                read_address <= (others => '0');
                                fisrt_address_set <= '1';
                            else
                                read_address <= read_address + 1;
                            end if;
                        end if;

                        -- This is depending on the timing of the pdpRam. (i.e. we have a strong coupling to the pdpRam)
                        -- An alternative solution was to spend an additional bit of the waveform - a big waste.
                        -- So we live with this coupling.
                        fisrt_address_set_d <= fisrt_address_set;
                        if RAM_OUTPUT_REG then
                            first_sample_s <= fisrt_address_set_d;
                        else
                            first_sample_s <= fisrt_address_set;
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
                        first_sample <= first_sample_s;
                        data_out <= read_data;
                    end if;
                else
                    first_sample <= '0';
                    data_out <= (others => '0');
                end if;
            end if;
        end if;
    end process;

end architecture behavioral;
