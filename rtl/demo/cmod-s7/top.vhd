-- SPDX-FileCopyrightText: The IPDBG authors
-- SPDX-License-Identifier: CERN-OHL-W-2.0

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

library work;
use work.ipdbg_interface_pkg.all;

entity top is
    generic(
        MFF_LENGTH : natural := 3
    );
    port(
        clk_pin : in  std_logic;
        leds    : out std_logic_vector(3 downto 0);
        buttons : in  std_logic_vector(1 downto 0);
        uart_tx : out std_logic; -- to the USB UART of the board (FTDI interface 1)
        uart_rx : in  std_logic
    );
end top;

architecture structure of top is
    component clk_wiz_0 is
        port (
            clk_out1 : out STD_LOGIC;
            locked : out STD_LOGIC;
            clk_in1 : in STD_LOGIC
        );
    end component clk_wiz_0;

    component dffpc is
        port(
            clk : in  std_logic;
            ce  : in  std_logic;
            d   : in  std_logic;
            q   : out std_logic
        );
    end component dffpc;

    component JtagHub is
        generic(
            MFF_LENGTH           : natural := 3;
            FLOW_CONTROL_ENABLE  : std_logic_vector(6 downto 0);
            TDI_HAS_EXT_REGISTER : boolean := false
        );
        port(
            clk        : in  std_logic;
            ce         : in  std_logic;
            dn_lines_0 : out ipdbg_dn_lines;
            dn_lines_1 : out ipdbg_dn_lines;
            dn_lines_2 : out ipdbg_dn_lines;
            dn_lines_3 : out ipdbg_dn_lines;
            dn_lines_4 : out ipdbg_dn_lines;
            dn_lines_5 : out ipdbg_dn_lines;
            dn_lines_6 : out ipdbg_dn_lines;
            up_lines_0 : in  ipdbg_up_lines := unused_up_lines;
            up_lines_1 : in  ipdbg_up_lines := unused_up_lines;
            up_lines_2 : in  ipdbg_up_lines := unused_up_lines;
            up_lines_3 : in  ipdbg_up_lines := unused_up_lines;
            up_lines_4 : in  ipdbg_up_lines := unused_up_lines;
            up_lines_5 : in  ipdbg_up_lines := unused_up_lines;
            up_lines_6 : in  ipdbg_up_lines := unused_up_lines
        );
    end component JtagHub;

    component LogicAnalyserTop is
        generic(
             ADDR_WIDTH             : natural := 4;
             ASYNC_RESET            : boolean := true;
             USE_EXT_TRIGGER        : boolean := false;
             RUN_LENGTH_COMPRESSION : natural range 0 to 32 := 0
        );
        port(
            clk            : in  std_logic;
            rst            : in  std_logic;
            ce             : in  std_logic;
            dn_lines       : in  ipdbg_dn_lines;
            up_lines       : out ipdbg_up_lines;
            sample_enable  : in  std_logic;
            ext_trigger    : in  std_logic := '1';
            probe          : in  std_logic_vector
        );
    end component LogicAnalyserTop;

    component WaveformGeneratorTop is
        generic(
            ADDR_WIDTH    : natural := 13;          --! 2**ADDR_WIDTH = size of sample memory
            ASYNC_RESET   : boolean := true;
            DOUBLE_BUFFER : boolean := false;
            SYNC_MASTER   : boolean := true
        );
        port(
            clk           : in  std_logic;
            rst           : in  std_logic;
            ce            : in  std_logic;
            dn_lines      : in  ipdbg_dn_lines;
            up_lines      : out ipdbg_up_lines;
            data_out      : out std_logic_vector;
            first_sample  : out std_logic;
            sample_enable : in  std_logic;
            output_active : out std_logic;
            one_shot      : in  std_logic := '0';
            sync_out      : out std_logic;
            sync_in       : in  std_logic := '0'
        );
    end component WaveformGeneratorTop;

    component IoProbeTop is
        generic(
            ASYNC_RESET : boolean := true
        );
        port(
            clk                  : in  std_logic;
            rst                  : in  std_logic;
            ce                   : in  std_logic;
            dn_lines             : in  ipdbg_dn_lines;
            up_lines             : out ipdbg_up_lines;
            probe_inputs         : in  std_logic_vector;
            probe_outputs        : out std_logic_vector;
            probe_outputs_update : out std_logic
        );
    end component IoProbeTop;

    component IpdbgUart is
        generic(
            CLOCKS_PER_ONE_SIXTEENTH_BIT : positive;
            NUM_META_FLOPS               : positive;
            ASYNC_RESET                  : boolean
        );
        port(
            clk      : in  std_logic;
            rst      : in  std_logic;
            ce       : in  std_logic;
            txd      : out std_logic;
            rxd      : in  std_logic;
            dn_lines : out ipdbg_dn_lines;
            up_lines : in  ipdbg_up_lines
        );
    end component IpdbgUart;

    component WbMaster is
        generic (
            ASYNC_RESET : boolean
        );
        port (
            clk      : in    std_logic;
            rst      : in    std_logic;
            ce       : in    std_logic;
            dn_lines : in    ipdbg_dn_lines;
            up_lines : out   ipdbg_up_lines;
            lock_o   : out   std_logic;
            cyc_o    : out   std_logic;
            stb_o    : out   std_logic;
            ack_i    : in    std_logic;
            rty_i    : in    std_logic := '0';
            err_i    : in    std_logic := '0';
            we_o     : out   std_logic;
            adr_o    : out   std_logic_vector;
            sel_o    : out   std_logic_vector;
            dat_o    : out   std_logic_vector;
            dat_i    : in    std_logic_vector
        );
    end component WbMaster;

    constant ASYNC_RESET                : boolean   := false;
    signal rst                          : std_logic;
    signal clk                          : std_logic;


    signal dn_lines_0 : ipdbg_dn_lines;
    signal dn_lines_1 : ipdbg_dn_lines;
    signal dn_lines_2 : ipdbg_dn_lines;
    signal dn_lines_3 : ipdbg_dn_lines;
    signal dn_lines_4 : ipdbg_dn_lines;
    signal dn_lines_5 : ipdbg_dn_lines;
    signal dn_lines_6 : ipdbg_dn_lines;
    signal up_lines_0 : ipdbg_up_lines;
    signal up_lines_1 : ipdbg_up_lines;
    signal up_lines_2 : ipdbg_up_lines;
    signal up_lines_3 : ipdbg_up_lines;
    signal up_lines_4 : ipdbg_up_lines := unused_up_lines;
    signal up_lines_5 : ipdbg_up_lines := unused_up_lines;
    signal up_lines_6 : ipdbg_up_lines := unused_up_lines;

    signal la_probe   : std_logic_vector(15 downto 0);
    signal wfg_out    : std_logic_vector(15 downto 0);

    signal io_probe_rd : std_logic_vector(9 downto 0);

    -- 100 MHz / (16 * 54) = 115741 baud, 0.5 % above 115200
    constant UART_CLOCKS_PER_ONE_SIXTEENTH_BIT : positive := 54;

