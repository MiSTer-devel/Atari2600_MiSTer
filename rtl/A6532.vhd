-- A6532 RAM-I/O-Timer (RIOT)
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ramx8 is
generic(addr_width : integer := 7);
port(
	clk   : in  std_logic;
	r     : in  std_logic;
	d_in  : in  std_logic_vector(7 downto 0);
	d_out : out std_logic_vector(7 downto 0);
	a     : in  std_logic_vector(addr_width - 1 downto 0));
end ramx8;

architecture arch of ramx8 is
	type ram_type is array (0 to 2**addr_width - 1) of std_logic_vector(7 downto 0);
	signal ram: ram_type;
begin
	process (clk, r, a)
	begin
		if rising_edge(clk) then
			if (r = '1') then
				d_out <= ram(to_integer(unsigned(a)));
			else
				ram(to_integer(unsigned(a))) <= d_in;
			end if;
		end if;
	end process;
end arch;

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity A6532 is
port(
	clk : in  std_logic;
	res : in  std_logic; 
	r   : in  std_logic;
	rs  : in  std_logic;
	cs  : in  std_logic;
	irq : out std_logic;
	di  : in  std_logic_vector(7 downto 0);
	do  : out std_logic_vector(7 downto 0);
	pai : in  std_logic_vector(7 downto 0);
	pbi : in  std_logic_vector(7 downto 0);
	pa7 : in  std_logic;
	a   : in  std_logic_vector(6 downto 0));
end A6532;

architecture arch of A6532 is

	signal pa_reg: std_logic_vector(7 downto 0) := "00000000";
	signal pb_reg: std_logic_vector(7 downto 0) := "00000000";
	signal pa_ddr: std_logic_vector(7 downto 0) := "00000000";
	signal pb_ddr: std_logic_vector(7 downto 0) := "00000000";
	signal pa_in: std_logic_vector(7 downto 0);
	signal pb_in: std_logic_vector(7 downto 0);

	signal timer: std_logic_vector(7 downto 0) := "00000000";
	signal timer_write: std_logic;
	signal timer_read: std_logic;
	signal timer_intr: std_logic := '0';
	signal timer_intvl: std_logic_vector(1 downto 0) := "11";
	signal timer_dvdr: std_logic_vector(10 downto 0) := "00000000001";
	signal timer_inc: std_logic;
	signal timer_irq_en: std_logic := '0';

	signal edge_pol: std_logic := '0';
	signal edge_irq_en: std_logic := '0';
	signal edge_intr_lo: std_logic := '0';
	signal edge_intr_hi: std_logic := '0';
	signal edge_intr: std_logic;

	signal intr_read: std_logic;

	signal ram_d_out: std_logic_vector(7 downto 0);
	signal ram_r : std_logic;
	signal ram_a : std_logic_vector(6 downto 0);
	signal clr_a : std_logic_vector(6 downto 0);

begin
	io: for i in 0 to 7 generate
		pa_in(i) <= pai(i);
		pb_in(i) <= pbi(i) when pb_ddr(i) = '0' else pb_reg(i);
	end generate;

	ram: work.ramx8 port map(clk, ram_r, di, ram_d_out, ram_a);

	ram_r <= ((not rs and r) or rs or not cs) and not res;
	ram_a <= a when res = '0' else clr_a;
	clr_a <= clr_a + 1 when rising_edge(clk);

	timer_write <= (not r) and rs and a(2) and a(4) and cs;
	timer_read <= r and rs and a(2) and (not a(0)) and cs;
	intr_read <=  r and rs and a(0) and a(2) and cs;

	irq <= not ((timer_intr and timer_irq_en) or (edge_intr and edge_irq_en));
	edge_intr <= edge_intr_lo when edge_pol = '0' else edge_intr_hi;

	process(cs, r, rs, a, ram_d_out, pa_in, pa_ddr, pb_in, pb_ddr, timer, timer_intr, edge_intr)
	begin
		if r = '1' then
			if (cs = '0') then
				do <= x"FF";
			elsif rs = '0' then
				do <= ram_d_out;
			elsif a(2) = '0' then
				case a(1 downto 0) is
					when "00" => do <= pa_in;
					when "01" => do <= pa_ddr;
					when "10" => do <= pb_in;
					when "11" => do <= pb_ddr;
					when others => null;
				end case;
			elsif a(0) = '0' then
				do <= timer;
			elsif a(0) = '1' then
				do <= timer_intr & edge_intr & "000000";
			else
				do <= x"FF";
			end if;
		else
			do <= x"FF";
		end if;
	end process;

	process(clk, res)
	begin
		if res = '1' then
			--pa_reg <= x"00";
			pa_ddr <= x"00";
			pb_reg <= x"00";
			pb_ddr <= x"00";
			edge_pol <= '0';
			edge_irq_en <= '0';
		elsif rising_edge(clk) then
			if (cs = '1' and rs = '1') then
				if a(2) = '0' then
					case a(1 downto 0) is
						--when "00" => pa_reg <= di;
						when "01" => pa_ddr <= di;
						when "10" => pb_reg <= di;
						when "11" => pb_ddr <= di;
						when others => null;
					end case;
				elsif a(4) = '0' then
					edge_pol <= a(0);
					edge_irq_en <= a(1);
				end if;
			end if;
		end if;
	end process;

	process(pa7, intr_read)
	begin
		if (intr_read = '1') then
			edge_intr_lo <= '0';
		elsif (pa7'event and pa7 = '1') then
			edge_intr_lo <= '1';
		end if;

		if (intr_read = '1') then
			edge_intr_hi <= '0';
		elsif (pa7'event and pa7 = '0') then
			edge_intr_hi <= '1';
		end if;
	end process;

	with timer_intvl select timer_inc <=
		  timer_dvdr(0) when "00",
		  timer_dvdr(3) when "01",
		  timer_dvdr(6) when "10",
		  timer_dvdr(10) when "11",
		  '-' when others;

	process(clk, res)
	begin
		if res = '1' then
			timer <= x"00";
			timer_intr <= '0';
			timer_intvl <= "11";
			timer_irq_en <= '0';
			timer_dvdr <= "00000000001";
		elsif rising_edge(clk) then
			if (timer_inc = '1') then
				timer_dvdr <= "00000000001";
			else
				timer_dvdr <= timer_dvdr + 1;
			end if;

			if (timer_write = '1') then
				timer <= di - 1;
				timer_intvl <= a(1 downto 0);
				timer_irq_en <= a(3);
				timer_dvdr <= "00000000001";
			elsif (timer_intr = '0') then
				timer <= timer - timer_inc;
			elsif (not (timer = X"00")) then
				timer <= timer - 1;
			end if;

			if (timer = X"00" and timer_inc = '1' and timer_intr = '0' and timer_write = '0') then
				timer_intr <= '1';
			elsif (timer_read = '1' or timer_write = '1') then
				timer_intr <= '0';
			end if;
		end if;
	end process;
end arch;
