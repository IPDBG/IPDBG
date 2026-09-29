-- SPDX-FileCopyrightText: The IPDBG authors
-- SPDX-License-Identifier: CERN-OHL-W-2.0

-- Iurt: a UART for the CPU in the FPGA whose other end is a TCP port on the
-- host (terminal, nc, ...), connected through IPDBG.
--
-- Programming model of a 16450 (16550 without FIFO), so the existing 8250 /
-- 16550 drivers work, e.g. Linux with compatible = "ns16450". The registers
-- are described in iurt.rdl; the generated register block implements IIR,
-- LCR, MCR, LSR, MSR and SCR and forwards the accesses to the two registers
-- that depend on LCR.DLAB to this entity:
--
--   rbr_*: offset 0x00, DLAB = 0: RBR (read) / THR (write), DLAB = 1: DLL
--   ier_*: offset 0x04, DLAB = 0: IER,                      DLAB = 1: DLM
--
-- This entity also provides the status for IIR, LSR and MSR and the
-- transfers to and from the host:
--   * While RBR is full, the host is stalled (dnlink_ready = '0'), so enable
--     the flow control of the hub for this channel (JtagHub
--     FLOW_CONTROL_ENABLE). Without it, a byte arriving while RBR is full is
--     lost and sets LSR.OE, like a 16450 overrun.
--   * While THR is full, THRE stays 0 until the host has taken the byte.
--   * The bytes to and from the host are not escaped, so any TCP terminal
--     works.
--   * Interrupts: receiver line status (overrun), received data available
--     and THR empty, with the priorities of the 16450.
--
-- The register accesses are handled regardless of ce; ce only applies to the
-- transfers to and from the host.

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.ipdbg_interface_pkg.all;

entity IurtCore is
    generic(
        ASYNC_RESET : boolean
    );
    port(
        clk            : in  std_logic;
        rst            : in  std_logic;
        ce             : in  std_logic;

        -- external register at 0x00: RBR / THR / DLL
        rbr_req        : in  std_logic;
        rbr_req_is_wr  : in  std_logic;
        rbr_wr_data    : in  std_logic_vector(31 downto 0);
        rbr_wr_biten   : in  std_logic_vector(31 downto 0);
        rbr_rd_ack     : out std_logic;
        rbr_rd_data    : out std_logic_vector(31 downto 0);
        rbr_wr_ack     : out std_logic;

        -- external register at 0x04: IER / DLM
        ier_req        : in  std_logic;
        ier_req_is_wr  : in  std_logic;
        ier_wr_data    : in  std_logic_vector(31 downto 0);
        ier_wr_biten   : in  std_logic_vector(31 downto 0);
        ier_rd_ack     : out std_logic;
        ier_rd_data    : out std_logic_vector(31 downto 0);
        ier_wr_ack     : out std_logic;

        -- generated registers
        lcr_dlab       : in  std_logic;
        mcr            : in  std_logic_vector(4 downto 0); -- loopback, out2, out1, rts, dtr
        iir_rd         : in  std_logic;                    -- IIR is read
        iir_no_int     : out std_logic;
        iir_id         : out std_logic_vector(1 downto 0);
        lsr_dr         : out std_logic;
        lsr_oe         : in  std_logic;
        lsr_oe_set     : out std_logic;
        lsr_thre       : out std_logic;                    -- also TEMT
        msr            : out std_logic_vector(7 downto 4); -- dcd, ri, dsr, cts

        irq            : out std_logic; -- level, active high

        -- host interface (JtagHub or ....)
        dn_lines       : in  ipdbg_dn_lines;
        up_lines       : out ipdbg_up_lines
    );
end entity IurtCore;

architecture behavioral of IurtCore is
    constant ID_RLS   : std_logic_vector(1 downto 0) := "11"; -- receiver line status
    constant ID_RDA   : std_logic_vector(1 downto 0) := "10"; -- received data available
    constant ID_THRE  : std_logic_vector(1 downto 0) := "01"; -- THR empty

    signal arst, srst : std_logic;

    signal rbr        : std_logic_vector(7 downto 0);
    signal dr         : std_logic; -- data ready: RBR full
    signal thr        : std_logic_vector(7 downto 0);
    signal thr_full   : std_logic;
    signal thre_int   : std_logic; -- THR empty interrupt pending
    signal ier        : std_logic_vector(3 downto 0);
    signal dll        : std_logic_vector(7 downto 0);
    signal dlm        : std_logic_vector(7 downto 0);

    signal int_rls    : std_logic;
    signal int_rda    : std_logic;
    signal int_thre   : std_logic;
    signal id         : std_logic_vector(1 downto 0);
