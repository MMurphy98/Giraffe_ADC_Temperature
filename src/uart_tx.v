

module uart_tx
	#(
    	parameter BAUDRATE = 115200,
    	parameter FREQ = 50_000_000,	
		parameter N_start=1,
		parameter N_data=6,
		parameter N_stop=1
	)
	(
	//	inout vddd,
    // 	inout gndd,
 		input clk,
		input nrst,
    	input wreq,
    	input [(N_data-1):0] wdata,
    	output tx,
    	output rdy
    );
	reg [(N_data-1):0] wdata_reg;

	reg tx_reg;
	reg rdy_reg;

	assign rdy = rdy_reg;
	assign tx = tx_reg;	

    reg [3:0] cnt_bit;
    reg [31:0] cnt_clk;

    localparam T = FREQ / BAUDRATE;

// define the FSM for pixel compensation
	reg [1:0] cs,ns;
	parameter IDLE = 0,
			START = 1,
			DATA = 2,
			STOP = 3;
////////////////  states transferring   ///////////////////
	always @(posedge clk or negedge nrst) begin : ss_tran
   		if(nrst == 1'b0) begin
      		cs <= IDLE;
      	end else if(clk == 1'b1) begin
         	cs <= ns;
      	end
   	end
//////////////  calculate the next state /////////////////
	always @(cs, cnt_clk, wreq, nrst, cnt_bit) begin
		if (nrst == 0) begin
			ns = IDLE;
		end begin
			case(cs)
				IDLE : 
					if(wreq == 1)
						ns = START;
					else
						ns = IDLE;
				START : 
					if(cnt_bit == N_start)
						ns = DATA;
					else
						ns = START;
				DATA : 
					if(cnt_bit == N_data + N_start)
						ns = STOP;
					else 
						ns = DATA;
				STOP :
					if(cnt_bit == N_data + N_start + N_stop)
						ns = IDLE;
					else 
						ns = STOP;
				default : ns = ns;
			endcase
		end

	end	
//////////  data processing in various states /////////////

	always @(cs, ns, nrst) begin
		// rdy=0 means sending, rdy=1 means ready for new data
		if(cs == IDLE && ns == IDLE && nrst == 1)
			rdy_reg = 1'b1;
		else
			rdy_reg = 1'b0;
	end

	always @(posedge clk or negedge nrst) begin
		if(nrst==0) begin
			cnt_bit <= 4'd0;
			cnt_clk <= 32'd0;
			tx_reg <= 1'b1;
		end else if(clk == 1'b1) begin
			case (ns)
				IDLE : begin
					cnt_bit <= 4'd0;
					cnt_clk <= 32'd0;
					tx_reg <= 1'b1;
					wdata_reg <= 0;
				end
				START : begin
					if (cnt_clk == 0 && cnt_bit == 0) begin
						wdata_reg <= wdata;
					end else begin
						wdata_reg <= wdata_reg;
					end
					tx_reg <= 1'b0;
				
					if (cnt_clk < T-1) begin
						cnt_clk <= cnt_clk + 1'b1;
					end else begin
						cnt_clk <= 32'd0;
						cnt_bit <= cnt_bit + 4'd1;
					end
				end
				DATA : begin
					tx_reg <= wdata_reg[(cnt_bit-1)];
					if (cnt_clk<T-1) begin
						cnt_clk <= cnt_clk + 1'b1;
					end else begin
						cnt_clk <= 32'd0;
						cnt_bit <= cnt_bit + 4'd1;
					end
				end
				STOP : begin
					tx_reg <= 1'b1;
					
					if (cnt_clk<T-1) begin
						cnt_clk <= cnt_clk + 1'b1;
					end else begin
						cnt_clk <= 32'd0;
						cnt_bit <= cnt_bit + 4'd1;
					end
				end
				default : begin
					cnt_bit <= 4'd0;
					cnt_clk <= 32'd0;
					tx_reg <= 1'b1;
				end
			endcase
		end
	end

endmodule
