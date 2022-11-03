library ieee;
use ieee.std_logic_1164.all;

entity IpdbgTap is
    port(
        TCK     : in  std_logic;
        TMS     : in  std_logic;
        TDI     : in  std_logic;
        TDO     : out std_logic;

        drclk   : out std_logic;
        capture : out std_logic;
        user    : out std_logic;
        shift   : out std_logic;
        update  : out std_logic;
        tdi_o   : out std_logic;
        tdo_i   : in  std_logic
    );
end entity;

architecture intel_arch of IpdbgTap is

    component IpdbgTap_intel_jtag is
        port (
            tms         : in  std_logic;
            tck         : in  std_logic;
            tdi         : in  std_logic;
            tdo         : out std_logic;
            tdouser     : in  std_logic;
            tmsutap     : out std_logic;
            tckutap     : out std_logic;
            tdiutap     : out std_logic;
            shiftuser   : out std_logic;
            updateuser  : out std_logic;
            runidleuser : out std_logic;
            usr1user    : out std_logic
        );
    end component IpdbgTap_intel_jtag;


    signal drclk_s       : std_logic;
    signal update_s      : std_logic;
    signal capture_s     : std_logic;
    signal user_s        : std_logic;
    signal shift_s       : std_logic;
    signal user1user     : std_logic;

    signal tmsutap       : std_logic;
    signal runidleuser   : std_logic;


    type TAP_States      is (Test_logic_reset, Run_test, Select_dr_scan, Capture_dr, Shift_dr, Exit1_dr, Pause_dr,
                             Exit2_dr, Update_dr, Select_ir_scan, Capture_ir, Shift_ir, Exit1_ir, Pause_ir, Exit2_ir, Update_ir);
    signal TAP           : TAP_States;
begin

    drclk <= drclk_s;
    user <= user1user; --
    update <= update_s;
    shift <= shift_s;


    jtag_tap_i: component IpdbgTap_intel_jtag
        port map(
            tms         => tms,
            tck         => tck,
            tdi         => tdi,
            tdo         => tdo,
            tdouser     => tdo_i,
            tmsutap     => tmsutap,
            tckutap     => drclk_s,
            tdiutap     => tdi_o,
            shiftuser   => shift_s,
            updateuser  => update_s,
            runidleuser => runidleuser,
            usr1user    => user1user
        );

    drclk <= drclk_s;
    update <= update_s;

    -- there is no captureuser so we follow the tap fsm here to generate it.
    process(drclk_s)begin
        if rising_edge(drclk_s) then

            case TAP is
            when Test_logic_reset => if tmsutap = '0' then TAP <= Run_test;                                 end if;
            when Run_test         => if tmsutap = '1' then TAP <= Select_dr_scan;                           end if;
            ---------------------------DR---------------------
            when Select_dr_scan   => if tmsutap = '1' then TAP <= Select_ir_scan;   else TAP <= Capture_dr; end if;
            when Capture_dr       => if tmsutap = '1' then TAP <= Exit1_dr;         else TAP <= Shift_dr;   end if;
            when Shift_dr         => if tmsutap = '1' then TAP <= Exit1_dr;                                 end if;
            when Exit1_dr         => if tmsutap = '1' then TAP <= Update_dr;        else TAP <= Pause_dr;   end if;
            when Pause_dr         => if tmsutap = '1' then TAP <= Exit2_dr;                                 end if;
            when Exit2_dr         => if tmsutap = '1' then TAP <= Update_dr;        else TAP <= Shift_dr;   end if;
            when Update_dr        => if tmsutap = '1' then TAP <= Select_dr_scan;   else TAP <= Run_test;   end if;
            ---------------------------IR---------------------
            when Select_ir_scan   => if tmsutap = '1' then TAP <= Test_logic_reset; else TAP <= Capture_ir; end if;
            when Capture_ir       => if tmsutap = '1' then TAP <= Exit1_ir;         else TAP <= Shift_ir;   end if;
            when Shift_ir         => if tmsutap = '1' then TAP <= Exit1_ir;                                 end if;
            when Exit1_ir         => if tmsutap = '1' then TAP <= Update_ir;        else TAP <= Pause_ir;   end if;
            when Pause_ir         => if tmsutap = '1' then TAP <= Exit2_ir;                                 end if;
            when Exit2_ir         => if tmsutap = '1' then TAP <= Update_ir;        else TAP <= Shift_ir;   end if;
            when Update_ir        => if tmsutap = '1' then TAP <= Select_dr_scan;   else TAP <= Run_test;   end if;
            end case;

            if runidleuser = '1' then
                if tmsutap = '1' then
                    TAP <= Select_dr_scan;
                else
                    TAP <= Run_test;
                end if;
            elsif update_s = '1' then
                if tmsutap = '1' then
                    TAP <= Select_dr_scan;
                else
                    TAP <= Run_test;
                end if;
            end if;

        end if;
    end process;

    capture <= '1' when TAP = Capture_dr else '0';

end architecture intel_arch;