begin
    jtag_hub_i : component JtagHub
        generic map(
            MFF_LENGTH           => MFF_LENGTH,
            FLOW_CONTROL_ENABLE  => "0000000",
            TDI_HAS_EXT_REGISTER => false
        )
        port map(
            clk        => clk,
            ce         => '1',
            dn_lines_0 => dn_lines_0,
            dn_lines_1 => dn_lines_1,
            dn_lines_2 => dn_lines_2,
            dn_lines_3 => dn_lines_3,
            dn_lines_4 => dn_lines_4,
            dn_lines_5 => dn_lines_5,
            dn_lines_6 => dn_lines_6,
            up_lines_0 => up_lines_0,
            up_lines_1 => up_lines_1,
            up_lines_2 => up_lines_2,
            up_lines_3 => up_lines_3,
            up_lines_4 => up_lines_4,
            up_lines_5 => up_lines_5,
            up_lines_6 => up_lines_6
        );

    la_i : component LogicAnalyserTop
        generic map(
             ADDR_WIDTH             => 9,
             ASYNC_RESET            => false,
             USE_EXT_TRIGGER        => false,
             RUN_LENGTH_COMPRESSION => 0
        )
        port map(
            clk            => clk,
            rst            => rst,
            ce             => '1',
            dn_lines       => dn_lines_0,
            up_lines       => up_lines_0,
            sample_enable  => '1',
            ext_trigger    => '1',
            probe          => la_probe
        );

    la_probe <= wfg_out;

    wfg_i : component WaveformGeneratorTop
        generic map(
            ADDR_WIDTH    => 12,
            ASYNC_RESET   => false,
            DOUBLE_BUFFER => false,
            SYNC_MASTER   => true
        )
        port map(
            clk           => clk,
            rst           => rst,
            ce            => '1',
            dn_lines      => dn_lines_1,
            up_lines      => up_lines_1,
            data_out      => wfg_out,
            first_sample  => open,
            sample_enable => '1',
            output_active => open,
            one_shot      => '0',
            sync_out      => open,
            sync_in       => '0'
        );


    io_probe_i : component IoProbeTop
        generic map(
            ASYNC_RESET => false
        )
        port map(
            clk                  => clk,
            rst                  => rst,
            ce                   => '1',
            dn_lines             => dn_lines_2,
            up_lines             => up_lines_2,
            probe_inputs         => io_probe_rd,
            probe_outputs        => leds,
            probe_outputs_update => open
        );

    ba: block
        signal reg    : std_logic_vector(31 downto 0) := (others => '0');
        signal wr_dat : std_logic_vector(31 downto 0);
        signal rd_dat : std_logic_vector(31 downto 0);
        signal cyc    : std_logic;
        signal stb    : std_logic;
        signal ack    : std_logic;
        signal we     : std_logic;
        signal adr    : std_logic_vector(15 downto 0);
        signal sel    : std_logic_vector(1 downto 0);
        signal lock   : std_logic;
    begin

        bus_access_i : component WbMaster
            generic map (
                ASYNC_RESET => ASYNC_RESET
            )
            port map (
                clk      => clk,
                rst      => rst,
                ce       => '1',
                dn_lines => dn_lines_3,
                up_lines => up_lines_3,
                lock_o   => lock,
                cyc_o    => cyc,
                stb_o    => stb,
                ack_i    => ack,
                we_o     => we,
                adr_o    => adr,
                sel_o    => sel,
                dat_o    => wr_dat,
                dat_i    => rd_dat
            );

        rd_dat     <= reg;
        ack        <= stb;
        io_probe_rd <= buttons & reg(7 downto 0);

        process(clk)
        begin
            if rising_edge(clk) then
                if stb = '1' and cyc = '1' then
                    if we = '1' then
                        -- 32 bit data, 2 bit sel: each sel bit selects 16 bits
                        if sel(0) = '1' then
                            reg(15 downto 0) <= wr_dat(15 downto 0);
                        end if;
                        if sel(1) = '1' then
                            reg(31 downto 16) <= wr_dat(31 downto 16);
                        end if;
                    end if;
                end if;
            end if;
        end process;

    end block;

    -- a second IoProbe on the USB UART of the board, through IpdbgUart and
    -- sw/UartBridge on the host: 8 outputs, 10 inputs = buttons & outputs
    uart: block
        signal dn_lines_uart : ipdbg_dn_lines;
        signal up_lines_uart : ipdbg_up_lines;
        signal outputs       : std_logic_vector(7 downto 0);
        signal inputs        : std_logic_vector(9 downto 0);
    begin
        uart_i : component IpdbgUart
            generic map(
                CLOCKS_PER_ONE_SIXTEENTH_BIT => UART_CLOCKS_PER_ONE_SIXTEENTH_BIT,
                NUM_META_FLOPS               => MFF_LENGTH,
                ASYNC_RESET                  => ASYNC_RESET
            )
            port map(
                clk      => clk,
                rst      => rst,
                ce       => '1',
                txd      => uart_tx,
                rxd      => uart_rx,
                dn_lines => dn_lines_uart,
                up_lines => up_lines_uart
            );

        uart_probe_i : component IoProbeTop
            generic map(
                ASYNC_RESET => ASYNC_RESET
            )
            port map(
                clk                  => clk,
                rst                  => rst,
                ce                   => '1',
                dn_lines             => dn_lines_uart,
                up_lines             => up_lines_uart,
                probe_inputs         => inputs,
                probe_outputs        => outputs,
                probe_outputs_update => open
            );
        inputs <= buttons & outputs;
    end block;

    clocking_and_reset : block
        signal rst_n            : std_logic;
        signal clkfbout         : std_logic;
        signal clkfbout_buf     : std_logic;
        signal clk_pin_buffered : std_logic;
        signal clk_out1_clk     : std_logic;
        signal rst_nd           : std_logic_vector(3 downto 0);
    begin
        clk_buf : unisim.vcomponents.IBUF
            generic map(
                IOSTANDARD => "DEFAULT"
            )
            port map (
                I => clk_pin,
                O => clk_pin_buffered
            );
        clkf_buf: unisim.vcomponents.BUFG
            port map (
                I => clkfbout,
                O => clkfbout_buf
            );
        clkout1_buf: unisim.vcomponents.BUFG
            port map (
                I => clk_out1_clk,
                O => clk
            );
        mmcm_adv_i : unisim.vcomponents.MMCME2_ADV
            generic map(
                BANDWIDTH => "OPTIMIZED",
                CLKFBOUT_MULT_F => 62.500000,
                CLKFBOUT_PHASE => 0.000000,
                CLKFBOUT_USE_FINE_PS => false,
                CLKIN1_PERIOD => 83.333000,
                CLKIN2_PERIOD => 0.000000,
                CLKOUT0_DIVIDE_F => 7.500000,
                CLKOUT0_DUTY_CYCLE => 0.500000,
                CLKOUT0_PHASE => 0.000000,
                CLKOUT0_USE_FINE_PS => false,
                CLKOUT1_DIVIDE => 1,
                CLKOUT1_DUTY_CYCLE => 0.500000,
                CLKOUT1_PHASE => 0.000000,
                CLKOUT1_USE_FINE_PS => false,
                CLKOUT2_DIVIDE => 1,
                CLKOUT2_DUTY_CYCLE => 0.500000,
                CLKOUT2_PHASE => 0.000000,
                CLKOUT2_USE_FINE_PS => false,
                CLKOUT3_DIVIDE => 1,
                CLKOUT3_DUTY_CYCLE => 0.500000,
                CLKOUT3_PHASE => 0.000000,
                CLKOUT3_USE_FINE_PS => false,
                CLKOUT4_CASCADE => false,
                CLKOUT4_DIVIDE => 1,
                CLKOUT4_DUTY_CYCLE => 0.500000,
                CLKOUT4_PHASE => 0.000000,
                CLKOUT4_USE_FINE_PS => false,
                CLKOUT5_DIVIDE => 1,
                CLKOUT5_DUTY_CYCLE => 0.500000,
                CLKOUT5_PHASE => 0.000000,
                CLKOUT5_USE_FINE_PS => false,
                CLKOUT6_DIVIDE => 1,
                CLKOUT6_DUTY_CYCLE => 0.500000,
                CLKOUT6_PHASE => 0.000000,
                CLKOUT6_USE_FINE_PS => false,
                COMPENSATION => "ZHOLD",
                DIVCLK_DIVIDE => 1,
                IS_CLKINSEL_INVERTED => '0',
                IS_PSEN_INVERTED => '0',
                IS_PSINCDEC_INVERTED => '0',
                IS_PWRDWN_INVERTED => '0',
                IS_RST_INVERTED => '0',
                REF_JITTER1 => 0.010000,
                REF_JITTER2 => 0.010000,
                SS_EN => "FALSE",
                SS_MODE => "CENTER_HIGH",
                SS_MOD_PERIOD => 10000,
                STARTUP_WAIT => false
            )
            port map (
                CLKFBIN => clkfbout_buf,
                CLKFBOUT => clkfbout,
                CLKFBOUTB => open,
                CLKFBSTOPPED => open,
                CLKIN1 => clk_pin_buffered,
                CLKIN2 => '0',
                CLKINSEL => '1',
                CLKINSTOPPED => open,
                CLKOUT0 => clk_out1_clk,
                CLKOUT0B => open,
                CLKOUT1 => open,
                CLKOUT1B => open,
                CLKOUT2 => open,
                CLKOUT2B => open,
                CLKOUT3 => open,
                CLKOUT3B => open,
                CLKOUT4 => open,
                CLKOUT5 => open,
                CLKOUT6 => open,
                DADDR(6 downto 0) => B"0000000",
                DCLK => '0',
                DEN => '0',
                DI(15 downto 0) => B"0000000000000000",
                DO => open,
                DRDY => open,
                DWE => '0',
                LOCKED => rst_n,
                PSCLK => '0',
                PSDONE => open,
                PSEN => '0',
                PSINCDEC => '0',
                PWRDWN => '0',
                RST => '0'
            );

        rst_nd(0) <= rst_n;
        meta_ff : for I in 1 to 3 generate
        begin
            meta_ff0 : component dffpc
                port map(
                    clk => clk,
                    ce  => '1',
                    d   => rst_nd(I - 1),
                    q   => rst_nd(I)
                );
        end generate;
        rst <= not rst_nd(3);
    end block;

end architecture structure;
