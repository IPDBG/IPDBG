library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity TAP is
    port(
        --clk             : out std_logic;
        --reset           : out std_logic;

        Capture         : out std_logic;
        Shift           : out std_logic;
        Update          : out std_logic;
        TDI_o           : out std_logic;
        TDO_i           : in  std_logic;
        SEL             : out std_logic;
        DRCK            : out std_logic;

        TDI_i           : in  std_logic;
        TDO_o           : out std_logic;
        TMS             : in  std_logic;
        TCK             : in  std_logic


         );
end entity;


architecture tab of TAP is

    type TAP_Controller is(Test_logic_reset, Run_test, Select_dr_scan, Capture_dr, Shift_dr, Exit1_dr, Pause_dr, Exit2_dr, Update_dr, Select_ir_scan, Capture_ir, Shift_ir, Exit1_ir, Pause_ir, Exit2_ir, Update_ir);
    signal TAP    : TAP_Controller :=  Run_test;

    signal InstuctionRegister   : std_logic_vector(7 downto 0);
    signal BypassRegister       : std_logic;
    signal IDCodeRegister       : std_logic_vector(7 downto 0) := "11110000";
    signal User1Register        : std_logic;

    signal shift_ir_s           : std_logic;
    signal shift_dr_s           : std_logic;

    constant Bypass             : std_logic_vector(7 downto 0) := "11111111";
    constant User1              : std_logic_vector(7 downto 0) := "01010101";
    constant IDCode             : std_logic_vector(7 downto 0) := "11110000";


begin
    DRCK <= TCK ;
    process(TCK)
    begin
        --DRCK <= '0';
        if rising_edge(TCK) then
            --DRCK <= '1';
            shift <= shift_dr_s;
            case TAP is
                when Test_logic_reset =>
                    if TMS = '0' then
                        TAP <= Run_test;
                    end if;
                when Run_test =>
                    if TMS = '1' then
                        TAP <= Select_dr_scan;
                    end if;

                when Select_dr_scan =>
                    if TMS = '1' then
                        TAP <= Select_ir_scan;
                    end if;
                    if TMS = '0' then
                        TAP <= Capture_dr;
                    end if;

                when Capture_dr =>
                    Capture <= '1';
                    if TMS = '1' then
                        TAP <= Exit1_dr;
                        Capture <= '0';
                    end if;
                    if TMS = '0' then
                        TAP <= Shift_dr;
                        shift_dr_s <= '1';
                        Capture <= '0';
                    end if;

                when Shift_dr =>
                    shift_dr_s <= '1';
                    if TMS = '1' then
                        TAP <= Exit1_dr;
                        shift_dr_s <= '0';
                    end if;

                when Exit1_dr =>
                    if TMS = '1' then
                        TAP <= Update_dr;
                    end if;
                    if TMS = '0' then
                        TAP <= Pause_dr;
                    end if;

                when Pause_dr =>
                    if TMS = '1' then
                        TAP <= Exit2_dr;
                    end if;

                when Exit2_dr =>
                    if TMS = '1' then
                        TAP <= Update_dr;
                    end if;
                    if TMS = '0' then
                        TAP <= Shift_dr;
                        shift_dr_s <= '1';
                    end if;

                when Update_dr =>
                    Update <= '1';
                    if TMS = '1' then
                        Update <= '0';
                        TAP <= Select_dr_scan;
                    end if;
                    if TMS = '0' then
                        Update <= '0';
                        TAP <= Run_test;
                    end if;


---------------------------IR---------------------
                when Select_ir_scan =>
                    if TMS = '1' then
                        TAP <= Test_logic_reset;
                    end if;
                    if TMS = '0' then
                        TAP <= Capture_ir;
                    end if;

                when Capture_ir =>
                    Capture <= '1';
                    if TMS = '1' then
                        Capture <= '0';
                        TAP <= Exit1_ir;
                    end if;
                    if TMS = '0' then
                        Capture <= '0';
                        shift_ir_s <= '1';
                        TAP <= Shift_ir;
                    end if;

                when Shift_ir =>
                    shift_ir_s <= '1';
                    if TMS = '0' then
                        --shift_ir_s <= '1';

                    else
                        TAP <= Exit1_ir;
                        shift_ir_s <= '0';
                    end if;

                when Exit1_ir =>
                    if TMS = '1' then
                        TAP <= Update_ir;
                    end if;
                    if TMS = '0' then
                        TAP <= Pause_ir;
                    end if;

                when Pause_ir =>
                    if TMS = '1' then
                        TAP <= Exit2_ir;
                    end if;

                when Exit2_ir =>
                    if TMS = '1' then
                        TAP <= Update_ir;
                    end if;
                    if TMS = '0' then
                        TAP <= Shift_ir;
                    end if;

                when Update_ir =>
                    Update <= '1';
                    if TMS = '1' then
                        TAP <= Select_dr_scan;
                        Update <= '0';
                    end if;
                    if TMS = '0' then
                        TAP <= Run_test;
                        Update <= '0';
                    end if;
            end case;
        end if;
    end process;

    process(TCK)
    begin
        if rising_edge(TCK) then
            if shift_ir_s = '1' then
                InstuctionRegister <= TDI_i & InstuctionRegister(InstuctionRegister'left downto 1);
            else
                if InstuctionRegister = Bypass then
                    SEL <= '0';
                    if shift_dr_s = '1' then
                        TDI_o <= TDI_i;
                        TDO_o <= TDO_i;
                    end if;
                end if;
                if InstuctionRegister = User1 then
                    SEL <= '1';
                    if shift_dr_s = '1' then
                        TDI_o <= TDI_i;
                        TDO_o <= TDO_i;
                    end if;
                end if;
                 if InstuctionRegister = IDCode then
                     SEL <= '0';
                     if shift_dr_s = '1' then
                         IDCodeRegister <= IDCodeRegister(IDCodeRegister'left downto 0);
                         TDO_o <= IDCodeRegister(7);
                     end if;
                 end if;
            end if;
        end if;
    end process;
end architecture tab;
