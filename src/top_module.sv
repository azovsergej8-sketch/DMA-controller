module top_module(
  parameter CLK_FREQ = 50000000
)(
  input wire clk, rst, rx,
  output reg tx
);
  //Соединения генератора тиков
  wire tick_9600, tick_x16, tick_1MHz; //Строб сигналы
  
  //Инстанцирование драйвера тиков
  clk_divider #(
    .CLK_FREQ  (CLK_FREQ)
  )clk_driver(
    .clk       (clk),
    .rst       (rst),
    .tick_9600 (tick_9600),
    .tick_x16  (tick_x16),
    .tick_1MHz (tick_1MHz)
  );
    
  );
  //Соединения UART
  reg tx_start;        
  reg[7:0] tx_data_UART;    
  wire rx_ready;        
  wire tx_busy;         
  wire[7:0] rx_data_UART;    

  //Инстанцирование UART
  UART uart_unit (
    .rst       (rst),           
    .clk       (clk),          
    .tick_x16  (tick_x16),      
    .tick_9600 (tick_9600),    
    .rx        (rx),   
    .tx        (tx),   
    .tx_start  (tx_start),      
    .tx_data   (tx_data_UART),  
    .rx_data   (rx_data_UART),  
    .rx_ready  (rx_ready),       
    .tx_busy   (tx_busy)         
  );
  
  //Соединения Register_File
  wire[7:0] length, dest_addr, start_addr; //Адреса записи/чтения и длина блока данных
  wire start_DMA; //Сигнал старта для DMA
  
  //Инстанцирование Register_File
  Register_File register_file(
    .clk        (clk),
    .tick_x16   (tick_x16),
    .rst        (rst),
    .rx_ready   (rx_ready),
    .rx         (rx_data_UART),
    .length     (length),
    .dest_addr  (dest_addr),
    .start_addr (start_addr),
    .start      (start_DMA)
  );
  
  //Соединения DMA_Engine
  wire DMA_busy, error_sgn; //Сигнал ошибки, cигнал занятости
  wire[7:0] data_b_in; //Данные для записи в RAM
  wire we_b; //Сигнал чтения/записи для RAM
  wire[7:0] addr_b; //Указатель для чтения
  wire[7:0] data_b_out; //Данные от RAM
  
  //Инстанцирование DMA_Engine
  DMA_engine DMA(
    .start      (start_DMA),
    .clk        (clk),
    .rst        (rst),
    .length     (length),
    .start_addr (start_addr),
    .dest_addr  (dest_addr),
    .data_b_out (data_b_out),
    .we_b       (we_b),
    .addr_b     (addr_b),
    .data_b_in  (data_b_in),
    .busy       (DMA_busy),
    .error_sgn  (error_sgn)
  );
  
  //Инстанцирование Dual-Port_RAM
  reg[7:0] addr_a; //Указатель для прямой записи
  reg[7:0] data_a_in; //Данные для прямой записи
  reg we_a, we_a_r; //Сигналы разрешения записи/чтения
  reg[7:0] data_a_out; //Данные, полученные при прямом чтении
  Dual-Port_RAM dual-port_RAM(
    .clk        (clk),
    .addr_a     (addr_a),
    .addr_b     (addr_b),
    .we_a       (we_a),
    .we_b       (we_b),
    .data_a_in  (data_a_in),
    .data_b_out (data_b_out),
    .data_a_out (data_a_out)
  );
  
  //Состояния FSM - команда, прямой доступ к памяти, DMA и отправка ответного сигнала
  typedef enum logic[2:0]{COMMAND, DATA, DMA, ASK, REALISE} state_t;
  state_t state;
  
  //Регистры и флаги
  reg[7:0] ask; //Ответ для внешнего устройства
  reg[7:0] command; //Команда
  reg need_data; //Флаг необходимости команды
  reg is_start; //Флаг начала работы DMA
  reg is_end; //Флаг завершения работы DMA
  
  //Получение спада DMA_busy
  wire DMA_busy_edge; //Спад
  reg DMA_busy_prev; //Предыдущее состояние
  always@(posedge clk) DMA_busy_prev <= DMA_busy;
  assign DMA_busy_edge = (DMA_busy == 0 && DMA_busy_prev == 1); //Детектируем спад
  
  //FSM
  always@(posedge clk or negedge rst) begin
    if(!rst) begin
      state <= COMMAND; we_a <= 0; we_a_r <= 0; data_a_out <= 0; data_a_in <= 0; addr_a <= 0; start_rf <= 0;
      command <= 0; is_end <= 0; is_start <= 0; DMA_busy_prev <= 0; ask <= 0; need_data <= 0; tx_start <= 0;
    end else begin
        case(state)
          COMMAND: begin
            if(rx_ready) begin
             if(!DMA_busy) begin
              //Читаем значение команды
              command <= rx_data_UART;
              case(rx_data_UART)
              //Команда прямой записи в память
              8'hA1: begin
                state <= DATA;
              end
              //Команда прямого чтения из памяти
              8'hA2: begin
                state <= DATA;
              end
              //Команда передачи длины блока
              8'hD1: begin
            	state <= DMA;
              end
              //Команда передачи адреса чтения
              8'hD2: begin
            	state <= DMA;
              end
              //Команда передачи адреса записи
              8'hD3: begin
            	state <= DMA;
              end
              //Команда старта DMA
              8'hD0: begin
            	state <= DMA;
              end
              default: begin
                state <= ASK; ask <= 8'hE0; //Неизвестная команда
              end
             endcase
             end else begin
              state <= ASK; ask <= 8'hE2; //Если DMA занят - переходим в состояние ASK и отправляем сигнал занятости
             end
            end
          end
          DATA: begin
            if(rx_ready) begin
             case(command)
              //Команда прямой записи в память
              8'hA1: begin
                if(need_data) begin
                  data_a_in <= rx_data_UART;
                  need_data <= 0;
                  we_a <= 1;
              	  state <= REALISE;
                end else begin
                  addr_a <= rx_data_UART;
                  need_data <= 1;
                  state <= DATA;
                end
              end
              //Команда прямого чтения из памяти
              8'hA2: begin
                //Читаем значение указателя
                we_a_r <= 1; addr_a <= rx_data_UART;
              	state <= REALISE;
              end
             endcase
            end
          end
          //Состояние для команд прямого доступа к памяти
          REALISE: begin
            we_a <= 0; we_a_r <= 0;
            if(command == 8'hA2) ask <= data_a_out;
            else ask <= 8'h01; //Успешная отправка
            state <= ASK;
          end
          DMA: begin
            //Детектируем спад
            if(DMA_busy_edge) is_end <= 1;
            //Детектируем начало работы
            if(start_DMA) is_start <= 1;
            //Если DMA выдал ошибку
            if(error_sgn) ask <= 8'hE1;
            if(is_end && is_start) begin
              state <= ASK;
              is_end <= 0; is_start <= 0;
              if(ask == 0) ask <= 8'h02; //Успешная работа DMA
            end
          end
          ASK: begin
            if(!tx_busy) begin
              tx_data_UART <= ask;
              ask <= 0;
              command <= 0;
              tx_start <= 1;
              state <= START;
            end
          end
    	endcase
    end
  end 
endmodule