begin
    async_init : if ASYNC_RESET generate begin
        arst <= rst;
        srst <= '0';
    end generate async_init;
    sync_init : if not ASYNC_RESET generate begin
        arst <= '0';
        srst <= rst;
    end generate sync_init;

    int_rls  <= ier(2) and lsr_oe;
    int_rda  <= ier(0) and dr;
    int_thre <= ier(1) and thre_int;
    id       <= ID_RLS  when int_rls = '1' else
                ID_RDA  when int_rda = '1' else
                ID_THRE when int_thre = '1' else
                "00";
    iir_id     <= id;
    iir_no_int <= not (int_rls or int_rda or int_thre);
    irq        <= int_rls or int_rda or int_thre;

    lsr_dr   <= dr;
    lsr_thre <= not thr_full;

    msr <= mcr(3) & mcr(2) & mcr(0) & mcr(1) when mcr(4) = '1' else -- loopback: DCD = OUT2, RI = OUT1, DSR = DTR, CTS = RTS
           "1011";                                                -- DCD, DSR, CTS

    up_lines.dnlink_ready <= not dr;

    process (clk, arst)
        procedure reset_assignments is begin
            rbr                   <= (others => '-');
            dr                    <= '0';
            lsr_oe_set            <= '0';
            thr                   <= (others => '-');
            thr_full              <= '0';
            thre_int              <= '0';
            ier                   <= (others => '0');
            dll                   <= (others => '0');
            dlm                   <= (others => '0');
            rbr_rd_ack            <= '0';
            rbr_rd_data           <= (others => '-');
            rbr_wr_ack            <= '0';
            ier_rd_ack            <= '0';
            ier_rd_data           <= (others => '-');
            ier_wr_ack            <= '0';
            up_lines.uplink_valid <= '0';
            up_lines.uplink_data  <= (others => '-');
        end procedure reset_assignments;

        -- the written bits of a register
        function merge(old : std_logic_vector; data, biten : std_logic_vector(31 downto 0)) return std_logic_vector is
            variable res : std_logic_vector(old'length - 1 downto 0) := old;
        begin
            for i in res'range loop
                if biten(i) = '1' then
                    res(i) := data(i);
                end if;
            end loop;
            return res;
        end function merge;
    begin
        if arst = '1' then
            reset_assignments;
        elsif rising_edge(clk) then
            if srst = '1' then
                reset_assignments;
            else
                -- to and from the host
                up_lines.uplink_valid <= '0';
                lsr_oe_set            <= '0';
                if ce = '1' then
                    if thr_full = '1' and dn_lines.uplink_ready = '1' then
                        up_lines.uplink_valid <= '1';
                        up_lines.uplink_data  <= thr;
                        thr_full              <= '0';
                        thre_int              <= '1';
                    end if;
                    if dn_lines.dnlink_valid = '1' then
                        if dr = '0' then
                            rbr <= dn_lines.dnlink_data;
                            dr  <= '1';
                        else
                            lsr_oe_set <= '1'; -- only without flow control
                        end if;
                    end if;
                end if;

                -- register accesses, after the host transfers: a write to THR wins
                if iir_rd = '1' and id = ID_THRE then
                    thre_int <= '0';
                end if;

                rbr_rd_ack <= rbr_req and not rbr_req_is_wr;
                rbr_wr_ack <= rbr_req and rbr_req_is_wr;
                if rbr_req = '1' then
                    if rbr_req_is_wr = '0' then
                        if lcr_dlab = '1' then
                            rbr_rd_data <= x"000000" & dll;
                        else
                            rbr_rd_data <= x"000000" & rbr;
                            dr          <= '0';
                        end if;
                    elsif rbr_wr_biten(7 downto 0) /= x"00" then
                        if lcr_dlab = '1' then
                            dll <= merge(dll, rbr_wr_data, rbr_wr_biten);
                        else
                            thr      <= merge(thr, rbr_wr_data, rbr_wr_biten);
                            thr_full <= '1';
                            thre_int <= '0';
                        end if;
                    end if;
                end if;

                ier_rd_ack <= ier_req and not ier_req_is_wr;
                ier_wr_ack <= ier_req and ier_req_is_wr;
                if ier_req = '1' then
                    if ier_req_is_wr = '0' then
                        if lcr_dlab = '1' then
                            ier_rd_data <= x"000000" & dlm;
                        else
                            ier_rd_data <= x"0000000" & ier;
                        end if;
                    elsif ier_wr_biten(7 downto 0) /= x"00" then
                        if lcr_dlab = '1' then
                            dlm <= merge(dlm, ier_wr_data, ier_wr_biten);
                        else
                            ier <= merge(ier, ier_wr_data, ier_wr_biten);
                            -- like a 16550: enabling the THRE interrupt while THR is empty raises it
                            if ier_wr_biten(1) = '1' and ier_wr_data(1) = '1' and thr_full = '0' then
                                thre_int <= '1';
                            end if;
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;
end architecture behavioral;
