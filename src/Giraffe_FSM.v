module Giraffe_FSM #(
    parameter   NUM_bit         =   6,
    parameter   NUM_Sampled     =   102400,
    parameter   NUM_Calibration =   10000,
    parameter   UART_NUM_DATA   =   8,
    parameter   UART_BAUDRATE   =   256000,
    parameter   UART_FREQ       =   50_000_000,
    parameter   CMDLENGTH       =   4,
    parameter   RESET_PERIOD    =   1000,
    parameter   UART_PRE_DELAY  =   5_000_000,
    parameter   SPI_BIT_LENGTH  =   96
) 
(
    // signals from FPGA
    input                           clk,
    input                           nrst,
    input                           pll_locked,
    input   [8:0]                   sw_NOWA,

    // LED Display for system status
    output  [17:0]                  LED_cnt_adc_received,
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

    output  [SPI_BIT_LENGTH-1:0]    spi_wdata,
    output                          spi_wreq,
    input                           spi_csn
    // input   [31:0]                  cnt_spi_send

    // Disable Uart TX
    // output  [UART_NUM_DATA-1:0]     uart_wdata,
    // output                          uart_wreq,
    // input                           uart_rdy
);

// ********************* Parameter Declaration *********************
    localparam memory_deepth = NUM_Sampled*4;
    localparam memory_deepth_calib = NUM_Calibration*4;

    localparam num_spi_per = SPI_BIT_LENGTH / 24;
    localparam num_spi_sent = NUM_Sampled / num_spi_per;
    localparam num_spi_sent_calib = NUM_Calibration / num_spi_per;


    localparam uart_period = UART_FREQ / UART_BAUDRATE;

// ********************* Wire Declaration *********************
    wire                        adc_trigger;
    wire                        uart_rx_done;
    wire    [CMDLENGTH-1:0]     uart_rx_cmdout;
// ********************* Registor Declaration *********************
    // Counters
//    reg [7:0]   cnt_adc_ena;    // for debug;
    reg [31:0]  cnt_adc_ena;
    reg [31:0]  cnt_adc_received;
    reg [31:0]  cnt_reset;
    reg [7:0]   cnt_adc_ena_clk;
//    reg [31:0]  cnt_uart_clk;
    reg [31:0]  cnt_uart_wait;
    // reg [31:0]  cnt_uart_send;
    reg [31:0]  cnt_spi_send;
    reg [15:0]  cnt_ad_times;


    // Output Reg
    reg adc_rstn_reg, adc_calib_ena_reg, adc_ena_reg;
    reg [8:0]   adc_NOWA_reg;
    // reg [UART_NUM_DATA-1:0] uart_wdata_reg;
    // reg uart_wreq_reg;   
    reg [SPI_BIT_LENGTH-1:0] spi_wdata_reg;
//	 reg [SPI_BIT_LENGTH-1:0] spi_wdata_buffer;

    reg spi_wreq_reg;


    reg leds_reset, leds_ena, leds_received, leds_uart;     

    // Assign reg Onchip_Memory as M9K block memory 
	// (* regstyle = "M9K" *) reg [NUM_bit-1:0] Onchip_Memory [memory_deepth-1:0];

    // reg [1:0]   ns_flag;    // 2'b10 for calibration; 2'b01 for calibration;


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
	 
	 wire spi_csn_trigger;

