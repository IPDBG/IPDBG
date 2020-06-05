library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity JtagCdc is
    generic(
        MFF_LENGTH       : natural := 3;
        --PORT_ENABLE : std_logic_vector(6 downto 0) := "0000010" -- only iurt has handshaking enabled
        HANDSHAKE_ENABLE : std_logic_vector(6 downto 0) := "0000010" -- only iurt has handshaking enabled
    );
    port(
        clk                   : in  std_logic;
        ce                    : in  std_logic;


        --data_clk              : in  std_logic_vector(6 downto 0);
-------------------------- to function
        data_dwn_0            : out std_logic_vector(7 downto 0);
        data_dwn_1            : out std_logic_vector(7 downto 0);
        data_dwn_2            : out std_logic_vector(7 downto 0);
        data_dwn_3            : out std_logic_vector(7 downto 0);
        data_dwn_4            : out std_logic_vector(7 downto 0);
        data_dwn_5            : out std_logic_vector(7 downto 0);
        data_dwn_6            : out std_logic_vector(7 downto 0);
        data_dwn_valid        : out std_logic_vector(6 downto 0);
        data_dwn_ready        : in  std_logic_vector(6 downto 0);

-------------------------- from function
        data_up_ready         : out std_logic_vector(6 downto 0);
        data_up_valid         : in  std_logic_vector(6 downto 0);

        data_up_0             : in  std_logic_vector(7 downto 0);
        data_up_1             : in  std_logic_vector(7 downto 0);
        data_up_2             : in  std_logic_vector(7 downto 0);
        data_up_3             : in  std_logic_vector(7 downto 0);
        data_up_4             : in  std_logic_vector(7 downto 0);
        data_up_5             : in  std_logic_vector(7 downto 0);
        data_up_6             : in  std_logic_vector(7 downto 0);

-------------------------- BSCAN-Component
        DRCLK                : in  std_logic;
        USER                 : in  std_logic;
        UPDATE               : in  std_logic;
        CAPTURE              : in  std_logic;
        SHIFT                : in  std_logic;
        TDI                  : in  std_logic;
        TDO                  : out std_logic
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

    constant DATA_LENGTH                   : natural := 8;
    constant FUNCTION_LENGTH               : natural := 3;
    constant XOFF_LENGTH                   : natural := 1;
    constant VALID_LENGTH                  : natural := 1;
    constant DR_LENGTH                     : natural := DATA_LENGTH + FUNCTION_LENGTH + XOFF_LENGTH + VALID_LENGTH;
    constant INTERNAL_FUNCTIONS            : natural := 1;
    constant NUM_FUNCTIONS                 : natural := 2**FUNCTION_LENGTH-INTERNAL_FUNCTIONS;

    -- from DR to controller:
    signal update_req                      : std_logic;
    signal xoff_sent                       : std_logic;
    signal up_transfer_register_valid_sent : std_logic;
    signal dwn_transfer_data               : std_logic_vector(DATA_LENGTH-1 downto 0);
    signal dwn_transfer_function_number    : std_logic_vector(FUNCTION_LENGTH-1 downto 0);
    signal dwn_transfer_register_valid     : std_logic;

    -- from controller to DR
    -- make sure delay of up_transfer_data and up_transfer_function_number is shorter than
    -- one cycle of clk + delay from up_transfer_register_valid
    -- or the delay difference for up_transfer_data, up_transfer_function_number and
    -- up_transfer_register_valid are small compared to a clk cycle
    signal up_transfer_data            : std_logic_vector(DATA_LENGTH-1 downto 0);
    signal up_transfer_function_number : std_logic_vector(FUNCTION_LENGTH-1 downto 0);
    signal up_transfer_register_valid  : std_logic;
    signal xoff                        : std_logic;

    -- signals from handshake controller to arbiter:
    signal xon_pending                 : std_logic;
    signal xon_data                    : std_logic_vector(NUM_FUNCTIONS-1 downto 0);
    -- arbiter to handshake controller
    signal xon_pending_ack             : std_logic;--_vector(NUM_FUNCTIONS-1 downto 0);
begin


--    process begin
--        report "NUM_FUNCTIONS = " & integer'image(NUM_FUNCTIONS);
--    end process;

    jtag_dr: block
        signal capture_en                        : std_logic;
        signal shift_en                          : std_logic;
        signal update_en                         : std_logic;
        signal dr                                : std_logic_vector(DR_LENGTH downto 0);
        signal dr_in                             : std_logic_vector(DR_LENGTH-1 downto 0);

        signal shift_counter                  : natural range 0 to DR_LENGTH;
    begin
        capture_en <= CAPTURE and USER;
        shift_en <= SHIFT and USER;
        update_en <= UPDATE and USER;

        update_req <= update_en;
        dwn_transfer_data            <= dr(DATA_LENGTH-1 downto 0);
        dwn_transfer_function_number <= dr(DATA_LENGTH+FUNCTION_LENGTH-1  downto DATA_LENGTH);
        dwn_transfer_register_valid  <= dr(DATA_LENGTH+FUNCTION_LENGTH+XOFF_LENGTH);

        process(DRCLK)begin
            if rising_edge(DRCLK) then
                if capture_en = '1' then
                    shift_counter <= DR_LENGTH;
                elsif shift_en = '1' then
                    if shift_counter /= 0 then
                        shift_counter <= shift_counter - 1;
                    end if;

                    if shift_counter = 1 then
                        up_transfer_register_valid_sent <= dr(0);
                    end if;

                    if shift_counter = 2 then
                        xoff_sent <= dr(0);
                    end if;
                elsif update_en = '1' then
                end if;
            end if;
        end process;

        dr(DR_LENGTH) <= TDI;
        TDO <= dr(0);

        dr_in <= up_transfer_register_valid & xoff & up_transfer_function_number & up_transfer_data;
        shift_register: block
            signal clock_enable : std_logic;
        begin
            clock_enable <= capture_en or shift_en;

            gen_ffs: for I in 0 to DR_LENGTH-1 generate
                signal d            : std_logic;
            begin
                d <= dr(I+1) when (capture_en = '0') else dr_in(I);


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
        signal clear             : std_logic;
        signal do_update         : std_logic;
    begin

        cdc: block
            signal x                      : std_logic_vector(MFF_LENGTH downto 0);
            signal update_req_synced      : std_logic;
            signal update_req_synced_prev : std_logic;
        begin
            x(0) <= update_req;
            mff_flops: for K in 0 to MFF_LENGTH-1 generate begin
                MFF : dffpc
                    port map(
                        clk => clk,
                        ce  => ce,
                        d   => x(K),
                        q   => x(K+1)
                    );
            end generate;
            update_req_synced <= x(MFF_LENGTH);
            process (clk) begin
                if rising_edge(clk) then
                    update_req_synced_prev <= update_req_synced;
                end if;
            end process;
            do_update <= update_req_synced and (not update_req_synced_prev); -- detect 0 -> 1 change
        end block;


        down: block
            signal data_dwn                 : data_port_arr;
            signal data_out_register_enable : std_logic;
            signal near_full                : std_logic_vector(DATA_LENGTH-1 downto 0);
        begin
            process (clk) begin
                if rising_edge(clk) then
                    data_out_register_enable <= '0';
                    if do_update = '1' then
                        data_out_register_enable <= '1';
                    end if;
                end if;
            end process;

            xoff_mux: block
                signal sel : unsigned(FUNCTION_LENGTH-1 downto 0);
            begin
                process (clk) begin
                    if rising_edge(clk) then
                        if clear = '1' then
                            sel <= "111";
                        else
                            if data_out_register_enable = '1' then
                                if dwn_transfer_register_valid = '1' then
                                    sel <= to_01(unsigned(dwn_transfer_function_number));
                                else
                                    sel <= "111"; -- internal function never xoff'ed
                                end if;
                            end if;
                        end if;
                    end if;
                end process;

                xoff <= near_full(to_integer(sel));
            end block;



--    capture  shift  update    capture  shift  update    capture  shift  update           capture  shift  update    capture  shift  update
--                      w1                        w2                        w3                               w4                        w5
--xoff drclk                       x1                        x2                               x3                       x4
-- xoff clk                                       x1                        x2                               x3                        x4
--
--                                                0                         1




            dwn_handshake_control: block
                signal xoff_state       : std_logic_vector(NUM_FUNCTIONS-1 downto 0);
                signal clear_xoff_state : std_logic_vector(NUM_FUNCTIONS-1 downto 0);
            begin
                functions: for I in 0 to NUM_FUNCTIONS-1 generate begin
                    w_hs_xoffstate: if HANDSHAKE_ENABLE(I) = '1' generate
                        signal update_xoff_state : std_logic; -- timing: reduce inputs to xoff_state
                    begin
                        process(clk)begin
                            if rising_edge(clk) then
                                if clear = '1' then
                                    xoff_state(I) <= '0';
                                else
                                    update_xoff_state <= '0';
                                    if data_out_register_enable = '1' then
                                        if dwn_transfer_register_valid = '1' then -- xoff sent to host is only valid when dwn transfer had valid data
                                            if xoff_sent = '1' then
                                                update_xoff_state <= '1';
                                            end if;
                                        end if;
                                    end if;
                                    if update_xoff_state = '1' and I = to_integer(to_01(unsigned(dwn_transfer_function_number), '1')) then
                                        xoff_state(I) <= '1';
                                    elsif xon_pending_ack = '1' and clear_xoff_state(I) = '1' then
                                        xoff_state(I) <= '0';
                                    end if;
                                end if;
                            end if;
                        end process;
                    end generate;
                    wo_hs_xoffstate: if HANDSHAKE_ENABLE(I) = '0' generate begin
                        xoff_state(I) <= '0';
                    end generate;
                end generate;


                ctrl: block
                begin
                    process(clk)begin
                        if rising_edge(clk) then
                            if clear = '1' then
                                xon_pending <= '0';
                                xon_data <= (others => '-');
                                clear_xoff_state <= (others => '0');
                                -- xon_pending_ack
                            else
                                clear_xoff_state <= xon_data;
                                if do_update = '1' and up_transfer_register_valid_sent = '1' then
                                    xon_pending <= '0';
                                else
                                    xon_data <= (others => '0');

                                    for I in 0 to NUM_FUNCTIONS-1 loop
                                        if HANDSHAKE_ENABLE(I) = '1' then
                                            if xoff_state(I) = '1' and near_full(I) = '0' then
                                                xon_data(I) <= '1';
                                                xon_pending <= '1';
                                            end if;
                                        end if;
                                    end loop;
                                end if;
                            end if;
                        end if;
                    end process;
                end block;
            end block;

            outputs_stages: for I in 0 to NUM_FUNCTIONS-1 generate begin
                w_hs: if HANDSHAKE_ENABLE(I) = '1' generate
                    type buffer_t    is array(2 downto 0) of std_logic_vector(DATA_LENGTH-1 downto 0);
                    signal valid     : std_logic;
                    signal buf       : buffer_t;
                    signal occupied  : std_logic_vector(2 downto 0);
                    signal can_write : std_logic;
                begin

                    can_write <= data_dwn_ready(I) and (not valid);

                    near_full(I) <= occupied(0);

                    fifo: process (clk) begin
                        if rising_edge (clk) then
                            if clear = '1' then
                                valid <= '0';
                                data_dwn(I) <= (others => '-');
                                occupied <= (others => '0');
                                buf <= (others => (others => '-'));
                            else
                                valid <= '0';
                                if can_write = '1' then
                                    data_dwn(I) <= buf(0);
                                    buf(0)      <= buf(1);
                                    buf(1)      <= buf(2);
                                    buf(2)      <= (others => '-');
                                    valid       <= occupied(0);
                                    occupied(0) <= occupied(1);
                                    occupied(1) <= occupied(2);
                                    occupied(2) <= '0';
                                end if;

                                if data_out_register_enable = '1' then
                                    if dwn_transfer_register_valid = '1' and I = to_integer(to_01(unsigned(dwn_transfer_function_number), '1')) then
                                        if occupied(0) = '0' then
                                            if can_write = '1' then
                                                data_dwn(I) <= dwn_transfer_data;
                                                valid <= '1';
                                            else
                                                buf(0)      <= dwn_transfer_data;
                                                occupied(0) <= '1';
                                            end if;
                                        elsif occupied(1) = '0' then
                                            if can_write = '1' then
                                                buf(0)      <= dwn_transfer_data;
                                                occupied(0) <= '1';
                                            else
                                                buf(1)      <= dwn_transfer_data;
                                                occupied(1) <= '1';
                                            end if;
                                        else -- occupied(2) is '0'
                                            if can_write = '1' then
                                                buf(1)      <= dwn_transfer_data;
                                                occupied(1) <= '1';
                                            else
                                                buf(2)      <= dwn_transfer_data;
                                                occupied(2) <= '1';
                                            end if;
                                        end if;
                                    end if;
                                end if;
                            end if;
                        end if;
                    end process;
                    data_dwn_valid(I) <= valid;
                end generate;

                wo_hs: if HANDSHAKE_ENABLE(I) = '0' generate begin
                    near_full(I) <= '0';
                    process (clk) begin
                        if rising_edge (clk) then
                            data_dwn_valid(I) <= '0';
                            if data_out_register_enable = '1' then
                                data_dwn(I) <= dwn_transfer_data;
                                if dwn_transfer_register_valid = '1' and I = to_integer(to_01(unsigned(dwn_transfer_function_number), '1')) then
                                    data_dwn_valid(I) <= '1';
                                end if;
                            end if;
                        end if;
                    end process;
                end generate;
            end generate;

            internal_output: process (clk) begin
                if rising_edge (clk) then
                    clear <= '0';
                    if data_out_register_enable = '1' then
                        if dwn_transfer_register_valid = '1' and dwn_transfer_function_number = "111" then
                            clear <= '1';
                        end if;
                    end if;
                end if;
            end process;
            near_full(NUM_FUNCTIONS) <= '0';

            data_dwn_0 <= data_dwn(0);
            data_dwn_1 <= data_dwn(1);
            data_dwn_2 <= data_dwn(2);
            data_dwn_3 <= data_dwn(3);
            data_dwn_4 <= data_dwn(4);
            data_dwn_5 <= data_dwn(5);
            data_dwn_6 <= data_dwn(6);
        end block down;

        up: block
            signal set_up_transfer_register_valid : std_logic;
            signal data_up_buffer_empty           : std_logic_vector(NUM_FUNCTIONS-1 downto 0);
            signal data_up_buffer                 : data_port_arr;
            signal data_up                        : data_port_arr;
        begin
            data_up_ready <= data_up_buffer_empty;

            data_up(0) <= data_up_0;
            data_up(1) <= data_up_1;
            data_up(2) <= data_up_2;
            data_up(3) <= data_up_3;
            data_up(4) <= data_up_4;
            data_up(5) <= data_up_5;
            data_up(6) <= data_up_6;

            input_buffering: process (clk) begin
                if rising_edge(clk) then
                    if clear = '1' then
                        up_transfer_register_valid <= '0';
                        data_up_buffer_empty <= (others => '1');
                        data_up_buffer <= (others => (others => '-'));
                    else
                        if set_up_transfer_register_valid = '1' then
                            up_transfer_register_valid <= '1';
                        end if;

                        for I in 0 to NUM_FUNCTIONS-1 loop
                            if data_up_buffer_empty(I) = '1' and data_up_valid(I) = '1' then
                                data_up_buffer_empty(I) <= '0';
                                data_up_buffer(I) <= data_up(I);
                            end if;
                        end loop;
                        if do_update = '1' then
                            if up_transfer_register_valid_sent = '1' then
                                up_transfer_register_valid <= '0';
                                -- data has been transmitted so the up_transfer_data is empty again
                                for I in 0 to NUM_FUNCTIONS-1 loop
                                    if I = to_integer(to_01(unsigned(up_transfer_function_number), '1')) then
                                        data_up_buffer_empty(I) <= '1';
                                    end if;
                                end loop;
                            end if;
                        end if;
                    end if;
                end if;
            end process;

            arbiter: block
                constant handshake_needed : boolean := HANDSHAKE_ENABLE /= "0000000";
                signal state              : unsigned(FUNCTION_LENGTH-1 downto 0);
                type transfer_t           is (is_active, is_idle);
                signal transfer           : transfer_t;
            begin
                process (clk) begin
                    if rising_edge(clk) then
                        if clear = '1' then
                            set_up_transfer_register_valid <= '0';
                            state <= "000";
                            transfer <= is_idle;
                            up_transfer_function_number <= "---";
                            up_transfer_data <= "--------";
                            xon_pending_ack <= '0';
                        else
                            xon_pending_ack <= '0';
                            set_up_transfer_register_valid <= '0';
                            if handshake_needed and state = "111" then
                                if xon_pending = '0' then
                                    state <= "000";
                                    transfer <= is_idle;
                                else
                                    xon_pending_ack             <= '1';
                                    up_transfer_function_number <= std_logic_vector(to_01(state));
                                    if transfer = is_idle then
                                        up_transfer_data            <= '0' & xon_data;
                                        set_up_transfer_register_valid <= '1';
                                        transfer <= is_active;
                                    end if;
                                end if;
                            else
                                if data_up_buffer_empty(to_integer(to_01(state))) = '1' then
                                    if (not handshake_needed and state = "110") or state = "111" then
                                        state <= "000";
                                    else
                                        state <= to_01(state) + 1;
                                    end if;
                                    transfer <= is_idle;
                                else
                                    up_transfer_data            <= data_up_buffer(to_integer(to_01(state)));
                                    up_transfer_function_number <= std_logic_vector(to_01(state));
                                    if transfer = is_idle then
                                        set_up_transfer_register_valid <= '1';
                                        transfer <= is_active;
                                    end if;
                                end if;
                            end if;
                        end if;
                    end if;
                end process;
            end block;
        end block up;
    end block;
end architecture;
