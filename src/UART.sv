module UART(
  input wire rst, clk, tick_x16, rx, tick_9600, tx_start,
  input wire[7:0] tx_data, output wire[7:0] rx_data,
  output wire rx_ready, tx, tx_busy
);
  //Инстанцирование приёмника
  UART_receiver uart_rx_inst (
       .rst      (rst),
       .clk      (clk),
       .tick_x16 (tick_x16),
       .rx       (rx),
       .rx_ready (rx_ready),
       .rx_data  (rx_data)
  );
  // Инстанцирование передатчика
  UART_transmitter uart_tx_inst (
        .rst        (rst),
        .clk        (clk),
        .tick_9600  (tick_9600),
        .tx_start   (tx_start),
        .tx_data    (tx_data),
        .tx         (tx),
        .tx_busy    (tx_busy)
   );

endmodule
