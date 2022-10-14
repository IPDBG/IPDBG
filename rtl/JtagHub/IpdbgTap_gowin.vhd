library ieee;
use ieee.std_logic_1164.all;

entity IpdbgTap is
    port(
        TCK     : in  std_logic;
        TMS     : in  std_logic;
        TDI     : in  std_logic;
        TDO     : out std_logic;

        capture : out std_logic;
        drclk   : out std_logic;
        user    : out std_logic;
        shift   : out std_logic;
        update  : out std_logic;
        tdi_o   : out std_logic;
        tdo_i   : in  std_logic
    );
end entity;

architecture gowin of IpdbgTap is

    component GW_JTAG is
        port(
            tck_pad_i             : in  std_logic;
            tms_pad_i             : in  std_logic;
            tdi_pad_i             : in  std_logic;
            tdo_pad_o             : out std_logic;
            tdo_er1_i             : in  std_logic;
            tdo_er2_i             : in  std_logic;
            tck_o                 : out std_logic;
            tdi_o                 : out std_logic;
            test_logic_reset_o    : out std_logic;
            run_test_idle_er1_o   : out std_logic;
            run_test_idle_er2_o   : out std_logic;
            shift_dr_capture_dr_o : out std_logic;
            pause_dr_o            : out std_logic;
            update_dr_o           : out std_logic;
            enable_er1_o          : out std_logic;
            enable_er2_o          : out std_logic
        );
    end component GW_JTAG;

    signal drclk_s       : std_logic;
    signal run_test_idle : std_logic;
    signal update_s      : std_logic;

    type TAP_States      is (Test_logic_reset, Run_test, Select_dr_scan, Capture_dr, Shift_dr, Exit1_dr, Pause_dr,
                             Exit2_dr, Update_dr, Select_ir_scan, Capture_ir, Shift_ir, Exit1_ir, Pause_ir, Exit2_ir, Update_ir);
    signal TAP           : TAP_States;
begin

    gw_jtag_i: GW_JTAG
        port map(
            tck_pad_i             => TCK,
            tms_pad_i             => TMS,
            tdi_pad_i             => TDI,
            tdo_pad_o             => TDO,
            tdo_er1_i             => tdo_i,
            tdo_er2_i             => '0',
            tck_o                 => drclk_s,
            tdi_o                 => tdi_o,
            test_logic_reset_o    => open,
            run_test_idle_er1_o   => run_test_idle,
            run_test_idle_er2_o   => open,
            shift_dr_capture_dr_o => shift,
            pause_dr_o            => open,
            update_dr_o           => update_s,
            enable_er1_o          => user,
            enable_er2_o          => open
        );

    drclk <= drclk_s;
    update <= update_s;

    -- shift_dr_capture_dr_o is only active during the shift state
    -- so we follow the tap fsm here again to generate capture
    -- test_logic_reset_o is always '1' .. so we don't sync on this
    -- same for pause_dr_o
    process(drclk_s)begin
        if rising_edge(drclk_s) then

            case TAP is
            when Test_logic_reset => if TMS = '0' then TAP <= Run_test;                                 end if;
            when Run_test         => if TMS = '1' then TAP <= Select_dr_scan;                           end if;
            ---------------------------DR---------------------
            when Select_dr_scan   => if TMS = '1' then TAP <= Select_ir_scan;   else TAP <= Capture_dr; end if;
            when Capture_dr       => if TMS = '1' then TAP <= Exit1_dr;         else TAP <= Shift_dr;   end if;
            when Shift_dr         => if TMS = '1' then TAP <= Exit1_dr;                                 end if;
            when Exit1_dr         => if TMS = '1' then TAP <= Update_dr;        else TAP <= Pause_dr;   end if;
            when Pause_dr         => if TMS = '1' then TAP <= Exit2_dr;                                 end if;
            when Exit2_dr         => if TMS = '1' then TAP <= Update_dr;        else TAP <= Shift_dr;   end if;
            when Update_dr        => if TMS = '1' then TAP <= Select_dr_scan;   else TAP <= Run_test;   end if;
            ---------------------------IR---------------------
            when Select_ir_scan   => if TMS = '1' then TAP <= Test_logic_reset; else TAP <= Capture_ir; end if;
            when Capture_ir       => if TMS = '1' then TAP <= Exit1_ir;         else TAP <= Shift_ir;   end if;
            when Shift_ir         => if TMS = '1' then TAP <= Exit1_ir;                                 end if;
            when Exit1_ir         => if TMS = '1' then TAP <= Update_ir;        else TAP <= Pause_ir;   end if;
            when Pause_ir         => if TMS = '1' then TAP <= Exit2_ir;                                 end if;
            when Exit2_ir         => if TMS = '1' then TAP <= Update_ir;        else TAP <= Shift_ir;   end if;
            when Update_ir        => if TMS = '1' then TAP <= Select_dr_scan;   else TAP <= Run_test;   end if;
            end case;

            if run_test_idle = '1' then
                if TMS = '1' then
                    TAP <= Select_dr_scan;
                else
                    TAP <= run_test;
                end if;
            elsif update_s = '1' then
                if TMS = '1' then
                    TAP <= Select_dr_scan;
                else
                    TAP <= run_test;
                end if;
            end if;

        end if;
    end process;

    capture <= '1' when TAP = Capture_dr else '0';

end architecture gowin;
