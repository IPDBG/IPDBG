`timescale 1us/1ns

module tb_iurtcontroller(); // Testbench has no inputs, outputs

    reg         clk = 1'b0;
    reg         rst;
    reg         ce;

    reg         cyc;
    reg         stb;
    reg         we;
    reg  [2:2]  adr;
    reg  [31:0] dat_dn;
    wire [31:0] dat_up;
    wire        ack;

    wire        break_o;
    wire        data_dwn_ready;
    reg         data_dwn_valid;
    reg  [7:0]  data_dwn;
    reg         data_up_ready;
    wire        data_up_valid;
    wire [7:0]  data_up;


    IurtController #(.ASYNC_RESET(0)) dut
    (
        // system
        .clk(clk), .rst(rst), .ce(ce),

        // wishbone
        .cyc_i(cyc), .stb_i(stb), .we_i(we), .adr_i(adr), .dat_i(dat_dn), .dat_o(dat_up), .ack_o(ack),

        .break_o(break_o),
        .data_dwn_ready(data_dwn_ready), .data_dwn_valid(data_dwn_valid), .data_dwn(data_dwn),
        .data_up_ready(data_up_ready), .data_up_valid(data_up_valid), .data_up(data_up)
    );

    initial begin
        $dumpfile("iurt.vcd");
        $dumpvars(0, dut);

        #5000 $finish;
    end

    always #5 clk <= !clk;

    initial begin
        ce = 1;
        rst = 1;
        #52;
        rst = 0;
    end

    initial begin               // sequential block
        data_dwn_valid = 0;
        data_dwn = 8'h42;

        #200;
        data_dwn_valid = 1;
        #10;
        data_dwn_valid = 0;



    end

    initial begin               // sequential block
        data_up_ready = 1;


    end


    initial begin
        cyc = 0;
        stb = 0;
        we  = 0;
        adr = 0;
        dat_dn = 0;

        #100;
        we = 1;
        cyc = 1;
        stb = 1;
        adr = 0;
        dat_dn = 8'h55;
        #20;
        cyc = 0;
        stb = 0;

        #200
        we = 0;
        cyc = 1;
        stb = 1;
        #20;
        cyc = 0;
        stb = 0;

    end



endmodule
