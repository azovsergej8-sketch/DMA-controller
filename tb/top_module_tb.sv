
`timescale 1ns / 1ps

module tb_top_module();
    reg clk, rst, rx;
    wire tx;

    // Инстанцирование
    top_module #( .CLK_FREQ(1000000) ) dut ( 
        .clk(clk), .rst(rst), .rx(rx), .tx(tx)
    );

    // Генерация тактового сигнала (50 МГц)
    always #10 clk = ~clk;

    
    task uart_send(input [7:0] data);
        integer i;
        begin
            rx = 0; // Start bit
            #104166; // Период для 9600 бод
            for (i = 0; i < 8; i = i + 1) begin
                rx = data[i];
                #104166;
            end
            rx = 1; // Stop bit
            #104166;
        end
    endtask

    initial begin
        // Инициализация
        clk = 0; rst = 0; rx = 1;
        #100 rst = 1;
        #200;

        // Тест 1: Прямая запись (A1) -> Адрес (0x05) -> Данные (0xBE)
        uart_send(8'hA1);
        uart_send(8'h05);
        uart_send(8'hBE);

        #500000;

        // Тест 2: Запуск DMA (Команда D0)
        
        uart_send(8'hD0);

        #2000000;
        $display("Simulation finished.");
        $finish;
    end
endmodule
