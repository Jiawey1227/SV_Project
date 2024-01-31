class Transaction;
    rand bit wr, rd;
    bit full, empty;
    rand bit [7:0] din;
    bit [7:0] dout;

    constraint wr_rd_c {
        wr dist {1:/70, 0:/30};
        (wr == 1) <-> (rd == 0);
    }
endclass //Transaction

class Generator;
    Transaction tr;
    mailbox #(Transaction) mbx; 
    
    event next; 
    event done;
    int count; // Number of transactions to generate
    int i;     // Iteration counter

    function new(mailbox #(Transaction) mbx);
        this.mbx = mbx;
        tr = new();
    endfunction

    task run();
        repeat(count) begin
            assert (tr.randomize) else $error("Randomization Failed");
            i++;
            mbx.put(tr);
            $display("[GEN] : Oper : %0d iteration : %0d", tr.oper, i);
            @(next);
        end -> done;
    endtask
endclass

class Driver;
    Transaction tr;
    mailbox #(Transaction) mbx;
    virtual fifo_if vif;

    function new(mailbox #(Transaction) mbx);
        this.mbx = mbx;
    endfunction

    task reset();
        vif.rst <= 1'b1;
        vif.wr  <= 1'b0;
        vif.rd  <= 1'b0;
        vif.din <= 0;
        repeat(5) @(posedge vif.clk);
        vif.rst <= 1'b0;
        @(posedge vif.clk);
        $display("[DRV] : Reset Done");
        $display("-----------------------------");
    endtask

    // task write(ref Transaction tr);
    //     @(posedge vif.clk);
    //     vif.rst <= 1'b0;
    //     vif.rd  <= 1'b0;
    //     vif.wr  <= 1'b1;
    //     vif.din <= tr.din;
    //   	@(posedge vif.clk);
    //     vif.wr  <= 1'b0;
    //     $display("[DRV] : DATA WRITE data : %0d", vif.din);
    //   	@(posedge vif.clk);
    // endtask

    // task read(ref Transaction tr);
    //     @(posedge vif.clk);
    //     vif.rst <= 1'b0;
    //     vif.rd  <= 1'b1;
    //     vif.wr  <= 1'b0;
    //     @(posedge vif.clk);
    //     vif.rd  <= 1'b0;
    //     $display("[DRV] : Data read data");
    //     @(posedge vif.clk);
    // endtask

    task run();
        forever begin
            mbx.get(tr);
            @(posedge vif.clk);
            vif.rst <= 1'b0;
            vif.rd  <= tr.rd;
            vif.wr  <= tr.wr;
            vif.din <= tr.din;
            @(posedge vif.clk);
            vif.wr <= 1'b0;
            vif.rd <= 1'b0;
            if (tr.wr) begin
                $display("[DRV] : DATA WRITE data : %0d", vif.din);
            end
            else begin
                $display("[DRV] : Data read data");
            end
            @(posedge vif.clk);
        end
    endtask
endclass

class Monitor;
    Transaction tr;
    mailbox #(Transaction) mbx; 
    virtual fifo_if vif;

    function new(mailbox #(Transaction) mbx);
        this.mbx = mbx;
    endfunction

    task run();
        tr = new();
        forever begin
            repeat(2) @(posedge vif.clk);
            tr.wr = vif.wr;
            tr.rd = vif.rd;
            tr.din = vif.din;
            tr.full = vif.full;
            tr.empty = vif.empty;
            @(posedge vif.clk);
            tr.dout = vif.dout; // Using blocking assignment in monitor!!!

            mbx.put(tr);
            $display("[MON] : Wr:%0d rd:%0d din:%0d dout:%0d full:%0d empty:%0d", tr.wr, tr.rd, tr.din, tr.dout, tr.full, tr.empty);
        end
    endtask
endclass

class ScoreBoard;
  	mailbox #(Transaction) mbx;
    Transaction tr;
    event next;
    bit [7:0] din[$];
    bit [7:0] temp;
    int err = 0;

    function new(mailbox #(Transaction) mbx);
        this.mbx = mbx;
    endfunction

    task run();
        forever begin
            mbx.get(tr);
            $display("[SCB] : Wr:%0d rd:%0d din:%0d dout:%0d full:%0d empty:%0d", tr.wr, tr.rd, tr.din, tr.dout, tr.full, tr.empty);

            if (tr.wr) begin
                if (!tr.full) begin
                    din.push_front(tr.din);
                    $display("[SCB] : data stored in queue : %0d", tr.din);
                end
                else begin
                    $display("[SCB] : FIFO is full");
                end
            end
            else if (tr.rd) begin
                if (!tr.empty) begin
                    temp = din.pop_back();

                    if (tr.dout == temp) begin
                        $display("[SCB] : data matched!");
                    end
                    else begin
                        $display("[SCB] : data mismatched!!");
                        err++;
                    end
                end
                else begin
                    $display("[SCB] : FIFO is empty");
                end
            end

            -> next;
        end

    endtask

endclass

class Environment;
    Generator  gen;
    Driver     drv;
    Monitor    mon;
    ScoreBoard scb;
    mailbox #(Transaction) mbx_gen2drv;
    mailbox #(Transaction) mbx_mon2scb;
    event next;
    virtual fifo_if vif;

    function new(virtual fifo_if vif);
        mbx_gen2drv = new();
        mbx_mon2scb = new();
        gen = new(mbx_gen2drv);
        drv = new(mbx_gen2drv);
        mon = new(mbx_mon2scb);
        scb = new(mbx_mon2scb);

        this.vif = vif;
        drv.vif  = vif;
        mon.vif  = vif;

        gen.next = next;
        scb.next = next;
    endfunction

    task pre_test();
        drv.reset();
    endtask

    task test();
        fork
            gen.run();
            drv.run();
            mon.run();
            scb.run();
        join_any
    endtask

    task post_test();
        wait(gen.done.triggered);
        $display("---------------------");
        $display("Error Count : %0d", scb.err);
        $display("---------------------");
        $finish();
    endtask

    task run();
        pre_test();
        test();
        post_test();
    endtask
endclass

module tb;

    fifo_if vif();
 	FIFO dut (vif.clk, vif.rst, vif.wr, vif.rd, vif.din, vif.dout, vif.empty, vif.full);
     // Cause we do not use if in DUT
    
    initial begin
        vif.clk <= 0;
    end

    always #10 vif.clk <= ~vif.clk;

    Environment env;

    initial begin
        env = new(vif);
        env.gen.count = 10;
        env.run();
    end


endmodule
