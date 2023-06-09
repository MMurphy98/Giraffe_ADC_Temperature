module Giraffe_ADC #(
    // Parameters for UART
    parameter UART_BAUDRATE = 256000,            // Maximum: 256000
    parameter UART_FREQ = 50_000_000,
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
    // input                   calib_ena_FPGA,
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

// ****************** Clock Buffer of the whole system ******************
    PLL_50M Inst_PLL (
        .areset                 (~nrst),
        .locked                 (sys_locked)
        .inclk0                 (clk_50M),
        .c0                     (clk_adc),      // 50MHz
        .c1					    (clk_uart)      // 50MHz
    );


// ****************** Build communication with PC ******************
    uart_tx #(
        .BAUDRATE               (UART_BAUDRATE), 
        .FREQ                   (UART_FREQ), 
        .N_start                (UART_NUM_START), 
        .N_data                 (UART_NUM_DATA), 
        .N_stop                 (UART_NUM_STOP)) 
	u_uart_tx (
        .clk                    (clk_uart),
        .nrst                   (nrst),
        .wreq	                (uart_wreq),
        .tx		                (tx2M),
        .wdata	                (uart_wdata),
        .rdy                    (uart_rdy)
    );

    uart_rx #(
		.BAUDRATE               (UART_BAUDRATE), 
		.FREQ                   (UART_FREQ), 
		.N_start                (UART_NUM_START), 
		.N_data                 (UART_NUM_DATA), 
		.N_stop                 (UART_NUM_STOP))
	Inst_uart_rx (
        .clk                    (clk_uart),
        .nrst                   (nrst),
        .rx                     (rxfM),
        .rdata                  (rdata),
        .vld	                (vld)           
        // reset whole A/D system via UART host;
    );

// ****************** FSM controlled of the whole system ******************
    Giraffe_ADC_FSM #(

    )
    Inst_Giraffe_ADC_FSM (
        
    );

endmodule