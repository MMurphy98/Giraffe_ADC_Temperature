module Giraffe #(
    // Parameters for UART
    parameter UART_BAUDRATE = 256000,            // Maximum: 256000
    parameter UART_FREQ = 50_000_000,
    parameter UART_NUM_START = 1,
    parameter UART_NUM_DATA = 8,
    parameter UART_NUM_STOP = 1,
    
    // Number of Sub-ADC bit
    parameter NUM_bit = 6,

    // Number of Sampled Points
    parameter NUM_Sampled = 102400,
    parameter NUM_Calibration = 1000
)
(
    //  FPGA Board
    input                   clk_50M,
    input                   nrst,
    // input                   calib_ena_FPGA,
    input  [8:0]            sw_NOWA,

//    input                   system_ena,
    output	[3:0]	        LED_out,
    output [17:0]           LED_cnt_adc_received,
    output [3:0]            LED_state,

    // UART TX
    output                  tx2M,
	input					rxfM,
	 
    // Control the ADC
    output                  adc_rstn,
    output                  clk_adc,
    output                  adc_calib_ena,
	output				    adc_ena,
    output  [8:0]           adc_NOWA,
    input                   adc_ack,
    input                   adc_ack_sub,
    input   [NUM_bit-1:0]   adc_dout,

    // To caparray
    output                  cap_rstn,
	 
	 // SW for random clock
	 input	                sw_or,
	 input	                sw_and
);

	wire sys_locked;
	wire clk_uart;
	wire uart_wreq, uart_rdy;
	wire [UART_NUM_DATA-1:0] uart_wdata, uart_rdata;

    wire clk_adc_nand;
    wire clk_adc_pll;
	 
	
	
// ****************** Clock Buffer of the whole system ******************
    PLL_50M Inst_PLL (
        .areset                 (~nrst),
        .locked                 (sys_locked),
        .inclk0                 (clk_50M),
        .c0                     (clk_adc_pll),      // 50MHz
        .c1					    (clk_uart)      // 50MHz
    );
	assign clk_adc = clk_50M;

// ****************** Build communication with PC ******************
    uart_tx #(
        .BAUDRATE               (UART_BAUDRATE), 
        .FREQ                   (UART_FREQ), 
        .N_start                (UART_NUM_START), 
        .N_data                 (UART_NUM_DATA), 
        .N_stop                 (UART_NUM_STOP)
    ) 
	u_uart_tx (
        .clk                    (clk_uart),
        .nrst                   (nrst),
        .tx		                (tx2M),
        .wreq	                (uart_wreq),
        .wdata	                (uart_wdata),
        .rdy                    (uart_rdy)
    );

    // reset whole ADC system via rdata
    uart_rx #(
		.BAUDRATE               (UART_BAUDRATE), 
		.FREQ                   (UART_FREQ), 
		.N_start                (UART_NUM_START), 
		.N_data                 (UART_NUM_DATA), 
		.N_stop                 (UART_NUM_STOP)
    )
	Inst_uart_rx (
        .clk                    (clk_uart),
        .nrst                   (nrst),
        .rx                     (rxfM),
        .rdata                  (uart_rdata),
        .vld	                (uart_vld)           
    );

// ****************** FSM controlled of the whole system ******************
    Giraffe_FSM #(
        .NUM_bit                (NUM_bit),
        .NUM_Sampled            (NUM_Sampled),
        .NUM_Calibration        (NUM_Calibration),
        .UART_NUM_DATA          (UART_NUM_DATA),
        .UART_BAUDRATE          (UART_BAUDRATE),
        .UART_FREQ              (UART_FREQ)
    )
    Inst_Giraffe_FSM (
        // signals from FPGA
        .clk                    (clk_adc),
        .nrst                   (nrst),
        .pll_locked             (sys_locked),
        .sw_NOWA                (sw_NOWA),
        
        // LED Display for system status
        .LED_cnt_adc_received   (LED_cnt_adc_received),
        .LED_state              (LED_state),
        .LED_out                (LED_out),

        //  communicating with chip
        .adc_rstn               (adc_rstn),
        .adc_calib_ena          (adc_calib_ena),
        .adc_ena                (adc_ena),
        .adc_NOWA               (adc_NOWA),
        .adc_ack                (adc_ack),
        .adc_ack_sub            (adc_ack_sub),
        .adc_dout               (adc_dout),

        //  communicating with UART
        .uart_rdata             (uart_rdata),
        .uart_vld               (uart_vld),
        .uart_wdata             (uart_wdata),
        .uart_wreq              (uart_wreq),
        .uart_rdy               (uart_rdy)
    );
    assign cap_rstn = adc_rstn;


    // nand(clk_adc_nand, clk_adc_pll, sw_and);
    // nor(clk_adc, clk_adc_nand, sw_or);
//    assign clk_adc_nand = ~(clk_adc_pll & sw_and);
//    assign clk_adc = ~ (clk_adc_nand | sw_or);

endmodule