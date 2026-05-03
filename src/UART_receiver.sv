module UART_receiver(
  input wire rst, clk, tick_x16, rx,
  output reg rx_ready, 
  output reg [7:0] rx_data
);
  reg rx_sync;
  reg [2:0] count_rx;
  reg [3:0] count_sample; // 0-15
  reg [7:0] shift_reg;
  typedef enum logic[1:0] {IDLE, START, DATA, STOP} state_t;
  state_t state;

  always @(posedge clk) rx_sync <= rx; // Синхронизатор

  always @(posedge clk or negedge rst) begin
    if(!rst) begin
      state <= IDLE; rx_ready <= 0; rx_data <= 0; count_sample <= 0;
    end else begin
      if(tick_x16) begin
        case(state)
          IDLE: begin
            rx_ready <= 0;
            if(rx_sync == 0) begin
              state <= START;
              count_sample <= 0;
            end
          end
          START: begin
            if(count_sample == 7) begin
              if(rx_sync == 0) begin
                state <= DATA;
                count_sample <= 0;
                count_rx <= 0;
              end else state <= IDLE; // Ложный старт
            end else count_sample <= count_sample + 1;
          end
          DATA: begin
            if(count_sample == 15) begin // Середина информационного бита
              shift_reg[count_rx] <= rx_sync;
              count_sample <= 0;
              if(count_rx == 7) state <= STOP;
              else count_rx <= count_rx + 1;
            end else count_sample <= count_sample + 1;
          end
          STOP: begin
            if(count_sample == 15) begin
              if(rx_sync == 1) begin // Проверка стоп-бита
                rx_data <= shift_reg;
                rx_ready <= 1;
              end
              state <= IDLE;
            end else count_sample <= count_sample + 1;
          end
        endcase
      end
    end
  end
endmodule
