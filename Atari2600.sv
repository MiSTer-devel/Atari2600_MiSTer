//============================================================================
//  Atari 2600
// 
//  Port to MiSTer
//  Copyright (C) 2017,2018 Sorgelig
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] VIDEO_ARX,
	output  [7:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S, // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;
assign {SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 6'b111111;
assign SDRAM_DQ = 'Z;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

assign LED_USER  = 0;
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS   = 0;

assign VIDEO_ARX = status[8] ? 8'd16 : 8'd4;
assign VIDEO_ARY = status[8] ? 8'd9  : 8'd3; 

`include "build_id.v" 
localparam CONF_STR = {
	"ATARI2600;;",
	"F,*;",
	"O9A,SuperChip,Auto,Disable,Enable;",
	"-;",
	"O1,Colors,NTSC,PAL;",
	"O2,Video mode,Color,Mono;",
	"O8,Aspect ratio,4:3,16:9;", 
	"O57,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"-;",
	"O3,Difficulty P1,B,A;",
	"O4,Difficulty P2,B,A;",
	"-;",
	"OF,Swap Joystick,No,Yes;",
	"OB,Invert Paddle,No,Yes;",
	"-;",
	"R0,Reset;",
	"J1,Fire,Stick Btn,Paddle Btn,Game Reset,Game Select;",
	"jn,A,B,X|P,Start,Select;",
	"jp,A,B,X|P,Start,Select;",
	"V,v",`BUILD_DATE
};

////////////////////   CLOCKS   ///////////////////

wire locked;
wire clk_sys,clk_cpu;
wire clk_mem;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys),
	.outclk_1(clk_cpu),
	.outclk_2(CLK_VIDEO),
	.locked(locked)
);

reg ce_pix;
always @(negedge CLK_VIDEO) begin
	reg [4:0] div;

	div <= div + 1'd1;
	if(div == 23) div <= 0;
	ce_pix <= !div;
end

wire reset = RESET | status[0] | buttons[1] | ioctl_download;


//////////////////   HPS I/O   ///////////////////
wire [15:0] joy_0,joy_1,joy_2,joy_3;
wire [15:0] joya_0,joya_1,joya_2,joya_3;
wire  [7:0] pd_0,pd_1,pd_2,pd_3;
wire  [1:0] buttons;
wire [31:0] status;
wire [24:0] ps2_mouse;

wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire        ioctl_download;
wire  [7:0] ioctl_index; 
wire [31:0] ioctl_file_ext;
wire [21:0] gamma_bus;

wire        forced_scandoubler;

hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),

	.joystick_0(joy_0),
	.joystick_1(joy_1),
	.joystick_2(joy_2),
	.joystick_3(joy_3),
	.joystick_analog_0(joya_0),
	.joystick_analog_1(joya_1),
	.joystick_analog_2(joya_2),
	.joystick_analog_3(joya_3),
	.paddle_0(pd_0),
	.paddle_1(pd_1),
	.paddle_2(pd_2),
	.paddle_3(pd_3),

	.buttons(buttons),
	.status(status),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),

	.ps2_kbd_led_use(0),
	.ps2_kbd_led_status(0),

	.ps2_mouse(ps2_mouse),

	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_file_ext(ioctl_file_ext),

	.sd_lba(0),
	.sd_rd(0),
	.sd_wr(0),
	.sd_conf(0),
	.sd_buff_din(0),
	.ioctl_wait(0)
);

(* ram_init_file = "rom.mif" *)
reg [7:0] rom[32768];
always @(posedge clk_sys) if(ioctl_wr && !ioctl_addr[24:15]) rom[ioctl_addr[14:0]] <= ioctl_dout;

reg  [14:0] rom_a;
always @(posedge clk_cpu) rom_a <= rom_addr;

wire [14:0] rom_addr;
wire  [7:0] rom_data = rom[rom_a];


wire [23:0] ext = (ioctl_file_ext[23:16] == ".") ? ioctl_file_ext[23:0] : ioctl_file_ext[31:8];

