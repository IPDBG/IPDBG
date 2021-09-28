library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ipdbg_interface_pkg.all;

entity tb_WaveformGeneratorTop is
end tb_WaveformGeneratorTop;

architecture test of tb_WaveformGeneratorTop is
    component WaveformGeneratorTop is
    generic(
        ADDR_WIDTH    : natural; --! 2**ADDR_WIDTH = size if sample memory
        ASYNC_RESET   : boolean;
        DOUBLE_BUFFER : boolean;
        SYNC_MASTER   : boolean
    );
    port(
        clk           : in  std_logic;
        rst           : in  std_logic;
        ce            : in  std_logic;

        --      host interface (UART or ....)
        dn_lines      : in  ipdbg_dn_lines;
        up_lines      : out ipdbg_up_lines;

        -- WaveformGenerator interface
        data_out      : out std_logic_vector;
        first_sample  : out std_logic;
        sample_enable : in  std_logic;


        sync_out      : out std_logic;
        sync_in       : in std_logic;
        one_shot      : in std_logic;

        output_active : out std_logic
    );
end component WaveformGeneratorTop;

    constant NUMBER_OF_SAMPLES_MASTER  : integer:= 16;
    constant NUMBER_OF_SAMPLES_SLAVE   : integer:= 40;


    constant ADDR_WIDTH    : natural := 11;
    constant ASYNC_RESET   : boolean := false;
    constant DOUBLE_BUFFER : boolean := false;
    signal  clk            : std_logic;
    signal  rst            : std_logic;
    signal  ce             : std_logic;

    signal  dn_lines_master  : ipdbg_dn_lines;
    signal  up_lines_master  : ipdbg_up_lines;

    signal  dn_lines_slave   : ipdbg_dn_lines;
    signal  up_lines_slave   : ipdbg_up_lines;

    signal  data_out_m       : std_logic_vector(7 downto 0);
    signal  first_sample_m   : std_logic:= '0';
    signal  sample_enable_m  : std_logic:= '0';
    signal  output_active_m  : std_logic:= '0';

    signal  data_out_s       : std_logic_vector(7 downto 0);
    signal  first_sample_s   : std_logic:= '0';
    signal  sample_enable_s  : std_logic:= '0';
    signal  output_active_s  : std_logic:= '0';

    signal  sync_out         : std_logic;
    signal  sync_in          : std_logic;

    signal  one_shot         : std_logic:= '0';


    constant T               : time := 10 ns;

