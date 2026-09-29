-- SPDX-FileCopyrightText: The IPDBG authors
-- SPDX-License-Identifier: CERN-OHL-W-2.0

-- Iurt with a bus slave interface: APB3.
-- See IurtCore.vhd for the registers and the behaviour.
-- The bus ports have the names of the bus specification, slave view; they
-- connect to generated/IurtRegsApb3.vhd (PeakRDL-regblock-vhdl, --cpuif,
-- flattened). The address selects one of the 8 registers of Iurt (32 bytes).
-- The register block has a synchronous reset: clk must run while rst is
-- active. ASYNC_RESET and ce only apply to IurtCore.
--
-- Needs IurtCore.vhd, generated/IurtRegsApb3.vhd, generated/IurtRegsApb3_pkg.vhd,
-- generated/reg_utils.vhd (VHDL-2008) and rtl/common/ipdbg_interface_pkg.vhd.

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.ipdbg_interface_pkg.all;
use work.IurtRegsApb3_pkg.all;

entity IurtApb3 is
    generic(
        ASYNC_RESET : boolean
    );
    port(
        clk      : in  std_logic;
        rst      : in  std_logic;
        ce       : in  std_logic;

        psel     : in  std_logic;
        penable  : in  std_logic;
        pwrite   : in  std_logic;
        paddr    : in  std_logic_vector(4 downto 0);
        pwdata   : in  std_logic_vector(31 downto 0);
        pready   : out std_logic;
        prdata   : out std_logic_vector(31 downto 0);
        pslverr  : out std_logic;

        irq      : out std_logic; -- level, active high

        -- host interface (JtagHub or ....)
        dn_lines : in  ipdbg_dn_lines;
        up_lines : out ipdbg_up_lines
    );
end entity IurtApb3;

architecture structure of IurtApb3 is
    component IurtRegsApb3 is
        port (
            clk           : in  std_logic;
            rst           : in  std_logic;
            s_apb_psel    : in  std_logic;
            s_apb_penable : in  std_logic;
            s_apb_pwrite  : in  std_logic;
            s_apb_paddr   : in  std_logic_vector(4 downto 0);
            s_apb_pwdata  : in  std_logic_vector(31 downto 0);
            s_apb_pready  : out std_logic;
            s_apb_prdata  : out std_logic_vector(31 downto 0);
            s_apb_pslverr : out std_logic;
            hwif_in       : in  iurt_in_t;
            hwif_out      : out iurt_out_t
        );
    end component IurtRegsApb3;

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

    signal hwif_in  : iurt_in_t;
    signal hwif_out : iurt_out_t;
    signal iir_id   : std_logic_vector(1 downto 0);
    signal lsr_thre : std_logic;
    signal msr      : std_logic_vector(7 downto 4);
begin
    regs : component IurtRegsApb3
        port map (
            clk           => clk,
            rst           => rst,
            s_apb_psel    => psel,
            s_apb_penable => penable,
            s_apb_pwrite  => pwrite,
            s_apb_paddr   => paddr,
            s_apb_pwdata  => pwdata,
            s_apb_pready  => pready,
            s_apb_prdata  => prdata,
            s_apb_pslverr => pslverr,
            hwif_in       => hwif_in,
            hwif_out      => hwif_out
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
end architecture structure;
