-- A2601 Main Core
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

library ieee;
use ieee.std_logic_1164.all;

entity A2601 is
	port(
		clk: in std_logic;
		rst: in std_logic;
		do: out std_logic_vector(7 downto 0);
		di: in std_logic_vector(7 downto 0);
		a: out std_logic_vector(12 downto 0);
		r: out std_logic;
		pa: in std_logic_vector(7 downto 0);
		pb: in std_logic_vector(7 downto 0);
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
		ph2_out: out std_logic;
		pal: in std_logic
	);
end A2601;

architecture arch of A2601 is
	signal rdy     : std_logic;
	signal cpu_a   : std_logic_vector(12 downto 0);
	signal read    : std_logic;
	signal ph0     : std_logic;
	signal ph2     : std_logic;
	signal cpu_do  : std_logic_vector(7 downto 0);
	signal tia_do  : std_logic_vector(7 downto 0);
	signal riot_do : std_logic_vector(7 downto 0);
begin

ph0_out <= not clk and ph0;
ph2_out <= ph2;

r <= read;
a <= cpu_a;
do <= cpu_do and tia_do and riot_do when rst = '0' else (others => '0');

cpu_A6507: work.A6507
port map(
	clk     => not clk,
	cen     => ph0,
	rst     => rst,
	rdy     => rdy,
	do      => cpu_do,
	di      => di and tia_do and riot_do,
	ad      => cpu_a,
	r       => read
);

riot_A6532: work.A6532
port map(
	clk     => not clk and ph2,
	res     => rst,
	r       => read,
	rs      => cpu_a(9),
	cs      => not cpu_a(12) and cpu_a(7),
	irq     => open,
	di      => cpu_do,
	do      => riot_do,
	pai     => pa,
	pbi     => pb,
	pa7     => '0',
	a       => cpu_a(6 downto 0)
);

TIA: work.TIA
port map(
	clk        => clk,
	cs         => not cpu_a(12) and not cpu_a(7),
	r          => read,
	a          => cpu_a(5 downto 0),
	di         => cpu_do,
	do         => tia_do,
	colu       => colu,
	hsyn       => hsyn,
	vsyn       => vsyn,
	ohblank    => hblank,
	ovblank    => vblank,
	rgbx2      => rgbx2,
	rdy        => rdy,
	ph0        => ph0,
	ph2        => ph2,
	au0        => au0,
	au1        => au1,
	av0        => av0,
	av1        => av1,
	paddle_0   => paddle_0,
	paddle_1   => paddle_1,
	paddle_ena1=> paddle_ena1,
	paddle_2   => paddle_2,
	paddle_3   => paddle_3,
	paddle_ena2=> paddle_ena2,
	inpt4      => inpt4,
	inpt5      => inpt5,
	pal        => pal
);

end arch;

