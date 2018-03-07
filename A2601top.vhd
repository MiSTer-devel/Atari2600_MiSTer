-- A2601 Top Level Entity (ROM stored in on-chip RAM)
-- Copyright 2006, 2010 Retromaster
--
--  This file is part of A2601.
--
--  A2601 is free software: you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation, either version 3 of the License,
--  or any later version.
--
--  A2601 is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with A2601.  If not, see <http://www.gnu.org/licenses/>.
--

-- This top level entity supports a single cartridge ROM stored in FPGA built-in
-- memory (such as Xilinx Spartan BlockRAM). To generate the required cart_rom
-- entity, use bin2vhdl.py found in the util directory.
--
-- For more information, see the A2601 Rev B Board Schematics and project
-- website at <http://retromaster.wordpress.org/a2601>.

library std;
use std.textio.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity A2601top is
   port (
		reset     : in std_logic;
		clk       : in std_logic;
		clk_vid   : in std_logic;

		audio     : out std_logic_vector(4 downto 0);

		O_VSYNC   : out std_logic;
		O_HSYNC   : out std_logic;
		O_HBLANK  : out std_logic;
		O_VBLANK  : out std_logic;
		O_VIDEO_R : out std_logic_vector(5 downto 0);
		O_VIDEO_G : out std_logic_vector(5 downto 0);
		O_VIDEO_B : out std_logic_vector(5 downto 0);			

		p_l       : in std_logic;
		p_r       : in std_logic;
		p_u       : in std_logic;
		p_d       : in std_logic;
		p_f       : in std_logic;

		p2_l      : in std_logic;
		p2_r      : in std_logic;
		p2_u      : in std_logic;
		p2_d      : in std_logic;
		p2_f      : in std_logic;

		p_a       : in std_logic;
		p_b       : in std_logic;
		paddle_0  : in std_logic_vector(7 downto 0);
		paddle_1  : in std_logic_vector(7 downto 0);
		
		p2_a      : in std_logic;
		p2_b      : in std_logic;
		paddle_2  : in std_logic_vector(7 downto 0);
		paddle_3  : in std_logic_vector(7 downto 0);

		p_start   : in std_logic;
		p_select  : in std_logic;
		p_color   : in std_logic;

		cart_size : in std_logic_vector(19 downto 0);
		ram_addr  : out std_logic_vector(15 downto 0);
		ram_data  : in std_logic_vector(7 downto 0);

		pal       : in std_logic;
		p_dif     : in std_logic_vector(1 downto 0)
	);
end A2601top;

