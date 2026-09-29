-- SPDX-FileCopyrightText: The IPDBG authors
-- SPDX-License-Identifier: CERN-OHL-W-2.0

-- Self-checking testbench for Iurt through IurtWb (BUS_TYPE = "wb") or IurtAhb
-- (BUS_TYPE = "ahb"), with ASYNC_RESET true or false. Stops with an error on the
-- first mismatch, reports "tb_Iurt: all tests passed" at the end.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ipdbg_interface_pkg.all;

entity tb_Iurt is
    generic(
        BUS_TYPE    : string  := "wb";
        ASYNC_RESET : boolean := true
    );
end entity tb_Iurt;

architecture test of tb_Iurt is
    constant T : time := 10 ns;

    constant RBR : natural := 16#00#; -- also THR, DLL
    constant IER : natural := 16#04#; -- also DLM
    constant IIR : natural := 16#08#; -- also FCR
    constant LCR : natural := 16#0C#;
    constant MCR : natural := 16#10#;
    constant LSR : natural := 16#14#;
    constant MSR : natural := 16#18#;
    constant SCR : natural := 16#1C#;

    signal clk      : std_logic := '0';
    signal rst      : std_logic := '1';
    signal ce       : std_logic := '1';
    signal irq      : std_logic;
    signal dn_lines : ipdbg_dn_lines;
    signal up_lines : ipdbg_up_lines;

    -- wishbone
    signal wb_we, wb_cyc, wb_stb, wb_ack, wb_err, wb_stall : std_logic;
    signal wb_sel   : std_logic_vector(3 downto 0);
    signal wb_adr   : std_logic_vector(4 downto 0);
    signal wb_odat  : std_logic_vector(31 downto 0);
    signal wb_idat  : std_logic_vector(31 downto 0);

    -- ahb
    signal hsel, hwrite, hreadyout, hresp : std_logic;
    signal haddr    : std_logic_vector(4 downto 0);
    signal htrans   : std_logic_vector(1 downto 0);
    signal hsize    : std_logic_vector(2 downto 0);
    signal hwdata   : std_logic_vector(31 downto 0);
    signal hrdata   : std_logic_vector(31 downto 0);

    -- host model
    signal host_take      : std_logic := '1'; -- host takes bytes from Iurt
    signal host_rx_count  : natural := 0;
    signal host_rx_last   : std_logic_vector(7 downto 0);
    signal host_tx_data   : std_logic_vector(7 downto 0) := x"00";
    signal host_tx_req    : natural := 0;     -- incremented by the test: send host_tx_data
    signal host_tx_done   : natural := 0;
    signal host_ignore_rdy: std_logic := '0'; -- send without waiting for dnlink_ready (no flow control)

    signal done : boolean := false;
