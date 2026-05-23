module DMA_engine(
  input wire start, clk, rst,
  input wire[7:0] length, start_addr, //Длина блока и адрес начала блока для чтения
  input wire[7:0] dest_addr, //Начало блока для записи
  input wire[7:0] data_b_out, //Данные от RAM
  output reg we_b, //Сигнал чтения/записи для RAM
  output reg[7:0] addr_b, //Указатель для чтения
  output reg[7:0] data_b_in, //Данные для записи в RAM
  output reg busy, //Сигнал занятости
  output reg error_sgn //Сигнал ошибки
);
  reg[7:0] save_length, save_start_addr; //Регистры для сохранения длины команд
  reg[7:0] save_dest_adrr;
  reg[7:0] save_data;
  wire error; //Проверка четности
  typedef enum logic[2:0]{IDLE, FETCH, READ, WRITE, INC} state_t; //Состояния FSM
  state_t state; //Состояния
  //Проверка четности
  always_comb begin
    error = ^data_b_out;
  end
  //FSM
  always&(posedge clk or negedge rst) begin
    if(!rst) begin
      state <= IDLE; we_b <= 0; busy <= 0; addr_b <= 0; error <= 0; error_sgn <= 0;
    end else begin
    	case(state)
      	IDLE: begin
          	we_b <= 0;
        	if(start) begin
              	error <= 0;
              	error_sgn <= 0;
          		//Сохраняем значения адресов и длин
          		save_length <= length;
          		save_start_addr <= start_addr; save_dest_adrr <= dest_adrr;
          		state <= FETCH;
            	busy <= 1; //Сигнал занятости
        	end else begin
             	busy <= 0;
            end
      	end
      	FETCH: begin
        	we_b <= 0; //Сигнал чтения
        	addr_b <= save_start_addr; //Подаем адрес начала блока данных
        	state <= READ;
      	end
      	READ: begin
        	save_data <= data_b_out;
          	if(!error) state <= WRITE;
          	else begin
              state <= IDLE; error_sgn <= 1;
            end
      	end
      	WRITE: begin
        	we_b <= 1; //Сигнал записи для RAM
        	addr_b <= save_dest_adrr; //Адрес для записи
        	data_b_in <= save_data; //Перекладываем данные
        	state <= INC;
      	end
      	INC: begin
        	//Уменьшаем количество отправляемых команд
        	save_length <= save_length - 1;
        	//Инкремент счетчиков
        	save_start_addr <= save_start_addr + 1;
        	save_dest_adrr <= save_dest_adrr + 1;
        	if(length > 1) begin
          		state <= FETCH;
        	end else begin
          		state <= IDLE;
        	end
      	end
    	endcase
    end
  end
endmodule
