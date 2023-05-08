interface calc_if ();

    logic reset;
    logic[80 * 8 - 1:0] item;
    logic[7:0] qty;
    logic equals;
    logic[15:0] price_in_cents;
    logic load;
    logic[15:0] total_in_cents;
    logic err;

    modport dut (
    input reset,
    input item,
    input qty,
    input equals,
    input price_in_cents,
    input load,
    output total_in_cents,
    output err
    );

    modport driver (
    output reset,
    output item,
    output qty,
    output equals,
    output price_in_cents,
    output load,
    input total_in_cents,
    input err
    );

    modport monitor (
    input reset,
    input item,
    input qty,
    input equals,
    input price_in_cents,
    input load,
    input total_in_cents,
    input err
    );
endinterface : calc_if

  module calculator (calc_if i);
    logic[15:0] total_in_cents;
    logic err;
    logic[15:0] price_list[string];
    
    assign i.dut.total_in_cents = total_in_cents;
    assign i.dut.err = err;
  
    always @(posedge i.dut.reset or posedge i.dut.load or posedge i.dut.equals) begin
      if (i.dut.reset) begin
        total_in_cents = 0;
        err = 0;
        price_list.delete();
      end
      else if (i.dut.load) begin
        price_list[i.dut.item] = i.dut.price_in_cents;
      end
      else if (i.dut.equals) begin
        if (price_list.exists(i.dut.item)) begin
          total_in_cents = i.dut.qty * price_list[i.dut.item];
          err = 0;
        end
        else begin
          total_in_cents = 9999;
          err = 1;
        end
      end
    end
  endmodule : calculator
