class Transaction;
  rand bit din; // Define a random input 
  bit dout;     // Define an output

  function Transaction copy();
    copy = new();
    copy.din = din;
    copy.dout = dout;
  endfunction

  function void display(string tag);
    $display("[%0s] : DIN : %0b, DOUT : %0b", tag, din, dout);
  endfunction

endclass


class Generator;
  Transaction tr;
  mailbox #(Transaction) mbx;    // From gen to drv
  mailbox #(Transaction) mbxref; // From gen to scb

  event scbnext; // Sense the completion of scb
  event done;    
  int count;

  function new(mailbox #(Transaction) mbx, mailbox #(Transaction) mbxref);
    this.mbx = mbx;
    this.mbxref = mbxref;
    tr = new();
  endfunction

  task run();
    repeat(count) begin
        assert(tr.randomize) else $error("[GEN] : Randomization Failed");
        mbx.put(tr.copy);
        mbxref.put(tr.copy);
        tr.display("GEN");
        @(scbnext); // Wait for the scb's completion
    end
    -> done;
  endtask 
endclass


class Driver;
  Transaction tr;
  mailbox #(Transaction) mbx; // Get from gen
  virtual dff_if vif;         // Virtual if for DUT

  function new(mailbox #(Transaction) mbx);
    this.mbx = mbx;
  endfunction

  task reset();
    vif.rst <= 1'b1;
    repeat(5) @(posedge vif.clk);
    vif.rst <= 1'b0;
    @(posedge vif.clk);
    $display("[DRV : Reset Done]");
  endtask

  task run();
    forever begin
        mbx.get(tr);
        vif.din <= tr.din;
        @(posedge vif.clk); 
        tr.display("DRV");
        vif.din <= 1'b0;
        @(posedge vif.clk); 
    end
  endtask
endclass


class Monitor;
  Transaction tr;
  mailbox #(Transaction) mbx; // From mon to scb
  virtual dff_if vif;         // Virtual if for DUT

  function new(mailbox #(Transaction) mbx);
    this.mbx = mbx;
  endfunction

  task run();
    tr = new();
    forever begin
        repeat(2) @(posedge vif.clk); 
        tr.dout = vif.dout;
        mbx.put(tr);
        tr.display("MON");
    end
  endtask;
endclass


class Scoreboard;
  Transaction tr;
  Transaction trref; // Define a reference for comparison
  mailbox #(Transaction) mbx;    // Get from mon
  mailbox #(Transaction) mbxref; // Get from gen
  event scbnext;

  function new(mailbox #(Transaction) mbx, mailbox #(Transaction) mbxref);
    this.mbx = mbx;
    this.mbxref = mbxref;
  endfunction

  task run();
    forever begin
        mbx.get(tr);
        mbxref.get(trref);
        tr.display("SCB");
        trref.display("REF");

      if (tr.dout == trref.din) begin
            $display("[SCB] : Data Matched");
        end
        else begin
            $display("[SCB] : Data Mismatched");
        end
        $display("-------------------------------------------");
        -> scbnext;
    end
  endtask
endclass


class Env;
  Generator gen;
  Driver drv;
  Monitor mon;
  Scoreboard scb;
  event next;
  mailbox #(Transaction) mbx_gen2drv; // gen <-> drv
  mailbox #(Transaction) mbx_gen2scb; // gen <-> scb
  mailbox #(Transaction) mbx_mon2scb; // mon <-> scb
  virtual dff_if vif;

  function new(virtual dff_if vif);
    // connect mailbox
    mbx_gen2drv = new();
    mbx_gen2scb = new();
    mbx_mon2scb = new();
    gen = new(mbx_gen2drv, mbx_gen2scb);
    drv = new(mbx_gen2drv);
    mon = new(mbx_mon2scb);
    scb = new(mbx_mon2scb, mbx_gen2scb);
    
    // connect vif
    this.vif = vif;
    drv.vif = this.vif;
    mon.vif = this.vif;

    // connect event
    gen.scbnext = next;
    scb.scbnext = next;
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


module tb;
  dff_if vif(); 

  dff DUT(vif); // Instantiate DUT

  initial begin // Instantiate clk
    vif.clk <= 0;
  end

  always #10 vif.clk <= ~vif.clk; 

  Env env;

  initial begin
    env = new(vif);
    env.gen.count = 30; // Set stimulus count
    env.run();
  end

  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end
endmodule