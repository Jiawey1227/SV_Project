module FIFO #(parameter DEPTH = 16, WIDTH = 8) (
    input clk, rst, wr, rd,
    input [WIDTH-1:0] din, 
    output reg [WIDTH-1:0] dout,
    output empty, full
);

    reg [$clog2(DEPTH)-1:0] wptr = 0, rptr = 0;  // Pointer of write and read
    reg [WIDTH-1:0] fifo[DEPTH]; 

    always @(posedge clk) begin
        // Set the default value on reset
        if (rst) begin
            wptr  <= 0;
            rptr <= 0;
            dout  <= 0;
        end

        else if (wr && !full) begin // write enable and FIFO is not full
            fifo[wptr] <= din;
            wptr <= wptr + 1;
        end

        else if (rd && !empty) begin
            dout  <= fifo[rptr];
            rptr <= rptr + 1;
        end
    end

    assign empty = (wptr == rptr);        // Empty condition
    assign full  = ((wptr+1'b1) == rptr); // Full  condition
endmodule

interface fifo_if #(parameter DEPTH = 16, WIDTH = 8);
    logic clk, rst, wr, rd;
    logic full, empty;
    logic [WIDTH-1:0] din;
    logic [WIDTH-1:0] dout;
endinterface //fifo_if