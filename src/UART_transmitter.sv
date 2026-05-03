module UART_transmitter(
  output reg tx, tx_busy,
  input wire rst, clk, tick_9600, tx_start,
  input wire[7:0] tx_data
);
  reg[2:0] count_tx;
  reg[7:0] data_shifter;
  typedef enum logic[1:0] {IDLE, START, DATA, STOP} state_t;
  state_t state;
  always @(posedge clk or negedge rst) begin
    if(!rst) begin
      state <= IDLE; tx <= 1; tx_busy <= 0; count_tx <= 0;
    end else begin
      case(state)
        IDLE: begin
          tx <= 1;
          if(tx_start) begin
            tx_busy <= 1;
            data_shifter <= tx_data;
            state <= START;
          end else tx_busy <= 0;
        end
        START: begin
          if(tick_9600) begin
            tx <= 0; // СТАРТ-БИТ
            state <= DATA;
            count_tx <= 0;
          end
        end
        DATA: begin
          if(tick_9600) begin
            tx <= data_shifter[count_tx];
            if(count_tx == 7) state <= STOP;
            else count_tx <= count_tx + 1;
          end
        end
        STOP: begin
          if(tick_9600) begin
            tx <= 1; // СТОП-БИТ
            state <= IDLE;
          end
        end
      endcase
    end
  end
endmodule
