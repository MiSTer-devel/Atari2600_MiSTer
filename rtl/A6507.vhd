-- A6500 - 6502 CPU and variants
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
use ieee.numeric_std.ALL;    

entity A6507 is 
	port(
		clk : in  std_logic;
		cen : in  std_logic;
		rst : in  std_logic;
		rdy : in  std_logic;
		do  : out std_logic_vector(7 downto 0);
		di  : in  std_logic_vector(7 downto 0);
		ad  : out std_logic_vector(12 downto 0);
		r   : out std_logic
	);
end A6507;

architecture arch of A6507 is

signal R_W_n : std_logic;
signal addr  : std_logic_vector(23 downto 0);
signal cpuDi : std_logic_vector(7 downto 0);
signal cpuDo : std_logic_vector(7 downto 0);

begin

ad    <= addr(12 downto 0);
do    <= x"00" when rst = '1' else cpuDo when R_W_n = '0' else x"FF";
r     <= R_W_n;
cpuDi <= cpuDo when R_W_n = '0' else di;

cpu : work.T65
port map(
	Mode    => "00",
	Res_n   => not rst,
	Enable  => cen,
	Clk     => clk,
	Rdy     => rdy,
	Abort_n => '1',
	IRQ_n   => '1',
	NMI_n   => '1',
	SO_n    => '1',
	R_W_n   => R_W_n,
	A       => addr,
	DI      => cpuDi,
	DO      => cpuDo
);

end arch;
