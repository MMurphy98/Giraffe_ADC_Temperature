module RiseEdgeTrigger (
    input   clk,
    input   nrst,
    input   locked,
    
    input   tin,
    output  tout
);
    reg tin_ff1;

    always @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            tin_ff1 <= 1'd0;
        end
        else if (locked) begin
            tin_ff1 <= tin;
        end
        else begin
            tin_ff1 <= tin_ff1;
        end
    end


    assign  tout    =   (~tin_ff1) & tin;

endmodule;