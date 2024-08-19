/*
    Notes:
        - Idle  = CS high
        - Start = CS pulled low
        - Stop  = CS pulled high
    
    Modes [Clock_Polarity, Clock_Phase]:
    
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


    - need to detect leading and trailing edge for clock
    - input clock should be at least 2x faster than SPI clock
    - each CS line should have a coresponding mode register to configure the mode for that slave device

    SPECS:
        - support 8 slave devices (with configuration registers)

    PARAMETERS:
        - SPI CLOCK frequency (8Mhz by default?)


    CLKS_PER_HALF_BIT - Sets frequency of o_SPI_Clk.  o_SPI_Clk is
                        derived from i_Clk.  Set to integer number of clocks for each
                        half-bit of SPI data.  E.g. 100 MHz i_Clk, CLKS_PER_HALF_BIT = 2
                        would create o_SPI_CLK of 25 MHz.  Must be >= 2
*/


/*
    Slave Configuration Register(s):
        Setting:  [SPI_Mode] [MSB/LSB_First] [CS_Polarity]
        Bits:         2             1              1
*/





module spi_master (

    /* Basic Inputs */
    input wire      i_clk,
    input wire      i_rst,

    /* Configuration Inputs */
    input wire      i_config_slave,        // Pulse to set the configuration registers for a specific slave device
    input reg[2:0]  i_slave_select,        // Slave to be configured or TX/RX (slaves 0-7)
    input reg[3:0]  i_config_data,

    /* TX Inputs and Outputs (MOSI) */
    input wire      i_tx_data_valid,      // Pulse to begin transaction or notify that next byte is ready
    input reg[7:0]  i_tx_data_byte,
    output reg      o_tx_ready,           // Ready for next byte to transmit

    /* RX Inputs and Outputs (MISO) */
    output reg      o_rx_data_valid,
    output reg[7:0] o_rx_data_byte,

    /* SPI Inputs and Outputs */
    output reg      o_spi_sclk,
    output reg[7:0] o_spi_mosi,
    input reg[7:0]  i_spi_miso
);









endmodule
