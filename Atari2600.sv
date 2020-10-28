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

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
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

assign VIDEO_ARX = status[14] ? 8'd16 : 8'd154;
assign VIDEO_ARY = status[14] ? 8'd9  : status[13] ? 8'd108 : adaptive_ary;

// Status Bit Map:
// 0         1         2         3
// 01234567890123456789012345678901
// 0123456789ABCDEFGHIJKLMNOPQRSTUV
// XXXXXXXX XXXXXXXXXX

`include "build_id.v" 
localparam CONF_STR = {
	"ATARI2600;;",
	"F,*;",
	"O9A,SuperChip,Auto,Disable,Enable;",
	"-;",
	"O1,Colors,NTSC,PAL;",
	"O2,Video mode,Color,Mono;",
	"OC,VBlank,Regenerate,Original;",
	"OG,De-comb,Off,On;",
	"ODE,Aspect ratio,Adaptive,Fixed,Wide;",
	"O57,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"-;",
	"OHI,Audio,Mono,Stereo 100%,Stereo 75%,Stereo 50%;",
	"-;",
	"O3,Difficulty P1,B,A;",
	"O4,Difficulty P2,B,A;",
	"-;",
	"OF,Swap Joystick,No,Yes;",
	"OB,Invert Paddle,No,Yes;",
	"-;",
	"R0,Reset;",
	"J1,Fire 1,Stick Btn,Paddle Btn,Game Reset,Game Select,Pause,Fire 2,Switch B/W,P1 difficulty,P2 difficulty;",
	"jn,A,B,X|P,Start,Select,L,Y;",
	"jp,A,B,X|P,Start,Select,L,Y;",
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
reg  [31:0] status_in;
reg         status_set;

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
	.status_in(status_in),
	.status_set(status_set),
	
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

(* ram_init_file = "rtl/rom.mif" *)
reg [7:0] rom[65536];
always @(posedge clk_sys) if(ioctl_wr && !ioctl_addr[24:16]) rom[ioctl_addr[15:0]] <= ioctl_dout;

reg  [15:0] rom_a;
always @(posedge clk_cpu) rom_a <= rom_addr;

wire [15:0] rom_addr;
wire  [7:0] rom_data = rom[rom_a];


wire [23:0] ext = (ioctl_file_ext[23:16] == ".") ? ioctl_file_ext[23:0] : ioctl_file_ext[31:8];

reg [3:0] force_bs = 0;
reg sc = 0;
always @(posedge clk_sys) begin
	reg old_download;

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
		if (ext == ".E7") force_bs <= 12;
		if (ext == ".F0") force_bs <= 13;
		if (ext == ".32") force_bs <= 14;

		sc <= (!status[10:9]) ? (ioctl_file_ext[7:0] == "S") : status[10];
	end
end

wire [3:0] aud0,aud1;
assign AUDIO_R = {4{aud1}};
assign AUDIO_L = {4{aud0}};
assign AUDIO_S = 0;
assign AUDIO_MIX = status[18:17] + 2'd3;

A2601top A2601top
(
	.reset(reset),
	.clk(clk_cpu),
	.vid_clk(clk_sys),

	.aud0(aud0),
	.aud1(aud1),

	.O_VSYNC(vs),
	.O_HSYNC(hs),
	.O_HBLANK(HBlank),
	.O_VBLANK(vb),
	.O_VIDEO_R(R),
	.O_VIDEO_G(G),
	.O_VIDEO_B(B),

	.p1_r(status[15] ? ~joy_1[0] : ~joy_0[0]),
	.p1_l(status[15] ? ~joy_1[1] : ~joy_0[1]),
	.p1_d(status[15] ? ~joy_1[2] : ~joy_0[2]),
	.p1_u(status[15] ? ~joy_1[3] : ~joy_0[3]),
	.p1_f(status[15] ? ~joy_1[4] : ~joy_0[4]),
	.p1_f2(status[15]? ~joy_1[10]: ~joy_0[10]),

	.p2_r(status[15] ? ~joy_0[0] : ~joy_1[0]),
	.p2_l(status[15] ? ~joy_0[1] : ~joy_1[1]),
	.p2_d(status[15] ? ~joy_0[2] : ~joy_1[2]),
	.p2_u(status[15] ? ~joy_0[3] : ~joy_1[3]),
	.p2_f(status[15] ? ~joy_0[4] : ~joy_1[4]),
	.p2_f2(status[15]? ~joy_0[10]: ~joy_1[10]),

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

	.pause(pause),

	.pal(status[1]),
	.p_dif(status[4:3]),
	.decomb(status[16])
);

wire [7:0] R,G,B;
wire hs, vs;
reg  HSync, VSync;
wire HBlank;
wire VBlank = status[12] ? vb : vbl_gen;
wire vb;
reg  vbl_gen;
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

wire [7:0] vertical_ar_lut[256] = '{
	8'h00, 8'h01, 8'h01, 8'h02, 8'h02, 8'h03, 8'h03, 8'h04,
	8'h05, 8'h05, 8'h06, 8'h06, 8'h07, 8'h07, 8'h08, 8'h08,
	8'h09, 8'h0A, 8'h0A, 8'h0B, 8'h0B, 8'h0C, 8'h0C, 8'h0D,
	8'h0E, 8'h0E, 8'h0F, 8'h0F, 8'h10, 8'h10, 8'h11, 8'h11,
	8'h12, 8'h13, 8'h13, 8'h14, 8'h14, 8'h15, 8'h15, 8'h16,
	8'h17, 8'h17, 8'h18, 8'h18, 8'h19, 8'h19, 8'h1A, 8'h1A,
	8'h1B, 8'h1C, 8'h1C, 8'h1D, 8'h1D, 8'h1E, 8'h1E, 8'h1F,
	8'h1F, 8'h20, 8'h21, 8'h21, 8'h22, 8'h22, 8'h23, 8'h23,
	8'h24, 8'h25, 8'h25, 8'h26, 8'h26, 8'h27, 8'h27, 8'h28,
	8'h28, 8'h29, 8'h2A, 8'h2A, 8'h2B, 8'h2B, 8'h2C, 8'h2C,
	8'h2D, 8'h2E, 8'h2E, 8'h2F, 8'h2F, 8'h30, 8'h30, 8'h31,
	8'h31, 8'h32, 8'h33, 8'h33, 8'h34, 8'h34, 8'h35, 8'h35,
	8'h36, 8'h37, 8'h37, 8'h38, 8'h38, 8'h39, 8'h39, 8'h3A,
	8'h3B, 8'h3B, 8'h3C, 8'h3C, 8'h3D, 8'h3D, 8'h3E, 8'h3E,
	8'h3F, 8'h40, 8'h40, 8'h41, 8'h41, 8'h42, 8'h42, 8'h43,
	8'h44, 8'h44, 8'h45, 8'h45, 8'h46, 8'h46, 8'h47, 8'h47,
	8'h48, 8'h49, 8'h49, 8'h4A, 8'h4A, 8'h4B, 8'h4B, 8'h4C,
	8'h4D, 8'h4D, 8'h4E, 8'h4E, 8'h4F, 8'h4F, 8'h50, 8'h50,
	8'h51, 8'h52, 8'h52, 8'h53, 8'h53, 8'h54, 8'h54, 8'h55,
	8'h56, 8'h56, 8'h57, 8'h57, 8'h58, 8'h58, 8'h59, 8'h59,
	8'h5A, 8'h5B, 8'h5B, 8'h5C, 8'h5C, 8'h5D, 8'h5D, 8'h5E,
	8'h5E, 8'h5F, 8'h60, 8'h60, 8'h61, 8'h61, 8'h62, 8'h62,
	8'h63, 8'h64, 8'h64, 8'h65, 8'h65, 8'h66, 8'h66, 8'h67,
	8'h68, 8'h68, 8'h69, 8'h69, 8'h6A, 8'h6A, 8'h6B, 8'h6B,
	8'h6C, 8'h6D, 8'h6D, 8'h6E, 8'h6E, 8'h6F, 8'h6F, 8'h70,
	8'h71, 8'h71, 8'h72, 8'h72, 8'h73, 8'h73, 8'h74, 8'h74,
	8'h75, 8'h76, 8'h76, 8'h77, 8'h77, 8'h78, 8'h78, 8'h79,
	8'h7A, 8'h7A, 8'h7B, 8'h7B, 8'h7C, 8'h7C, 8'h7D, 8'h7D,
	8'h7E, 8'h7F, 8'h7F, 8'h80, 8'h80, 8'h81, 8'h81, 8'h82,
	8'h83, 8'h83, 8'h84, 8'h84, 8'h85, 8'h85, 8'h86, 8'h86,
	8'h87, 8'h88, 8'h88, 8'h89, 8'h89, 8'h8A, 8'h8A, 8'h8B,
	8'h8C, 8'h8C, 8'h8D, 8'h8D, 8'h8E, 8'h8E, 8'h8F, 8'h8F
};

reg [7:0] adaptive_ary = 8'd108;

always @(posedge clk_sys) begin
	reg [8:0] line_cnt, vblank_start, visible_cnt;

	HSync <= hs;
	if(~HSync & hs) begin
		VSync <= vs;
		line_cnt <= line_cnt + 1'b1;
		if (~VBlank)
			visible_cnt <= visible_cnt + 1'b1;

		if (~VSync & vs) begin
			line_cnt <= 0;
			visible_cnt <= 0;
			if (visible_cnt < 255)
				adaptive_ary <= vertical_ar_lut[visible_cnt[7:0]];
			else
				adaptive_ary <= vertical_ar_lut[255];

			vblank_start <= line_cnt - 9'd25;
		end

		if (line_cnt == vblank_start) begin
			vbl_gen <= 1'b1;
		end

		if (line_cnt == 9'd34) begin
			vbl_gen <= 0;
		end
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

wire pause_btn = joy_0[9] | joy_1[9] | joy_2[9] | joy_3[9];

reg pause = 0;
always @(posedge clk_cpu) begin
	reg old_p2,old_p1;
	
	old_p1 <= pause_btn;
	old_p2 <= old_p1;
	
	if(~old_p2 & old_p1) pause <= ~pause;

	if(reset) pause <= 0;
end

wire [2:0] sw_ctl = joy_0[13:11] | joy_1[13:11];

always @(posedge clk_sys) begin
	reg [2:0] old_sw;
	
	status_set <= 0;

	old_sw <= sw_ctl;
	if(~old_sw[0] & sw_ctl[0]) begin
		status_set <= 1;
		status_in <= status;
		status_in[2] <= ~status[2];
	end
	
	if(~old_sw[1] & sw_ctl[1]) begin
		status_set <= 1;
		status_in <= status;
		status_in[3] <= ~status[3];
	end

	if(~old_sw[2] & sw_ctl[2]) begin
		status_set <= 1;
		status_in <= status;
		status_in[4] <= ~status[4];
	end
end

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
