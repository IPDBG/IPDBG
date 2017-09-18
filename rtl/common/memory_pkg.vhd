library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all; -- unsigned needed in max length check

use std.textio.all;

package memory_pkg is
    impure function initRAM(INIT_FILE_NAME : string; constant  DATA_WIDTH : natural; constant MEM_SIZE : natural) return std_logic_vector;
    --if INIT_FILE_NAME'length = 0 or INIT_FILE_NAME = "UNUSED" then

    pure function initRAMwithConstant(CONST : std_logic_vector; constant MEM_SIZE : natural) return std_logic_vector;
    pure function initRAMwithZeros(constant  DATA_WIDTH : natural; constant MEM_SIZE : natural) return std_logic_vector;
end;


package body memory_pkg is


    pure function initRAMwithConstant(CONST : std_logic_vector; constant MEM_SIZE : natural) return std_logic_vector is
        constant  DATA_WIDTH : natural := CONST'length;
        variable initValues  : std_logic_vector(DATA_WIDTH*MEM_SIZE-1 downto 0);
    begin
        for I in 0 to MEM_SIZE-1 loop
            initValues((I+1)*DATA_WIDTH-1 downto I*DATA_WIDTH) := CONST;
        end loop;
        return initValues;
    end initRAMwithConstant;

    pure function initRAMwithZeros(constant  DATA_WIDTH : natural; constant MEM_SIZE : natural) return std_logic_vector is
        constant ZERO  : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    begin
        return initRAMwithConstant(ZERO, MEM_SIZE);
    end initRAMwithZeros;

    impure function initRAMFromMifFile(INIT_FILE_NAME : string; constant  DATA_WIDTH : natural; constant MEM_SIZE : natural) return std_logic_vector is
        type radix_t is (BIN, HEX, OCT, DEC, UNS);
        type parts_t is (Header, AddresPart, AddressBegin, AddressSingle, AddressDots, AddressEnd, DataPart,
              DepthPart, WidthPart, AddrRadixPart, DataRadixPart);--, ContentPart);
        constant MAX_TOKEN_LENGTH : natural := 14;
        type MifParserState_t is record
            -- lexer:
            part           : parts_t;
            inBlockComment : boolean;
            lastCh         : character;

            token          : string(1 to MAX_TOKEN_LENGTH); -- ADDRESS_RADIX is longest token
            tokenLength    : natural;

            AddressRadix   : radix_t;
            DataRadix      : radix_t;
            memDepth       : natural;
            memWidth       : natural;

            -- temp storage
            number         : unsigned(DATA_WIDTH-1 downto 0);
            negNumber      : boolean;
            hasParsedNumber: boolean;

            AddressBegin   : natural;
            AddressEnd     : natural;
            AddressOffset  : natural;
            AddrIsRange    : boolean;

            endDetected    : boolean;
            minusSignFound : boolean;

        end record;
        file     fp          : text;
        variable linePtr     : line;
        variable ch          : character;
        variable initValues  : std_logic_vector(DATA_WIDTH*MEM_SIZE-1 downto 0);
        variable inString    : boolean;
        variable parserState : MifParserState_t;
        variable lineNumber  : natural;
        procedure clearToken is
        begin
            parserState.token       := "              ";
            parserState.tokenLength := 0;
        end procedure;
        procedure clearParsedNumber is
        begin
            parserState.hasParsedNumber := false;
            parserState.number := to_unsigned(0,parserState.number'length);
            parserState.negNumber := false;
        end procedure;

        procedure storeData is
            variable data  : std_logic_vector(DATA_WIDTH-1 downto 0);
            variable dat_i : integer;
            variable idx   : natural;
        begin
            if parserState.hasParsedNumber then
                idx := parserState.AddressBegin + parserState.AddressOffset;
                if not parserState.negNumber then
                    initValues((idx+1)*DATA_WIDTH-1 downto idx*DATA_WIDTH) := std_logic_vector(parserState.number);
                else
                    initValues((idx+1)*DATA_WIDTH-1 downto idx*DATA_WIDTH) := std_logic_vector(-signed(parserState.number));
                end if;
                parserState.AddressOffset := parserState.AddressOffset+1;
            end if;
            clearParsedNumber;
        end procedure;
        procedure fillData is
            variable rdIdx      : natural;
            constant RD_IDX_END : natural := parserState.AddressOffset-1;
            variable rdAddr     : natural;
            variable wrAddr     : natural;
        begin
            if parserState.AddrIsRange then
                rdIdx := parserState.AddressBegin;
                while parserState.AddressOffset <= parserState.AddressEnd loop
                    wrAddr := parserState.AddressBegin + parserState.AddressOffset;
                    rdAddr := parserState.AddressBegin + rdIdx;
                    wrAddr := wrAddr mod parserState.memDepth;
                    rdAddr := rdAddr mod parserState.memDepth;
                    initValues((wrAddr+1)*DATA_WIDTH-1 downto wrAddr*DATA_WIDTH) := initValues((rdAddr+1)*DATA_WIDTH-1 downto rdAddr*DATA_WIDTH);

                    -- increment both pointer
                    parserState.AddressOffset := parserState.AddressOffset+1;
                    if rdIdx = RD_IDX_END then
                        rdIdx := 0;
                    else
                        rdIdx := rdIdx + 1;
                    end if;
                end loop;
            end if;
        end procedure;
        procedure parseRadix(variable ch : inout character) is
            variable tmpRadix : radix_t;
        begin
            if parserState.tokenLength+1 <= 4 then
                if ch >= 'A' and ch <= 'Z' then -- BIN , UNS
                    ch := character'val( (character'pos(ch) - character'pos('A')) + character'pos('a'));
                end if;
                -- there is no check that there are no white-spaces in BIN, HEX, ...
                parserState.token(parserState.tokenLength+1) := ch;
                parserState.tokenLength := parserState.tokenLength+1;
                if parserState.tokenLength = 4 then
                    if parserState.token(1 to 4) = "bin;" then    tmpRadix := BIN;
                    elsif parserState.token(1 to 4) = "hex;" then tmpRadix := HEX;
                    elsif parserState.token(1 to 4) = "oct;" then tmpRadix := OCT;
                    elsif parserState.token(1 to 4) = "dec;" then tmpRadix := DEC;
                    elsif parserState.token(1 to 4) = "uns;" then tmpRadix := UNS;
                    else
                        report "parsing failed the radix at" & parserState.token severity failure;
                    end if;
                    if parserState.part = AddrRadixPart then
                        parserState.AddressRadix := tmpRadix;
                    else
                        parserState.DataRadix := tmpRadix;
                    end if;
                    parserState.part := Header;
                end if;
            else
                report "parsing the radix failed at" & parserState.token severity failure;
            end if;
        end procedure;
        procedure parseNumber(variable ch : inout character) is
            variable tmpRadix    : radix_t;
            variable illegalchar : boolean;
            variable tch         : character;
        begin
            illegalchar := false;

            case parserState.part is
            when DepthPart | WidthPart =>
                if not ((ch >= '0' and ch <= '9')) then
                    report "expecting number for a depth or width number" severity failure;
                else
                    if parserState.part = DepthPart then
                        parserState.memDepth := parserState.memDepth*10 + character'pos(ch)-character'pos('0');
                    else
                        parserState.memWidth := parserState.memWidth*10 + character'pos(ch)-character'pos('0');
                    end if;
                end if;
                clearParsedNumber;
            when AddressBegin | AddressEnd | AddressSingle | DataPart =>
                if parserState.part = DataPart then
                    tmpRadix := parserState.DataRadix;
                else
                    tmpRadix := parserState.AddressRadix;
                end if;
                if ch >= 'A' and ch <= 'Z' then
                    ch := character'val( (character'pos(ch) - character'pos('A')) + character'pos('a'));
                end if;
                case tmpRadix is
                when BIN =>
                    if ch = '0' then
                        parserState.number := resize(parserState.number*2,DATA_WIDTH);
                    elsif ch = '1' then
                        parserState.number := resize(parserState.number*2,DATA_WIDTH) + 1;
                    else
                        illegalchar := true;
                    end if;
                    parserState.negNumber := false;
                when DEC =>
                    if parserState.minusSignFound and parserState.hasParsedNumber = false then
                        parserState.negNumber := true;
                    end if;
                    if ch >= '0' and ch <= '9' then
                        parserState.number := resize(parserState.number*10,DATA_WIDTH) + character'pos(ch) - character'pos('0');
                    else
                        illegalchar := true;
                    end if;
                when HEX =>
                    if ch >= '0' and ch <= '9' then
                        parserState.number := resize(parserState.number*16,DATA_WIDTH) + character'pos(ch) - character'pos('0');
                    elsif ch >= 'a' and ch <= 'f' then
                        parserState.number := resize(parserState.number*16,DATA_WIDTH) + 10 + character'pos(ch) - character'pos('a');
                    else
                        illegalchar := true;
                    end if;
                    parserState.negNumber := false;
                when OCT =>
                    if ch >= '0' and ch <= '7' then
                        parserState.number := resize(parserState.number*8,DATA_WIDTH) + character'pos(ch) - character'pos('0');
                    else
                        illegalchar := true;
                    end if;
                    parserState.negNumber := false;
                when UNS =>
                    if ch >= '0' and ch <= '9' then
                        parserState.number := resize(parserState.number*10,DATA_WIDTH) + character'pos(ch) - character'pos('0');
                    else
                        illegalchar := true;
                    end if;
                    parserState.negNumber := false;
                end case;
                if parserState.part = AddressSingle then -- "end" expecting
                    tch := ch;
                    if ch >= 'A' and ch <= 'Z' then
                        tch := character'val( (character'pos(ch) - character'pos('A')) + character'pos('a'));
                    end if;
                    parserState.token := parserState.token(2 to MAX_TOKEN_LENGTH) & tch;
                    if tch = 'e' or parserState.token(13 to 14) = "en" then
                        illegalchar := false;
                    elsif parserState.token(12 to 14) = "end" then
                        parserState.endDetected := true;
                        illegalchar := false;
                    end if;
                end if;
                if illegalchar = true then
                    report "number contains illegal character!" severity failure;
                else
                    parserState.hasParsedNumber := true;
                end if;
            when others =>

                report "no number in these sections" severity failure;
            end case;
        end procedure;

    begin
        file_open(fp, INIT_FILE_NAME, READ_MODE);

        -- init state before parsing
        parserState.part            := Header;
        parserState.inBlockComment  := false;
        parserState.lastCh          := NUL;
        parserState.AddressRadix    := HEX; -- hex is default
        parserState.DataRadix       := HEX;
        clearToken;

        parserState.memDepth        := 0;
        parserState.memWidth        := 0;
        parserState.hasParsedNumber := false;
        parserState.endDetected     := false;

        fileLoop: while (not endfile(fp)) and (not parserState.endDetected) loop
            readline (fp, linePtr);
            lineNumber := lineNumber+1;
            read(linePtr, ch, inString);
            parserState.lastCh      := '0';
            lineLoop: while (inString and (not parserState.endDetected)) loop
                if not parserState.inBlockComment then
                    if ch = '-' then
                        if parserState.lastCh = '-' then
                            -- skip till end of line
                            clearToken;
                            next fileLoop;
                        else
                            parserState.minusSignFound := true;
                        end if;
                    elsif ch = '%' then
                        parserState.inBlockComment := true;
                        next;
                    elsif ch = ' ' or ch = HT then
                        --skip white-spaces
                        --clearToken;

                        if parserState.part = DataPart then
                            storeData;
                        end if;

                    else

                        case parserState.part is
                        when Header =>
                            if parserState.tokenLength+1 <= MAX_TOKEN_LENGTH then
                                if ch >= 'A' and ch <= 'Z' then
                                    ch := character'val( (character'pos(ch) - character'pos('A')) + character'pos('a'));
                                end if;
                                parserState.token(parserState.tokenLength+1) := ch;
                                parserState.tokenLength := parserState.tokenLength+1;
                            else
                                report "parsing failed at token" & parserState.token severity failure;
                            end if;
                            if parserState.tokenLength = 6 then
                                if parserState.token(1 to 6) = "depth=" then
                                    parserState.memDepth := 0;
                                    parserState.part := DepthPart;
                                    clearToken;
                                elsif  parserState.token(1 to 6) = "width=" then
                                    parserState.memWidth := 0;
                                    parserState.part := WidthPart;
                                    clearToken;
                                end if;
                            elsif parserState.tokenLength = 11 then
                                if parserState.token(1 to 11) = "data_radix=" then
                                    parserState.part := DataRadixPart;
                                    clearToken;
                                end if;
                            elsif parserState.tokenLength = 12 then
                                if  parserState.token(1 to 12) = "contentbegin" then
                                    parserState.part := AddresPart;
                                    clearToken;
                                end if;
                            elsif parserState.tokenLength = 14 then
                                if parserState.token(1 to 14) = "address_radix=" then
                                    parserState.part := AddrRadixPart;
                                    clearToken;
                                end if;
                            end if;

                        when DepthPart | WidthPart =>
                            if ch = ';' then
                                parserState.part := Header;
                            else
                                parseNumber(ch);
                            end if;
                        when AddrRadixPart | DataRadixPart =>
                            parseRadix(ch);
                        --when ContentPart =>
                        when AddresPart =>
                            clearParsedNumber;
                            parserState.AddressOffset := 0;
                            clearToken;
                            if ch = '[' then
                                parserState.part := AddressBegin;
                                parserState.AddrIsRange := true;
                            else
                                parserState.part := AddressSingle;
                                parserState.AddrIsRange := false;
                                parseNumber(ch);
                            end if;
                        when AddressSingle =>
                            if ch = ':' then
                                parserState.AddressBegin := to_integer(parserState.number);
                                clearParsedNumber;
                                parserState.part := DataPart;
                            else
                                parseNumber(ch);
                            end if;
                        when AddressBegin =>
                            if ch = '.' then
                                parserState.AddressBegin := to_integer(parserState.number);
                                clearParsedNumber;
                                parserState.part := AddressDots;
                            else
                                parseNumber(ch);
                            end if;
                        when AddressDots =>
                            if ch /= '.' then
                                parserState.part := AddressEnd;
                                clearParsedNumber;
                                parseNumber(ch);
                            end if;
                        when AddressEnd =>
                            if ch = ']' then
                                null;
                            elsif ch = ':' then
                                parserState.AddressEnd := to_integer(parserState.number);
                                clearParsedNumber;
                                parserState.part := DataPart;
                            else
                                parseNumber(ch);
                            end if;
                        when DataPart =>
                            if ch = ';' then
                                storeData;
                                fillData;
                                parserState.part := AddresPart;
                            else
                                parseNumber(ch);
                            end if;
                        end case;

                        parserState.minusSignFound := false;
                    end if;
                else
                    -- check end of block comment
                    if ch = '%' then
                        parserState.inBlockComment := false;
                    end if;
                    parserState.minusSignFound := false;
                end if;

                parserState.lastCh := ch;
                read(linePtr, ch, inString);
            end loop;

            if parserState.part = DataPart then
                storeData;
            end if;
        end loop;
        file_close(fp);

        return initValues;
    end initRAMFromMifFile;

    impure function initRAM(INIT_FILE_NAME : string; constant DATA_WIDTH : natural; constant MEM_SIZE : natural) return std_logic_vector is
    begin
        if INIT_FILE_NAME'length = 0 or INIT_FILE_NAME = "UNUSED" then
            return initRAMwithZeros(DATA_WIDTH, MEM_SIZE);
        else
            --return initRAMFromFile(INIT_FILE_NAME);
            return initRAMFromMifFile(INIT_FILE_NAME, DATA_WIDTH, MEM_SIZE);
        end if;
    end initRAM;

end package body;

