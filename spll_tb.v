module spll_tb();

reg clk_250Mhz=0;
reg i_ld=0;
reg [31:0] i_step=0;
reg i_ce=0;
reg clk_2kHz=0;
reg  [4:0]  i_lgcoeff=0;
wire [31:0] o_phase;
wire [1:0]  o_err;
wire        o_freq;

always begin
    #2 clk_250Mhz = ~clk_250Mhz; 
end

initial begin 
    #300000;
    forever begin
    clk_2kHz = 0;
    #250000 clk_2kHz = 1'b1;
    #250000; 
 end end
 
 
 initial begin
    #1000 
    i_lgcoeff = 6;
	//i_step    = 32'd140737488;
	i_step    = 32'd34360; //2khz
	//i_step    = 32'd36078; //2.1khz
	i_ld      = 1;
	#1001
	i_ld      = 0; 
	#1050 
	i_ce      = 1;
	
 end
 

//PLL
spll spll
(
    .i_clk      (clk_250Mhz),
    
    .i_ld       (i_ld),
    .i_step     (i_step),

    .i_ce       (i_ce),
    .i_input    (clk_2kHz),
    .i_lgcoeff  (i_lgcoeff),
    .o_phase    (o_phase),
    .o_err      (o_err),
    .o_freq     (o_freq)
);

endmodule
