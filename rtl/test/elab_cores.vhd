-- SPDX-FileCopyrightText: The IPDBG authors
-- SPDX-License-Identifier: CERN-OHL-W-2.0

-- Instantiates every core, bus interface and transport once with typical
-- widths, so that run.sh can check that they elaborate and start up without
-- assertion failures. It checks nothing else; the behaviour is tested by the
-- self-checking testbenches and the co-simulation.

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.ipdbg_interface_pkg.all;

entity elab_cores is
end entity elab_cores;

architecture test of elab_cores is
    constant ASYNC_RESET : boolean := false;

    signal clk  : std_logic := '0';
    signal rst  : std_logic := '1';
    signal done : boolean   := false;

    type dn_array is array (natural range <>) of ipdbg_dn_lines;
    type up_array is array (natural range <>) of ipdbg_up_lines;
    signal dn : dn_array(0 to 31);
    signal up : up_array(0 to 31);

    constant idle_dn : ipdbg_dn_lines := (uplink_ready => '1', dnlink_valid => '0', dnlink_data => (others => '0'));

    signal tdo : std_logic;
begin
    clk <= not clk after 5 ns when not done;
    rst <= '0' after 50 ns;
    done <= true after 2 us;

    -- channels 0 to 6: the hub (JtagHub_4ext with the generic TAP)
    hub : entity work.JtagHub
        generic map(
            MFF_LENGTH          => 3,
            FLOW_CONTROL_ENABLE => "1000000"
        )
        port map(
            TCK => '0', TMS => '1', TDI => '0', TDO => tdo,
            clk => clk, ce => '1',
            dn_lines_0 => dn(0), dn_lines_1 => dn(1), dn_lines_2 => dn(2), dn_lines_3 => dn(3),
            dn_lines_4 => dn(4), dn_lines_5 => dn(5), dn_lines_6 => dn(6),
            up_lines_0 => up(0), up_lines_1 => up(1), up_lines_2 => up(2), up_lines_3 => up(3),
            up_lines_4 => up(4), up_lines_5 => up(5), up_lines_6 => up(6)
        );

    la : block
        signal probe : std_logic_vector(15 downto 0) := (others => '0');
    begin
        la_i : entity work.LogicAnalyserTop
            generic map(ADDR_WIDTH => 6, ASYNC_RESET => ASYNC_RESET, USE_EXT_TRIGGER => false, RUN_LENGTH_COMPRESSION => 0)
            port map(clk => clk, rst => rst, ce => '1', dn_lines => dn(0), up_lines => up(0),
                     sample_enable => '1', ext_trigger => '1', probe => probe);
        la_rlc_i : entity work.LogicAnalyserTop
            generic map(ADDR_WIDTH => 6, ASYNC_RESET => true, USE_EXT_TRIGGER => true, RUN_LENGTH_COMPRESSION => 8)
            port map(clk => clk, rst => rst, ce => '1', dn_lines => idle_dn, up_lines => up(7),
                     sample_enable => '1', ext_trigger => '0', probe => probe);
    end block;

    wfg : block
        signal data_out, data_out_db : std_logic_vector(11 downto 0);
        signal sync                  : std_logic;
    begin
        wfg_i : entity work.WaveformGeneratorTop
            generic map(ADDR_WIDTH => 6, ASYNC_RESET => ASYNC_RESET, DOUBLE_BUFFER => false, SYNC_MASTER => true)
            port map(clk => clk, rst => rst, ce => '1', dn_lines => dn(1), up_lines => up(1),
                     data_out => data_out, first_sample => open, sample_enable => '1',
                     output_active => open, one_shot => '0', sync_out => sync, sync_in => '0');
        wfg_db_i : entity work.WaveformGeneratorTop
            generic map(ADDR_WIDTH => 6, ASYNC_RESET => true, DOUBLE_BUFFER => true, SYNC_MASTER => false)
            port map(clk => clk, rst => rst, ce => '1', dn_lines => idle_dn, up_lines => up(8),
                     data_out => data_out_db, first_sample => open, sample_enable => '1',
                     output_active => open, one_shot => '0', sync_out => open, sync_in => sync);
    end block;

    ioprobe : block
        signal outputs : std_logic_vector(7 downto 0);
    begin
        ioprobe_i : entity work.IoProbeTop
            generic map(ASYNC_RESET => ASYNC_RESET)
            port map(clk => clk, rst => rst, ce => '1', dn_lines => dn(2), up_lines => up(2),
                     probe_inputs => "0101010101", probe_outputs => outputs, probe_outputs_update => open);
    end block;

    bus_masters : block
        signal adr16             : std_logic_vector(15 downto 0);
        signal dat32_o           : std_logic_vector(31 downto 0);
        signal sel4              : std_logic_vector(3 downto 0);
        signal adr32_w, adr32_r  : std_logic_vector(31 downto 0);
        signal wdata64           : std_logic_vector(63 downto 0);
        signal wstrb8            : std_logic_vector(7 downto 0);
        signal haddr             : std_logic_vector(31 downto 0);
        signal hwdata            : std_logic_vector(31 downto 0);
        signal hburst            : std_logic_vector(2 downto 0);
        signal hprot             : std_logic_vector(3 downto 0);
        signal hwstrb            : std_logic_vector(3 downto 0);
        signal hburst_none       : std_logic_vector(0 downto 1); -- no hburst
        signal hprot7            : std_logic_vector(6 downto 0);
        signal haddr_2, hwdata_2 : std_logic_vector(31 downto 0);
        signal hwstrb_2          : std_logic_vector(3 downto 0);
        signal av_addr           : std_logic_vector(31 downto 0);
        signal av_wdata          : std_logic_vector(127 downto 0);
        signal av_be             : std_logic_vector(15 downto 0);
        signal apb_addr          : std_logic_vector(11 downto 0);
        signal apb_wdata         : std_logic_vector(15 downto 0);
        signal apb_strb          : std_logic_vector(1 downto 0);
        signal dmi_addr          : std_logic_vector(6 downto 0);
    begin
        wb_i : entity work.WbMaster
            generic map(ASYNC_RESET => ASYNC_RESET)
            port map(clk => clk, rst => rst, ce => '1', dn_lines => dn(3), up_lines => up(3),
                     lock_o => open, cyc_o => open, stb_o => open, ack_i => '1', we_o => open,
                     adr_o => adr16, sel_o => sel4, dat_o => dat32_o, dat_i => x"12345678");

        axi_i : entity work.Axi4lMaster
            generic map(ASYNC_RESET => ASYNC_RESET)
            port map(clk => clk, rst => rst, ce => '1', dn_lines => idle_dn, up_lines => up(9),
                     araddr => adr32_r, arprot => open, arvalid => open, arready => '1',
                     rdata => x"0000000000000000", rresp => "00", rvalid => '0', rready => open,
                     awaddr => adr32_w, awprot => open, awvalid => open, awready => '1',
                     wdata => wdata64, wstrb => wstrb8, wvalid => open, wready => '1',
                     bresp => "00", bvalid => '0', bready => open);

        ahb_i : entity work.AhbMaster
            generic map(ASYNC_RESET => ASYNC_RESET, MASTER_ID => "0001")
            port map(clk => clk, rst => rst, ce => '1', dn_lines => idle_dn, up_lines => up(10),
                     haddr => haddr, hwrite => open, hsize => open, hburst => hburst, hprot => hprot,
                     htrans => open, hmastlock => open, hwdata => hwdata, hready => '1', hresp => '0',
                     hrdata => x"00000000", hwstrb => hwstrb, hmaster => open);

        -- AHB without hburst, hprot with 7 bits
        ahb_2_i : entity work.AhbMaster
            generic map(ASYNC_RESET => ASYNC_RESET, MASTER_ID => "0010")
            port map(clk => clk, rst => rst, ce => '1', dn_lines => idle_dn, up_lines => up(22),
                     haddr => haddr_2, hwrite => open, hsize => open, hburst => hburst_none, hprot => hprot7,
                     htrans => open, hmastlock => open, hwdata => hwdata_2, hready => '1', hresp => '0',
                     hrdata => x"00000000", hwstrb => hwstrb_2, hmaster => open);

        avalon_i : entity work.AvalonMaster
            generic map(ASYNC_RESET => ASYNC_RESET)
            port map(clk => clk, rst => rst, ce => '1', dn_lines => idle_dn, up_lines => up(11),
                     address => av_addr, byteenable => av_be, debugaccess => open, read => open,
                     readdata => (127 downto 0 => '0'), response => "00", write => open,
                     writedata => av_wdata, lock => open, waitrequest => '0');

        apb_i : entity work.ApbMaster
            generic map(ASYNC_RESET => ASYNC_RESET)
            port map(clk => clk, rst => rst, ce => '1', dn_lines => idle_dn, up_lines => up(12),
                     paddr => apb_addr, pwrite => open, pwdata => apb_wdata, prdata => x"0000",
                     psel => open, penable => open, pready => '1', pslverr => '0', pprot => open,
                     pstrb => apb_strb);

        dtm_i : entity work.RiscvDtm
            generic map(ASYNC_RESET => ASYNC_RESET)
            port map(clk => clk, rst => rst, ce => '1', dn_lines => idle_dn, up_lines => up(13),
                     op => open, write_req => open, read_req => open, address => dmi_addr,
                     write_data => open, read_data => x"00000000", ack => '1',
                     dmireset => open, dmihardreset => open);
    end block;

    iurt : block
    begin
        wb_i : entity work.IurtWb
            generic map(ASYNC_RESET => ASYNC_RESET)
            port map(clk => clk, rst => rst, ce => '1', we_i => '0', cyc_i => '0', stb_i => '0',
                     sel_i => "1111", adr_i => "00000", dat_i => x"00000000", dat_o => open,
                     ack_o => open, err_o => open, stall_o => open, irq => open,
                     dn_lines => dn(6), up_lines => up(6));
        axi_i : entity work.IurtAxi4l
            generic map(ASYNC_RESET => ASYNC_RESET)
            port map(clk => clk, rst => rst, ce => '1', awready => open, awvalid => '0',
                     awaddr => "00000", awprot => "000", wready => open, wvalid => '0',
                     wdata => x"00000000", wstrb => "1111", bready => '1', bvalid => open,
                     bresp => open, arready => open, arvalid => '0', araddr => "00000",
                     arprot => "000", rready => '1', rvalid => open, rdata => open, rresp => open,
                     irq => open, dn_lines => idle_dn, up_lines => up(14));
        apb3_i : entity work.IurtApb3
            generic map(ASYNC_RESET => ASYNC_RESET)
            port map(clk => clk, rst => rst, ce => '1', psel => '0', penable => '0', pwrite => '0',
                     paddr => "00000", pwdata => x"00000000", pready => open, prdata => open,
                     pslverr => open, irq => open, dn_lines => idle_dn, up_lines => up(15));
        apb4_i : entity work.IurtApb4
            generic map(ASYNC_RESET => true)
            port map(clk => clk, rst => rst, ce => '1', psel => '0', penable => '0', pwrite => '0',
                     pprot => "000", paddr => "00000", pwdata => x"00000000", pstrb => "1111",
                     pready => open, prdata => open, pslverr => open, irq => open,
                     dn_lines => idle_dn, up_lines => up(16));
        avalon_i : entity work.IurtAvalon
            generic map(ASYNC_RESET => ASYNC_RESET)
            port map(clk => clk, rst => rst, ce => '1', read => '0', write => '0',
                     waitrequest => open, address => "000", writedata => x"00000000",
                     byteenable => "1111", readdatavalid => open, writeresponsevalid => open,
                     readdata => open, response => open, irq => open,
                     dn_lines => idle_dn, up_lines => up(17));
        obi_i : entity work.IurtObi
            generic map(ASYNC_RESET => ASYNC_RESET)
            port map(clk => clk, rst => rst, ce => '1', req => '0', gnt => open, addr => "00000",
                     we => '0', be => "1111", wdata => x"00000000", aid => "0", rvalid => open,
                     rready => '1', rdata => open, err => open, rid => open, irq => open,
                     dn_lines => idle_dn, up_lines => up(18));
        ahb_i : entity work.IurtAhb
            generic map(ASYNC_RESET => ASYNC_RESET)
            port map(clk => clk, rst => rst, ce => '1', hsel => '0', haddr => "00000",
                     htrans => "00", hwrite => '0', hsize => "010", hwdata => x"00000000",
                     hready => '1', hreadyout => open, hresp => open, hrdata => open, irq => open,
                     dn_lines => idle_dn, up_lines => up(19));
    end block;

    transports : block
        signal txd : std_logic;
    begin
        -- channel 4: a core with another clock than the hub
        cdc_i : entity work.IpdbgClockDomainCrossing
            generic map(ASYNC_RESET => ASYNC_RESET, MFF_LENGTH => 3)
            port map(clk_func => clk, rst_func => rst, ce_func => '1',
                     clk_host => clk, rst_host => rst, ce_host => '1',
                     dn_lines_host => dn(4), up_lines_host => up(4),
                     dn_lines_func => dn(20), up_lines_func => unused_up_lines);
        up(5) <= unused_up_lines;

        uart_i : entity work.IpdbgUart
            generic map(CLOCKS_PER_ONE_SIXTEENTH_BIT => 4, NUM_META_FLOPS => 3, ASYNC_RESET => ASYNC_RESET)
            port map(clk => clk, rst => rst, ce => '1', txd => txd, rxd => txd,
                     dn_lines => dn(21), up_lines => unused_up_lines);
    end block;
end architecture test;
