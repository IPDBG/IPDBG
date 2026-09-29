-- SPDX-FileCopyrightText: The IPDBG authors
-- SPDX-License-Identifier: CERN-OHL-W-2.0

-- Iurt with a bus slave interface: AHB-Lite (AMBA 3 AHB-Lite / AHB5 subset).
-- See IurtCore.vhd for the registers and the behaviour.
-- The AHB-Lite slave is converted to the passthrough interface of
-- generated/IurtRegsPassthrough.vhd (PeakRDL-regblock-vhdl). haddr is the
-- byte address within the 32 bytes of Iurt. Transfers of 8, 16 or 32 bits,
-- little endian; hresp is always OKAY. Every transfer takes at least two
-- wait states.
-- The register block and this adapter have a synchronous reset: clk must run
-- while rst is active. ASYNC_RESET and ce only apply to IurtCore.
--
-- Needs IurtCore.vhd, generated/IurtRegsPassthrough.vhd,
-- generated/IurtRegsPassthrough_pkg.vhd, generated/reg_utils.vhd (VHDL-2008)
-- and rtl/common/ipdbg_interface_pkg.vhd.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ipdbg_interface_pkg.all;
use work.IurtRegsPassthrough_pkg.all;

entity IurtAhb is
    generic(
        ASYNC_RESET : boolean
    );
    port(
        clk         : in  std_logic;
        rst         : in  std_logic;
        ce          : in  std_logic;

        hsel        : in  std_logic;
        haddr       : in  std_logic_vector(4 downto 0);
        htrans      : in  std_logic_vector(1 downto 0);
        hwrite      : in  std_logic;
        hsize       : in  std_logic_vector(2 downto 0);
        hwdata      : in  std_logic_vector(31 downto 0);
        hready      : in  std_logic;
        hreadyout   : out std_logic;
        hresp       : out std_logic;
        hrdata      : out std_logic_vector(31 downto 0);

        irq         : out std_logic; -- level, active high

        -- host interface (JtagHub or ....)
        dn_lines    : in  ipdbg_dn_lines;
        up_lines    : out ipdbg_up_lines
    );
end entity IurtAhb;

architecture behavioral of IurtAhb is
    component IurtRegsPassthrough is
        port (
            clk                  : in  std_logic;
            rst                  : in  std_logic;
            s_cpuif_req          : in  std_logic;
            s_cpuif_req_is_wr    : in  std_logic;
            s_cpuif_addr         : in  std_logic_vector(4 downto 0);
            s_cpuif_wr_data      : in  std_logic_vector(31 downto 0);
            s_cpuif_wr_biten     : in  std_logic_vector(31 downto 0);
            s_cpuif_req_stall_wr : out std_logic;
            s_cpuif_req_stall_rd : out std_logic;
            s_cpuif_rd_ack       : out std_logic;
            s_cpuif_rd_err       : out std_logic;
            s_cpuif_rd_data      : out std_logic_vector(31 downto 0);
            s_cpuif_wr_ack       : out std_logic;
            s_cpuif_wr_err       : out std_logic;
            hwif_in              : in  iurt_in_t;
            hwif_out             : out iurt_out_t
        );
    end component IurtRegsPassthrough;

    component IurtCore is
        generic(
            ASYNC_RESET : boolean
        );
        port(
            clk           : in  std_logic;
            rst           : in  std_logic;
            ce            : in  std_logic;
            rbr_req       : in  std_logic;
            rbr_req_is_wr : in  std_logic;
            rbr_wr_data   : in  std_logic_vector(31 downto 0);
            rbr_wr_biten  : in  std_logic_vector(31 downto 0);
            rbr_rd_ack    : out std_logic;
            rbr_rd_data   : out std_logic_vector(31 downto 0);
            rbr_wr_ack    : out std_logic;
            ier_req       : in  std_logic;
            ier_req_is_wr : in  std_logic;
            ier_wr_data   : in  std_logic_vector(31 downto 0);
            ier_wr_biten  : in  std_logic_vector(31 downto 0);
            ier_rd_ack    : out std_logic;
            ier_rd_data   : out std_logic_vector(31 downto 0);
            ier_wr_ack    : out std_logic;
            lcr_dlab      : in  std_logic;
            mcr           : in  std_logic_vector(4 downto 0);
            iir_rd        : in  std_logic;
            iir_no_int    : out std_logic;
            iir_id        : out std_logic_vector(1 downto 0);
            lsr_dr        : out std_logic;
            lsr_oe        : in  std_logic;
            lsr_oe_set    : out std_logic;
            lsr_thre      : out std_logic;
            msr           : out std_logic_vector(7 downto 4);
            irq           : out std_logic;
            dn_lines      : in  ipdbg_dn_lines;
            up_lines      : out ipdbg_up_lines
        );
    end component IurtCore;

    -- IDLE:    no data phase pending, hreadyout = '1'
    -- REQUEST: data phase, request to the register block (hwdata is valid now)
    -- WAIT:    waiting for the response of the register block
    type state_t    is (IDLE, REQUEST, WAIT_RESPONSE);
    signal state    : state_t;

    signal addr     : std_logic_vector(4 downto 0);
    signal is_wr    : std_logic;
    signal biten    : std_logic_vector(31 downto 0);

    signal req      : std_logic;
    signal stall_wr : std_logic;
    signal stall_rd : std_logic;
    signal rd_ack   : std_logic;
    signal rd_data  : std_logic_vector(31 downto 0);
    signal wr_ack   : std_logic;

    signal hwif_in  : iurt_in_t;
    signal hwif_out : iurt_out_t;
    signal iir_id   : std_logic_vector(1 downto 0);
    signal lsr_thre : std_logic;
    signal msr      : std_logic_vector(7 downto 4);

    -- byte lanes of a transfer, little endian
    function lanes(size : std_logic_vector(2 downto 0); a : std_logic_vector(1 downto 0)) return std_logic_vector is
        variable res : std_logic_vector(31 downto 0) := (others => '0');
        constant lo  : natural := to_integer(unsigned(a));
    begin
        case size is
            when "000" => -- byte
                res(8 * lo + 7 downto 8 * lo) := (others => '1');
            when "001" => -- halfword
                if a(1) = '0' then
                    res(15 downto 0) := (others => '1');
                else
                    res(31 downto 16) := (others => '1');
                end if;
            when others => -- word
                res := (others => '1');
        end case;
        return res;
    end function lanes;
