
module IurtController
    (
        clk, rst, ce, // system
        cyc_i, stb_i, we_i, adr_i, dat_i, dat_o, ack_o, // wishbone
        break,
        data_dwn_ready, data_dwn_valid, data_dwn, data_up_ready, data_up_valid, data_up
    );

    parameter    ASYNC_RESET = 0;

    input         clk;
    input         rst;
    input         ce;
    input         cyc_i;
    input         stb_i;
    input         we_i;
    input  [2:2]  adr_i;
    input  [31:0] dat_i;
    output [31:0] dat_o;
    output        ack_o;
    output        break;
    output        data_dwn_ready;
    input         data_dwn_valid;
    input  [7:0]  data_dwn;
    input         data_up_ready;
    output        data_up_valid;
    output [7:0]  data_up;

    wire          arst;
    wire          srst;

    wire          break;

    wire          ack_o;
    reg           ack_wr;
    reg           ack_rd;
    wire          dat_o;
    wire          data_dwn_ready;
    wire          TxReady;
    reg           break_local;
    reg           break_enable;
    reg           data_up_valid;
    reg           data_up;



    generate if (ASYNC_RESET) begin : gensrst
        assign srst = 0;
        assign arst = rst;
    end else begin : genarst
        assign srst = rst;
        assign arst = 0;
    end
    endgenerate

    assign break = break_local & break_enable;

    always @(posedge clk)
        if (ce) begin
            break_local <= data_dwn_valid;
        end

    always @(posedge clk or posedge arst)
        if (arst) begin
            break_enable <= 1;
        end else begin
            if (srst) begin
                break_enable <= 1;
            end else begin
                if (ce) begin
                    if (break) begin
                        break_enable <= 0; // clear after activation
                    end
                    if (cyc_i & stb_i & we_i & adr_i[2] & ~ack_wr) begin
                        break_enable <= dat_i[0];
                    end
                end
            end
        end

    assign ack_o = ack_wr | ack_rd;

    generate if (1) begin
        wire       valid;
        reg        data_dwn_ready_local;
        reg        set_ready;
        reg  [7:0] data_o_local;

        assign dat_o = {22'b0, TxReady, valid , data_o_local};
        assign data_dwn_ready = data_dwn_ready_local;
        assign valid = ~data_dwn_ready_local;

        always @(posedge clk or posedge arst)
            if (arst) begin
                ack_rd <= 0;
                set_ready <= 1'bx;
                data_dwn_ready_local <= 1;
                data_o_local <= 8'bxxxxxxxx;
            end else begin
                if (srst) begin
                    ack_rd <= 0;
                    set_ready <= 1'bx;
                    data_dwn_ready_local <= 1;
                    data_o_local <= 8'bxxxxxxxx;
                end else begin
                    if (ce) begin
                        set_ready <= 0;
                        ack_rd <= 0;

                        if (cyc_i & stb_i & ~we_i & ~ack_rd) begin
                            ack_rd <= 1;
                            if (adr_i[2] == 0) begin
                                set_ready <= 1;
                            end
                        end

                        if (data_dwn_valid)
                          begin
                            data_o_local <= data_dwn;
                            data_dwn_ready_local <= 0;
                          end
                        else if (set_ready)
                            data_dwn_ready_local <= 1;
                    end
                end
            end
    end endgenerate


    generate if (1) begin
        reg       buffer_empty;
        reg [7:0] data_buffer;

        assign TxReady = buffer_empty;

        always @(posedge clk or posedge arst)
            if (arst) begin
                buffer_empty <= 1;
                ack_wr <= 0;
                data_buffer <= 8'bxxxxxxxx;
                data_up_valid <= 0;
                data_up  <= 8'bxxxxxxxx;
            end else begin
                if (srst) begin
                    buffer_empty <= 1;
                    ack_wr <= 0;
                    data_buffer <= 8'bxxxxxxxx;
                    data_up_valid <= 0;
                    data_up  <= 8'bxxxxxxxx;
                end else begin
                    if (ce) begin
                        data_up_valid <= 0;
                        if (data_up_ready & ~buffer_empty) begin
                            buffer_empty <= 1;
                            data_up_valid <= 1;
                            data_up <= data_buffer;
                        end

                        ack_wr <= 0;
                        if (cyc_i & stb_i & we_i & ~ack_wr & (buffer_empty | adr_i[2])) begin
                            ack_wr <= 1;
                            if (adr_i[2] == 0) begin
                                data_buffer <= dat_i[7:0];
                                buffer_empty <= 0;
                            end
                        end
                    end
                end
            end
    end endgenerate

endmodule
