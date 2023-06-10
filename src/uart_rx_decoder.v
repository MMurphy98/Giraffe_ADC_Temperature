module uart_rx_decoder #(
    parameter   UART_NUM_DATA   =   8,
    parameter   CMDLENGTH       =   4
)
(
    input   clk,
    input   nrst,
    input   sys_locked,

    input   [UART_NUM_DATA-1:0] uart_rdata,
    input                       uart_vld,

    output  [CMDLENGTH-1:0]     cmdout
);

    reg     [CMDLENGTH-1:0]     cmdout_reg;
    always @(posedge clk or negedge nrst) begin
        if ((~nrst) | (~sys_locked)) begin
            cmdout_reg <= 4'd0;
        end
        else begin
            if (uart_vld) begin 
                case (uart_rdata) 
                    8'hCB:      // Calibration
                        cmdout_reg <= 4'h1;
                    8'hAD:      // A/D Sample
                        cmdout_reg <= 4'h2;
                    default:
                        cmdout_reg <= 4'hF;
                endcase
            end
            else
                cmdout_reg <= cmdout_reg;
        end 
    end

    assign  cmdout = cmdout_reg;

endmodule