architecture arch of A2601top is

    component A2601 is
		port(
			clk: in std_logic;
			clk_vid: in std_logic;
         rst: in std_logic;
         d: inout std_logic_vector(7 downto 0);
         a: out std_logic_vector(12 downto 0);
         r: out std_logic;
         pa: inout std_logic_vector(7 downto 0);
         pb: inout std_logic_vector(7 downto 0);
         paddle_0: in std_logic_vector(7 downto 0);
         paddle_1: in std_logic_vector(7 downto 0);
         paddle_ena1: in std_logic;
         paddle_2: in std_logic_vector(7 downto 0);
         paddle_3: in std_logic_vector(7 downto 0);
         paddle_ena2: in std_logic;
         inpt4: in std_logic;
         inpt5: in std_logic;
         colu: out std_logic_vector(6 downto 0);
         vsyn: out std_logic;
         hsyn: out std_logic;
			hblank: out std_logic;
			vblank: out std_logic;
			rgbx2: out std_logic_vector(23 downto 0);
         au0: out std_logic;
         au1: out std_logic;
         av0: out std_logic_vector(3 downto 0);
         av1: out std_logic_vector(3 downto 0);
         ph0_out: out std_logic;
         ph1_out: out std_logic;
         pal: in std_logic
		);
    end component;
	
    component ram128x8 is
        port(clk: in std_logic;
             r: in std_logic;
             d_in: in std_logic_vector(7 downto 0);
             d_out: out std_logic_vector(7 downto 0);
             a: in std_logic_vector(6 downto 0));
    end component;
    
    component ram256x8 is
        port(clk: in std_logic;
             r: in std_logic;
             d_in: in std_logic_vector(7 downto 0);
             d_out: out std_logic_vector(7 downto 0);
             a: in std_logic_vector(7 downto 0));
    end component;

    signal a: std_logic_vector(14 downto 0);
    signal pa: std_logic_vector(7 downto 0);
    signal pb: std_logic_vector(7 downto 0);
    signal inpt4: std_logic;
    signal inpt5: std_logic;
    signal au0: std_logic;
    signal au1: std_logic;
    signal av0: std_logic_vector(3 downto 0);
    signal av1: std_logic_vector(3 downto 0);

    signal auv0: unsigned(4 downto 0);
    signal auv1: unsigned(4 downto 0);

    signal rst: std_logic := '1';
    signal sys_clk_dvdr: unsigned(4 downto 0) := "00000";

    signal ph0: std_logic;
    signal ph1: std_logic;
	 
    signal rgbx2: std_logic_vector(23 downto 0);
    signal hsyn: std_logic;
    signal vsyn: std_logic;
	 
	 signal ctrl_cntr: unsigned(3 downto 0);

	 signal rst_cntr: unsigned(12 downto 0) := "0000000000000";
	 signal sc_clk: std_logic;
    signal sc_r: std_logic;
    signal sc_d_in: std_logic_vector(7 downto 0);
    signal sc_d_out: std_logic_vector(7 downto 0);
    signal sc_a: std_logic_vector(6 downto 0);

    subtype bss_type is std_logic_vector(3 downto 0);

    signal bank: std_logic_vector(3 downto 0) := "0000";
    signal tf_bank: std_logic_vector(1 downto 0);
    signal e0_bank: std_logic_vector(2 downto 0);
    signal e0_bank0: std_logic_vector(2 downto 0) := "000";
    signal e0_bank1: std_logic_vector(2 downto 0) := "000";
    signal e0_bank2: std_logic_vector(2 downto 0) := "000";

    signal f0_bank: std_logic_vector(3 downto 0) := "0000";

    signal cpu_a: std_logic_vector(12 downto 0);
    signal cpu_d: std_logic_vector(7 downto 0);
	
    constant BANK00: bss_type := "0000";
    constant BANKF8: bss_type := "0001";
    constant BANKF6: bss_type := "0010";
    constant BANKFE: bss_type := "0011";
    constant BANKE0: bss_type := "0100";
    constant BANK3F: bss_type := "0101";
    constant BANKF4: bss_type := "0110";
    constant BANKF0: bss_type := "0111";
    constant BANKFA: bss_type := "1000";

    signal bss:  bss_type := BANK00; 	--bank switching method
    signal bss2: bss_type := BANK00; 	--bank switching method
    signal sc: std_logic := '0';		--superchip enabled or not
  
    signal paddle_ena1 : std_logic := '0';
    signal paddle_ena2 : std_logic := '0';
	 
	 signal cpu_r : std_logic;