reg [3:0] force_bs = 0;
reg sc = 0;
always @(posedge clk_sys) begin
	reg       old_download;

	old_download <= ioctl_download;
	if(~old_download & ioctl_download) begin
		force_bs <= 0;
		sc <= status[9];
		if (ext == ".F8") force_bs <= 1;
		if (ext == ".F6") force_bs <= 2;
		if (ext == ".FE") force_bs <= 3;
		if (ext == ".E0") force_bs <= 4;
		if (ext == ".3F") force_bs <= 5;
    	if (ext == ".F4") force_bs <= 6;
		if (ext == ".P2") force_bs <= 7; // Pitfall II
    	if (ext == ".FA") force_bs <= 8;
    	if (ext == ".CV") force_bs <= 9;
    	if (ext == ".UA") force_bs <= 11;
	
		sc <= (!status[10:9]) ? (ioctl_file_ext[8:0] == "S") : status[10];
	end
end

wire [4:0] audio;
assign AUDIO_R = {3{audio}};
assign AUDIO_L = AUDIO_R;
assign AUDIO_S = 0;
assign AUDIO_MIX = 0;

A2601top A2601top
(
	.reset(reset),
	.clk(clk_cpu),

	.audio(audio),

	//.O_VSYNC(VSync),
	.O_HSYNC(hs),
	.O_HBLANK(HBlank),
	.O_VBLANK(VBlank),
	.O_VIDEO_R(R),
	.O_VIDEO_G(G),
	.O_VIDEO_B(B),

	.p1_r(status[15] ? ~joy_1[0] : ~joy_0[0]),
	.p1_l(status[15] ? ~joy_1[1] : ~joy_0[1]),
	.p1_d(status[15] ? ~joy_1[2] : ~joy_0[2]),
	.p1_u(status[15] ? ~joy_1[3] : ~joy_0[3]),
	.p1_f(status[15] ? ~joy_1[4] : ~joy_0[4]),

	.p2_r(status[15] ? ~joy_0[0] : ~joy_1[0]),
	.p2_l(status[15] ? ~joy_0[1] : ~joy_1[1]),
	.p2_d(status[15] ? ~joy_0[2] : ~joy_1[2]),
	.p2_u(status[15] ? ~joy_0[3] : ~joy_1[3]),
	.p2_f(status[15] ? ~joy_0[4] : ~joy_1[4]),

	.p_1(status[15] ? ~p_2 : ~p_1),
	.p_2(status[15] ? ~p_1 : ~p_2),
	.p_3(status[15] ? ~p_4 : ~p_3),
	.p_4(status[15] ? ~p_3 : ~p_4),

	.paddle_1(status[15] ? paddle_2 : paddle_1),
	.paddle_2(status[15] ? paddle_1 : paddle_2),
	.paddle_3(status[15] ? paddle_4 : paddle_3),
	.paddle_4(status[15] ? paddle_3 : paddle_4),

	.p_start (~(joy_0[7] | joy_1[7] | joy_2[7] | joy_3[7])),
	.p_select(~(joy_0[8] | joy_1[8] | joy_2[8] | joy_3[8])),

	.p_color(~status[2]),

	.sc(sc),
	.force_bs(force_bs),
	.rom_size(ioctl_addr[16:0]),
	.rom_a(rom_addr),
	.rom_do(rom_data),

	.pal(status[1]),
	.p_dif(status[4:3])
);

wire [7:0] R,G,B;
wire hs;
reg  HSync;
wire HBlank, VBlank;
reg VSync;

/*
always @(posedge CLK_VIDEO) begin
	reg       old_vbl;
	reg [2:0] vbl;
	reg [7:0] vblcnt, vspos;
	
	HSync <= hs;
	if(~HSync & hs) begin
		old_vbl <= VBlank;
		
		if(VBlank) vblcnt <= vblcnt+1'd1;
		if(~old_vbl & VBlank) vblcnt <= 0;
		if(old_vbl & ~VBlank) vspos <= (vblcnt>>1) - 8'd10;

		{VSync,vbl} <= {vbl,1'b0};
		if(vblcnt == vspos) {VSync,vbl} <= '1;
	end
end
*/

