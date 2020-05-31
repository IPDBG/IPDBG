module JtagHub (
    clk,
    rst,
    ce,

    data_dwn,

    data_dwn_ready_la,
    data_dwn_ready_ioview,
    data_dwn_ready_gdb,
    data_dwn_ready_wfg,

    data_dwn_valid_la,
    data_dwn_valid_ioview,
    data_dwn_valid_gdb,
    data_dwn_valid_wfg,

    data_up_ready_la,
    data_up_ready_ioview,
    data_up_ready_gdb,
    data_up_ready_wfg,

    data_up_valid_la,
    data_up_valid_ioview,
    data_up_valid_gdb,
    data_up_valid_wfg,

    data_up_la,
    data_up_ioview,
    data_up_wfg,
    data_up_gdb
);

    input        clk;
    input        rst;
    input        ce;

    output [7:0] data_dwn;

    input        data_dwn_ready_la;
    input        data_dwn_ready_ioview;
    input        data_dwn_ready_gdb;
    input        data_dwn_ready_wfg;

    output       data_dwn_valid_la;
    output       data_dwn_valid_ioview;
    output       data_dwn_valid_gdb;
    output       data_dwn_valid_wfg;

    output       data_up_ready_la;
    output       data_up_ready_ioview ;
    output       data_up_ready_gdb;
    output       data_up_ready_wfg;

    input        data_up_valid_la;
    input        data_up_valid_ioview;
    input        data_up_valid_gdb;
    input        data_up_valid_wfg;

    input  [7:0] data_up_la;
    input  [7:0] data_up_ioview;
    input  [7:0] data_up_wfg;
    input  [7:0] data_up_gdb;

    initial begin
        $jtaghostloop;
    end


    wire [3:0] data_dwn_ready;
    wire [3:0] data_in_valid;
    wire [7:0] data_in [3:0];

    reg  [3:0] enable_o;
    reg  [3:0] data_in_ready_o;

    reg  [7:0] data_dwn;
    wire       data_dwn_valid_la;
    wire       data_dwn_valid_ioview;
    wire       data_dwn_valid_gdb;
    wire       data_dwn_valid_wfg;
    wire       data_up_ready_la;
    wire       data_up_ready_ioview ;
    wire       data_up_ready_gdb;
    wire       data_up_ready_wfg;

    assign     data_dwn_ready = {data_dwn_ready_wfg, data_dwn_ready_gdb, data_dwn_ready_ioview, data_dwn_ready_la};
    assign     data_in_valid = {data_up_valid_wfg, data_up_valid_gdb, data_up_valid_ioview, data_up_valid_la};
    assign     data_in[0] = data_up_la;
    assign     data_in[1] = data_up_ioview;
    assign     data_in[2] = data_up_gdb;
    assign     data_in[3] = data_up_wfg;

    reg [15:0] data_temp_dwn;
    reg [3:0]  data_pending = 4'h0;

    always @(posedge clk)
        if (ce) begin
            if (data_pending == 4'h0 && enable_o == 4'h0) begin
                $get_data_from_jtag_host(data_temp_dwn);//[15:0];
                data_dwn <= data_temp_dwn[7:0];
                data_pending = data_temp_dwn[11:8];
            end

            case (data_pending)
            4'hC    : if (data_dwn_ready[0]) begin enable_o <= 4'h1; data_pending = 4'h0; end
            4'hA    : if (data_dwn_ready[1]) begin enable_o <= 4'h2; data_pending = 4'h0; end
            4'h9    : if (data_dwn_ready[2]) begin enable_o <= 4'h4; data_pending = 4'h0; end
            4'hB    : if (data_dwn_ready[3]) begin enable_o <= 4'h8; data_pending = 4'h0; end
            default : begin enable_o <= 4'h0; data_pending = 4'h0; end
            endcase
        end

    always @(posedge clk)
        if (ce) begin
            data_in_ready_o <= 4'hf;
            if (data_in_valid[0] & data_in_ready_o[0]) begin
                data_in_ready_o[0] <= 1'b0;
                $set_data_to_jtag_host({7'h0C, data_in[0]});
            end
            if (data_in_valid[1] & data_in_ready_o[1]) begin
                data_in_ready_o[1] <= 1'b0;
                $set_data_to_jtag_host({7'h0A, data_in[1]});
            end
            if (data_in_valid[2] & data_in_ready_o[2]) begin
                data_in_ready_o[2] <= 1'b0;
                $set_data_to_jtag_host({7'h09, data_in[2]});
            end
            if (data_in_valid[3] & data_in_ready_o[3]) begin
                data_in_ready_o[3] <= 1'b0;
                $set_data_to_jtag_host({7'h0B, data_in[3]});
            end
        end

    assign data_dwn_valid_la     = enable_o[0];
    assign data_dwn_valid_ioview = enable_o[1];
    assign data_dwn_valid_gdb    = enable_o[2];
    assign data_dwn_valid_wfg    = enable_o[3];
    assign data_up_ready_la     = data_in_ready_o[0];
    assign data_up_ready_ioview = data_in_ready_o[1];
    assign data_up_ready_gdb    = data_in_ready_o[2];
    assign data_up_ready_wfg    = data_in_ready_o[3];

endmodule

