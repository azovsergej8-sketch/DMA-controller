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
  reg[7:0] data_rf;
  reg ready;
  
  //Инстанцирование Register_File
  Register_File register_file(
    .clk        (clk),
    .rst        (rst),
    .ready      (ready),
    .data_rf    (data_rf),
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
    .we_a_r     (we_a_r),
    .data_a_in  (data_a_in),
    .data_b_out (data_b_out),
    .data_a_out (data_a_out)
  );
  
  //Состояния FSM - команда, прямой доступ к памяти, DMA и отправка ответного сигнала
  typedef enum logic[2:0]{START, WRITE, READ, DMA, ASK} state_t;
  state_t state;
  
  //Регистры и флаги
  reg[7:0] ask[]127:0]; //Буфер ответов для аск
  reg[7:0] data[255:0]; //Буфер получаемых данных
  reg[8:0] read_ptr_d, write_ptr_d; //Указатели записи и чтения для буффера данных
  reg[8:0] read_ptr_a, write_ptr_a; //Указатели чтения и записи для буфера аск
  reg is_start; //Флаг начала работы DMA
  reg is_end; //Флаг завершения работы DMA
  wire fifo_is_empty; //Флаг наличия данных в очереди
  wire ask_is_empty; //Флаг наличия данных для ответа
  reg[3:0] count; //Счетчик стадии обработки данных в старт
  reg[8:0] length_cnt; //Длина блока для записи
  reg[7:0] command; //Команда
  reg[8:0] addr; //Адрес
  reg[1:0] st; //Стадия отправки данных для Регистрового файла
  reg[7:0] dest_addr;
  reg parity_count;
  reg is_dest_addr;
  reg[7:0] base_command;
  
  //Получение спада DMA_busy
  wire DMA_busy_edge; //Спад
  reg DMA_busy_prev; //Предыдущее состояние
  always@(posedge clk) DMA_busy_prev <= DMA_busy;
  assign DMA_busy_edge = (DMA_busy == 0 && DMA_busy_prev == 1); //Детектируем спад

  //Проверка очереди на пустоту
  assign fifo_is_empty = (read_ptr_d == write_ptr_d);

  //Проверка буфера ответов на пустоту
  assign ask_is_empty = (read_ptr_a == write_ptr_a);

  
  always@(posedge clk or negedge rst) begin
    if(!rst) begin
      state <= START; we_a <= 0; we_a_r <= 0; addr_a <= 0; data_a_in <= 0; tx_start <= 0; tx_data_UART <= 0; read_ptr_d <= 0; read_ptr_a <= 0;
      write_ptr_a <= 0; count <= 0; st <= 0; ready <= 0; parity_count <= 0; is_dest_addr <= 0; base_command <= 8'h01; command <= 0; addr <= 0; dest_addr <= 0; length <= 0; length_cnt <= 0;
    end else begin
      //Сброс стробов по-умолчанию
      we_a <= 1'b0;
      we_a_r <= 1'b0;
      ready <= 1'b0;
      tx_start <= 1'b0;
      //Получение данных от UART
      if(rx_ready) begin
        data[write_ptr_d] <= rx_data_UART;
        write_ptr_d <= write_ptr_d + 1;
      end
      //FSM
      if(!DMA_is_busy) begin
        case(state)
          START: begin
            if(!fifo_is_empty) begin
              case(count)
                0: begin
                  command <= data[read_ptr_d];
                  read_ptr_d <= read_ptr_d + 1;
                  count <= count + 1;
                end
                1: begin
                  addr <= data[read_ptr_d];
                  read_ptr_d <= read_ptr_d + 1;
                  count <= count + 1;
                end
                2: begin
                  length <= data[read_ptr_d];
                  read_ptr_d <= read_ptr_d + 1;
                  count <= 0;
                  case(command[1:0])
                    2'b01: begin
                      state <= WRITE;
                    end
                    2'b10: begin
                      state <= READ;
                    end
                    2'b11: begin
                      state <= DMA;
                    end
                  endcase
                end
              endcase
            end
          end
          WRITE: begin
            if(!fifo_is_empty) begin
              if(length_cnt != 0) begin
                we_a <= 1;
                addr_a <= addr;
                data_a_in <= data[read_ptr_d];
                length_cnt <= length_cnt - 1;
                read_ptr_d <= read_ptr_d + 1;
              end else begin
                ask[write_ptr_a] <= "8'h02";
                write_ptr_a <= write_ptr_a + 1;
                state <= ASK;
                we_a <= 0;
              end
            end
          end
          READ: begin
            if(length_cnt != 0) begin
              if(!parity_count) begin
                we_a_r <= 1;
                addr_a <= addr;
                parity_count <= 1;
              end else begin
                ask[write_ptr_a] <= data_a_out;
                write_ptr_a <= write_ptr_a + 1;
                length_cnt <= length_cnt - 1;
                parity_count <= 0;
                we_a_r <= 0;
              end
            end
            end else begin
              ask[write_ptr_a] <= "8'h03";
              write_ptr_a <= write_ptr_a + 1;
              state <= ASK;
            end
          end
          DMA: begin
            if(!fifo_is_empty && !is_dest_addr) begin
              dest_addr <= data[read_ptr_d];
              read_ptr_d <= read_ptr_d + 1;
              is_dest_addr <= 1;
            end else if(is_dest_addr) begin
              if(st < 3 && base_command != 8'h04) begin
                if(!parity_count) begin
                  ready <= 1;
                  data_rf <= base_command;
                  parity_count <= 1;
                end else begin
                  case(base_command)
                    8'h01: data_rf <= addr;
                    8'h02: data_rf <= dest_addr;
                    8'h03: data_rf <= length;
                  endcase
                  base_command <= base_command + 1;
                  st <= st + 1;
                  parity_count <= 0;
                end
              end else begin
                data_rf <= base_command;
                base_command <= 8'h01;
                st <= 0;
                ask[write_ptr_a] <= "8'h00";
                write_ptr_a <= write_ptr_a + 1;
                state <= ASK;
                is_dest_addr <= 0; 
              end
            end
          end
          ASK: begin
            if(!tx_busy) begin
              if(DMA_busy_edge) begin
                ask[write_ptr_a] <= 8'h01;
                write_ptr_a <= write_ptr_a + 1;
              end
              tx_data_UART <= ask[read_ptr_a];
              tx_start <= 0;
              read_ptr_a <= read_ptr_a + 1;
            end
            if(ask_is_empty) state <= START;
          end
        endcase
      end
      else begin
        if(error_sgn) begin
          ask[write_ptr_a] <= 8'hE1;
          write_ptr_a <= write_ptr_a + 1;
        end
      end
    end
  end 
endmodule