begin
    clk <= not clk after T / 2 when not done;

    wb_gen : if BUS_TYPE = "wb" generate
        component IurtWb is
            generic(
                ASYNC_RESET : boolean
            );
            port(
                clk      : in  std_logic;
                rst      : in  std_logic;
                ce       : in  std_logic;
                we_i     : in std_logic;
                cyc_i    : in std_logic;
                stb_i    : in std_logic;
                sel_i    : in std_logic_vector(3 downto 0);
                adr_i    : in std_logic_vector(4 downto 0);
                dat_i    : in std_logic_vector(31 downto 0);
                dat_o    : out std_logic_vector(31 downto 0);
                ack_o    : out std_logic;
                err_o    : out std_logic;
                stall_o  : out std_logic;
                irq      : out std_logic;
                dn_lines : in  ipdbg_dn_lines;
                up_lines : out ipdbg_up_lines
            );
        end component IurtWb;
    begin
        dut : component IurtWb
            generic map(ASYNC_RESET => ASYNC_RESET)
            port map(
                clk => clk, rst => rst, ce => ce,
                we_i => wb_we, cyc_i => wb_cyc, stb_i => wb_stb, sel_i => wb_sel,
                adr_i => wb_adr, dat_i => wb_odat, dat_o => wb_idat,
                ack_o => wb_ack, err_o => wb_err, stall_o => wb_stall,
                irq => irq, dn_lines => dn_lines, up_lines => up_lines
            );
    end generate wb_gen;

    ahb_gen : if BUS_TYPE = "ahb" generate
        component IurtAhb is
            generic(
                ASYNC_RESET : boolean
            );
            port(
                clk             : in  std_logic;
                rst             : in  std_logic;
                ce              : in  std_logic;
                hsel            : in  std_logic;
                haddr           : in  std_logic_vector(4 downto 0);
                htrans          : in  std_logic_vector(1 downto 0);
                hwrite          : in  std_logic;
                hsize           : in  std_logic_vector(2 downto 0);
                hwdata          : in  std_logic_vector(31 downto 0);
                hready          : in  std_logic;
                hreadyout       : out std_logic;
                hresp           : out std_logic;
                hrdata          : out std_logic_vector(31 downto 0);
                irq             : out std_logic;
                dn_lines        : in  ipdbg_dn_lines;
                up_lines        : out ipdbg_up_lines
            );
        end component IurtAhb;
    begin
        dut : component IurtAhb
            generic map(ASYNC_RESET => ASYNC_RESET)
            port map(
                clk => clk, rst => rst, ce => ce,
                hsel => hsel, haddr => haddr, htrans => htrans,
                hwrite => hwrite, hsize => hsize, hwdata => hwdata,
                hready => hreadyout, hreadyout => hreadyout,
                hresp => hresp, hrdata => hrdata,
                irq => irq, dn_lines => dn_lines, up_lines => up_lines
            );
    end generate ahb_gen;

    -- host: takes the bytes from Iurt when host_take = '1'
    dn_lines.uplink_ready <= host_take;
    host_rx : process (clk) begin
        if rising_edge(clk) then
            if up_lines.uplink_valid = '1' then
                assert host_take = '1' report "uplink_valid while not ready" severity failure;
                host_rx_count <= host_rx_count + 1;
                host_rx_last  <= up_lines.uplink_data;
            end if;
        end if;
    end process;

    -- host: sends a byte when host_tx_req is incremented, respects dnlink_ready
    host_tx : process begin
        dn_lines.dnlink_valid <= '0';
        dn_lines.dnlink_data  <= (others => '-');
        wait until host_tx_req'event;
        wait until rising_edge(clk) and (up_lines.dnlink_ready = '1' or host_ignore_rdy = '1');
        dn_lines.dnlink_valid <= '1';
        dn_lines.dnlink_data  <= host_tx_data;
        wait until rising_edge(clk);
        host_tx_done <= host_tx_done + 1;
    end process;

    stimuli : process
        procedure bus_write(a : natural; d : std_logic_vector(7 downto 0)) is begin
            if BUS_TYPE = "wb" then
                wb_adr  <= std_logic_vector(to_unsigned(a, 5));
                wb_odat <= x"000000" & d;
                wb_sel  <= "1111";
                wb_we   <= '1';
                wb_cyc  <= '1';
                wb_stb  <= '1';
                wait until rising_edge(clk) and wb_stall = '0';
                wb_stb  <= '0';
                if wb_ack /= '1' then
                    wait until rising_edge(clk) and wb_ack = '1';
                end if;
                wb_cyc  <= '0';
                wb_we   <= '0';
            else
                hsel   <= '1';
                haddr  <= std_logic_vector(to_unsigned(a, 5));
                htrans <= "10";
                hwrite <= '1';
                hsize  <= "010";
                wait until rising_edge(clk) and hreadyout = '1';
                hsel   <= '0';
                htrans <= "00";
                hwdata <= x"000000" & d;
                wait until rising_edge(clk) and hreadyout = '1';
            end if;
        end procedure bus_write;

        procedure bus_read(a : natural; d : out std_logic_vector(7 downto 0)) is begin
            if BUS_TYPE = "wb" then
                wb_adr  <= std_logic_vector(to_unsigned(a, 5));
                wb_sel  <= "1111";
                wb_we   <= '0';
                wb_cyc  <= '1';
                wb_stb  <= '1';
                wait until rising_edge(clk) and wb_stall = '0';
                wb_stb  <= '0';
                if wb_ack /= '1' then
                    wait until rising_edge(clk) and wb_ack = '1';
                end if;
                assert wb_idat(31 downto 8) = x"000000" report "bits 31..8 not 0" severity failure;
                d := wb_idat(7 downto 0);
                wb_cyc  <= '0';
            else
                hsel   <= '1';
                haddr  <= std_logic_vector(to_unsigned(a, 5));
                htrans <= "10";
                hwrite <= '0';
                hsize  <= "010";
                wait until rising_edge(clk) and hreadyout = '1';
                hsel   <= '0';
                htrans <= "00";
                wait until rising_edge(clk) and hreadyout = '1';
                assert hresp = '0' report "hresp not OKAY" severity failure;
                assert hrdata(31 downto 8) = x"000000" report "bits 31..8 not 0" severity failure;
                d := hrdata(7 downto 0);
            end if;
        end procedure bus_read;

        procedure check(a : natural; expected : std_logic_vector(7 downto 0); what : string) is
            variable d : std_logic_vector(7 downto 0);
        begin
            bus_read(a, d);
            assert d = expected
                report what & ": read 0x" & to_hstring(d) & ", expected 0x" & to_hstring(expected)
                severity failure;
        end procedure check;

        procedure host_send(d : std_logic_vector(7 downto 0)) is
            variable n : natural;
        begin
            n := host_tx_done;
            host_tx_data <= d;
            host_tx_req  <= host_tx_req + 1;
            wait until host_tx_done = n + 1;
        end procedure host_send;

        procedure idle(n : natural) is begin
            for i in 1 to n loop
                wait until rising_edge(clk);
            end loop;
        end procedure idle;

        variable n : natural;
    begin
        wb_we <= '0'; wb_cyc <= '0'; wb_stb <= '0'; wb_sel <= "0000";
        wb_adr <= (others => '0'); wb_odat <= (others => '0');
        hsel <= '0'; haddr <= (others => '0'); htrans <= "00"; hwrite <= '0';
        hsize <= "010"; hwdata <= (others => '0');

        idle(3);
        rst <= '0';
        idle(2);

        -- after reset
        check(LSR, x"60", "LSR after reset");
        check(IIR, x"01", "IIR after reset");
        check(IER, x"00", "IER after reset");
        check(LCR, x"00", "LCR after reset");
        check(MSR, x"B0", "MSR after reset");
        assert irq = '0' report "irq after reset" severity failure;

        -- scratch, divisor latch, LCR
        bus_write(SCR, x"A5");
        check(SCR, x"A5", "SCR");
        bus_write(LCR, x"83");
        bus_write(RBR, x"12");
        bus_write(IER, x"34");
        check(RBR, x"12", "DLL");
        check(IER, x"34", "DLM");
        bus_write(LCR, x"03");
        check(LCR, x"03", "LCR");
        check(IER, x"00", "IER not changed by DLM write");
        bus_write(IIR, x"C7"); -- FCR: ignored
        check(IIR, x"01", "IIR after FCR write");

        -- loopback: MSR reflects MCR (Linux autoconfig test: MCR = 0x1A -> MSR & 0xF0 = 0x90)
        bus_write(MCR, x"1A");
        check(MCR, x"1A", "MCR");
        check(MSR, x"90", "MSR in loopback");
        bus_write(MCR, x"00");

        -- transmit
        host_take <= '0';
        n := host_rx_count;
        bus_write(RBR, x"41");
        check(LSR, x"00", "LSR while THR full");
        idle(5);
        assert host_rx_count = n report "byte sent while host not ready" severity failure;
        host_take <= '1';
        idle(3);
        assert host_rx_count = n + 1 and host_rx_last = x"41" report "byte not sent" severity failure;
        check(LSR, x"60", "LSR after transmit");

        -- receive with backpressure: second byte waits until RBR is read
        host_send(x"42");
        check(LSR, x"61", "LSR after receive");
        assert up_lines.dnlink_ready = '0' report "dnlink_ready while RBR full" severity failure;
        host_tx_data <= x"43";
        host_tx_req  <= host_tx_req + 1;
        idle(10);
        check(LSR, x"61", "LSR while host waits");
        check(RBR, x"42", "RBR first byte");
        wait until host_tx_done = 2;
        idle(2);
        check(RBR, x"43", "RBR second byte");
        check(LSR, x"60", "LSR after reading RBR");

        -- received data available interrupt
        bus_write(IER, x"01");
        assert irq = '0' report "irq without data" severity failure;
        host_send(x"44");
        idle(2);
        assert irq = '1' report "no rx irq" severity failure;
        check(IIR, x"04", "IIR rx data available");
        check(RBR, x"44", "RBR rx irq");
        idle(1);
        assert irq = '0' report "rx irq not cleared" severity failure;

        -- THR empty interrupt: raised when enabled, cleared by reading IIR
        bus_write(IER, x"02");
        idle(1);
        assert irq = '1' report "no thre irq on enable" severity failure;
        check(IIR, x"02", "IIR thre");
        idle(1);
        assert irq = '0' report "thre irq not cleared by IIR read" severity failure;
        check(IIR, x"01", "IIR after thre cleared");
        -- raised again when the host has taken a byte
        host_take <= '0';
        bus_write(RBR, x"45");
        idle(3);
        assert irq = '0' report "thre irq while THR full" severity failure;
        host_take <= '1';
        idle(3);
        assert irq = '1' report "no thre irq after transmit" severity failure;
        host_take <= '0';
        bus_write(RBR, x"46"); -- writing THR clears it
        idle(1);
        assert irq = '0' report "thre irq not cleared by THR write" severity failure;
        host_take <= '1';
        idle(3);
        assert host_rx_last = x"46" report "second byte not sent" severity failure;

        -- priority: rx data before thre
        bus_write(IER, x"03");
        host_send(x"47");
        idle(2);
        check(IIR, x"04", "IIR priority");
        check(RBR, x"47", "RBR priority");
        check(IIR, x"02", "IIR thre after rx");
        bus_write(IER, x"00");

        -- without flow control: overrun
        host_send(x"48");
        host_ignore_rdy <= '1';
        host_send(x"49");
        host_ignore_rdy <= '0';
        bus_write(IER, x"04");
        idle(1);
        assert irq = '1' report "no line status irq" severity failure;
        check(IIR, x"06", "IIR line status");
        check(LSR, x"63", "LSR overrun");
        check(LSR, x"61", "LSR overrun cleared by read");
        check(RBR, x"48", "RBR keeps first byte on overrun");
        bus_write(IER, x"00");

        report "tb_Iurt: all tests passed (BUS_TYPE = " & BUS_TYPE & ", ASYNC_RESET = " & boolean'image(ASYNC_RESET) & ")";
        done <= true;
        wait;
    end process;
end architecture test;
