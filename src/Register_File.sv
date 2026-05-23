module Register_File(
  input wire clk, rst, ready,
  input wire[7:0] data, //Вход от UART
  output reg[7:0] length, dest_addr, start_addr, //Длина и адреса
  output reg start //Сигнал старта
);
  reg[7:0] data[2:0], addr[2:0]; //Значение и адрес
  typedef enum logic[2:0]{START, ADDR, DATA, REALISE} state_t;
  state_t state;
  reg[7:0] trig_0, trig_1; //Цепочка триггеров
  reg need_data;
  reg[1:0] count;
  always@(posedge clk or negedge rst) begin
    if(!rst) begin
      length <= 0; dest_addr <= 0; start_addr <= 0; start <= 0; state <= START; need_data <= 0; count <= 0; start <= 0;
    end else begin
      trig_0 <= data;
      trig_1 <= trig_0;
      case(state)
        START: begin
          start <= 0;
          if(ready) begin
              if(need_data) state <= DATA;
              else state <= ADDR;
          end
        end
        ADDR: begin
          addr[count] <= trig_1;
          state <= START;
          need_data <= 1;
        end
        DATA: begin
          data[count] <= trig_1;
          if(count == 2 || addr_buf[count] == 8'h0A) begin
              state <= REALISE;
          end else begin
              count <= count + 1;
              state <= START;
          end
          need_data <= 0;
        end
        REALISE: begin
          case(addr[count])
            8'h01: start_addr <= data[count];
            8'h02: dest_addr <= data[count];
            8'h03: length <= data[count];
            8'h0A: start <= 1;
          endcase
          if(count > 0) begin
            count <= count - 1;
            state <= REALISE;
          end else begin
            state <= START;
          end
        end
      endcase
    end
  end
endmodule
