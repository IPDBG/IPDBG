library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library altera;
use altera.altera_primitives_components.all;

entity IpdbgTap is
    port(
        capture : out std_logic;
        drclk   : out std_logic;
        user    : out std_logic;
        shift   : out std_logic;
        update  : out std_logic;
        tdi     : out std_logic;
        tdo     : in  std_logic
    );
end entity;

architecture structure of IpdbgTap is

COMPONENT sld_virtual_jtag
        GENERIC (
            sld_auto_instance_index : STRING;
            sld_instance_index      : NATURAL;
            sld_ir_width            : NATURAL;
            sld_sim_action          : STRING;
            sld_sim_n_scan          : NATURAL;
            sld_sim_total_length    : NATURAL;
            lpm_type                : STRING
        );
        PORT (
            tdi                 : OUT STD_LOGIC ;
            jtag_state_rti_type : OUT STD_LOGIC ;
            jtag_state_e1dr     : OUT STD_LOGIC ;
            jtag_state_e2dr     : OUT STD_LOGIC ;
            tms                 : OUT STD_LOGIC ;
            jtag_state_pir      : OUT STD_LOGIC ;
            jtag_state_tlr      : OUT STD_LOGIC ;
            tck                 : OUT STD_LOGIC ;
            jtag_state_sir      : OUT STD_LOGIC ;
            ir_in               : OUT STD_LOGIC_VECTOR (1 DOWNTO 0);
            virtual_state_cir   : OUT STD_LOGIC ;
            virtual_state_pdr   : OUT STD_LOGIC ;
            ir_out              : IN STD_LOGIC_VECTOR (1 DOWNTO 0);
            virtual_state_uir   : OUT STD_LOGIC ;
            jtag_state_cir      : OUT STD_LOGIC ;
            jtag_state_uir      : OUT STD_LOGIC ;
            jtag_state_pdr      : OUT STD_LOGIC ;
            tdo                 : IN STD_LOGIC ;
            jtag_state_sdrs     : OUT STD_LOGIC ;
            virtual_state_sdr   : OUT STD_LOGIC ;
            virtual_state_cdr   : OUT STD_LOGIC ;
            jtag_state_sdr      : OUT STD_LOGIC ;
            jtag_state_cdr      : OUT STD_LOGIC ;
            virtual_state_udr   : OUT STD_LOGIC ;
            jtag_state_udr      : OUT STD_LOGIC ;
            jtag_state_sirs     : OUT STD_LOGIC ;
            jtag_state_e1ir     : OUT STD_LOGIC ;
            jtag_state_e2ir     : OUT STD_LOGIC ;
            virtual_state_e1dr  : OUT STD_LOGIC ;
            virtual_state_e2dr  : OUT STD_LOGIC
        );
    END COMPONENT;

begin

        BSCAN_MAX10_inst  :  sld_virtual_jtag
        generic map(
            sld_auto_instance_index => "YES",
            sld_instance_index      => 0,
            sld_ir_width            => 1,
            sld_sim_action          => "",
            sld_sim_n_scan          => 0,
            sld_sim_total_length    => 0,
            lpm_type                => "sld_virtual_jtag"
        )
        port map(
            tdi                 => tdi,
            jtag_state_rti_type => open,
            jtag_state_e1dr     => open,
            jtag_state_e2dr     => open,
            tms                 => open,
            jtag_state_pir      => open,
            jtag_state_tlr      => open,
            tck                 => drclk,
            jtag_state_sir      => open,
            ir_in               => open,
            virtual_state_cir   => open,
            virtual_state_pdr   => open,
            ir_out              => open,
            virtual_state_uir   => open,
            jtag_state_cir      => open,
            jtag_state_uir      => open,
            jtag_state_pdr      => open,
            tdo                 => tdo,
            jtag_state_sdrs     => open,
            virtual_state_sdr   => shift,
            virtual_state_cdr   => capture,
            jtag_state_sdr      => open,
            jtag_state_cdr      => open,
            virtual_state_udr   => update,
            jtag_state_udr      => open,
            jtag_state_sirs     => open,
            jtag_state_e1ir     => open,
            jtag_state_e2ir     => open,
            virtual_state_e1dr  => open,
            virtual_state_e2dr  => open
        );
	 user <= '1';

end architecture structure;
