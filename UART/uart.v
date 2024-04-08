`timescale 1ns / 1ps

module uart_top #(
    parameter clk_freq = 1000000, 
    parameter baud_rate = 9600
) (
    input clk, rst,
    input rx,
    input [7:0] dintx,
    input newd,
    output tx,
    output [7:0] doutrx,
    output donetx,
    output donerx
);

    // Instantiate uarttx
    uarttx #(clk_freq, baud_rate) utx (
        .clk(clk),
        .rst(rst),
        .newd(newd),
        .tx_data(dintx),
        .tx(tx),
        .donetx(donetx)
    );

    // Instantiate uartrx
    uartrx #(clk_freq, baud_rate) rtx (
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .rxdata(doutrx),
        .done(donerx)
    );

endmodule

module uarttx #(
    parameter clk_freq = 1000000, 
    parameter baud_rate = 9600
) (
    input clk, rst,
    input newd,
    input [7:0] tx_data,
    output reg tx,
    output reg donetx
);

    localparam clkcount = (clk_freq/baud_rate);

    integer count  = 0;
    integer counts = 0;

    reg uclk = 0;

    // enum bit [3:0] {idle = 4'b0001, start = 4'b0010, transfer = 4'b0100, done = 4'b1000} state;
    parameter idle  = 2'b01;
    parameter transfer = 2'b10;


    reg [1:0] state;

    // uart_clock_gen
    always @(posedge clk) begin
        if (count < clkcount/2) begin
            count <= count + 1;
        end else begin
            count <= 0;
            uclk  <= ~uclk;
        end
    end

    reg [7:0] din;

    // FSM 
    always@(posedge uclk) begin
        if(rst) begin 
            state <= idle;
        end else begin
            case(state)

                idle: begin
                    counts <= 0;
                    tx <= 1'b1;
                    donetx <= 1'b0;
                    
                    if(newd)  begin
                        state <= transfer;
                        din <= tx_data;
                        tx <= 1'b0; 
                    end else begin
                        state <= idle;   
                    end    
                end
                
                transfer: begin
                    if(counts <= 7) begin
                        counts <= counts + 1;
                        tx <= din[counts];
                        state <= transfer;
                    end else begin
                        counts <= 0;
                        tx <= 1'b1;
                        state <= idle;
                        donetx <= 1'b1;
                    end
                end
                
                default : state <= idle;
            endcase
        end
    end
endmodule

module uartrx #(
    parameter clk_freq = 1000000, 
    parameter baud_rate = 9600
) (
    input clk, rst,
    input rx,
    output reg [7:0] rxdata,
    output reg done
);

    localparam clkcount = (clk_freq/baud_rate);

    integer count  = 0;
    integer counts = 0;

    reg uclk = 0;

    // enum bit [3:0] {idle = 4'b0001, start = 4'b0010, transfer = 4'b0100, done = 4'b1000} state;
    parameter idle  = 2'b01;
    parameter start = 2'b10;


    reg [1:0] state;

    // uart_clock_gen
    always @(posedge clk) begin
        if (count < clkcount/2) begin
            count <= count + 1;
        end else begin
            count <= 0;
            uclk  <= ~uclk;
        end
    end

    always@(posedge uclk) begin
        if(rst) begin
            rxdata <= 8'h00;
            counts <= 0;
            done <= 1'b0;
        end else begin
            case(state)
                idle: begin
                    rxdata <= 8'h00;
                    counts <= 0;
                    done <= 1'b0;
                    if(rx == 1'b0) state <= start;
                    else state <= idle;
                end
                
                start: begin 
                    if(counts <= 7) begin
                        counts <= counts + 1;
                        rxdata <= {rx, rxdata[7:1]};
                    end else begin 
                        counts <= 0;
                        done <= 1'b1;
                        state <= idle;
                    end
                end   
   
                default : state <= idle;
            endcase
        end
    end

endmodule

interface uart_if;
    logic clk;
    logic uclktx;
    logic uclkrx;
    logic rst;
    logic rx;
    logic [7:0] dintx;
    logic newd;
    logic tx;
    logic [7:0] doutrx;
    logic donetx;
    logic donerx;
endinterface
