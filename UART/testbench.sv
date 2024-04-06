class Transaction;
    typedef enum bit {write = 1'b0, read = 1'b1} oper_type;

    randc oper_type oper;

    bit rx;

    rand bit [7:0] dintx;

    bit newd;
    bit tx;
    bit [7:0] doutrx;
    bit donetx;
    bit donerx;

    function transaction copy();
        copy = new();
        copy.rx = this.rx;
        copy.dintx = this.dintx;
        copy.newd = this.newd;
        copy.tx = this.tx;
        copy.doutrx = this.doutrx;
        copy.donetx = this.donetx;
        copy.donerx = this.donerx;
        copy.oper = this.oper;
    endfunction

endclass

class Generator;
    Transaction tr;

    mailbox #(Transaction) mbx;

    event done;
    event drvnext;
    event sconext;
    int count = 0;  

    function new(mailbox #(transaction) mbx);
        this.mbx = mbx;
        tr = new();
    endfunction

    task run();
        repeat(count) begin
            assert(tr.randomize) else $error("[GEN] :Randomization Failed");
            mbx.put(tr.copy);
            $display("[GEN]: Oper : %os Din: %0d", tr.oper.name(), tr.dintx);
            @(drvnext);
            @(sconext);
        end
        -> done;
    endtask

      

endclass

class Driver;

    virtual uart_if vif;

    Transaction tr;

    mailbox #(Transaction) mbx;
    mailbox #(bit [7:0]) mbxds;

    event drvnext;

    bit [7:0] datarx;
    
    function new(mailbox #(bit [7:0]) mbxds, mailbox #(transaction) mbx);
        this.mbx = mbx;
        this.mbxds = mbxds;
    endfunction

    task reset();
        vif.rst <= 1'b1;
        vif.dintx <= 0;
        vif.newd <= 0;
        vif.rx <= 1'b1;

        repeat(5) @(posedge vif.uclktx);
        
        vif.rst <= 1'b0;
        
        @(posedge vif.uclktx);
        $display("[DRV] : RESET DONE");
        $display("----------------------------------------");
    endtask

    task run();
        forever begin
            mbx.get(tr);
            if(tr.oper == 1'b0) begin
                @(posedge vif.uclktx);
                vif.rst <= 1'b0;
                vif.newd <= 1'b1;
                vif.rx <= 1'b1;
                vif.dintx <= tr.dintx;

                @(posedge vif.uclktx);
                vif.newd <= 1'b0;

                mbxds.put(tr.dintx);
                wait(vif.donetx == 1'b1);
                $display("[DRV]: Data Sent : %0d", tr.dintx);
                -> drvnext
            end
            else if(tr.oper == 1'b1) begin
                @(posedge vif.uclkrx);
                vif.rst <= 1'b0;
                vif.rx <= 1'b0;
                vif.newd <= 1'b0;

                @(posedge vif.uclkrx);
                for(int i=0; i<=7; i++) begin
                    @(posedge vif.uclkrx);                
                    vif.rx <= $urandom;
                    datarx[i] = vif.rx; 
                end

                mbxds.put(datarx);
                wait(vif.donerx == 1'b1);
                $display("[DRV]: Data RCVD : %0d", datarx); 
                vif.rx <= 1'b1;
                ->drvnext;
            end
        end
    endtask

endclass

class Monitor;

endclass

class Scoreboard;

endclass

class Env;

endclass

module tb();

endmodule