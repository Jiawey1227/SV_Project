`include "Transaction.sv"

class Generator;
    Transaction tr;

    mailbox #(Transaction) mbx_gen_drv; // gen <-> drv

    event done;
    event drvnext;
    event sconext;
    int count = 0;  

    function new(mailbox #(Transaction) mbx_gen_drv);
        this.mbx_gen_drv = mbx_gen_drv;
        tr = new();
    endfunction

    task run();
        repeat(count) begin
            assert(tr.randomize) else $error("[GEN] :Randomization Failed");
            mbx_gen_drv.put(tr.copy);
          	$display("[GEN]: Oper : %0s Din: %0d", tr.oper.name(), tr.dintx);
            @(drvnext);
            @(sconext);
        end
        -> done;
    endtask

endclass