begin
	  
	ms_A2601: A2601
        port map(clk, clk_vid, rst, cpu_d, cpu_a, cpu_r, pa, pb, 
				paddle_0, paddle_1, paddle_ena1, paddle_2, paddle_3, paddle_ena2,
				inpt4, inpt5, open, vsyn, hsyn, O_HBLANK, O_VBLANK, rgbx2, 
				au0, au1, av0, av1, ph0, ph1, pal);
	
	
  O_VIDEO_R <= rgbx2(23 downto 18);
  O_VIDEO_G <= rgbx2(15 downto 10);
  O_VIDEO_B <= rgbx2(7 downto 2);	
  O_HSYNC   <= hsyn;
  O_VSYNC   <= vsyn;

 process(ph0)
    begin
        if (ph0'event and ph0 = '1') then
			if reset = '1' then
				rst <= '1';
			else
				rst <= '0';
			end if;
		end if;
            
    end process;

	process(clk) begin
		if rising_edge(clk) then
			if p_f = '0'  then paddle_ena1 <= '0'; end if;
			if p_a = '0'  or p_b = '0'  then paddle_ena1 <= '1'; end if;
			if p2_f = '0' then paddle_ena2 <= '0'; end if;
			if p2_a = '0' or p2_b = '0' then paddle_ena2 <= '1'; end if;
		end if;
	end process;
	 
    process(ph0)
    begin
        if (ph0'event and ph0 = '1') then
            ctrl_cntr <= ctrl_cntr + 1;
            if (ctrl_cntr = "1111") then
                pb(0) <= p_start; 
                pb(1) <= p_select; 
            elsif (ctrl_cntr = "0111") then
					 if ( paddle_ena1 = '0' ) then
					   -- normal mapping
						pa(7 downto 4) <= p_r & p_l & p_d & p_u;
						inpt4 <= p_f;
					 else
					   -- fire button mapping when paddles are used
						pa(7 downto 4) <= p_a & p_b & "11";
						inpt4 <= '1';
					 end if;
					 if ( paddle_ena2 = '0' ) then
					   -- normal mapping
						pa(3 downto 0) <= p2_r & p2_l & p2_d & p2_u;
						inpt5 <= p2_f;
					 else
					   -- fire button mapping when paddles are used
						pa(3 downto 0) <= p2_a & p2_b & "11";
						inpt5 <= '1';
					 end if;
           end if;
        end if;
    end process;
    
    pb(3) <= p_color;  --b/w / colour
    pb(6) <= p_dif(0); -- p1/left difficulty
    pb(7) <= p_dif(1); -- p2/right difficulty
    pb(5) <= '1'; --nc ?
    pb(4) <= '1'; --nc
    pb(2) <= '1'; --nc
	 	 
    auv0 <= ("0" & unsigned(av0)) when (au0 = '1') else "00000";
    auv1 <= ("0" & unsigned(av1)) when (au1 = '1') else "00000";

    audio <= std_logic_vector(auv0 + auv1);

    sc_ram256x8: ram256x8
        port map(sc_clk, sc_r, cpu_d, sc_d_out, cpu_a(7 downto 0));

    -- This clock is phase shifted so that we can use Xilinx synchronous block RAM.
    sc_clk <= not ph1;
    sc_r <= '0' when cpu_a(12 downto 8) = "10000" and bss = BANKFA else '1';

    -- ROM and SC output
    process(cpu_a, ram_data, sc_d_out, sc, reset)
    begin
        if(reset = '1') then
            cpu_d <= x"FF";
        elsif (cpu_a(12 downto 8) = "10001" and bss = BANKFA) then
            cpu_d <= sc_d_out;
        elsif (cpu_a(12 downto 8) = "10000" and bss = BANKFA) then
            cpu_d <= "ZZZZZZZZ";
        elsif (cpu_a(12) = '1') then
            cpu_d <= ram_data;
        else
            cpu_d <= "ZZZZZZZZ";
        end if;
    end process;

    with cpu_a(11 downto 10) select e0_bank <=
        e0_bank0 when "00",
        e0_bank1 when "01",
        e0_bank2 when "10",
        "111" when "11",
        "---" when others;

    tf_bank <= bank(1 downto 0) when (cpu_a(11) = '0') else "11";

    with bss select ram_addr <=
		  "0000" & cpu_a(11 downto 0) when BANK00,
		  "000" & bank(0) & cpu_a(11 downto 0) when BANKF8,
		  "00" & bank(1 downto 0) & cpu_a(11 downto 0) when BANKFA,
		  "00" & bank(1 downto 0) & cpu_a(11 downto 0) when BANKF6,
        '0' & bank(2 downto 0) & cpu_a(11 downto 0) when BANKF4,
		  "000" & bank(0) & cpu_a(11 downto 0) when BANKFE,
		  "000" & e0_bank & cpu_a(9 downto 0) when BANKE0,
		  "000" & tf_bank & cpu_a(10 downto 0) when BANK3F,
		          f0_bank & cpu_a(11 downto 0) when BANKF0,
		  "----------------" when others;

    bankswch: process(ph0)
    begin
        if (ph0'event and ph0 = '1') then
            if (rst = '1') then
                bank <= "0000";
                e0_bank0 <= "000";
                e0_bank1 <= "000";
                e0_bank2 <= "000";
            else
                case bss is
                    when BANKFA =>
                        if (cpu_a = "1" & X"FF8") then
                            bank <= "0000";
                        elsif (cpu_a = "1" & X"FF9") then
                            bank <= "0001";
                        elsif (cpu_a = "1" & X"FFA") then
                            bank <= "0010";
                        end if;
                    when BANKF8 =>
                        if (cpu_a = "1" & X"FF8") then
                            bank <= "0000";
                        elsif (cpu_a = "1" & X"FF9") then
                            bank <= "0001";
                        end if;
                    when BANKF6 =>
                        if (cpu_a = "1" & X"FF6") then
                            bank <= "0000";
                        elsif (cpu_a = "1" & X"FF7") then
                            bank <= "0001";
                        elsif (cpu_a = "1" & X"FF8") then
                            bank <= "0010";
                        elsif (cpu_a = "1" & X"FF9") then
                            bank <= "0011";
                        end if;
                    when BANKF4 =>
                        if (cpu_a = "1" & X"FF4") then
                            bank <= "0000";
                        elsif (cpu_a = "1" & X"FF5") then
                            bank <= "0001";
                        elsif (cpu_a = "1" & X"FF6") then
                            bank <= "0010";
                        elsif (cpu_a = "1" & X"FF7") then
                            bank <= "0011";
                        elsif (cpu_a = "1" & X"FF8") then
                            bank <= "0100";
                        elsif (cpu_a = "1" & X"FF9") then
                            bank <= "0101";
                        elsif (cpu_a = "1" & X"FFA") then
                            bank <= "0110";
                        elsif (cpu_a = "1" & X"FFB") then
                            bank <= "0111";
                        end if;
                    when BANKFE =>
                        if (cpu_a = "0" & X"1FE") then
                            bank <= "0000";
                        elsif (cpu_a = "1" & X"1FE") then
                            bank <= "0001";
                        end if;
                    when BANKE0 =>
                        if (cpu_a(12 downto 4) = "1" & X"FE" and cpu_a(3) = '0') then
                            e0_bank0 <= cpu_a(2 downto 0);
                        elsif (cpu_a(12 downto 4) = "1" & X"FE" and cpu_a(3) = '1') then
                            e0_bank1 <= cpu_a(2 downto 0);
                        elsif (cpu_a(12 downto 4) = "1" & X"FF" and cpu_a(3) = '0') then
                            e0_bank2 <= cpu_a(2 downto 0);
                        end if;
                    when BANK3F =>
                        if (cpu_a = "0" & X"03F") then
                            bank(1 downto 0) <= cpu_d(1 downto 0);
                        end if;
                    when BANKF0 =>
                        if (cpu_a = "1" & X"FF0") then
                            f0_bank <= std_logic_vector(unsigned(f0_bank)+1);
                        end if;
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process;

	 -- derive banking scheme from cartridge size
    process(cart_size)
    begin
      if(cart_size <= x"01000") then    -- 4k and less
        bss <= BANK00;
      elsif(cart_size <= x"02000") then -- 8k and less
        bss <= BANKF8;
      elsif(cart_size <= x"03000") then -- 12k and less
        bss <= BANKFA;
      elsif(cart_size <= x"04000") then -- 16k and less
        bss <= BANKF6;
      elsif(cart_size <= x"08000") then -- 32k and less
        bss <= BANKF4;
      elsif(cart_size  = x"10000") then -- 64k
        bss <= BANKF0;
      else
        bss <= BANK00;
      end if;
    end process;

end arch;



