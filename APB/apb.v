module apb(
    input pclk,     // global clk signal
    input presetn,  // reset signal
    input [31:0] paddr, 
    input [2:0] pprot,
    input pselx,
    input penable,
    input pwrite,
    input [31:0] pwdata,
    input [3:0] pstrb,
    output pready,
    output [31:0] prdata,
    output pslverr
);

    parameter IDLE=0, SETUP=1, ACCESS=2, TRANS=3;
    reg [2:0] state;

    reg [31:0] mem [32];

    always @(posedge pclk) begin
        if(presetn == 1'b0) begin // active low
            state <= IDLE;
            prdata <= 32'h0000_0000;
            pready <= 1'b0;
            pslverr <= 1'b0;

            for (int i=0; i<32; i++) begin
                mem[i] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    prdata <= 32'h0000_0000;
                    pready <= 1'b0;
                    pslverr <= 1'b0;

                    if((psel == 1'b0) && (penable == 1'b0)) begin
                        state <= SETUP;
                    end
                end

                SETUP: begin
                    if((psel == 1'b1) && (penable == 1'b0)) begin
                        state <= ACCESS;
                        pready <= 1'b0;
                    end else begin
                        state <= SETUP;
                    end
                end

                ACCESS: begin
                    if(psel && pwrite && penable) begin // write
                        if(paddr < 32) begin
                            mem[paddr] <= pwdata;
                            state <= TRANS;
                            pslverr <= 1'b0;
                        end else begin
                            state <= TRANS;
                            pready <= 1'b1;
                            pslverr <= 1'b1;
                        end
                    end else if(psel && !pwrite && penable) begin // read
                        if(paddr < 32) begin
                            prdata <= mem[paddr];
                            state <= TRANS;
                            pready <= 1'b1;
                            pslverr <= 1'b0;
                        end else begin
                            state <= TRANS;
                            pready <= 1'b1;
                            pslverr <= 1'b1;
                            prdata <= 32'hxxxx_xxxx;
                        end
                    end
                end

                TRANS: begin
                    state <= SETUP;
                    pready <= 1'b0;
                    pslverr <= 1'b0;
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
endmodule