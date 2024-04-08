`include "Generator.sv"
`include "Driver.sv"
`include "Monitor.sv"
`include "Scoreboard.sv"

class environment;

    Generator gen;
    Driver drv;
    Monitor mon;
    Scoreboard sco;

    event drvnext;
    event sconext;
    
    mailbox #(Transaction) mbx_gen_drv;
    mailbox #(bit [7:0]) mbx_drv_sco;
    mailbox #(bit [7:0]) mbx_mon_sco;

    virtual uart_if vif;

    function new(virtual uart_if vif);
        mbx_gen_drv = new();
        mbx_drv_sco = new();
        mbx_mon_sco = new();

        mon = new(mbx_mon_sco);
        sco = new(mbx_drv_sco, mbx_mon_sco);
        gen = new(mbx_gen_drv);
        drv = new(mbx_drv_sco, mbx_gen_drv);
      
      	this.vif = vif;
        drv.vif = this.vif;
        mon.vif = this.vif;


        gen.sconext = sconext;
        sco.sconext = sconext;
        gen.drvnext = drvnext;
        drv.drvnext = drvnext;
    endfunction

    task pre_test();
        drv.reset();
    endtask

    task test();
        fork
            gen.run();
            drv.run();
            mon.run();
            sco.run();
        join_any
    endtask

    task post_test();
        wait(gen.done.triggered);
        $finish();
    endtask

    task run();
        pre_test();
        test();
        post_test();
    endtask

endclass