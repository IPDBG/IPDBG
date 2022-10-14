library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ipdbg_interface_pkg.all;

entity JtagCdc is
    generic(
        MFF_LENGTH           : natural := 3;
        FLOW_CONTROL_ENABLE  : std_logic_vector(6 downto 0);
        TDI_HAS_EXT_REGISTER : boolean := false
    );
    port(
        clk        : in  std_logic;
        ce         : in  std_logic;

        dn_lines_0 : out ipdbg_dn_lines;
        dn_lines_1 : out ipdbg_dn_lines;
        dn_lines_2 : out ipdbg_dn_lines;
        dn_lines_3 : out ipdbg_dn_lines;
        dn_lines_4 : out ipdbg_dn_lines;
        dn_lines_5 : out ipdbg_dn_lines;
        dn_lines_6 : out ipdbg_dn_lines;

        up_lines_0 : in  ipdbg_up_lines;
        up_lines_1 : in  ipdbg_up_lines;
        up_lines_2 : in  ipdbg_up_lines;
        up_lines_3 : in  ipdbg_up_lines;
        up_lines_4 : in  ipdbg_up_lines;
        up_lines_5 : in  ipdbg_up_lines;
        up_lines_6 : in  ipdbg_up_lines;
-------------------------- BSCAN-Component
        DRCLK      : in  std_logic;
        USER       : in  std_logic;
        UPDATE     : in  std_logic;
        CAPTURE    : in  std_logic;
        SHIFT      : in  std_logic;
        TDI        : in  std_logic;
        TDO        : out std_logic
    );
end entity;


architecture behavioral of JtagCdc is

    component dffpc is
        port(
            clk : in  std_logic;
            ce  : in  std_logic;
            d   : in  std_logic;
            q   : out std_logic
        );
    end component dffpc;

-- MSB                                     LSB
-- +--------+-----------+----------+---------+
-- | valid  | XOff      | function | data    |
-- | 1 bit  | 1 bit     | 3 bit    | 1 byte  |
-- +--------+-----------+----------+---------+

    constant DATA_LENGTH                     : natural := 8;
    constant FUNCTION_LENGTH                 : natural := 3;
    constant XOFF_LENGTH                     : natural := 1;
    constant VALID_LENGTH                    : natural := 1;
    constant DR_LENGTH                       : natural := DATA_LENGTH + FUNCTION_LENGTH + XOFF_LENGTH + VALID_LENGTH;
    constant INTERNAL_FUNCTIONS              : natural := 1;
    constant NUM_FUNCTIONS                   : natural := 2**FUNCTION_LENGTH-INTERNAL_FUNCTIONS;

    constant DO_FLOW_CONTROL                 : boolean := FLOW_CONTROL_ENABLE /= "0000000";

    -- from DR to controller:
    signal update_req                        : std_logic;
    signal xoff_sent_x                       : std_logic;
    signal up_transfer_register_valid_sent_x : std_logic;
    signal dwn_transfer_data_x               : std_logic_vector(DATA_LENGTH-1 downto 0);
    signal dwn_transfer_function_number_x    : std_logic_vector(FUNCTION_LENGTH-1 downto 0);
    signal dwn_transfer_register_valid_x     : std_logic;

    -- from controller to DR
    -- make sure delay of up_transfer_data and up_transfer_function_number is shorter than
    -- one cycle of clk + delay from up_transfer_register_valid
    -- or the delay difference for up_transfer_data, up_transfer_function_number and
    -- up_transfer_register_valid are small compared to a clk cycle
    signal up_transfer_data                  : std_logic_vector(DATA_LENGTH-1 downto 0);
    signal up_transfer_function_number       : std_logic_vector(FUNCTION_LENGTH-1 downto 0);
    signal up_transfer_register_valid        : std_logic;
    signal up_xoff                           : std_logic;

