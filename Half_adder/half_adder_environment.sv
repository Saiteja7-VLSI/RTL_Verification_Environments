//half_adder_if.sv
interface half_adder_if;
  logic a;
  logic b;
  logic sum;
  logic carry;
endinterface


//transaction.sv
class transaction;
  rand bit a;
  rand bit b;
  bit sum;
  bit carry;

  constraint c {
    a inside {0,1};
    b inside {0,1};
  }
endclass


//generator.sv
class generator;

  mailbox #(transaction) gen2drv;

  function new(mailbox #(transaction) gen2drv);
    this.gen2drv = gen2drv;
  endfunction

  task run();
    transaction tr;
    repeat (4) begin
      tr = new();
      tr.randomize();
      gen2drv.put(tr);
    end
  endtask

endclass


//driver.sv
class driver;

  virtual half_adder_if vif;
  mailbox #(transaction) gen2drv;
  event drv_done;

  function new(virtual half_adder_if vif,
               mailbox #(transaction) gen2drv,
               event drv_done);
    this.vif      = vif;
    this.gen2drv  = gen2drv;
    this.drv_done = drv_done;
  endfunction

  task run();
    transaction tr;
    forever begin
      gen2drv.get(tr);

      vif.a = tr.a;
      vif.b = tr.b;

      #1;              // allow combinational settle
      -> drv_done;     // notify monitor
    end
  endtask

endclass


//monitor.sv
class monitor;

  virtual half_adder_if vif;
  mailbox #(transaction) mon2scb;
  event drv_done;

  function new(virtual half_adder_if vif,
               mailbox #(transaction) mon2scb,
               event drv_done);
    this.vif      = vif;
    this.mon2scb  = mon2scb;
    this.drv_done = drv_done;
  endfunction

  task run();
    transaction tr;
    forever begin
      @drv_done;   // wait until inputs are stable

      tr = new();
      tr.a     = vif.a;
      tr.b     = vif.b;
      tr.sum   = vif.sum;
      tr.carry = vif.carry;

      mon2scb.put(tr);
    end
  endtask

endclass



//scoreboard.sv
class scoreboard;

  mailbox #(transaction) mon2scb;

  function new(mailbox #(transaction) mon2scb);
    this.mon2scb = mon2scb;
  endfunction

  task run();
    transaction tr;
    forever begin
      mon2scb.get(tr);

      if (tr.sum == (tr.a ^ tr.b) &&
          tr.carry == (tr.a & tr.b))
        $display("PASS: a=%0b b=%0b sum=%0b carry=%0b",
                  tr.a, tr.b, tr.sum, tr.carry);
      else
        $display("FAIL: a=%0b b=%0b sum=%0b carry=%0b",
                  tr.a, tr.b, tr.sum, tr.carry);
    end
  endtask

endclass


//environment.sv
class environment;

  generator  gen;
  driver     drv;
  monitor    mon;
  scoreboard scb;

  mailbox #(transaction) gen2drv;
  mailbox #(transaction) mon2scb;

  event drv_done;                 // ✅ declaration ONLY
  virtual half_adder_if vif;

  function new(virtual half_adder_if vif);
    this.vif = vif;

    gen2drv = new();
    mon2scb = new();
    // ❌ NO drv_done = new();

    gen = new(gen2drv);
    drv = new(vif, gen2drv, drv_done);
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



//testbench.sv
`include "half_adder.sv"
`include "half_adder_if.sv"
`include "transaction.sv"
`include "generator.sv"
`include "driver.sv"
`include "monitor.sv"
`include "scoreboard.sv"
`include "environment.sv"


module testbench;

  half_adder_if intf();

  half_adder dut (
    .a(intf.a),
    .b(intf.b),
    .sum(intf.sum),
    .carry(intf.carry)
  );

  environment env;

  initial begin
    env = new(intf);
    env.run();
    #50 $finish;
  end

endmodule
