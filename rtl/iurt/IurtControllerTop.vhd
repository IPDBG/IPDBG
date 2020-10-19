library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ipdbg_interface_pkg.all;

entity IurtControllerTop is
    generic(
         ASYNC_RESET : boolean
    );
    port(
        clk      : in  std_logic;
        rst      : in  std_logic;
        ce       : in  std_logic;
        cyc_i    : in  std_logic;
        stb_i    : in  std_logic;
        we_i     : in  std_logic;
        adr_i    : in  std_logic_vector(2 downto 2);
        dat_i    : in  std_logic_vector(31 downto 0);
        dat_o    : out std_logic_vector(31 downto 0);
        ack_o    : out std_logic;
        break_o  : out std_logic;
        dn_lines : in  ipdbg_dn_lines;
        up_lines : out ipdbg_up_lines
    );
end entity IurtControllerTop;


architecture behavioral of IurtController is
    component IurtController is
        generic(
             ASYNC_RESET : boolean
        );
        port(
            clk            : in  std_logic;
            rst            : in  std_logic;
            ce             : in  std_logic;
            cyc_i          : in  std_logic;
            stb_i          : in  std_logic;
            we_i           : in  std_logic;
            adr_i          : in  std_logic_vector(2 downto 2);
            dat_i          : in  std_logic_vector(31 downto 0);
            dat_o          : out std_logic_vector(31 downto 0);
            ack_o          : out std_logic;
            break_o        : out std_logic;
            data_dwn_ready : out std_logic;
            data_dwn_valid : in  std_logic;
            data_dwn       : in  std_logic_vector(7 downto 0);
            data_up_ready  : in  std_logic;
            data_up_valid  : out std_logic;
            data_up        : out std_logic_vector(7 downto 0)
        );
    end component IurtController;

    signal data_dwn_ready : std_logic;
    signal data_dwn_valid : std_logic;
    signal data_dwn       : std_logic_vector(7 downto 0);
    signal data_up_ready  : std_logic;
    signal data_up_valid  : std_logic;
    signal data_up        : std_logic_vector(7 downto 0);
begin


    ctrls: component IurtController
        generic map(
             ASYNC_RESET : boolean
        )
        port map(
            clk            => clk,
            rst            => rst,
            ce             => ce,
            cyc_i          => cyc_i,
            stb_i          => stb_i,
            we_i           => we_i,
            adr_i          => adr_i,
            dat_i          => dat_i,
            dat_o          => dat_o,
            ack_o          => ack_o,
            break_o        => break_o,
            data_dwn_ready => data_dwn_ready,
            data_dwn_valid => data_dwn_valid,
            data_dwn       => data_dwn,
            data_up_ready  => data_up_ready,
            data_up_valid  => data_up_valid,
            data_up        => data_up
        );

    up_lines.uplink_data  <= data_up;
    up_lines.uplink_valid <= data_up_valid;
    up_lines.dnlink_ready <= data_dwn_ready;

    data_dwn       <= dn_lines.dnlink_data;
    data_dwn_valid <= dn_lines.dnlink_valid;
    data_up_ready  <= dn_lines.uplink_ready;

end architecture behavioral;
