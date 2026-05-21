//Интерфейс сигналов
interface uart_if(input logic clk, input logic rst);
  //Сигналы к блоку
  logic rx;
  //Сигналы от блока
  logic tx;
  logic rx_ready;
  logic tx_busy;

  //Клокинг-блок монитора
  clocking mon_cb @(posedge clk);
    default input #1step;
    input tx, rx, rx_ready, tx_busy;
  endclocking
  //Модпорт блок монитора
  modport DRV (clocking mon_cb, input clk, input rst);
endinterface

//Тип транзакции
typedef enum bit[1:0]{COMMAND, DATA} data_type;
    
//Регистрация в фабрике UVM
`uvm_object_utils_begin(cpu_transaction)
  `uvm_field_int(data, UVM_ALL_ON)
    `uvm_field_enum(data_type, data_t, UVM_ALL_ON)
  `uvm_field_int(corrupt_parity, UVM_ALL_ON)
  `uvm_field_int(parity, UVM_ALL_ON)
`uvm_object_utils_end
    
//
class transaction extends uvm_sequence_item;
  
  //Поля
  rand bit[7:0] data;
  rand data_type data_t;
  rand bit corrupt_parity; //Флаг необходимости добавления ошибки четности
  bit parity;

  //Конструктор
  function new(string name = "transaction");
    super.new(name);
  endfunction
  
  //Ограничения
  constraint tipe_ct{data_t dist{60 := COMMAND}} 
endclass
