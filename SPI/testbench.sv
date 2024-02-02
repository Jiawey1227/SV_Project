class Transaction;
    rand bit newd;
    rand bit [11:0] din;
    
    bit mosi;

endclass

class Generator;
    Transaction tr;
    mailbox #(Transaction) mbx;
    event done;
    int count = 0;
    event drvnext;
    event scbnext;

    function new(mailbox #(Transaction) mbx);
        tr = new();
        this.mbx = mbx;
    endfunction


    task run();
        repeat(count) begin
            assert(tr.randomize) else $error("[GEN]:Randomization Failed");
            mbx.put(tr);
          	$display("[GEN] : newd: %0d, din: %b, mosi: %0d", tr.newd, tr.din, tr.mosi, $time);
            @(drvnext);
            @(scbnext);
        end
        -> done;
    endtask
endclass

class Driver;
    Transaction tr;
    mailbox #(Transaction) mbx;
    mailbox #(bit [11:0]) mbxds;
    event drvnext;
    virtual spi_if vif;

  	function new(mailbox #(Transaction) mbx, mailbox #(bit [11:0]) mbxds);
        this.mbx = mbx;
      	this.mbxds = mbxds;
    endfunction

    task reset();
        vif.rst  <= 1'b1;
        vif.newd <= 1'b0;
        vif.din  <= 0;
      	vif.cs   <= 1'b1;
      	repeat(10) @(posedge vif.clk);
        vif.rst <= 1'b0;
        @(posedge vif.clk);
      	$display("[DRV] : newd: %0d, din: %b, cs: %0d, mosi: %0d", vif.newd, vif.din, vif.cs, vif.mosi);
      	$display("[DRV] : Reset Done", $time);
        $display("--------------------");
    endtask

    task run();
        forever begin
            mbx.get(tr);
            @(posedge vif.sclk);
            vif.newd <= 1'b1;
            vif.din  <= tr.din;
            mbxds.put(tr.din);
            @(posedge vif.sclk);
          	$display("[DRV] : newd: %0d, din: %b, cs: %0d, mosi: %0d", vif.newd, vif.din, vif.cs, vif.mosi, $time);
          	@(monnext);
            vif.newd <= 1'b0;
          	@(posedge vif.sclk);
            -> drvnext;
        end
    endtask
endclass

class Monitor;
    
    mailbox #(bit [11:0]) mbx;
    virtual spi_if vif;
    bit [11:0] srx;

    function new(mailbox #(bit [11:0]) mbx);
        this.mbx = mbx;
    endfunction

    task run();
        forever begin
          @(posedge vif.sclk);
          wait(vif.cs == 1'b0); // Start transaction
          @(posedge vif.sclk);
          for (int i = 0; i < 12; i++)  begin
            @(posedge vif.sclk); // Must wait for a clock cycle!!!
            srx[i] = vif.mosi;
            $display("[MON] : newd: %0d, din: %b, cs: %0d, mosi: %0d", vif.newd, vif.din, vif.cs, vif.mosi, $time);
            $display("[MON] : data received: %0d", vif.mosi, $time);
          end
          wait(vif.cs == 1'b1); // End transaction
          mbx.put(srx);
          $display("[MON] : newd: %0d, din: %b, cs: %0d, mosi: %0d", vif.newd, vif.din, vif.cs, vif.mosi, $time);
          $display("[MON] : Data Sent: %b", srx, $time);
        end
    endtask

endclass

class Scoreboard;

    mailbox #(bit [11:0]) mbxds, mbxms;
    bit [11:0] ds;
    bit [11:0] ms;
  
  	event scbnext;

    function new(mailbox #(bit [11:0]) mbxds, mbxms);
        this.mbxds = mbxds;
        this.mbxms = mbxms;
    endfunction

    task run();
        forever begin
            mbxds.get(ds);
            mbxms.get(ms);
            -> scbnext;
          	$display("[SCB] : Received from [DRV]:%0d, [MON]:%0d", ds, ms);
            $display("------------------------------------------------");
        end
    endtask

endclass

class Env;

    Transaction tr;
  	Generator  gen;
    Driver     drv;
    Monitor    mon;
    Scoreboard scb;

    virtual spi_if vif;
  
    event drvnext;
    event scbnext;

    mailbox #(Transaction) mbx_gen2drv;
    mailbox #(bit [11:0]) mbx_drv2scb;
    mailbox #(bit [11:0]) mbx_mon2scb;

    function new(virtual spi_if vif);
        mbx_gen2drv = new();
        mbx_drv2scb = new();
        mbx_mon2scb = new();
        gen = new(mbx_gen2drv);
    	drv = new(mbx_gen2drv, mbx_drv2scb);
        mon = new(mbx_mon2scb);
      	scb = new(mbx_drv2scb, mbx_mon2scb);

        this.vif = vif;
        drv.vif = this.vif;
        mon.vif = this.vif;

        gen.drvnext = drvnext;
        drv.drvnext = drvnext;

        gen.scbnext = scbnext;
        scb.scbnext = scbnext;
        
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
        $finish();
    endtask
  
    task run();
      pre_test();
      test();
      post_test();
    endtask

endclass

module tb();

    Env env;

  	spi_if vif();
    spi DUT(vif.clk,vif.newd,vif.rst,vif.din,vif.sclk,vif.cs,vif.mosi);

    initial begin
        vif.clk = 0;
    end

    
    always #20 vif.clk = ~vif.clk; 

    initial begin
        env = new(vif);
        env.gen.count = 20;
        env.run();
    end
endmodule

