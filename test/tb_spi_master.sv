/* time_unit = 1ns, time_precision = 100ps */
`timescale 1ns / 1ps


module tb_spi_master ();

/* Clock Parameters */
localparam CLOCK_FREQ_HZ = 100_000_000;
localparam CLK_PERIOD_NS = (1_000_000_000 / CLOCK_FREQ_HZ);

/* Test Bench Signals */
integer tb_test_num;

/* DUT Port Signals */
localparam CLOCKS_PER_SPI_BIT = 4;
logic tb_clk, tb_rst;
logic tb_config_slave;
logic [2:0] tb_slave_select;
logic [3:0] tb_config_data;
logic tb_tx_data_valid, tb_tx_ready, tb_rx_data_valid;
logic [7:0] tb_tx_data;
logic [7:0] tb_rx_data;
logic tb_spi_sclk;
logic [7:0] tb_spi_cs, tb_spi_mosi;

/* Instantiate DUT */
spi_master #(
    .CLOCKS_PER_SPI_BIT(CLOCKS_PER_SPI_BIT)
) DUT (
    .i_clk(tb_clk),
    .i_rst(tb_rst),
    .i_config_slave(tb_config_slave),
    .i_slave_select(tb_slave_select),
    .i_config_data(tb_config_data),
    .i_tx_data_valid(tb_tx_data_valid),
    .i_tx_data_byte(tb_tx_data),
    .o_tx_ready(tb_tx_ready),
    .o_rx_data_valid(tb_rx_data_valid),
    .o_rx_data_byte(tb_rx_data),
    .o_spi_sclk(tb_spi_sclk),
    .o_spi_cs(tb_spi_cs),
    .o_spi_mosi(tb_spi_mosi),
    .i_spi_miso(tb_spi_mosi) // loopback
);

/* Generate DUT Clock */
always begin
    tb_clk = 1'b0;
    #(CLK_PERIOD_NS/2.0);
    tb_clk = 1'b1;
    #(CLK_PERIOD_NS/2.0);
end

/* Task: Reset DUT */
task dut_reset;
begin
    tb_rst = 1'b1; // active the reset
    #(CLK_PERIOD_NS*2);
    @(negedge tb_clk);
    tb_rst = 1'b0;
    #(CLK_PERIOD_NS*2);
end
endtask

/* Task: Initialize Inputs (idle) */
task dut_init_inputs;
begin
    tb_rst           = 1'b0;
    tb_config_slave  = 1'b0;
    tb_slave_select  = 0;
    tb_config_data   = 4'b0000;
    tb_tx_data_valid = 1'b0;
    tb_tx_data       = 8'h00;
end
endtask

/* Task: Configure Slave Mode Registers */
task dut_config_slave_regs(input [2:0] slave, input [3:0] config_data);
begin
    @(posedge tb_clk);
    tb_slave_select = slave;
    tb_config_data  = config_data;
    tb_config_slave = 1'b1;
    @(posedge tb_clk);
    tb_config_slave = 1'b0;
end
endtask

/* Task: Transmitt Byte */
task dut_tx_byte(input [2:0] slave, input [7:0] tx_data);
begin
    @(posedge tb_clk);
    tb_slave_select  = slave;
    tb_tx_data       = tx_data;
    tb_tx_data_valid = 1'b1;
    @(posedge tb_clk);
    tb_tx_data_valid = 1'b0;
    @(posedge tb_tx_ready); // wait until tx done
    // Todo: check read data here with asserts
end
endtask


initial begin
    
    /* Init Dut Inputs ---------------------------------------------------------- */
    tb_test_num = 0;
    dut_init_inputs();
    #(CLK_PERIOD_NS*3);

    /* Power-On Reset ----------------------------------------------------------- */
    tb_test_num = 1;
    dut_reset();
    #(CLK_PERIOD_NS*3);

    /* Configure Registers for Slaves 0-3 --------------------------------------- */
    tb_test_num = 2;
    // All Slaves: MSB first, active low CS
    dut_config_slave_regs(0, 4'b0000); // Slave 0: Mode 0
    dut_config_slave_regs(1, 4'b0100); // Slave 1: Mode 1
    dut_config_slave_regs(2, 4'b1000); // Slave 2: Mode 2
    dut_config_slave_regs(3, 4'b1100); // Slave 3: Mode 3

    /* Slave 0 TX --------------------------------------------------------------- */
    tb_test_num = 3;
    dut_tx_byte(0, 8'hCB);
    
    /* Slave 1 TX --------------------------------------------------------------- */
    tb_test_num = 4;
    dut_tx_byte(1, 8'hCB);

    /* Slave 2 TX --------------------------------------------------------------- */
    tb_test_num = 5;
    dut_tx_byte(2, 8'hCB);

    /* Slave 3 TX --------------------------------------------------------------- */
    tb_test_num = 6;
    dut_tx_byte(3, 8'hCB);


    // End Test
    $finish();
end













endmodule