/*

    - need to detect leading and trailing edge for clock
    - input clock should be at least 2x faster than SPI clock
    - each CS line should have a coresponding mode register to configure the mode for that slave device

    SPECS:
        - support 8 slave devices (with configuration registers)

    PARAMETERS:
        - SPI CLOCK frequency (8Mhz by default?)

*/
`timescale 1ns / 1ps

module spi_master (
    parameter CLOCKS_PER_SPI_BIT = 4    // 100MHz i_clk -> 25MHz spi_clk
)(

    /* Basic Inputs */
    input wire       i_clk,
    input wire       i_rst,

    /* Configuration Inputs */
    input wire       i_config_slave,    // Pulse to set the configuration registers for a specific slave device
    input wire [2:0] i_slave_select,    // Slave to be configured or TX/RX (slaves 0-7)
    input wire [3:0] i_config_data,

    /* TX Inputs and Outputs (MOSI) */
    input wire       i_tx_data_valid,   // Pulse to begin transaction or notify that next byte is ready
    input wire [7:0] i_tx_data_byte,
    output reg       o_tx_ready,        // Ready for next byte to transmit, low if busy

    /* RX Inputs and Outputs (MISO) */
    output reg       o_rx_data_valid,
    output reg [7:0] o_rx_data_byte,

    /* SPI Inputs and Outputs */
    output reg       o_spi_sclk,
    output reg [7:0] o_spi_cs,
    output reg [7:0] o_spi_mosi,
    input wire [7:0] i_spi_miso
);



/* Slave Configuration Registers:

    Setting:  [SPI_Mode] [MSB/LSB_First] [CS_Polarity]
    Bits:        3:2            1             0

    SPI_MODE: [Clock_Polarity, Clock_Phase]

        Mode_0 [00]: Clock Idle Plarity = Logic Low
                     Data Sampled       = rising edge of sclk
                     Data Shifted Out   = falling edge of sclk

        Mode_1 [01]: Clock Idle Plarity = Logic Low
                     Data Sampled       = falling edge of sclk
                     Data Shifted Out   = rising edge of sclk 

        Mode_2 [10]: Clock Idle Plarity = Logic High
                     Data Sampled       = falling edge of sclk
                     Data Shifted Out   = rising edge of sclk

        Mode_3 [11]: Clock Idle Plarity = Logic High
                     Data Sampled       = rising edge of sclk
                     Data Shifted Out   = falling edge of sclk

    MSB/LSB_FIRST:
        0 = MSB First
        1 = LSB First

    CS_POLARITY:
        0 = CS active low
        1 = CS active high
*/
reg [3:0] config_regs [7:0]; // configs for each slave device
always @(posedge clk) begin  // config regs are not cleared by a global reset
    if(i_config_slave && o_tx_ready) begin
        config_regs[i_slave_select] <= i_config_data;
    end
end

/* Register inputs when i_tx_data_valid pulsed */
reg [7:0] r_tx_data_byte   = 8'b00000000;
reg [2:0] r_slave_selected = 3'b000;
always @(posedge clk) begin // global reset not necessary here
    if(i_tx_data_valid && o_tx_ready) begin
        r_tx_data_byte   <= i_tx_data_byte;
        r_slave_selected <= i_slave_select;
    end
end

/* Configuration for Slave in Active Transaction */
wire cpol, cpha, lsb_first, cs_pol;
assign cpol      = config_regs[r_slave_selected][3]; // spi clock polarity
assign cpha      = config_regs[r_slave_selected][2]; // spi clock phase
assign lsb_first = config_regs[r_slave_selected][1]; // TX/RX byte lsb first
assign cs_pol    = config_regs[r_slave_selected][0]; // CS polarity

/* Generate SPI Clock */
// reg for spi clk cnt







/* Shift Out MOSI Data */
reg [2:0] r_tx_bit_cnt; // keep track of number of bits sent
// reset using o_tx_ready
// on reset, all of o_spi_cs should be assigned ~config_regs[n][0]

always @(posedge i_clk or posedge i_rst) begin


end







/* Shift In MISO Data */
always @(posedge i_clk or posedge i_rst) begin


end











endmodule
