module top();

  import uvm_pkg::*;

  calc_if vif();
  calculator dut(vif);

  initial begin
    uvm_config_db#(virtual calc_if)::set(uvm_coreservice_t::get().get_root(), "top", "vif", vif);
    run_test();
  end


  class calculator_sequencer extends uvm_sequencer#(uvm_sequence_item);
    `uvm_component_utils(calculator_sequencer)

    function new (string name="calculator_sequencer", uvm_component parent) ;
      super.new(name, parent);
    endfunction : new
  endclass


  class calculator_env extends uvm_env;
    `uvm_component_utils(calculator_env)

    calculator_sequencer calc_seqr;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction : new

    virtual function void build_phase(uvm_phase phase);
      calc_seqr = calculator_sequencer::type_id::create("calc_seqr", this);
    endfunction : build_phase

  endclass : calculator_env
  
  
  class calculator_base_seq extends uvm_sequence#(uvm_sequence_item);
    `uvm_object_utils(calculator_base_seq)
    
    function new(string name="calculator_base_seq");
      super.new(name);
    endfunction : new
  endclass : calculator_base_seq


  class calculator_base_test extends uvm_test;
    `uvm_component_utils(calculator_base_test)
    calculator_env calc_env;

    function new(string name = "calculator_base_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction : new

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      calc_env = calculator_env::type_id::create("calc_env", this);
    endfunction : build_phase
  endclass : calculator_base_test


  class bathtub_seq extends calculator_base_seq;

    function new(string name="bathtub_seq");
      super.new(name);
    endfunction : new

    `uvm_object_utils(bathtub_seq)

    virtual task body();
      `uvm_info(get_name(), "Hello, world!", UVM_NONE);
    endtask : body
  endclass : bathtub_seq


  class bathtub_test extends calculator_base_test;
    `uvm_component_utils(bathtub_test)

    function new(string name = "bathtub_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction : new

    virtual function void build_phase(uvm_phase phase);
      uvm_config_db#(uvm_object_wrapper)::set(this, "calc_env.calc_seqr.main_phase", "default_sequence", bathtub_seq::type_id::get());
      super.build_phase(phase);
    endfunction : build_phase

  endclass : bathtub_test

endmodule : top
