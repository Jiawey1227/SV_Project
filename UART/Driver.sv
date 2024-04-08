// `include "Transaction.sv"

class Driver;

    virtual uart_if vif;

    Transaction tr;

    mailbox #(Transaction) mbx_gen_drv; // gen <-> drv
    mailbox #(bit [7:0]) mbx_drv_sco;   // drv <-> sco

    event drvnext;

    bit [7:0] datarx;
    
  	function new(mailbox #(bit [7:0]) mbx_drv_sco, mailbox #(Transaction) mbx_gen_drv);
        this.mbx_gen_drv = mbx_gen_drv;
        this.mbx_drv_sco = mbx_drv_sco;
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
            mbx_gen_drv.get(tr);
            if(tr.oper == 1'b0) begin
                @(posedge vif.uclktx);
                vif.rst <= 1'b0;
                vif.newd <= 1'b1;
                vif.rx <= 1'b1;
                vif.dintx <= tr.dintx;

                @(posedge vif.uclktx);
                vif.newd <= 1'b0;

                mbx_drv_sco.put(tr.dintx);
                wait(vif.donetx == 1'b1);
                $display("[DRV]: Data Sent : %0d", tr.dintx);
                -> drvnext;
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

                mbx_drv_sco.put(datarx);
                wait(vif.donerx == 1'b1);
                $display("[DRV]: Data RCVD : %0d", datarx); 
                vif.rx <= 1'b1;
                ->drvnext;
            end
        end
    endtask

endclass