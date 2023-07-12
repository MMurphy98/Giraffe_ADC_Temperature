

module uart_rx 
	#(
    	parameter BAUDRATE = 1_200_000,
    	parameter FREQ = 50_000_000,
		parameter N_start = 1,
		parameter N_data = 8,
		parameter N_stop = 1
	)
	(
	//	inout    vddd,
    // 	inout    gndd,
    	input clk, nrst,
    	input rx,
    	output [N_data-1:0] rdata,
    	output vld
    );

    localparam T = FREQ / BAUDRATE;

	reg [7:0] rdata_reg;
	reg vld_reg;
	reg [3:0] cnt_bit;
    reg [31:0] cnt_clk;
    assign end_cnt_clk = cnt_clk == T - 1;
    assign end_cnt_bit = end_cnt_clk && cnt_bit == (N_start + N_data + N_stop  - 1);

	assign rdata = rdata_reg;
	assign vld = vld_reg;
    // flag represent state 1 means reciving
    reg flag;
    always @(posedge clk or negedge nrst) begin
        if(nrst == 0)
            flag <= 0;
        else if(flag == 0 && rx == 0)
            flag <= 1;
        else if(cnt_bit == 1 - 1 && cnt_clk == T / 2 - 1 && rx == 1)
            flag <= 0;
        else if(end_cnt_bit)
            flag <= 0;
    end
    
    always @(posedge clk or negedge nrst) begin
        if(nrst == 0)
            cnt_clk <= 0;
        else if(flag) begin
            if(end_cnt_clk)
                cnt_clk <= 0;
            else
                cnt_clk <= cnt_clk + 1'b1;
        end
        else
            cnt_clk <= 0;
    end

    always @(posedge clk or negedge nrst) begin
        if(nrst == 0)
            cnt_bit <= 0;
        else if(end_cnt_clk) begin
            if(end_cnt_bit)
                cnt_bit <= 0;
            else
                cnt_bit <= cnt_bit + 1'b1;
        end
    end

    // acquire data
    always @(posedge clk or negedge nrst) begin
        if(nrst == 0)
            rdata_reg <= 0;
        else if(cnt_clk == T / 2 - 1 && cnt_bit != 1 - 1 && cnt_bit != 10 - 1)
            rdata_reg[cnt_bit - 1] <= rx;
    end

    always @(posedge clk or negedge nrst) begin
        if(nrst == 0)
            vld_reg <= 0;
        else if(end_cnt_bit)
            vld_reg <= 1;
        else
            vld_reg <= 0;
    end

endmodule
