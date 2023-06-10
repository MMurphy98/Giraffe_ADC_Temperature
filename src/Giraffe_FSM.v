module Giraffe_FSM #(
    parameter   NUM_bit = 6,
    parameter   NUM_Sampled = 102400,
    parameter   NUM_Calibration = 1000,
    parameter   UART_NUM_DATA = 8,
    parameter   UART_BAUDRATE = 256000,
    parameter   UART_FREQ = 50_000_000,
    parameter   CMDLENGTH = 4
) 
(
    // signals from FPGA
    input                           clk,
    input                           nrst,
    input                           pll_locked,
    input   [8:0]                   sw_NOWA,

    // LED Display for system status
    output  [17:0]                  LED_cnt_received,
    output  [3:0]                   LED_state,
    output  [3:0]                   LED_out,

    //  communicating with chip
    output                          adc_rstn,
    output                          adc_calib_ena,
    output                          adc_ena,
    output  [8:0]                   adc_NOWA,
    input                           adc_ack,
    input                           adc_ack_sub,
    input   [NUM_bit-1:0]           adc_dout,

    //  communicating with UART
    input   [UART_NUM_DATA-1:0]     uart_rdata,
    input                           uart_vld,
    output  [UART_NUM_DATA-1:0]     uart_wdata,
    output                          uart_wreq,
    input                           uart_rdy
);
// ********************* Parameter Declaration *********************
    localparam memory_deepth = NUM_Sampled*4;
    localparam uart_period = UART_FREQ / UART_BAUDRATE;

// ********************* Wire Declaration *********************
    wire                        adc_trigger;
    wire                        uart_rx_done;
    wire    [CMDLENGTH-1:0]     uart_rx_cmdout;
// ********************* Registor Declaration *********************
    // Counters
    reg [31:0]  cnt_adc_ena, cnt_received;
    reg [31:0]  cnt_uart_send;
    
    // Output Reg
    reg adc_rstn_reg, adc_calib_ena_reg, adc_ena_reg;
    reg [8:0]   adc_NOWA_reg;
    reg [UART_NUM_DATA-1:0] uart_wdata_reg;
    reg uart_wreq_reg;        

    // Assign reg Onchip_Memory as M9K block memory 
	(* regstyle = "M9K" *) reg [NUM_bit-1:0] Onchip_Memory [memory_deepth-1:0];



    uart_rx_decoder #(
        .UART_NUM_DATA      (UART_NUM_DATA),
        .CMDLENGTH          (CMDLENGTH)
    )
    Inst_uart_rx_decoder (
        .clk                (clk),
        .nrst               (nrst),
        .sys_locked         (pll_locked),
        .uart_rdata         (uart_rdata),
        .uart_vld           (uart_vld),
        .cmdout             (uart_rx_cmdout)
    );

// ********************* Trigger Settup *********************
    RiseEdgeTrigger Inst_RiseEdgeTrigger (
        .clk        (clk),
        .nrst       (nrst),
        .locked     (pll_locked),
        .tin        ((adc_ack | adc_ack_sub)),
        .tout       (adc_trigger)
    );

    FallEdgeTrigger Inst_FallEdgeTrigger (
        .clk        (clk),
        .nrst       (nrst),
        .locked     (pll_locked),
        .tin        (uart_vld),
        .tout       (uart_rx_done)
    );

// ********************* FSM Settup *********************
    reg [3:0]   cs, ns;
    
    parameter   IDLE    =   4'd0;
    parameter   WAIT    =   4'd1;
    // parameter   

    always @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            cs <= IDLE;
        end 
//        else if (vld) begin
//            cs <= IDLE;
//        end 
        else if (clk) begin
            cs <= ns;
        end
    end

// ********************* Output Assigments *********************
    //  LED Display assignments  //FIXME
    assign  LED_cnt_received    =   cnt_received;
    assign  LED_state           =   cs;
    assign  LED_out             =   {leds_reset, leds_uart, leds_received, leds_ena};  
    
    //  communicating with chip
    assign  adc_rstn            =   adc_rstn_reg;
    assign  adc_calib_ena       =   adc_calib_ena_reg;
    assign  adc_ena             =   adc_ena_reg;
    assign  adc_NOWA            =   adc_NOWA_reg;

    //  communicating with UART
    assign  uart_wdata          =   uart_wdata_reg;
    assign  uart_wreq           =   uart_wreq_reg;

endmodule