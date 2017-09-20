library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity PdpRam is
    generic(
        DATA_WIDTH : natural := 8;    --! width of data ports
        ADDR_WIDTH : natural := 8;    --! width of address ports
        OUTPUT_REG : boolean := false --! Activates an additional output register
    );
    port(
        clk           : in  std_logic;                               --! clock input
        ce            : in  std_logic := '1';                        --! clock enable input

        write_enable  : in  std_logic;                               --! write value at write_data port into the memory at address write_address when set
        write_address : in  std_logic_vector(ADDR_WIDTH-1 downto 0); --! address to write data to
        write_data    : in  std_logic_vector(DATA_WIDTH-1 downto 0); --! data input for write access

        read_address  : in  std_logic_vector(ADDR_WIDTH-1 downto 0); --! address to read data from
        read_data     : out std_logic_vector(DATA_WIDTH-1 downto 0)  --! data output for read access
    );
end PdpRam;

architecture behav of PdpRam is
    constant MEM_SIZE : natural := 2**ADDR_WIDTH;
    type memory_t is array (MEM_SIZE-1 downto 0) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal memory         : memory_t;

    signal read_data_next : std_logic_vector(DATA_WIDTH-1 downto 0);
begin

    process (clk) begin
        if rising_edge(clk) then
            if ce = '1' then
                if write_enable = '1' then
                    memory(to_integer(unsigned(write_address))) <= write_data;
                    assert (write_address /= read_address) report "synthesized behavior my differ from behavioral (pre-synthesis) simulation!" severity warning;
                end if;
                read_data_next <= memory(to_integer(unsigned(read_address)));
            end if;
        end if;
    end process;

    gen_oreg : if OUTPUT_REG generate
        process (clk) begin
            if rising_edge (clk) then
                if ce = '1' then
                    read_data <= read_data_next;
                end if;
            end if;
        end process;
    end generate;
    gen_noreg : if not OUTPUT_REG generate
        read_data <= read_data_next;
    end generate;

end architecture behav;
