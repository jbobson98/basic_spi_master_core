/*  ------------------------------------------------
    Module:       spi_master
    Developer:    Jacob Bobson
    Date Created: 8/19/2024
    ------------------------------------------------
    Description:
    Basic SPI master that can support 8 slave devices (this can be expanded) and
    all SPI modes (0-3). The SPI frequency can be controlled by adjusting the 
    CLOCKS_PER_SPI_BIT parameter (see comments). The module also supports configuration
    options such as LSB/MSB-first selection and CS polarity selection.
*/
`timescale 1ns / 1ps

module spi_master #(
    parameter CLOCKS_PER_SPI_BIT     = 4,       // 100MHz i_clk -> 25MHz spi_clk
    parameter SPI_CS_INACTIVE_CLOCKS = 4       // Number of clocks required between transactions (slave specific)
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
        Mode_0 [00]: Clock Idle Plarity = Logic Low (leading edge = rising)
                     Data Sampled       = rising edge of sclk 
                     Data Shifted Out   = falling edge of sclk
        Mode_1 [01]: Clock Idle Plarity = Logic Low (leading edge = rising)
                     Data Sampled       = falling edge of sclk
                     Data Shifted Out   = rising edge of sclk 
        Mode_2 [10]: Clock Idle Plarity = Logic High (leading edge = falling)
                     Data Sampled       = falling edge of sclk
                     Data Shifted Out   = rising edge of sclk
        Mode_3 [11]: Clock Idle Plarity = Logic High (leading edge = falling)
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
always @(posedge i_clk) begin  // config regs are not cleared by a global reset
    if(i_config_slave && o_tx_ready) begin
        config_regs[i_slave_select] <= i_config_data;
    end
end

/* Register inputs when i_tx_data_valid pulsed */
reg [7:0] r_tx_data_byte   = 8'b00000000;
reg [2:0] r_slave_selected = 3'b000;
always @(posedge i_clk) begin // global reset not necessary here
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

/* State Machine States/Regs */
localparam IDLE     = 2'b00;
localparam INACTIVE = 2'b01;
localparam TX       = 2'b10;
reg [1:0] state     = IDLE;

/* Generate SPI Clock */
reg [$clog2(CLOCKS_PER_SPI_BIT)-1:0] r_clk_cnt = 0;
reg [4:0] r_byte_edges = 0;
reg r_leading_edge     = 1'b0;
reg r_trailing_edge    = 1'b0;
reg r_spi_clock_start  = 1'b0; // single clk pulse controlled by state machine
reg r_spi_clk          = 1'b0;
reg r_spi_clk_running   = 1'b0;
always @(posedge i_clk or posedge i_rst) begin
    if(i_rst) begin
        r_byte_edges     <= 0;
        r_clk_cnt        <= 0;
        r_leading_edge   <= 1'b0;
        r_trailing_edge  <= 1'b0;
        r_spi_clk        <= 1'b0;
        r_spi_clk_running <= 1'b0;
    end else begin
        r_leading_edge   <= 1'b0;
        r_trailing_edge  <= 1'b0;
        r_spi_clk_running <= 1'b0;
        if(r_spi_clock_start) begin
            r_byte_edges      <= 16; // total clock edges per byte = 16 (2 per bit)
            r_spi_clk         <= cpol;
            r_spi_clk_running <= 1'b1;
        end else if(r_byte_edges > 0) begin
            r_spi_clk_running <= 1'b1;
            if(r_clk_cnt == CLOCKS_PER_SPI_BIT-1) begin
                r_byte_edges     <= r_byte_edges - 1;
                r_trailing_edge  <= 1'b1;
                r_clk_cnt        <= 0;
                r_spi_clk        <= ~r_spi_clk;
            end else if(r_clk_cnt == CLOCKS_PER_SPI_BIT/2-1) begin
                r_byte_edges    <= r_byte_edges - 1;
                r_leading_edge  <= 1'b1;
                r_clk_cnt       <= r_clk_cnt + 1;
                r_spi_clk       <= ~r_spi_clk;
            end else begin
                r_clk_cnt <= r_clk_cnt + 1;
            end
        end
    end
end


/* State Machine */
reg [$clog2(SPI_CS_INACTIVE_CLOCKS+1)-1:0] r_inactive_cnt = 0;
reg [2:0] r_tx_bit_cnt = 0;
reg [2:0] r_rx_bit_cnt = 0;
always @(posedge i_clk or posedge i_rst) begin
    if(i_rst) begin
        state             <= IDLE;
        r_inactive_cnt    <= 0;
        r_spi_clock_start <= 1'b0;
        r_tx_bit_cnt      <= 0;
        r_rx_bit_cnt      <= 0;
        o_rx_data_valid   <= 1'b0;
        o_rx_data_byte    <= 8'b00000000;
        o_spi_mosi        <= 8'b00000000;
    end else begin
        case(state)

            IDLE: begin
                o_rx_data_valid <= 1'b0;
                o_spi_mosi <= 8'b00000000;
                if(i_tx_data_valid && o_tx_ready) begin
                    state <= INACTIVE;
                    r_inactive_cnt <= r_inactive_cnt + 1;
                end
            end

            INACTIVE: begin
                r_inactive_cnt <= r_inactive_cnt + 1;
                if(r_inactive_cnt == SPI_CS_INACTIVE_CLOCKS) begin
                    state <= TX;
                    r_spi_clock_start <= 1'b1;
                    r_inactive_cnt <= 0;
                    if(lsb_first) begin
                        o_spi_mosi[r_slave_selected] <= r_tx_data_byte[0];
                        r_tx_bit_cnt <= 1;
                        r_rx_bit_cnt <= 0;
                    end else begin
                        o_spi_mosi[r_slave_selected] <= r_tx_data_byte[7];
                        r_tx_bit_cnt <= 6;
                        r_rx_bit_cnt <= 7;
                    end
                end
            end

            TX: begin
                r_spi_clock_start <= 1'b0;
                if(~r_spi_clk_running && ~r_spi_clock_start) begin
                    state <= IDLE;
                    o_rx_data_valid <= 1'b1;
                end

                if((r_leading_edge && cpha) || (r_trailing_edge && ~cpha)) begin
                    o_spi_mosi[r_slave_selected] <= r_tx_data_byte[r_tx_bit_cnt];
                    if(lsb_first) begin
                        r_tx_bit_cnt <= r_tx_bit_cnt + 1;
                        r_rx_bit_cnt <= r_rx_bit_cnt + 1;
                    end else begin
                        r_tx_bit_cnt <= r_tx_bit_cnt - 1;
                        r_rx_bit_cnt <= r_rx_bit_cnt - 1;
                    end
                end else if((r_leading_edge && ~cpha) || (r_trailing_edge && cpha)) begin
                    o_rx_data_byte[r_rx_bit_cnt] <= i_spi_miso[r_slave_selected];
                end
            end

            default: state <= IDLE;
        endcase
    end
end


/* Handle SPI Outputs */
always @(*) begin
    o_spi_cs   = {~config_regs[7][0], ~config_regs[6][0], ~config_regs[5][0], ~config_regs[4][0], 
                  ~config_regs[3][0], ~config_regs[2][0], ~config_regs[1][0], ~config_regs[0][0]};
    o_spi_sclk = config_regs[i_slave_select][3];
    o_tx_ready =  1'b1;

    if(state == TX) begin
        o_spi_cs[r_slave_selected] = cs_pol;
        o_spi_sclk = r_spi_clk;
        o_tx_ready =  1'b0;
    end else if(state == INACTIVE) begin
        o_spi_sclk = cpol;
        o_tx_ready =  1'b0;
    end
end


endmodule