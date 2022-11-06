library ieee;
use ieee.std_logic_1164.all;

entity IpdbgTap is
    port(
        TCK     : in  std_logic;
        TMS     : in  std_logic;
        TDI     : in  std_logic;
        TDO     : out std_logic;
        capture : out std_logic;
        Shift   : out std_logic;
        Update  : out std_logic;
        user    : out std_logic;
        drclk   : out std_logic;
        tdi_o   : out std_logic;
        tdo_i   : in  std_logic
    );
end entity;


architecture tab of IpdbgTap is

    constant BypassCode         : std_logic_vector(7 downto 0) := "11111111";
    constant User1Code          : std_logic_vector(7 downto 0) := "01010101";
    constant IDCode             : std_logic_vector(7 downto 0) := "11110000";

    constant IdValue            : std_logic_vector(31 downto 0) := "11110000111100001111000011110001";

    type TAP_States             is(Test_logic_reset, Run_test, Select_dr_scan, Capture_dr, Shift_dr, Exit1_dr, Pause_dr,
                                   Exit2_dr, Update_dr, Select_ir_scan, Capture_ir, Shift_ir, Exit1_ir, Pause_ir, Exit2_ir, Update_ir);
    signal TAP                  : TAP_States;

    signal InstuctionRegister   : std_logic_vector(7 downto 0) := IDCode;
    constant Status             : std_logic_vector(7 downto 0) := x"01";
    signal BypassRegister       : std_logic;
    signal IDCodeRegister       : std_logic_vector(31 downto 0) := IdValue;

    signal IdRegisterSelected   : std_logic;
    signal User1Selected        : std_logic;
    signal BypassSelected       : std_logic;
begin
    process(TCK)begin
        if rising_edge(TCK) then
            case TAP is
            when Test_logic_reset => if TMS = '0' then TAP <= Run_test; end if;
            when Run_test         => if TMS = '1' then TAP <= Select_dr_scan; end if;

            ---------------------------DR---------------------
            when Select_dr_scan   => if TMS = '1' then TAP <= Select_ir_scan;   else TAP <= Capture_dr;  end if;
            when Capture_dr       => if TMS = '1' then TAP <= Exit1_dr;         else TAP <= Shift_dr;    end if;
            when Shift_dr         => if TMS = '1' then TAP <= Exit1_dr;                                  end if;
            when Exit1_dr         => if TMS = '1' then TAP <= Update_dr;        else TAP <= Pause_dr;    end if;
            when Pause_dr         => if TMS = '1' then TAP <= Exit2_dr;                                  end if;
            when Exit2_dr         => if TMS = '1' then TAP <= Update_dr;        else TAP <= Shift_dr;    end if;
            when Update_dr        => if TMS = '1' then TAP <= Select_dr_scan;   else TAP <= Run_test;    end if;

            ---------------------------IR---------------------
            when Select_ir_scan   => if TMS = '1' then TAP <= Test_logic_reset; else  TAP <= Capture_ir; end if;
            when Capture_ir       => if TMS = '1' then TAP <= Exit1_ir;         else TAP <= Shift_ir;    end if;
            when Shift_ir         => if TMS = '1' then TAP <= Exit1_ir;                                  end if;
            when Exit1_ir         => if TMS = '1' then TAP <= Update_ir;        else TAP <= Pause_ir;    end if;
            when Pause_ir         => if TMS = '1' then TAP <= Exit2_ir;                                  end if;
            when Exit2_ir         => if TMS = '1' then TAP <= Update_ir;        else TAP <= Shift_ir;    end if;
            when Update_ir        => if TMS = '1' then TAP <= Select_dr_scan;   else TAP <= Run_test;    end if;
            end case;
        end if;
    end process;

    Shift    <= '1' when TAP = Shift_dr   else '0';
    Capture  <= '1' when TAP = Capture_dr else '0';
    Update   <= '1' when TAP = Update_dr  else '0';

    user <= User1Selected;
    DRCLK <= TCK;

    outputMultiplexer: block
        signal DrMuxOutput : std_logic;
    begin
        process(TAP, InstuctionRegister, DrMuxOutput)begin
            if TAP = shift_ir then
                TDO <= InstuctionRegister(0);
            else
                TDO <= DrMuxOutput;
            end if;
        end process;

        process(User1Selected, BypassSelected, tdo_i, BypassRegister, IDCodeRegister)begin
            if User1Selected = '1' then
                DrMuxOutput <= tdo_i;
            elsif BypassSelected = '1' then
                DrMuxOutput <= BypassRegister;
            else
                DrMuxOutput <= IDCodeRegister(0);
            end if;
        end process;
    end block;

    tdi_o <= TDI;

    process(TCK)begin
        if rising_edge(TCK) then
            if TAP = Shift_ir then
                InstuctionRegister <= TDI & InstuctionRegister(InstuctionRegister'left downto 1);
            elsif TAP = Update_ir then
                User1Selected <= '0';
                BypassSelected <= '0';
                IdRegisterSelected <= '0';
                if InstuctionRegister = User1Code then
                    User1Selected <= '1';
                elsif InstuctionRegister = BypassCode then
                    BypassSelected <= '1';
                elsif InstuctionRegister = IDCode then
                    IdRegisterSelected <= '1';
                end if;
            elsif TAP = Test_logic_reset then
                User1Selected <= '0';
                BypassSelected <= '0';
                IdRegisterSelected <= '1';
                InstuctionRegister <= IDCode;
            elsif TAP = Capture_ir then
                InstuctionRegister <= Status;
            end if;

            if TAP = Shift_dr then
                if BypassSelected = '1' then
                    BypassRegister <= TDI;
                elsif User1Selected = '1' then
                    null;
                end if;
            end if;

            if TAP = Shift_dr then
                if IdRegisterSelected = '1' then
                    IDCodeRegister <= TDI & IDCodeRegister(IDCodeRegister'left downto 1);
                end if;
            elsif TAP = capture_ir then
                IDCodeRegister <= IdValue;
            end if;

        end if;
    end process;

end architecture tab;