begin

    jtag_dr: block
        signal capture_en                          : std_logic;
        signal shift_en                            : std_logic;
        signal update_en                           : std_logic;
        signal dr                                  : std_logic_vector(DR_LENGTH downto 0);
        signal dr_in                               : std_logic_vector(DR_LENGTH-1 downto 0);

        signal shift_counter                       : natural range 0 to DR_LENGTH;

        signal xoff_sent_ce                        : std_logic;
        signal up_transfer_register_valid_sent_ce  : std_logic;
    begin
        capture_en <= CAPTURE and USER;
        shift_en <= SHIFT and USER;
        update_en <= UPDATE and USER;

        update_req <= update_en;

        dwn_transfer_data_x            <= dr(DATA_LENGTH-1 downto 0);
        dwn_transfer_function_number_x <= dr(DATA_LENGTH+FUNCTION_LENGTH-1  downto DATA_LENGTH);
        no_ext_reg_on_tdi: if TDI_HAS_EXT_REGISTER = false generate begin
            dwn_transfer_register_valid_x  <= dr(DATA_LENGTH+FUNCTION_LENGTH+XOFF_LENGTH);
        end generate;
        with_ext_reg_on_tdi: if TDI_HAS_EXT_REGISTER generate
            signal shift_en_before : std_logic;
        begin
            process(DRCLK)begin
                if rising_edge(DRCLK) then
                    shift_en_before <= shift_en;
                    if shift_en = '0' and shift_en_before = '1' then -- we are in exit1 now
                        dwn_transfer_register_valid_x <= TDI;
                    end if;
                end if;
            end process;
        end generate;

        process(DRCLK)begin
            if rising_edge(DRCLK) then
                xoff_sent_ce <= '0';
                up_transfer_register_valid_sent_ce <= '0';

                if capture_en = '1' then
                    shift_counter <= DR_LENGTH;
                elsif shift_en = '1' then
                    if shift_counter /= 0 then
                        shift_counter <= shift_counter - 1;
                    end if;

                    if shift_counter = 2 then
                        up_transfer_register_valid_sent_ce <= '1';
                    end if;

                    if shift_counter = 3 then
                        xoff_sent_ce <= '1';
                    end if;
                end if;
            end if;
        end process;

        xoff_sent_ff : dffpc -- these flops are also used for cdc of up_transfer_register_valid
            port map(
                clk => DRCLK,
                ce  => xoff_sent_ce,
                d   => dr(0),
                q   => xoff_sent_x
            );
        up_transfer_register_valid_sent_ff : dffpc -- these flops are also used for cdc of up_transfer_register_valid
            port map(
                clk => DRCLK,
                ce  => up_transfer_register_valid_sent_ce,
                d   => dr(0),
                q   => up_transfer_register_valid_sent_x
            );

        dr(DR_LENGTH) <= TDI;
        TDO <= dr(0);

        dr_in <= up_transfer_register_valid & up_xoff & up_transfer_function_number & up_transfer_data;
        shift_register: block
            signal clock_enable : std_logic;
        begin
            clock_enable <= capture_en or shift_en;

            gen_ffs: for I in 0 to DR_LENGTH-1 generate
                signal d                      : std_logic;
                -- tdi is registerd outside this component (lattice jtagx).
                -- We need to be able to load all the dr flops on capture
                -- so for the first shift cycle the input to the 2nd flop is from the first
                -- local flop and afterwards from tdi.
                constant mux_to_skip_first_dr : boolean := I = DR_LENGTH - 2 and TDI_HAS_EXT_REGISTER;
            begin
                with_skip_first_dr_mux: if mux_to_skip_first_dr generate
                    signal skip_first_dr : std_logic;
                begin
                    process(DRCLK)begin
                        if rising_edge(DRCLK) then
                            if capture_en = '1' then
                                skip_first_dr <= '0';
                            elsif shift_en = '1' then
                                skip_first_dr <= '1';
                            end if;
                        end if;
                    end process;
                    d <= dr_in(I) when (capture_en = '1') else
                         TDI      when (skip_first_dr = '1') else
                         dr(I + 1);
                end generate;
                no_skip_first_dr_mux: if not mux_to_skip_first_dr generate begin
                    d <= dr_in(I) when (capture_en = '1') else dr(I + 1);
                end generate;

                dr_ffs : dffpc -- these flops are also used for cdc of up_transfer_register_valid
                    port map(
                        clk => DRCLK,
                        ce  => clock_enable,
                        d   => d,
                        q   => dr(I)
                    );
            end generate;
        end block;
    end block;


    function_clk: block
        type data_port_arr is array(NUM_FUNCTIONS-1 downto 0) of std_logic_vector(DATA_LENGTH-1 downto 0);

        signal clear                           : std_logic;

        signal dwn_do_update                   : std_logic;
        signal dwn_transfer_data               : std_logic_vector(DATA_LENGTH-1 downto 0);
        signal dwn_transfer_function_number    : std_logic_vector(FUNCTION_LENGTH-1 downto 0);
        signal dwn_transfer_register_valid     : std_logic;

        signal xoff_sent                       : std_logic;
        signal up_transfer_register_valid_sent : std_logic;

        signal near_full                       : std_logic_vector(NUM_FUNCTIONS downto 0);
        signal clear_xoff_bits_valid           : std_logic;
        signal clear_xoff_bits                 : std_logic_vector(NUM_FUNCTIONS-1 downto 0);
        signal xoff_state_host                 : std_logic_vector(NUM_FUNCTIONS-1 downto 0);
    begin

        cdc: block
            signal mff                    : std_logic_vector(MFF_LENGTH downto 0);
            signal update_req_synced      : std_logic;
            signal update_req_synced_prev : std_logic;
            signal dwn_enable             : std_logic;
            signal dff_ce                 : std_logic;
        begin
            mff(0) <= update_req;
            mff_flops: for K in 0 to MFF_LENGTH-1 generate begin
                dff_i : dffpc
                    port map(
                        clk => clk,
                        ce  => ce,
                        d   => mff(K),
                        q   => mff(K+1)
                    );
            end generate;
            update_req_synced <= mff(MFF_LENGTH);
            process (clk) begin
                if rising_edge(clk) then
                    if ce = '1' then
                        update_req_synced_prev <= update_req_synced;
                        dwn_enable <= update_req_synced and (not update_req_synced_prev); -- detect 0 -> 1 change
                        dwn_do_update <= dwn_enable;
                    end if;
                end if;
            end process;
            dff_ce <= dwn_enable and ce;

            dwn_data_ffs: for I in dwn_transfer_data'range generate
                dd_ffs : dffpc
                    port map(
                        clk => clk,
                        ce  => dff_ce,
                        d   => dwn_transfer_data_x(I),
                        q   => dwn_transfer_data(I)
                    );
            end generate;
            dwn_functions_ffs: for I in dwn_transfer_function_number'range generate
                df_ffs : dffpc
                    port map(
                        clk => clk,
                        ce  => dff_ce,
                        d   => dwn_transfer_function_number_x(I),
                        q   => dwn_transfer_function_number(I)
                    );
            end generate;
            dv_ffs : dffpc
                port map(
                    clk => clk,
                    ce  => dff_ce,
                    d   => dwn_transfer_register_valid_x,
                    q   => dwn_transfer_register_valid
                );
            xoff_sent_ffs : dffpc
                port map(
                    clk => clk,
                    ce  => dff_ce,
                    d   => xoff_sent_x,
                    q   => xoff_sent
                );
            up_dv_sent_ffs : dffpc
                port map(
                    clk => clk,
                    ce  => dff_ce,
                    d   => up_transfer_register_valid_sent_x,
                    q   => up_transfer_register_valid_sent
                );
        end block;


        down: block
            signal data_dwn        : data_port_arr;
            signal data_dwn_valid  : std_logic_vector(6 downto 0);
            signal common_data_dwn : std_logic_vector(7 downto 0);
   			signal data_dwn_ready  : std_logic_vector(6 downto 0);
        begin

            internal_output: process (clk) begin
                if rising_edge(clk) then
                    if ce = '1' then
                        clear <= '0';
                        if dwn_do_update = '1' then
                            if dwn_transfer_register_valid = '1' and dwn_transfer_function_number = "111" then
                                clear <= '1';
                            end if;
                        end if;
                    end if;
                end if;
            end process;

            process (clk) begin
                if rising_edge(clk) then
                    if ce = '1' then
                        common_data_dwn <= dwn_transfer_data;
                    end if;
                end if;
            end process;

            outputs_stages: for I in 0 to NUM_FUNCTIONS-1 generate begin
                w_fc: if FLOW_CONTROL_ENABLE(I) = '1' generate
                    type buffer_t           is array(2 downto 0) of std_logic_vector(DATA_LENGTH-1 downto 0);
                    signal valid            : std_logic;
                    signal buf              : buffer_t;
                    signal occupied         : std_logic_vector(2 downto 0);
                    signal can_write        : std_logic;
                    signal data_dwn_local   : std_logic_vector(DATA_LENGTH-1 downto 0);
                    signal channel_selected : std_logic;
                begin
                    can_write <= data_dwn_ready(I) and (not valid);
                    near_full(I) <= occupied(0);
                    process(clk)begin
                        if rising_edge(clk) then
                            if ce = '1' then
                                channel_selected <= '0';
                                if clear = '1' then
                                    valid <= '0';
                                    data_dwn_local <= (others => '-');
                                    occupied <= (others => '0');
                                    buf <= (others => (others => '-'));
                                else
                                    if dwn_do_update = '1' and dwn_transfer_register_valid = '1' and I = to_integer(to_01(unsigned(dwn_transfer_function_number), '1')) then
                                        channel_selected <= '1';
                                    end if;

                                    valid <= '0';
                                    if can_write = '1' then
                                        data_dwn_local <= buf(0);
                                        buf(0)         <= buf(1);
                                        buf(1)         <= buf(2);
                                        buf(2)         <= (others => '-');
                                        valid          <= occupied(0);
                                        occupied(0)    <= occupied(1);
                                        occupied(1)    <= occupied(2);
                                        occupied(2)    <= '0';
                                    end if;
                                    if channel_selected = '1' then
                                        if occupied(0) = '0' and can_write = '1' then                               data_dwn_local <= common_data_dwn;
                                                                                                                    valid          <= '1';
                                        elsif occupied(0) = '0' or (occupied(1) = '0' and can_write = '1') then     buf(0)         <= common_data_dwn;
                                                                                                                    occupied(0)    <= '1';
                                        elsif occupied(1) = '0' or (occupied(2) = '0' and can_write = '1') then     buf(1)         <= common_data_dwn;
                                                                                                                    occupied(1)    <= '1';
                                        elsif occupied(2) = '0' or can_write = '1' then                             buf(2)         <= common_data_dwn;
                                                                                                                    occupied(2)    <= '1';
                                        --else
                                        --    -- host did not act on xoff -> data is lost
                                        end if;
                                    end if;
                                end if;
                            end if;
                        end if;
                    end process;
                    data_dwn_valid(I) <= valid;
                    data_dwn(I) <= data_dwn_local;
                end generate;

                wo_fc: if FLOW_CONTROL_ENABLE(I) = '0' generate begin
                    near_full(I) <= '0';
                    data_dwn(I) <= common_data_dwn;
                    process (clk) begin
                        if rising_edge(clk) then
                            if ce = '1' then
                                data_dwn_valid(I) <= '0';
                                if dwn_do_update = '1' then
                                    if dwn_transfer_register_valid = '1' and I = to_integer(to_01(unsigned(dwn_transfer_function_number), '1')) then
                                        data_dwn_valid(I) <= '1';
                                    end if;
                                end if;
                            end if;
                        end if;
                    end process;
                end generate;
            end generate;
            near_full(NUM_FUNCTIONS) <= '0'; -- internal function/tool don't need flow control

            no_xoff_mux: if not DO_FLOW_CONTROL generate begin
                up_xoff <= '0';
            end generate;
            fc_gen: if DO_FLOW_CONTROL generate
                signal xoff_sel      : unsigned(FUNCTION_LENGTH-1 downto 0);
                signal xoff_host_set : std_logic_vector(NUM_FUNCTIONS-1 downto 0);
            begin
                xoff_mux: block
                    signal xoff : std_logic;
                begin
                    process (clk) begin
                        if rising_edge(clk) then
                            if ce = '1' then
                                if clear = '1' then
                                    xoff_sel <= "111";
                                else
                                    if dwn_do_update = '1' then
                                        if dwn_transfer_register_valid = '1' then
                                            xoff_sel <= to_01(unsigned(dwn_transfer_function_number));
                                        end if;
                                    end if;
                                end if;
                            end if;
                        end if;
                    end process;

                    assert near_full'length = 2**xoff_sel'length severity failure;

                    xoff <= near_full(to_integer(xoff_sel));

                    up_xoff_ffs : dffpc
                        port map(
                            clk => clk,
                            ce  => ce,
                            d   => xoff,
                            q   => up_xoff
                        );
                end block;

                xoff_host_set_gen: process(clk)begin
                    if rising_edge(clk) then
                        if ce = '1' then
                            xoff_host_set <= (others => '0');
                            if clear = '0' then
                                if dwn_do_update = '1' then
                                    if dwn_transfer_register_valid = '1' then -- xoff sent to host is only valid when dwn transfer had valid data
                                        if xoff_sent = '1' then
                                            for I in 0 to NUM_FUNCTIONS-1 loop
                                                if I = to_integer(to_01(unsigned(xoff_sel),'1')) then
                                                    xoff_host_set(I) <= '1';
                                                end if;
                                            end loop;
                                        end if;
                                    end if;
                                end if;
                            end if;
                        end if;
                    end if;
                end process;

                functions: for I in 0 to NUM_FUNCTIONS-1 generate begin
                    xoffstate: if FLOW_CONTROL_ENABLE(I) = '1' generate begin
                        process(clk)begin
                            if rising_edge(clk) then
                                if ce = '1' then
                                    if clear = '1' then
                                        xoff_state_host(I) <= '0';
                                    else
                                        if xoff_host_set(I) = '1' then
                                            xoff_state_host(I) <= '1';
                                        elsif clear_xoff_bits_valid = '1' and clear_xoff_bits(I) = '1' then
                                            xoff_state_host(I) <= '0';
                                        end if;
                                    end if;
                                end if;
                            end if;
                        end process;
                    end generate;
                    wo_xoffstate: if FLOW_CONTROL_ENABLE(I) = '0' generate begin
                        xoff_state_host(I) <= '0';
                    end generate;
                end generate;
            end generate;

            dn_lines_0.dnlink_data <= data_dwn(0);
            dn_lines_1.dnlink_data <= data_dwn(1);
            dn_lines_2.dnlink_data <= data_dwn(2);
            dn_lines_3.dnlink_data <= data_dwn(3);
            dn_lines_4.dnlink_data <= data_dwn(4);
            dn_lines_5.dnlink_data <= data_dwn(5);
            dn_lines_6.dnlink_data <= data_dwn(6);
            dn_lines_0.dnlink_valid <= data_dwn_valid(0);
            dn_lines_1.dnlink_valid <= data_dwn_valid(1);
            dn_lines_2.dnlink_valid <= data_dwn_valid(2);
            dn_lines_3.dnlink_valid <= data_dwn_valid(3);
            dn_lines_4.dnlink_valid <= data_dwn_valid(4);
            dn_lines_5.dnlink_valid <= data_dwn_valid(5);
            dn_lines_6.dnlink_valid <= data_dwn_valid(6);
            data_dwn_ready(0) <= up_lines_0.dnlink_ready;
            data_dwn_ready(1) <= up_lines_1.dnlink_ready;
            data_dwn_ready(2) <= up_lines_2.dnlink_ready;
            data_dwn_ready(3) <= up_lines_3.dnlink_ready;
            data_dwn_ready(4) <= up_lines_4.dnlink_ready;
            data_dwn_ready(5) <= up_lines_5.dnlink_ready;
            data_dwn_ready(6) <= up_lines_6.dnlink_ready;
        end block down;

        up: block
            signal data_up_buffer_empty : std_logic_vector(NUM_FUNCTIONS-1 downto 0);
            signal data_up_buffer       : data_port_arr;
            signal data_up              : data_port_arr;
            signal data_up_valid        : std_logic_vector(6 downto 0);
        begin
            data_up(0)       <= up_lines_0.uplink_data;
            data_up(1)       <= up_lines_1.uplink_data;
            data_up(2)       <= up_lines_2.uplink_data;
            data_up(3)       <= up_lines_3.uplink_data;
            data_up(4)       <= up_lines_4.uplink_data;
            data_up(5)       <= up_lines_5.uplink_data;
            data_up(6)       <= up_lines_6.uplink_data;
            data_up_valid(0) <= up_lines_0.uplink_valid;
            data_up_valid(1) <= up_lines_1.uplink_valid;
            data_up_valid(2) <= up_lines_2.uplink_valid;
            data_up_valid(3) <= up_lines_3.uplink_valid;
            data_up_valid(4) <= up_lines_4.uplink_valid;
            data_up_valid(5) <= up_lines_5.uplink_valid;
            data_up_valid(6) <= up_lines_6.uplink_valid;

            dn_lines_0.uplink_ready <= data_up_buffer_empty(0);
            dn_lines_1.uplink_ready <= data_up_buffer_empty(1);
            dn_lines_2.uplink_ready <= data_up_buffer_empty(2);
            dn_lines_3.uplink_ready <= data_up_buffer_empty(3);
            dn_lines_4.uplink_ready <= data_up_buffer_empty(4);
            dn_lines_5.uplink_ready <= data_up_buffer_empty(5);
            dn_lines_6.uplink_ready <= data_up_buffer_empty(6);

            input_buffering: process (clk) begin
                if rising_edge(clk) then
                    if ce = '1' then
                        if clear = '1' then
                            data_up_buffer_empty <= (others => '1');
                            data_up_buffer <= (others => (others => '-'));
                        else
                            for I in 0 to NUM_FUNCTIONS-1 loop
                                if data_up_buffer_empty(I) = '1' and data_up_valid(I) = '1' then
                                    data_up_buffer_empty(I) <= '0';
                                    data_up_buffer(I) <= data_up(I);
                                end if;

                                if dwn_do_update = '1' then
                                    if up_transfer_register_valid_sent = '1' then
                                        if I = to_integer(to_01(unsigned(up_transfer_function_number), '1')) then -- data has been transmitted so the up_transfer_data is empty again
                                            data_up_buffer_empty(I) <= '1';
                                        end if;
                                    end if;
                                end if;
                            end loop;
                        end if;
                    end if;
                end if;
            end process;

            arbiter: block
                signal state : unsigned(FUNCTION_LENGTH-1 downto 0);
            begin
                no_fc: if not DO_FLOW_CONTROL generate begin
                    process (clk) begin
                        if rising_edge(clk) then
                            if ce = '1' then
                                if clear = '1' then
                                    state <= "000";
                                    up_transfer_function_number <= "---";
                                    up_transfer_data <= "--------";
                                    up_transfer_register_valid <= '0';
                                else
                                    if up_transfer_register_valid = '1' then
                                        if dwn_do_update = '1' then
                                            if up_transfer_register_valid_sent = '1' then
                                                up_transfer_register_valid <= '0';
                                            end if;
                                        end if;
                                    else
                                        if state = "110" then
                                            state <= "000";
                                        else
                                            state <= to_01(state) + 1;
                                        end if;
                                        if data_up_buffer_empty(to_integer(to_01(state))) = '0' then
                                            up_transfer_data            <= data_up_buffer(to_integer(to_01(state)));
                                            up_transfer_function_number <= std_logic_vector(to_01(state));
                                            up_transfer_register_valid  <= '1';
                                        end if;
                                    end if;
                                end if;
                            end if;
                        end if;
                    end process;
                    clear_xoff_bits_valid <= '0';
                    clear_xoff_bits <= (others => '-');
                end generate;
                w_fc: if DO_FLOW_CONTROL generate
                    signal xon_data : std_logic_vector(NUM_FUNCTIONS-1 downto 0);
                begin
                    process (clk) begin
                        if rising_edge(clk) then
                            if ce = '1' then
                                clear_xoff_bits_valid <= '0';
                                if clear = '1' then
                                    state <= "000";
                                    up_transfer_function_number <= "---";
                                    up_transfer_data <= "--------";
                                    up_transfer_register_valid <= '0';
                                    clear_xoff_bits <= (others => '-');
                                    xon_data    <= (others => '0');
                                else
                                    if up_transfer_register_valid = '1' then
                                        if dwn_do_update = '1' then
                                            if up_transfer_register_valid_sent = '1' then
                                                up_transfer_register_valid <= '0';
                                                if up_transfer_function_number = "111" then
                                                    clear_xoff_bits_valid <= '1';
                                                    clear_xoff_bits <= up_transfer_data(clear_xoff_bits'range);
                                                    xon_data <= (others => '0');
                                                end if;
                                            end if;
                                        end if;
                                    else
                                        up_transfer_function_number <= std_logic_vector(to_01(state));
                                        if state = "111" then
                                            state <= "000";
                                            if xon_data /= "0000000" then
                                                up_transfer_data           <= '0' & xon_data;
                                                up_transfer_register_valid <= '1';
                                            end if;
                                        else
                                            state <= to_01(state) + 1;
                                            if data_up_buffer_empty(to_integer(to_01(state))) = '0' then
                                                up_transfer_data           <= data_up_buffer(to_integer(to_01(state)));
                                                up_transfer_register_valid <= '1';
                                            end if;
                                            for I in 0 to NUM_FUNCTIONS-1 loop
                                                if FLOW_CONTROL_ENABLE(I) = '1' and xoff_state_host(I) = '1' and clear_xoff_bits_valid = '0' and near_full(I) = '0' then
                                                    xon_data(I) <= '1';
                                                end if;
                                            end loop;
                                        end if;
                                    end if;
                                end if;
                            end if;
                        end if;
                    end process;
                end generate;
            end block;
        end block;
    end block;
end architecture;
