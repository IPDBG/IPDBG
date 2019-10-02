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
    signal tck        : std_logic;
    signal exit1dr    : std_logic;
    signal exit2dr 	 : std_logic;
    signal test_reset : std_logic;
    signal v_shift_dr : std_logic;
	 signal v_capture_dr : std_logic;
	 signal v_update_dr : std_logic;
	 signal load		 : std_logic;
	 signal update_counter : std_logic_vector(7 downto 0) := (others=>'0');
	 signal ucounter : natural range 0 to 255 := 0;
	 signal shift_count : natural range 0 to 255 := 0;
	 signal sr			 : std_logic_vector(7 downto 0) := (others=>'0');

begin

--		test : process(tck) begin
--			if rising_edge(tck) then
--				if test_reset = '1' then
--					sr <= x"42";
--				elsif v_shift_dr = '1' then
--					sr <= sr(0) & sr(7 downto 1);
--				elsif v_update_dr = '1' then
--					sr <= std_logic_vector(unsigned(sr)+1);
--				end if;
--			end if;
--		end process;


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
            jtag_state_tlr      => test_reset,
            tck                 => tck,
            jtag_state_sir      => open,
            ir_in               => open,
            virtual_state_cir   => open,
            virtual_state_pdr   => open,
            ir_out              => open,
            virtual_state_uir   => open,
            jtag_state_cir      => open,
            jtag_state_uir      => open,
            jtag_state_pdr      => open,
            tdo                 => tdo,--sr(0),
            jtag_state_sdrs     => open,
            virtual_state_sdr   => v_shift_dr,
            virtual_state_cdr   => v_capture_dr,
            jtag_state_sdr      => open,
            jtag_state_cdr      => open,
            virtual_state_udr   => v_update_dr,
            jtag_state_udr      => open,
            jtag_state_sirs     => open,
            jtag_state_e1ir     => open,
            jtag_state_e2ir     => open,
            virtual_state_e1dr  => open,
            virtual_state_e2dr  => open
        );

    drclk <= tck;
	 update <= v_update_dr;
	 capture <= v_capture_dr;
	 shift <= v_shift_dr;
	 user <= '1';
	 --tdi <= sr(7);

end architecture structure;
