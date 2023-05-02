interface calc_if(
  input logic reset,
  input logic[80 * 8 - 1:0] item,
  input logic[7:0] qty,
  input logic equals,
  input logic[15:0] price_in_cents,
  input logic load,
  output logic[15:0] total_in_cents,
  output logic err
);
endinterface : calc_if

  module calculator(calc_if i);
    logic[15:0] total_in_cents;
    logic err;
    logic[15:0] price_list[string];
    
    assign i.total_in_cents = total_in_cents;
    assign i.err = err;
  
    always @(posedge i.reset or posedge i.load or posedge i.equals) begin
      if (i.reset) begin
        total_in_cents = 0;
        err = 0;
        price_list.delete();
      end
      else if (i.load) begin
        price_list[i.item] = i.price_in_cents;
      end
      else if (i.equals) begin
        if (price_list.exists(i.item)) begin
          total_in_cents = i.qty * price_list[i.item];
          err = 0;
        end
        else begin
          total_in_cents = 9999;
          err = 1;
        end
      end
    end
  endmodule : calculator
  