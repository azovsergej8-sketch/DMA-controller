interface uart_if(input logic clk);
    logic rst;
    logic rx;
    logic tx;
    logic [2:0] current_state; 
endinterface
// 1. Класс транзакции — описывает команду
class uart_transaction;
    rand bit [7:0] opcode;
    rand bit [7:0] addr;
    rand bit [7:0] data;
    bit [7:0] expected_ack;

    function void display(string name);
        $display("[%s] Op: 0x%h | Addr: 0x%h | Data: 0x%h", name, opcode, addr, data);
    endfunction
endclass

// 2. Драйвер — переводит транзакцию в биты UART
class uart_driver;
    virtual uart_if vif;
    real bit_time = 104166; // Для 9600 бод при частоте по умолчанию

    function new(virtual uart_if vif);
        this.vif = vif;
    endfunction

    task send_byte(bit [7:0] byte_to_send);
        vif.rx = 0; // Start bit
        #(bit_time);
        for (int i = 0; i < 8; i++) begin
            vif.rx = byte_to_send[i];
            #(bit_time);
        end
        vif.rx = 1; // Stop bit
        #(bit_time);
    endtask

    task drive(uart_transaction tr);
        $display("[Driver] Sending Command...");
        send_byte(tr.opcode);
        if (tr.opcode == 8'hA1 || tr.opcode == 8'hA2) begin
            send_byte(tr.addr);
            if (tr.opcode == 8'hA1) send_byte(tr.data);
        end
    endtask
endclass

// 3. Монитор — захватывает ответы от DUT
class uart_monitor;
    virtual uart_if vif;
    real bit_time = 104166.0;

    function new(virtual uart_if vif);
        this.vif = vif;
    endfunction

    task monitor_tx(output bit [7:0] received_data);
        @(negedge vif.tx); // Ждем start bit
        #(bit_time * 1.5); // Смещаемся на середину первого бита данных
        for (int i = 0; i < 8; i++) begin
            received_data[i] = vif.tx;
            #(bit_time);
        end
        $display("[Monitor] Captured Response: 0x%h", received_data);
    endtask
endclass
class environment;
    uart_driver drv;
    uart_monitor mon;
    virtual uart_if vif;

    function new(virtual uart_if vif);
        this.vif = vif;
        drv = new(vif);
        mon = new(vif);
    endfunction

    task run_test();
        uart_transaction tr;
        bit [7:0] resp;

        // Тест 1: Прямая запись (DIRECT_WRITE)
        tr = new();
        tr.opcode = 8'hA1; tr.addr = 8'h10; tr.data = 8'h55;
        tr.display("TEST_WRITE");
        
        fork
            drv.drive(tr);
            mon.monitor_tx(resp);
        join
        
        if (resp == 8'h01) $display("SUCCESS: Write ACK received[cite: 1]");
        else $error("ERROR: Expected 0x01, got 0x%h", resp);

        #1000000;

        // Тест 2: Прямое чтение (DIRECT_READ)[cite: 1]
        tr = new();
        tr.opcode = 8'hA2; tr.addr = 8'h10;
        tr.display("TEST_READ");

        fork
            drv.drive(tr);
            mon.monitor_tx(resp);
        join

        if (resp == 8'h55) $display("SUCCESS: Data matches written value!");
        else $error("ERROR: Data mismatch! Expected 0x55, got 0x%h", resp);
    endtask
endclass
module tb_top_module_advanced();
    reg clk;
    uart_if _if(clk);
    environment env;

    // DUT[cite: 1]
    top_module #( .CLK_FREQ(50000000) ) dut (
        .clk(clk),
        .rst(_if.rst),
        .rx(_if.rx),
        .tx(_if.tx)
    );

    // Привязка внутреннего состояния для удобства отладки
    assign _if.current_state = dut.state;

    initial clk = 0;
    always #10 clk = ~clk;

    initial begin
        _if.rst = 0;
        _if.rx = 1;
        #200 _if.rst = 1;

        env = new(_if);
        $display("--- Starting Advanced OOP Testbench ---");
        env.run_test();
        
        $display("--- Testbench Finished ---");
        $finish;
    end
endmodule
