`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/07/07 14:48:04
// Design Name: 
// Module Name: spi_controller
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module SPI_Controller_Master #(
    parameter N_bit = 96
)
(
    input               clk,
    input               wreq,
    input   [N_bit-1:0] wdata,
    input               nrst,
    input               pll_locked,

    output              spi_sclk,
    output              spi_csn,
    output              spi_mosi
    // only for master write
);
    reg             spi_sclk_ena;
    reg             spi_csn_reg;
    reg             spi_mosi_reg;
    reg [N_bit-1:0] data_buffer;

    reg [31:0]      cnt_bit;
    
// ********************* FSM Settup *********************
    reg [3:0]   cs, ns;
    
    parameter   IDLE        =   4'd0;
    parameter   HOLD        =   4'd2;
    parameter   PRE_SEND    =   4'd3;
    parameter   SEND        =   4'd4;
    parameter   Wait	    =   4'd5;


    // state transfer
    always @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            cs <= IDLE;
        end 
        else if (clk) begin
            cs <= ns;
        end
    end

     // decide to next state
    always @(cs, nrst, cnt_bit, wreq, spi_csn_reg, pll_locked) begin
        if (!nrst) begin
            ns = IDLE;
        end
        else begin
            case (cs) 
                IDLE: 
                    if (pll_locked) 
                        ns = HOLD;
                    else
                        ns = IDLE;
                
                HOLD:
                    if (wreq == 1'd1) 
                        ns = PRE_SEND;
                    else
                        ns = HOLD;
					 	 
                PRE_SEND:
                    ns = SEND;

                SEND:
                    if (cnt_bit == N_bit) begin
                    //    if (wreq == 1'd1)
                    //        ns = PRE_SEND;
                    //    else
                    //        ns = HOLD;
                        ns = HOLD;
                    end
                    else
                        ns = SEND;

					Wait:	
							ns = HOLD;
                default:
                    ns = IDLE;
            endcase
        end
    end

    always @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            spi_sclk_ena <= 1'd0;
            spi_csn_reg <= 1'd1;
            spi_mosi_reg <= 1'd0;
            cnt_bit <= 32'd0;
            data_buffer <= 96'd0;
        end
        else begin
            if (!pll_locked) begin
                spi_sclk_ena <= 1'd0;
                spi_csn_reg <= 1'd1;
                spi_mosi_reg <= 1'd0;
                cnt_bit <= 32'd0;
                data_buffer <= 96'd0;
            end
            else begin
                case (ns) 
                    IDLE: begin
                        spi_sclk_ena <= 1'd0;
                        spi_csn_reg <= 1'd1;
                        spi_mosi_reg <= 1'd0;
                        cnt_bit <= 32'd0;
                        data_buffer <= 96'd0;
                    end

                    HOLD: begin
                        spi_sclk_ena <= 1'd0;
                        spi_csn_reg <= 1'd1;
                        spi_mosi_reg <= 1'd0;
                        cnt_bit <= 32'd0;
                        data_buffer <= 96'd0;
                    end  

                    PRE_SEND: begin
                        data_buffer <= wdata;
                        spi_csn_reg <= 1'd0;
                        cnt_bit <= 32'd0;
                    end

                    SEND: begin
                        spi_sclk_ena <= 1'd1;
                        spi_mosi_reg <= data_buffer[cnt_bit];
                        cnt_bit <= cnt_bit + 32'd1;
                    end
						  Wait: begin
                        spi_sclk_ena <= 1'd0;
                        spi_csn_reg <= 1'd1;
                        spi_mosi_reg <= 1'd0;
                        cnt_bit <= 32'd0;
                        data_buffer <= 96'd0;
                    end  

                    default: begin 
                        spi_sclk_ena <= 1'd0;
                        spi_csn_reg <= 1'd1;
                        spi_mosi_reg <= 1'd0;
                        cnt_bit <= 32'd0;
                        data_buffer <= 96'd0;
                    end
                endcase
            end
        end
    end

    assign spi_sclk = (~spi_sclk_ena) | clk;
    // SPI_C
    assign spi_csn = spi_csn_reg;
    assign spi_mosi = spi_mosi_reg;
endmodule