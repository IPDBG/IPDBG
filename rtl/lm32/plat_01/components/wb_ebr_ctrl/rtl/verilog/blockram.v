module blockram(clk, wr_addr, rd_addr, write_enable, wr_data, rd_data);
parameter WIDTH = 32;
parameter ADDR_WIDTH = 8;
parameter MEM_INIT_FILE = "";

parameter DEPTH = 2**ADDR_WIDTH;

input clk, write_enable;
input [ADDR_WIDTH-1:0] wr_addr;
input [ADDR_WIDTH-1:0] rd_addr;
input [WIDTH-1:0] wr_data;
output reg [WIDTH-1:0] rd_data;

// Start module here!
reg [WIDTH-1:0] mem [0:DEPTH-1];

integer i;
initial
begin
    $readmemh(MEM_INIT_FILE, mem);
end


always @(posedge(clk)) begin
    if( write_enable == 1 )
        mem[wr_addr] <= wr_data;
    //if( clear == 1 ) begin
        //for( i = 0; i < 2**n; i = i + 1 ) begin
            //reg_array[i] <= 0;
        //end
    //end
    rd_data = mem[rd_addr];
	end
endmodule
