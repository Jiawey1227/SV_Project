module apb(
    input pclk,     // global clk signal
    input presetn,  // reset signal
    input [31:0] paddr, // 
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
    reg [2:0] state, next_state;

    always @(posedge pclk) begin
        if(presetn == 0) begin // active low
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        case (state)
            IDEL: begin
                if((psel == 1'b0) && (penable == 1'b0)) begin
                    next_state = SETUP;
                end else begin
                    next_state = state; 
                end
            end

            SETUP: begin
                if((psel == 1'b1) && (penable == 1'b0)) begin
                    next_state = ACCESS;
                end else begin
                    next_state = state;
                end
            end

            ACCESS: begin
                if((psel == 1'b1) && (penable == 1'b1)) begin
                    next_state = TRANS;
                end else if 
            end
        endcase
    end
    
endmodule