`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 19.07.2026 15:26:12
// Design Name: 
// Module Name: SPI_ADC
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


module SPI_ADC(
input clk,enable,
input spi_miso,
output clkout,
output a1,a2,
output reg spi_sck,//spi clock
output reg amp_cs,//amplifier select
output reg adc_conv,//adc conversion controller signal
output reg spi_mosi,
output reg amp_shdn,//amplifier shutdown
output spi_ss_b,sf_ce0,fpga_init_b,dac_cs,//disable signal
output reg [13:0]adc_data1, //ADC output1
output reg [13:0]adc_data2, //ADC output2
output [15:0]adc_data//ADC output1
    );
    reg adc_sent=0;
    reg[2:0]cnt=0;
    reg[3:0]clk_10_count=0;
    reg[6:0]adc_clk_count=0;//for 34 clock pulse
    reg[5:0]adc_bit_count=17;//count for 16 clock pulse
    reg[3:0]gain_count=8;//gain count in amplifier 8 bit
    reg[4:0]pos_count,neg_count;
    reg [7:0]data_gain=8'b00010001;//gain settting =-1;
    reg[5:0]state=6'b000000;
    
    //Disabling other peripheral communicating with spi bus
    
    assign spi_ss_b=0;
    assign sf_ce0=1;
    assign fpga_init_b=1;
    assign dac_cs=1;
    
    //Clock division by 25 clk=50mhz
    
    always@(posedge clk or posedge enable)
    begin
    if(enable)
    begin
    pos_count<=0;
    end
    else
    begin
    if(pos_count==24)pos_count<=0;
    else pos_count<=pos_count+1;
    end
    end
    
    always@(negedge clk or posedge enable)
    begin
   if(enable)
    begin
    neg_count<=0;
    end
    else
    begin
    if(neg_count==24)neg_count<=0;
    else neg_count<=neg_count+1;
    end
    end
    
    assign clkout=((pos_count>(25>>1))|(neg_count>(25>>1)));
    assign a1=amp_cs;
    assign a2=adc_conv;
   
   assign adc_data={2'b00,adc_data1};//16bit 
    
    always@(posedge clkout or posedge enable)
    begin
    if(enable)
    begin
    spi_sck<=0;
    amp_shdn<=0;
    adc_conv<=0;
    amp_cs<=1;
    spi_mosi<=0;
    //adc_data1<=14'b1011001000111;
    state<=1;
    end
    else
    begin
    case(state)
    1:begin
    state<=2;
    end
    2:begin
    spi_sck<=0;
    amp_cs<=0;
    state<=3;
    end
    
    3:begin
    spi_sck<=0;
    state<=4;
    end
    
    4:begin // gain setting pf the amplifier to -1
    spi_sck<=0;
    amp_cs<=0;
    amp_shdn<=0;
    spi_mosi<=data_gain[gain_count-1];
    gain_count<=gain_count-1;
    state<=5;
    end
    
    5:begin
    amp_cs<=0;
    spi_sck<=1;
    if(gain_count>0)
    begin
    state<=6;
    end
    else
    begin
    spi_sck<=1;
    amp_shdn<=0;
    gain_count<=8;
    amp_cs<=0;
    state<=7;
    end
    end
    
    6:begin
    spi_sck<=1;
    state<=3;
    end
    
    7:begin
    amp_cs<=0;
    spi_sck<=1;
    state<=8;
    end
    
    8:begin
    spi_sck<=0;
    state<=9;
    end
    
    9:begin
    spi_sck<=0;
    state<=10;
    end
    
    10:begin
    if(cnt>5)//delay
    begin
    spi_sck<=0;
    state<=11;
    cnt<=0;
    end
    else
    begin
    cnt<=cnt+1;
    spi_sck<=0;
    end
    end
    
    11:begin
    amp_cs<=1; // disabling the gain setting after gain is set to -1
    spi_sck<=0;
    state<=12;
    end
    
    12:begin
    spi_sck<=0;
    state<=13;
    end
    
    13:begin
    spi_sck<=1;
    state<=14;
    end
    
    14:begin
    spi_sck<=1;
    state<=15;
    end
    
    15:begin
    spi_sck<=0;
    state<=30;
    end
    
    30:begin
     spi_sck<=0;
    state<=16;
    end
    
    16:begin
    adc_conv<=1;//start adc  from here
    spi_sck<=0;
    state<=17;
    end
    
    17:begin
    spi_sck<=0;
    state<=18;
    end
    
    18:begin
    adc_conv<=0;
    spi_sck<=0;
    state<=19;
    end
    
    19:begin
    if(cnt>5)//delay
    begin
    spi_sck<=0;
    cnt<=0;
    state<=20;
    end
    else
    begin
    cnt<=cnt+1;
    state<=19;
    end
    end
    
    20:begin
    spi_sck<=0;
    state<=21;
    end
    
    //adc starts from here
    
    21:begin
    spi_sck<=0;
    adc_conv<=0;
    adc_clk_count<=adc_clk_count+1;
    adc_bit_count<=adc_bit_count-1;
    state<=22;
    end
    
    22:begin
    spi_sck<=1;
    state<=23;
    end
    
    23:begin
    spi_sck<=1;
    if(adc_clk_count==34)
    begin
    adc_sent<=1;
    //spi_sck==0;
    state<=24;
    end
    else if(adc_clk_count<=2)
// first two clock where adc output is z
    begin
    //spi_sck==0;
    state<=20;
    end
    
    else if((adc_clk_count>2)&&(adc_clk_count<=16))//for first 14 bit data channel 1
    begin
    //spi_sck==0;
    adc_data1[adc_bit_count-1]<=spi_miso;//output of adc1
    state<=20;
    end
    
    else if((adc_clk_count>16)&&(adc_clk_count<=18))//here the adc output is again Z as previous
    begin
    //spi_sck==0;
    adc_bit_count<=15;
    state<=20;
    end
    
    else if((adc_clk_count>18)&&(adc_clk_count<=32))
    begin
    adc_data2[adc_bit_count-1]<=spi_miso;
    state<=20;
    end
    
    else if(adc_clk_count==33)//33 clock pulse
    begin
    //spi_sck<=0
    state<=20;
    end
    end
    
    24:begin
    adc_clk_count<=0;
    adc_bit_count<=17;
    spi_sck<=0;
    state<=25;
    end
    
    25:begin
    spi_sck<=0;
    adc_sent<=0;
    //adc_conv<=1;
    state<=26;
    end
    
    26:begin
    spi_sck<=1;
    amp_shdn<=0;
    state<=27;
    end
    
    27:begin
    spi_sck<=1;
    state<=28;
    end
    
    28:begin
    if(cnt>4)
    begin
    spi_sck<=0;
    state<=16;//gaetting adc output in 2 chaneels
    //after 34 clock cycles and when adc_conv=1'b1 again go for 2nd time
    cnt<=0;
    end
    else
    begin
    cnt<=cnt+1;
    spi_sck<=0;
    state<=28;
    end
    end
    endcase
    end
    end
    endmodule