// ********************* Trigger Settup *********************
    RiseEdgeTrigger Inst_RiseEdgeTrigger (
        .clk        (clk),
        .nrst       (nrst),
        .locked     (pll_locked),
        .tin        ((adc_ack | adc_ack_sub)),
        .tout       (adc_trigger)
    );

    RiseEdgeTrigger Inst_RiseEdgeTrigger_2 (
        .clk        (clk),
        .nrst       (nrst),
        .locked     (pll_locked),
        .tin        (spi_csn),
        .tout       (spi_csn_trigger)
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
    
    parameter   IDLE        =   4'd0;
    parameter   RESET       =   4'd1;
    parameter   HOLD        =   4'd2;
    parameter   SAMPLE      =   4'b0011;
    parameter   CALIB       =   4'b1100;
    // parameter   SENDS       =   4'b0111;
    // parameter   SENDC       =   4'b1110;
    parameter   UART_WAIT   =   4'b1111;

    // state transfer
    always @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            cs <= IDLE;
        end 
        else if (pll_locked && clk) begin
            cs <= ns;
        end
    end

    // decide to next state
    always @(cs, nrst, cnt_adc_ena, cnt_adc_received, cnt_spi_send, cnt_reset, uart_rx_done, uart_rx_cmdout, cnt_uart_wait, pll_locked) begin
        if (!nrst) begin
            ns = IDLE;
        end
        else begin
            case (cs)
                IDLE:
                    if (pll_locked)
                        ns = RESET;
                    else   
                        ns = IDLE;
                
                RESET:
                    if (cnt_reset == RESET_PERIOD)
                        ns = HOLD;
                    else 
                        ns = RESET;
                
                HOLD:
                    if (uart_rx_done) begin
                        // case (uart_rx_cmdout)
                        //     4'h1:       ns = CALIB;
                        //     4'h2:       ns = SAMPLE;
                        //     default:    ns = RESET;     // command error
                        // endcase
                        ns = UART_WAIT;
                    end
                    else begin      // wait for uart command in
                        ns = HOLD;
                    end

                UART_WAIT:
                    if (cnt_uart_wait == UART_PRE_DELAY) begin
                        case (uart_rx_cmdout)
                            4'h1:       ns = CALIB;
                            4'h2:       ns = SAMPLE;
                            default:    ns = RESET;     // command error
                        endcase
                    end
                    else begin
                        ns = UART_WAIT;
                    end
                
                CALIB:
                    if ((cnt_adc_ena==NUM_Calibration) && (cnt_adc_received==memory_deepth_calib) && (cnt_spi_send == num_spi_sent_calib))
                        ns = HOLD;
                    else
                        ns = CALIB;
                
                SAMPLE:
                    if ((cnt_adc_ena==NUM_Sampled) && (cnt_adc_received==memory_deepth) && (cnt_spi_send == num_spi_sent))
                        ns = HOLD;
                    else
                        ns = SAMPLE;
                
                // SENDC:
                //     if (cnt_uart_send == memory_deepth_calib) 
                //         ns = HOLD;
                //     else
                //         ns = SENDC;
                
                // SENDS:
                //     if (cnt_uart_send == memory_deepth)
                //         ns = HOLD;
                //     else
                //         ns = SENDS;
                
                default:
                    ns = IDLE;
            endcase
        end
    end

    always @(posedge clk or negedge nrst) begin
        if (!nrst) begin // reset all register
            cnt_adc_ena <= 32'd0;
            cnt_adc_received <= 32'd0;
            cnt_reset <= 32'd0;
            cnt_adc_ena_clk <= 8'd0;
//            cnt_uart_clk <= 32'd0;
            cnt_uart_wait <= 32'd0;
            cnt_spi_send <= 32'd0;

            adc_rstn_reg <= 1'd1;         // low Level effective
            adc_calib_ena_reg <= 1'd0;
            adc_ena_reg <= 1'd0;
            adc_NOWA_reg <= 9'd0;
            
            spi_wdata_reg <= 96'd0;
            spi_wreq_reg <= 1'd0;
            cnt_ad_times <= 16'd0;

            leds_reset <= 1'd0;
            leds_ena <= 1'd0;
            leds_received <= 1'd0;
            leds_uart <= 1'd0;

        end
        else begin
            if (!pll_locked) begin
                cnt_adc_ena <= 32'd0;
                cnt_adc_received <= 32'd0;
                cnt_reset <= 32'd0;
                cnt_adc_ena_clk <= 8'd0;
//                cnt_uart_clk <= 32'd0;
                cnt_uart_wait <= 32'd0;
                cnt_spi_send <= 32'd0;

                adc_rstn_reg <= 1'd1;         // low Level effective
                adc_calib_ena_reg <= 1'd0;
                adc_ena_reg <= 1'd0;
                adc_NOWA_reg <= 9'd0;
                
                spi_wdata_reg <= 96'd0;
//					 spi_wdata_buffer <= 96'd0;
                spi_wreq_reg <= 1'd0;
                cnt_ad_times <= 16'd0;

                leds_reset <= 1'd0;
                leds_ena <= 1'd0;
                leds_received <= 1'd0;
                leds_uart <= 1'd0;
            end
            else begin
                case (ns) 
                    IDLE: begin
                        cnt_adc_ena <= 32'd0;
                        cnt_adc_received <= 32'd0;
                        cnt_reset <= 32'd0;
                        cnt_adc_ena_clk <= 8'd0;
//                        cnt_uart_clk <= 32'd0;
                        cnt_uart_wait <= 32'd0;
                        cnt_spi_send <= 32'd0;

                        adc_rstn_reg <= 1'd1;         // low Level effective
                        adc_calib_ena_reg <= 1'd0;
                        adc_ena_reg <= 1'd0;
                        adc_NOWA_reg <= 9'd0;
                        
                        spi_wdata_reg <= 96'd0;
//								spi_wdata_buffer <= 96'd0;
                        spi_wreq_reg <= 1'd0;
                        cnt_ad_times <= 16'd0;


                        leds_reset <= 1'd0;
                        leds_ena <= 1'd0;
                        leds_received <= 1'd0;
                        leds_uart <= 1'd0;
                    end

                    RESET: begin
                        cnt_reset <= cnt_reset + 32'd1;
                        adc_rstn_reg <= 1'd0;
                        leds_reset <= 1'd0;

                        adc_NOWA_reg <= sw_NOWA;
                    end

                    HOLD: begin
                        cnt_adc_ena <= 32'd0;
                        cnt_adc_received <= 32'd0;
                        cnt_spi_send <= 32'd0;
                        cnt_reset <= 32'd0;
//                        cnt_uart_clk <= 32'd0;
                        cnt_adc_ena_clk <= 8'd0;
                        cnt_uart_wait <= 32'd0;
        
                        adc_calib_ena_reg <= 1'd0;
                        adc_ena_reg <= 1'd0;
                        adc_rstn_reg <= 1'd1;

                        spi_wdata_reg <= 96'd0;
//								spi_wdata_buffer <= 96'd0;
                        spi_wreq_reg <= 1'd0;
                        cnt_ad_times <= 16'd0;

                        leds_reset <= 1'd1;
                    end

                    UART_WAIT: begin
                        cnt_uart_wait <= cnt_uart_wait + 32'd1;
                    end

                    CALIB: begin
                        adc_calib_ena_reg <= 1'd1;
                        cnt_uart_wait <= 32'd0;
                        if (cnt_adc_ena < NUM_Calibration) begin    // Generate adc_ena signal
                            if (cnt_adc_ena_clk == 8'd24) begin
                                cnt_adc_ena_clk <= 8'd0;
                                adc_ena_reg <= 1'd1;
                                cnt_adc_ena <= cnt_adc_ena + 32'd1;
                            end 
                            else begin
                                cnt_adc_ena_clk <= cnt_adc_ena_clk + 8'd1;
                                adc_ena_reg <= 1'd0;
                                cnt_adc_ena <= cnt_adc_ena;
                            end
                            leds_ena <= 1'd0;
                        end
                        else begin
                            adc_ena_reg <= 1'd0;
                            cnt_adc_ena <= cnt_adc_ena;
                            cnt_adc_ena_clk <= cnt_adc_ena_clk;
                            leds_ena <= 1'd1;
                        end

                        if (adc_trigger == 1) begin                 // Store and Dout of ADC
                            if (cnt_adc_received < memory_deepth_calib) begin
                                cnt_adc_received <= cnt_adc_received + 32'd1;
                                // Onchip_Memory[cnt_adc_received] <= {adc_dout};
                                spi_wdata_reg <= {spi_wdata_reg[89:0],adc_dout};
//										  spi_wdata_reg <= {adc_dout, spi_wdata_reg[95:6]};

                                leds_received <= 1'd1;
                            end
                            else begin
                                cnt_adc_received <= cnt_adc_received;
                            end

                            if (cnt_ad_times == 16'd15) begin
                                cnt_ad_times <= 16'd0;
                                spi_wreq_reg <= 1'd1;
                            end
                            else begin
                                cnt_ad_times <= cnt_ad_times + 16'd1;
                                spi_wreq_reg <= 1'd0;
                            end
                        end
                        else begin
                            cnt_adc_received <= cnt_adc_received;
                            spi_wreq_reg <= 1'd0;
//                            cnt_ad_times <= 16'd0;
                        end

                        if (spi_csn_trigger == 1) begin
                            if (cnt_spi_send < num_spi_sent_calib) begin
                                cnt_spi_send <= cnt_spi_send + 32'd1;
                            end
                            else begin
                                cnt_spi_send <= cnt_spi_send;
                            end    
                        end
                        else begin
                            cnt_spi_send <= cnt_spi_send;
                        end
                    end

                    SAMPLE: begin
                        adc_calib_ena_reg <= 1'd0;
                        cnt_uart_wait <= 32'd0;
                        if (cnt_adc_ena < NUM_Sampled) begin    // Generate adc_ena signal
                            if (cnt_adc_ena_clk == 8'd24) begin
                                cnt_adc_ena_clk <= 8'd0;
                                adc_ena_reg <= 1'd1;
                                cnt_adc_ena <= cnt_adc_ena + 32'd1;
                            end 
                            else begin
                                cnt_adc_ena_clk <= cnt_adc_ena_clk + 8'd1;
                                adc_ena_reg <= 1'd0;
                                cnt_adc_ena <= cnt_adc_ena;
                            end
                            leds_ena <= 1'd0;
                        end
                        else begin
                            adc_ena_reg <= 1'd0;
                            cnt_adc_ena <= cnt_adc_ena;
                            cnt_adc_ena_clk <= cnt_adc_ena_clk;
                            leds_ena <= 1'd1;
                        end
                    
                        if (adc_trigger == 1) begin                 // Store and Dout of ADC
                            if (cnt_adc_received < memory_deepth) begin
                                cnt_adc_received <= cnt_adc_received + 32'd1;
                                // Onchip_Memory[cnt_adc_received] <= {adc_dout};
                                spi_wdata_reg <= {spi_wdata_reg[89:0],adc_dout};
//										  spi_wdata_reg <= {adc_dout, spi_wdata_reg[95:6]};
                                leds_received <= 1'd1;
                            end
                            else begin
                                cnt_adc_received <= cnt_adc_received;
                            end

                            if (cnt_ad_times == 16'd15) begin
                                cnt_ad_times <= 16'd0;
                                spi_wreq_reg <= 1'd1;
                            end
                            else begin
                                cnt_ad_times <= cnt_ad_times + 16'd1;
                                spi_wreq_reg <= 1'd0;
                            end
                        end
                        else begin
                            cnt_adc_received <= cnt_adc_received;
                            spi_wreq_reg <= 1'd0;
//                            cnt_ad_times <= 16'd0;
                        end

                        if (spi_csn_trigger == 1) begin
                            if (cnt_spi_send < num_spi_sent) begin
                                cnt_spi_send <= cnt_spi_send + 32'd1;
                            end
                            else begin
                                cnt_spi_send <= cnt_spi_send;
                            end    
                        end
                        else begin
                            cnt_spi_send <= cnt_spi_send;
                        end
                    end
                    default: begin
                        cnt_adc_ena <= 32'd0;
                        cnt_adc_received <= 32'd0;
                        cnt_reset <= 32'd0;
                        cnt_adc_ena_clk <= 8'd0;
//                        cnt_uart_clk <= 32'd0;
                        cnt_uart_wait <= 32'd0;
                        cnt_spi_send <= 32'd0;

                        adc_rstn_reg <= 1'd1;         // low Level effective
                        adc_calib_ena_reg <= 1'd0;
                        adc_ena_reg <= 1'd0;
                        adc_NOWA_reg <= 9'd0;
                        
                        spi_wdata_reg <= 96'd0;
                        spi_wreq_reg <= 1'd0;
//								spi_wdata_buffer <= 96'd0;
                        cnt_ad_times <= 16'd0;

                        leds_reset <= 1'd0;
                        leds_ena <= 1'd0;
                        leds_received <= 1'd0;
                        leds_uart <= 1'd0;
                    end
                endcase
            end
        end     
    end 


	reg	spi_wreq_reg_ff;
	always @(posedge clk or negedge nrst) begin
		if (!nrst) 
			spi_wreq_reg_ff <= 1'd0;
		else
			spi_wreq_reg_ff <= spi_wreq_reg;
	end


// ********************* Output Assigments *********************
    //  LED Display assignments  //FIXME
    assign  LED_cnt_adc_received    =   cnt_adc_received[17:0];
    assign  LED_state           =   cs;
    assign  LED_out             =   {leds_reset, leds_uart, leds_received, leds_ena};  
    
    //  communicating with chip
    assign  adc_rstn            =   adc_rstn_reg;
    assign  adc_calib_ena       =   adc_calib_ena_reg;
    assign  adc_ena             =   adc_ena_reg;
    assign  adc_NOWA            =   adc_NOWA_reg;

    //  communicating with UART
    // assign  uart_wdata          =   uart_wdata_reg;
    // assign  uart_wreq           =   uart_wreq_reg;
    assign spi_wreq             =   spi_wreq_reg_ff;
    assign spi_wdata            =   spi_wdata_reg;

endmodule