begin
    hresp <= '0'; -- OKAY

    req <= '1' when state = REQUEST else '0';

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state     <= IDLE;
                hreadyout <= '1';
                hrdata    <= (others => '0');
                addr      <= (others => '-');
                is_wr     <= '-';
                biten     <= (others => '-');
            else
                case state is
                    when IDLE =>
                        -- address phase of a NONSEQ or SEQ transfer
                        if hsel = '1' and hready = '1' and htrans(1) = '1' then
                            addr      <= haddr;
                            is_wr     <= hwrite;
                            biten     <= lanes(hsize, haddr(1 downto 0));
                            state     <= REQUEST;
                            hreadyout <= '0';
                        end if;
                    when REQUEST =>
                        if (is_wr = '1' and stall_wr = '0') or (is_wr = '0' and stall_rd = '0') then
                            state <= WAIT_RESPONSE;
                        end if;
                    when WAIT_RESPONSE =>
                        null;
                end case;

                -- response, also possible in the cycle after REQUEST
                if (state = REQUEST or state = WAIT_RESPONSE) and (rd_ack = '1' or wr_ack = '1') then
                    if rd_ack = '1' then
                        hrdata <= rd_data;
                    end if;
                    hreadyout <= '1';
                    state     <= IDLE;
                end if;
            end if;
        end if;
    end process;

    regs : component IurtRegsPassthrough
        port map (
            clk                  => clk,
            rst                  => rst,
            s_cpuif_req          => req,
            s_cpuif_req_is_wr    => is_wr,
            s_cpuif_addr         => addr,
            s_cpuif_wr_data      => hwdata,
            s_cpuif_wr_biten     => biten,
            s_cpuif_req_stall_wr => stall_wr,
            s_cpuif_req_stall_rd => stall_rd,
            s_cpuif_rd_ack       => rd_ack,
            s_cpuif_rd_err       => open,
            s_cpuif_rd_data      => rd_data,
            s_cpuif_wr_ack       => wr_ack,
            s_cpuif_wr_err       => open,
            hwif_in              => hwif_in,
            hwif_out             => hwif_out
        );

    hwif_in.iir.id.next_q   <= iir_id;
    hwif_in.lsr.thre.next_q <= lsr_thre;
    hwif_in.lsr.temt.next_q <= lsr_thre;
    hwif_in.msr.dcd.next_q  <= msr(7);
    hwif_in.msr.ri.next_q   <= msr(6);
    hwif_in.msr.dsr.next_q  <= msr(5);
    hwif_in.msr.cts.next_q  <= msr(4);

    core : component IurtCore
        generic map (
            ASYNC_RESET => ASYNC_RESET
        )
        port map (
            clk           => clk,
            rst           => rst,
            ce            => ce,
            rbr_req       => hwif_out.rbr_thr_dll.req,
            rbr_req_is_wr => hwif_out.rbr_thr_dll.req_is_wr,
            rbr_wr_data   => hwif_out.rbr_thr_dll.wr_data,
            rbr_wr_biten  => hwif_out.rbr_thr_dll.wr_biten,
            rbr_rd_ack    => hwif_in.rbr_thr_dll.rd_ack,
            rbr_rd_data   => hwif_in.rbr_thr_dll.rd_data,
            rbr_wr_ack    => hwif_in.rbr_thr_dll.wr_ack,
            ier_req       => hwif_out.ier_dlm.req,
            ier_req_is_wr => hwif_out.ier_dlm.req_is_wr,
            ier_wr_data   => hwif_out.ier_dlm.wr_data,
            ier_wr_biten  => hwif_out.ier_dlm.wr_biten,
            ier_rd_ack    => hwif_in.ier_dlm.rd_ack,
            ier_rd_data   => hwif_in.ier_dlm.rd_data,
            ier_wr_ack    => hwif_in.ier_dlm.wr_ack,
            lcr_dlab      => hwif_out.lcr.dlab.value,
            mcr(4)        => hwif_out.mcr.loopback.value,
            mcr(3)        => hwif_out.mcr.out2.value,
            mcr(2)        => hwif_out.mcr.out1.value,
            mcr(1)        => hwif_out.mcr.rts.value,
            mcr(0)        => hwif_out.mcr.dtr.value,
            iir_rd        => hwif_out.iir.no_int.rd_swacc,
            iir_no_int    => hwif_in.iir.no_int.next_q,
            iir_id        => iir_id,
            lsr_dr        => hwif_in.lsr.dr.next_q,
            lsr_oe        => hwif_out.lsr.oe.value,
            lsr_oe_set    => hwif_in.lsr.oe.hwset,
            lsr_thre      => lsr_thre,
            msr           => msr,
            irq           => irq,
            dn_lines      => dn_lines,
            up_lines      => up_lines
        );
end architecture behavioral;
