//Interface
interface full_adder_if;
  logic [3:0]a;
  logic [3:0]b;
  logic cin;
  logic [3:0]sum;
  logic cout;
  
endinterface

//transaction
class transaction;
  rand bit [3:0]a;
  rand bit [3:0]b;
  rand bit cin;
  bit sum;
  bit cout;
  
  constraint c{
    a inside {0,1};
    b inside {0,1};
  }
  
endclass

//generator
class generator;
  mailbox #(transaction) gen2drive;
  transaction trans;
  
  function new(mailbox #(transaction) gen2drive);
    this.gen2drive = gen2drive;
  endfunction
  
  task run();
    repeat(512) begin
      trans=new();
      trans.randomize();
      gen2drive.put(trans);
    end
  endtask
endclass

//driver
class driver;

  virtual full_adder_if vif;
  mailbox #(transaction) gen2drive;
  event drv_done;

  function new(
    virtual full_adder_if vif,
    mailbox #(transaction) gen2drive,
    event drv_done
  );
    this.vif      = vif;
    this.gen2drive = gen2drive;
    this.drv_done = drv_done;
  endfunction

  task run();
    transaction tr;
    forever begin
      gen2drive.get(tr);

      vif.a   = tr.a;
      vif.b   = tr.b;
      vif.cin = tr.cin;

      #1;           
      -> drv_done;  
    end
  endtask

endclass

//monitor
class monitor;

  virtual full_adder_if vif;
  mailbox #(transaction) mon2scb;
  event drv_done;

  function new(
    virtual full_adder_if vif,
    mailbox #(transaction) mon2scb,
    event drv_done
  );
    this.vif      = vif;
    this.mon2scb  = mon2scb;
    this.drv_done = drv_done;
  endfunction

  task run();
    transaction tr;
    forever begin
      @drv_done;
      tr = new();
      tr.a    = vif.a;
      tr.b    = vif.b;
      tr.cin  = vif.cin;
      tr.sum  = vif.sum;
      tr.cout = vif.cout;
      mon2scb.put(tr);
    end
  endtask

endclass


//scoreboard
class scoreboard;

  mailbox #(transaction) mon2scb;

  function new(mailbox #(transaction) mon2scb);
    this.mon2scb = mon2scb;
  endfunction

  task run();
    transaction trans;
    logic [4:0] exp;   // 5-bit expected result

    forever begin
      mon2scb.get(trans);

      exp = trans.a + trans.b + trans.cin;

      if ({trans.cout, trans.sum} == exp)
        $display("PASS: a=%0d b=%0d cin=%0d sum=%0d cout=%0d",
                  trans.a, trans.b, trans.cin, trans.sum, trans.cout);
      else
        $display("FAIL: a=%0d b=%0d cin=%0d sum=%0d cout=%0d  exp=%0d",
                  trans.a, trans.b, trans.cin, trans.sum, trans.cout, exp);
    end
  endtask

endclass

//environment
class environment;

  generator  gen;
  driver     drv;
  monitor    mon;
  scoreboard scb;

  mailbox #(transaction) gen2drive;
  mailbox #(transaction) mon2scb;

  event drv_done;
  virtual full_adder_if vif;

  function new(virtual full_adder_if vif);
    this.vif = vif;

    gen2drive = new();
    mon2scb   = new();

    gen = new(gen2drive);
    drv = new(vif, gen2drive, drv_done);
    mon = new(vif, mon2scb, drv_done);
    scb = new(mon2scb);
  endfunction

  task run();
    fork
      gen.run();
      drv.run();
      mon.run();
      scb.run();
    join_none
  endtask

endclass

`include "full_adder.sv"
`include "full_adder_if.sv"
`include "transaction.sv"
`include "generator.sv"
`include "driver.sv"
`include "monitor.sv"
`include "scoreboard.sv"
`include "environment.sv"

module testbench;

 
  full_adder_if intf();

  
  full_adder dut (
    .a   (intf.a),
    .b   (intf.b),
    .cin (intf.cin),
    .sum (intf.sum),
    .cout(intf.cout)
  );

  environment env;

  initial begin
    env = new(intf);  
    env.run();
    #50 $finish;
  end

endmodule
