module Giraffe_ADC #(
    // Parameters for UART
    parameter BAUDRATE = 256000,            // Maximum: 256000
    parameter FREQ = 50_000_000,
    parameter UART_NUM_START = 1,
    parameter UART_NUM_DATA = 8,
    parameter UART_NUM_STOP = 1,
    
    // Number of Sub-ADC bit
    parameter N_bit = 6,

    // Number of Sampled Points
    parameter NUM_Sampled = 102400
)
(
    //  FPGA Board
    input                   clk_50M,
    input                   nrst,
    input                   calib_ena_FPGA,
    input  [8:0]            sw_NOWA,

//    input                   system_ena,
    output	[3:0]	        LED_out,
    output [17:0]           LED_cnt_send,
    output [3:0]            LED_state,

    // UART TX
    output                  tx2M,
	input					rxfM,
	 
    // Control the ADC
    output                  rstn_adc,
    output                  clk_adc,
	output					clk_ultra,
    output                  calib_ena_adc,
	output				    adc_ena,
    output  [8:0]           NOWA_adc,
    input                   adc_ack,
    input                   adc_ack_sub,
    input   [N_bit-1:0]     dout_adc,

    // To caparray
    output                  cap_rstn
);