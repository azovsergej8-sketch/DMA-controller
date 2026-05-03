module Dual-Port_RAM(
  input wire clk, //Тактовый сигнал
  input wire[7:0] addr_a, addr_b, //Указатели записи
  input wire we_a, we_b, //Сигналы разрешения
  input wire[7:0] data_a_in, data_b_in, //Данные для записи
  output reg[7:0] data_b_out //Данные для чтения
);
  reg[7:0] mem[255:0]; //Блок памяти
  always@(posedge clk) begin
	if(we_a) begin
    	mem[addr_a] <= data_a_in;
    end
    if(we_b) begin
        mem[addr_b] <= ata_b_in;
    end
    data_b_out <= mem[addr_b];
  end
endmodule