begin

    process begin
        clk <= '0';
        wait for T/2;
        clk <= '1';
        wait for (T-(T/2));-- to avoid rounding differences
    end process;
    process begin
        sample_enable_m <= '0';
        sample_enable_s <= '0';
        wait for (4*T-(T/2));-- to avoid rounding differences
        sample_enable_m <= '1';
        sample_enable_s <= '1';
        wait for T/2;
    end process;
    process begin
        rst <= '1';
        wait for 3/2*T;
        rst <= '0';
        wait;
    end process;

    ce <= '1';
    dn_lines_master.uplink_ready <= '1';
    dn_lines_slave.uplink_ready <= '1';


    process begin

        dn_lines_master.dnlink_valid <= '0';
        dn_lines_master.dnlink_data <= (others => '0');
        dn_lines_slave.dnlink_valid <= '0';
        dn_lines_slave.dnlink_data <= (others => '0');
        wait until rising_edge(clk) and rst = '0';
        wait for T/5;
        wait for 5*T;

        -- set address of last sample Master
        dn_lines_master.dnlink_valid <= '1';
        dn_lines_master.dnlink_data  <= x"f4";

        wait for T;
        dn_lines_master.dnlink_data  <= x"00";
        wait for T;
        if to_unsigned(NUMBER_OF_SAMPLES_MASTER, dn_lines_master.dnlink_data'length) = x"55" then
            dn_lines_master.dnlink_data  <= x"55"; --Escape escape symbol
            wait for T;
        elsif to_unsigned(NUMBER_OF_SAMPLES_MASTER, dn_lines_master.dnlink_data'length) = x"EE" then
            dn_lines_master.dnlink_data  <= x"55"; --Escape Reset symbol
            wait for T;
        end if;
        dn_lines_master.dnlink_data <= std_logic_vector(to_unsigned(NUMBER_OF_SAMPLES_MASTER, dn_lines_master.dnlink_data'length));
        wait for T;
        dn_lines_master.dnlink_valid <= '0';
        wait for 50*T;

        -- set address of last sample Slave
        dn_lines_slave.dnlink_valid  <= '1';
        dn_lines_slave.dnlink_data   <= x"f4";
        wait for T;
        dn_lines_slave.dnlink_data  <= x"00";
        wait for T;
        if to_unsigned(NUMBER_OF_SAMPLES_SLAVE, dn_lines_slave.dnlink_data'length) = x"55" then
            wait for T;
        elsif to_unsigned(NUMBER_OF_SAMPLES_SLAVE, dn_lines_slave.dnlink_data'length) = x"EE" then
            dn_lines_slave.dnlink_data  <= x"55"; --Escape Reset symbol
            wait for T;
        end if;
        dn_lines_slave.dnlink_data <= std_logic_vector(to_unsigned(NUMBER_OF_SAMPLES_SLAVE, dn_lines_slave.dnlink_data'length));--x"09"; --
        wait for T;
        dn_lines_slave.dnlink_valid  <= '0';
        wait for 5*T;


        -- write samples Master
        dn_lines_master.dnlink_valid <= '1';
        dn_lines_master.dnlink_data  <= x"f3";
        wait for T;

        dn_lines_master.dnlink_valid <= '1';
        for k in 0 to NUMBER_OF_SAMPLES_MASTER loop
            if k = 85 then  -- ESCAPE_SYMBOL = 0x55
                dn_lines_master.dnlink_data  <= x"55"; --Escape Escape symbol
                wait for T;
            elsif k = 238 then -- RESET_SYMBOL = 0xEE
                dn_lines_master.dnlink_data  <= x"55"; --Escape Reset symbol
                wait for T;
            end if;
            dn_lines_master.dnlink_data  <= std_logic_vector(to_unsigned(k, dn_lines_master.dnlink_data'length));
            wait for T;
        end loop;
        dn_lines_master.dnlink_valid <= '0';
        wait for 5*T;

        -- write samples Slave
        dn_lines_slave.dnlink_valid  <= '1';
        dn_lines_slave.dnlink_data   <= x"f3";
        wait for T;
        dn_lines_slave.dnlink_valid  <= '1';
        for k in 0 to NUMBER_OF_SAMPLES_SLAVE loop
            if k = 85 then  -- ESCAPE_SYMBOL = 0x55
                dn_lines_slave.dnlink_data  <= x"55"; --Escape Escape symbol
                wait for T;
            elsif k = 238 then -- RESET_SYMBOL = 0xEE
                dn_lines_slave.dnlink_data  <= x"55"; --Escape Reset symbol
                wait for T;
            end if;
            dn_lines_slave.dnlink_data  <= std_logic_vector(to_unsigned(k, dn_lines_slave.dnlink_data'length));
            wait for T;
        end loop;


        dn_lines_slave.dnlink_valid  <= '0';
        wait for 50*T;


        -- set start Master
        dn_lines_master.dnlink_valid <= '1';
        dn_lines_master.dnlink_data  <= x"f0";
        wait for T;
        dn_lines_master.dnlink_valid <= '0';

        wait for 36*T;

        -- set stop Master
        dn_lines_master.dnlink_valid <= '1';
        dn_lines_master.dnlink_data  <= x"f1";
        wait for T;
        dn_lines_master.dnlink_valid <= '0';
        wait for T;


        wait for T;
        wait for 50*T;

        -- set oneshot Master
        dn_lines_master.dnlink_valid  <= '1';
        dn_lines_master.dnlink_data   <= x"f6";
        wait for T;
        dn_lines_master.dnlink_valid  <= '0';

        wait for 7*T;

        -- set oneshot Slave
        dn_lines_slave.dnlink_valid  <= '1';
        dn_lines_slave.dnlink_data   <= x"f6";
        wait for T;
        dn_lines_slave.dnlink_valid  <= '0';
        wait for 20*T;

        --set stop Slave               = Has no effect if oneshot is currently running
        dn_lines_slave.dnlink_valid <= '1';
        dn_lines_slave.dnlink_data  <= x"f1";
        wait for T;
        dn_lines_slave.dnlink_valid <= '0';


        wait for 150*T;


        -- set start Master
        dn_lines_master.dnlink_valid <= '1';
        dn_lines_master.dnlink_data  <= x"f0";
        wait for T;
        dn_lines_master.dnlink_valid <= '0';
        wait for T;

        -- set start slave
        dn_lines_slave.dnlink_valid <= '1';
        dn_lines_slave.dnlink_data  <= x"f0";
        wait for T;
        dn_lines_slave.dnlink_valid <= '0';

        wait for 90*T;

        -- set oneshot Slave            = Has no effects to output if slave is already running
        dn_lines_slave.dnlink_valid  <= '1';
        dn_lines_slave.dnlink_data   <= x"f6";
        wait for T;
        dn_lines_slave.dnlink_valid  <= '0';
        wait for 20*T;

        --set stop Slave
        dn_lines_slave.dnlink_valid <= '1';
        dn_lines_slave.dnlink_data  <= x"f1";
        wait for T;
        dn_lines_slave.dnlink_valid <= '0';
        wait for 50*T;


        -- set stop Master
        dn_lines_master.dnlink_valid <= '1';
        dn_lines_master.dnlink_data  <= x"f1";
        wait for T;
        dn_lines_master.dnlink_valid <= '0';

        wait for 80*T;


         -- set start slave         = Won't work if master is stopped
        dn_lines_slave.dnlink_valid <= '1';
        dn_lines_slave.dnlink_data  <= x"f0";
        wait for T;
        dn_lines_slave.dnlink_valid <= '0';

        wait for 89*T;


        -- set start Master         = Slave should start on sync
        dn_lines_master.dnlink_valid <= '1';
        dn_lines_master.dnlink_data  <= x"f0";
        wait for T;
        dn_lines_master.dnlink_valid <= '0';
        wait for T;
        wait;
    end process;





    uut_Master : component WaveformGeneratorTop
    generic map(
        ADDR_WIDTH     => ADDR_WIDTH,
        ASYNC_RESET    => ASYNC_RESET,
        DOUBLE_BUFFER  => DOUBLE_BUFFER,
        SYNC_MASTER    => true
    )
    port map(
        clk            => clk,
        rst            => rst,
        ce             => ce,

        dn_lines       => dn_lines_master,
        up_lines       => up_lines_master,

        data_out       => data_out_m,
        first_sample   => first_sample_m,
        sample_enable  => sample_enable_m,
        output_active  => output_active_m,

        sync_in        => sync_out,--'0',--must be connected even when master
        sync_out       => sync_out,

        one_shot       => one_shot
    );

    uut_Slave : component WaveformGeneratorTop
    generic map(
        ADDR_WIDTH     => ADDR_WIDTH,
        ASYNC_RESET    => ASYNC_RESET,
        DOUBLE_BUFFER  => DOUBLE_BUFFER,
        SYNC_MASTER    => false
    )
    port map(
        clk            => clk,
        rst            => rst,
        ce             => ce,

        dn_lines       => dn_lines_slave,
        up_lines       => up_lines_slave,

        data_out       => data_out_s,
        first_sample   => first_sample_s,
        sample_enable  => sample_enable_s,
        output_active  => output_active_s,

        sync_in     => sync_out,
        sync_out    => open,

        one_shot    => one_shot
    );


end architecture test;
