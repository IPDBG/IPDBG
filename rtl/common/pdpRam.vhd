library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.memory_pkg.all;

--! pseudo dual ported ram (pseudo because it uses only one clock for a read and a write port.)
--! Synthesis will automatically inferring block ram for this design.
--! tested with
--! - Quartus 13.1.0 Build 162 10/23/2013 SJ Web Edition
--!   - cyclone V
--!   - cyclone V
--! - PlanAhead v14.7 Build 321239 Sep 27 2013
--!   - Kintex 6
--!   - Spartan 6
--!   - Virtex 6
--! - Diamond 3.0.0.97 / Synplify Pro H-2013.03L
--!   - ECP 2
--! - was not able to test with precision!


entity pdpRam is
    generic(
        DATA_WIDTH     : natural := 8;                                             --! width of data ports
        ADDR_WIDTH     : natural := 8;                                             --! width of address ports
        INIT_FILE_NAME : string  := "";
        OUTPUT_REG     : boolean := false                                          --! Activates an additional output register
    );
    port(
        clk                         : in  std_logic;                               --! clock input
        ce                          : in  std_logic := '1';                        --! clock enable input

        writeEnable                 : in  std_logic;                               --! write value at writeData port into the memory at address writeAddress when set
        writeAddress                : in  std_logic_vector(ADDR_WIDTH-1 downto 0); --! address to write data to
        writeData                   : in  std_logic_vector(DATA_WIDTH-1 downto 0); --! data input for write access

        readAddress                 : in  std_logic_vector(ADDR_WIDTH-1 downto 0); --! address to read data from
        readData                    : out std_logic_vector(DATA_WIDTH-1 downto 0)  --! data output for read access
    );
end pdpRam;

architecture behav of pdpRam is

    constant MEM_SIZE : natural := 2**ADDR_WIDTH;
    type memory_t is array (MEM_SIZE-1 downto 0) of std_logic_vector(DATA_WIDTH-1 downto 0);

    signal readDataNext : std_logic_vector(DATA_WIDTH-1 downto 0);

    impure function slv2memory( initVect : std_logic_vector ) return memory_t is
        variable initVals : memory_t;
    begin
        assert initVect'length = MEM_SIZE*DATA_WIDTH
            report "init vector must have a length of DATA_WIDTH*(2**ADDR_WIDTH)" severity failure;
            for I in 0 to MEM_SIZE-1 loop
                initVals(I) := initVect((I+1)*DATA_WIDTH-1 downto I*DATA_WIDTH);
            end loop;
            return initVals;
    end function slv2memory;

    --! initialization from file does not work for altera quartus!
    --! according to "Quartus II Integrated Synthesis" the following attribute is needed:
    --! supported are .mif or .hex files(what ever the format of .hex-file (intel/motorola/...?) is!).
    --! VHDL's textio functions are not supported for synthesis. (verilog $readmemb is supported)
    --! Initialization with constants as implemented in initRAMwithZeros is supported by quartus.
    --! The attribute ram_init_file is ignored if the memory signal/variable is initialized.
    --! The attribute ram_init_file is not supported by synplify or XST, they ignore it.

    -- trick to not initialize for altera:
    signal memory : memory_t
    -- altera translate_off
        := slv2memory(initRAM(INIT_FILE_NAME, DATA_WIDTH, MEM_SIZE))
    -- altera translate_on
    ;
    -- pragma translate_off
    -- altera translate_on
    attribute ram_init_file : string;
    attribute ram_init_file of memory : signal is INIT_FILE_NAME;
    -- altera translate_off
    -- pragma translate_on

begin

    process (clk) begin
        if rising_edge(clk) then
            if ce = '1' then
                if (writeEnable = '1') then
                    memory(to_integer(unsigned(writeAddress))) <= writeData;
                    assert (writeAddress /= readAddress) report "synthesized behavior my differ from behavioral (pre-synthesis) simulation!" severity warning;
                end if;
                readDataNext <= memory(to_integer(unsigned(readAddress)));
            end if;
        end if;
    end process;

    gen_oreg : if OUTPUT_REG generate
        process (clk) begin
            if rising_edge (clk) then
                if ce = '1' then
                    readData <= readDataNext;
                end if;
            end if;
        end process;
    end generate;
    gen_noreg : if not OUTPUT_REG generate
        readData <= readDataNext;
    end generate;

end architecture behav;
