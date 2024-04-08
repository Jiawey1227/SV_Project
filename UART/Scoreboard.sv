class Scoreboard;
    mailbox #(bit [7:0]) mbx_drv_sco, mbx_mon_sco;

    bit [7:0] ds;
    bit [7:0] ms;

    event sconext;

    function new(mailbox #(bit [7:0]) mbx_drv_sco, mailbox #(bit [7:0]) mbx_mon_sco);
        this.mbx_drv_sco = mbx_drv_sco;
        this.mbx_mon_sco = mbx_mon_sco;
    endfunction

    task run();
        forever begin
            mbx_drv_sco.get(ds);
            mbx_mon_sco.get(ms);
            $display("[SCO] : DRV : %0d MON : %0d", ds, ms);

            if(ds == ms) begin
                $display("DATA MATCHED");
            end else begin
                $display("DATA MISMATCHED");
            end
            $display("----------------------------------------");
            -> sconext;
        end
    endtask
endclass