always @(posedge clk_sys) begin
	reg       old_vbl;
	reg [7:0] vbl;
	
	HSync <= hs;
	if(~HSync & hs) begin
		old_vbl <= VBlank;
		{VSync,vbl} <= {vbl,1'b0};
		if(~old_vbl & VBlank) vbl <= 8'b00111100;
	end
end

wire [2:0] scale = status[7:5];
wire [2:0] sl = scale ? scale - 1'd1 : 3'd0;
wire       scandoubler = scale || forced_scandoubler;

assign VGA_F1 = 0;
assign VGA_SL = sl[1:0];
assign VGA_DE = de & ~(VGA_VS|VGA_HS);

wire de;

video_mixer #(.LINE_LENGTH(250), .GAMMA(1)) video_mixer
(
	.*,
	.clk_vid(CLK_VIDEO),
	.ce_pix(ce_pix),
	.ce_pix_out(CE_PIXEL),

	.scanlines(0),
	.hq2x(scale==1),
	.mono(0),

	.VGA_DE(de)
);

//////////////////   PADDLES   ///////////////////

wire p_1,p_2,p_3,p_4;
wire [7:0] paddle_1,paddle_2,paddle_3,paddle_4;

paddle_ctl p1
(
	.clk(clk_sys),
	.inv(status[11]),

	.stick_btn(joy_0[5]),
	.joy_a(joya_0),

	.paddle_btn(joy_0[6]),
	.paddle(pd_0),

	.ps2_mouse(ps2_mouse),

	.b_out(p_1),
	.a_out(paddle_1)
);

paddle_ctl p2
(
	.clk(clk_sys),
	.inv(status[11]),

	.stick_btn(joy_1[5]),
	.joy_a(joya_1),

	.paddle_btn(joy_1[6]),
	.paddle(pd_1),

	.b_out(p_2),
	.a_out(paddle_2)
);

paddle_ctl p3
(
	.clk(clk_sys),
	.inv(status[11]),

	.stick_btn(joy_2[5]),
	.joy_a(joya_2),

	.paddle_btn(joy_2[6]),
	.paddle(pd_2),

	.b_out(p_3),
	.a_out(paddle_3)
);

paddle_ctl p4
(
	.clk(clk_sys),
	.inv(status[11]),

	.stick_btn(joy_3[5]),
	.joy_a(joya_3),

	.paddle_btn(joy_3[6]),
	.paddle(pd_3),

	.b_out(p_4),
	.a_out(paddle_4)
);

endmodule

module paddle_ctl
(
	input        clk,
	input        inv,

	input        stick_btn,
	input [15:0] joy_a,

	input        paddle_btn,
	input  [7:0] paddle,

	input [24:0] ps2_mouse,
	
	output reg       b_out,
	output reg [7:0] a_out
);

// 0 - paddle, 1 - stick, 2 - mouse
reg [1:0] inp = 0;
reg       xy = 0;

reg  signed [8:0] mx = 0;
wire signed [8:0] mdx = {ps2_mouse[4],ps2_mouse[4],ps2_mouse[15:9]};
wire signed [8:0] mdx2 = (mdx > 10) ? 9'd10 : (mdx < -10) ? -8'd10 : mdx;
wire signed [8:0] nmx = mx + mdx2;

reg  signed [8:0] my = 0;
wire signed [8:0] mdy = {ps2_mouse[5],ps2_mouse[5],ps2_mouse[23:17]};
wire signed [8:0] mdy2 = (mdy > 10) ? 9'd10 : (mdy < -10) ? -9'd10 : mdy;
wire signed [8:0] nmy = my + mdy2;

always @(posedge clk) begin
	reg old_stb = 0;
	reg [7:0] pre_out;

	old_stb <= ps2_mouse[24];
	if(old_stb != ps2_mouse[24]) begin
		inp <= 2;
		mx <= (nmx < -128) ? -9'd128 : (nmx > 127) ? 9'd127 : nmx;
		my <= (nmy < -128) ? -9'd128 : (nmy > 127) ? 9'd127 : nmy;
	end

	if(stick_btn)  inp <= 1;
	if(paddle_btn) inp <= 0;

	if(inp == 2) begin
		if(ps2_mouse[1]) xy <= 1;
		if(ps2_mouse[0]) xy <= 0;
	end

	if(inp == 1) begin
		if(!joy_a[15] && (joy_a[15:8] > 100)) xy <= 1;
		if(!joy_a[7] && (joy_a[7:0] > 100))   xy <= 0;
	end

	case(inp)
		0: pre_out <= {~paddle[7],paddle[6:0]};
		1: pre_out <= xy ? joy_a[15:8] : joy_a[7:0];
		2: pre_out <= xy ? my[7:0] : mx[7:0];
	endcase
	
	a_out <= inv ? ~pre_out : pre_out;

	case(inp)
		0: b_out <= paddle_btn;
		1: b_out <= stick_btn;
		2: b_out <= |ps2_mouse[1:0];
	endcase
end

endmodule
