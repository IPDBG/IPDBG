library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_fifo is
end tb_fifo;

architecture test of tb_fifo is
    component FIFO is
      generic(
        EXTRA_LEVEL_COUNTER : boolean;
        ASYNC_RESET         : boolean;
        MEM_DEPTH           : integer
       );
        port(
            clk               : in  std_logic;
            rst               : in  std_logic;
            ce                : in  std_logic;
            full              : out std_logic;
            write_data_enable : in  std_logic;
            write_data        : in  std_logic_vector;
            empty             : out std_logic;
            read_data_enable  : in  std_logic;
            read_data         : out std_logic_vector
        );
    end component FIFO;
    signal clk               : std_logic;
    signal rst               : std_logic;
    signal ce                : std_logic;
    signal full              : std_logic;
    signal write_data_enable : std_logic;
    signal write_data        : std_logic_vector(7 downto 0);
    signal empty             : std_logic;
    signal read_data_enable  : std_logic;
    signal read_data         : std_logic_vector(7 downto 0);
    signal count             :integer :=0 ;
    constant T               : time := 10 ns;
begin

    process begin
        clk <= '0';
        wait for T/2;
        clk <= '1';
        wait for (T-(T/2));-- to avoid rounding differences
    end process;
    process begin
        rst <= '1';
        wait for 3/2*T;
        rst <= '0';
        wait;
    end process;
    ce <= '1';

    if output_wb
    process begin
        write_data <=  x"01";


        while true loop
            wait until rising_edge(clk);
                if count <= 20 then
                    wait for 1*T;
                    count <= count +1;
                    write_data <= std_logic_vector(unsigned(write_data) SLL 1);
                    write_data_enable <= '1';
                else
                    write_data_enable <= '0';
                end if;

                if  empty /= '1'  then
                    read_data_enable <= '1';
                else
                    read_data_enable <= '0';
                end if;


        end loop;

    end process;




    uut : component FIFO
     generic map(
            EXTRA_LEVEL_COUNTER => false,
            ASYNC_RESET         => false,
            MEM_DEPTH           => 4
        )

        port map(
            clk               => clk,
            rst               => rst,
            ce                => ce,
            full              => full,
            write_data_enable => write_data_enable,
            write_data        => write_data,
            empty             => empty,
            read_data_enable  => read_data_enable,
            read_data         => read_data
        );
end architecture test;



