module top();

  import uvm_pkg::*;

  calc_if vif();
  calculator dut(vif);

  initial begin
    uvm_config_db#(virtual calc_if)::set(uvm_coreservice_t::get().get_root(), "top", "vif", vif);
    $info("Hello, world!");
    run_test();
  end
endmodule : top