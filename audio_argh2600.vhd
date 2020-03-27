-- Copyright (c) 2014, Juha Turunen
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met: 
--
-- 1. Redistributions of source code must retain the above copyright notice, this
--    list of conditions and the following disclaimer. 
-- 2. Redistributions in binary form must reproduce the above copyright notice,
--    this list of conditions and the following disclaimer in the documentation
--    and/or other materials provided with the distribution. 
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
-- ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
-- LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
-- ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity audio_argh2600 is 
port 
(
	clk : in std_logic;
	clk_audio : in std_logic;
	freq : in std_logic_vector(4 downto 0); 	-- AUDF
	ctrl : in std_logic_vector(3 downto 0); 	-- AUDC
	output : out std_logic
);
end audio_argh2600;

architecture Behavioral of audio_argh2600 is

signal w: std_logic;
signal f_counter : std_logic_vector(4 downto 0) := (others=>'0'); 
signal toggled, toggled_next : std_logic;

signal cnt3, cnt3_next : std_logic_vector(1 downto 0);
signal cnt3_ena : std_logic;

signal lfsr4, lfsr4_next : std_logic_vector(3 downto 0);
signal lfsr5, lfsr5_next : std_logic_vector(4 downto 0);
signal lfsr9, lfsr9_next : std_logic_vector(8 downto 0);
signal lfsr4_clk_audio : std_logic;
signal lfsr4_out, lfsr5_out, lfsr9_out : std_logic;
signal lfsr5_edge : std_logic;

signal div31_edge, div6_edge : std_logic;

begin
	process(clk, clk_audio)

	-- prescalers
	begin
		if (clk'event and clk = '1' and clk_audio = '1') then

				if (f_counter = freq) then

						f_counter <= "00000";

						if (lfsr4_clk_audio = '1') then
							lfsr4 <= lfsr4_next;
						end if;

						lfsr5 <= lfsr5_next;
						lfsr9 <= lfsr9_next;
						toggled <= toggled_next;

						if (cnt3_ena = '1') then
							cnt3 <= cnt3_next;
						end if;

				else

						f_counter <= f_counter + 1;

				end if;

		end if;
	end process;

	lfsr5_edge <= '1' when 
							--(lfsr5(1 downto 0) = "10" or lfsr5(1 downto 0) = "01") -- original
							--lfsr5(4 downto 2) = "100"
							lfsr5(4 downto 1) = "0110"
							else '0';

	div31_edge <= '1' when lfsr5 = "11111" or lfsr5 = "10000" else '0';
	div6_edge  <= '1' when cnt3 = "10" else '0';


	-- The Audio Control register generates and manipulates a pulse wave to create complex pulses or noise. The following table (with designed duplicates) explains how its tones are generated:
	-- 
	-- HEX	D7	D6	D5	D4	D3	D2	D1	D0	Type of noise or division
	-- 0					0	0	0	0	Set to 1 (volume only)
	-- 1					0	0	0	1	4 bit poly
	-- 2					0	0	1	0	÷ 15 → 4 bit poly
	-- 3					0	0	1	1	5 bit poly → 4 bit poly
	-- 4					0	1	0	0	÷ 2
	-- 5					0	1	0	1	÷ 2
	-- 6					0	1	1	0	÷ 31
	-- 7					0	1	1	1	5 bit poly → ÷ 2
	-- 8					1	0	0	0	9-bit poly (white noise)
	-- 9					1	0	0	1	5-bit poly
	-- A					1	0	1	0	÷ 31
	-- B					1	0	1	1	Set last 4 bits to 1
	-- C					1	1	0	0	÷ 6
	-- D					1	1	0	1	÷ 6
	-- E					1	1	1	0	÷ 93
	-- F					1	1	1	1	5-bit poly ÷ 6


	process (ctrl, toggled, lfsr4_out, lfsr5_out, lfsr9_out, lfsr5_edge, div31_edge, div6_edge)
	begin

		lfsr4_clk_audio <= '1';
		toggled_next <= toggled;
		cnt3_ena <= '1';

		case ctrl is 

			when "0000" => 		-- 0
				w <= '1';

			when "0001" => 		-- 1            	-- 1, 2, 3, queda, corda, morte no pitfall
				w <= lfsr4_out;

			when "0010" => 		-- 2
				w <= lfsr4_out;
				lfsr4_clk_audio <= div31_edge;

			when "0011" => 		-- 3
				w <= lfsr4_out;
				lfsr4_clk_audio <= lfsr5_out;

			when "0100" => 		-- 4     			-- 4, 5, 6, nada no sequest
				w <= toggled;
				toggled_next <= not toggled;

			when "0101" => 		-- 5
				w <= toggled;
				toggled_next <= not toggled;

			when "0110" => 		-- 6
				w <= toggled;
				if (div31_edge = '1') then
					toggled_next <= not toggled;
				end if;

			when "0111" => 		-- 7              -- 7, 8, 9, tronco no pitfall, ar e explosao no sequest
				w <= lfsr5_out;

			when "1000" =>			-- 8
				w <= lfsr9_out;

			when "1001" =>			-- 9
				w <= lfsr5_out;

			when "1010" =>			-- A     			-- a, b, c, morte do peixe no seaquest
				w <= toggled;
				if (div31_edge = '1') then
					toggled_next <= not toggled;
				end if;

			when "1011" =>			-- B
				w <= '1';

			when "1100" =>			-- C
				w <= toggled;
				if (div6_edge = '1') then
					toggled_next <= not toggled;
				end if;

			when "1101" =>			-- D
				w <= toggled;
				if (div6_edge = '1') then
					toggled_next <= not toggled;
				end if;

			when "1110" =>			-- E
				w <= toggled;
				cnt3_ena <= div31_edge;
				if (div6_edge = '1') then
					toggled_next <= not toggled;
				end if;

			when "1111" =>			-- F         		-- F, tiro e morte no sequest
				w <= toggled;
				if (lfsr5_edge = '1') then
					toggled_next <= not toggled;
				end if;

			when others =>
				null;

		end case;
	end process;

	cnt3_next <= "00" when cnt3 ="10" else cnt3 + 1;

	lfsr4_next <= "1111" when lfsr4 = "0000" else 
					  (lfsr4(0) xor lfsr4(1)) & lfsr4(3 downto 1);

	lfsr5_next <= "11111" when lfsr5 = "00000" else 
					  (lfsr5(0) xor lfsr5(2)) & lfsr5(4 downto 1); 

	lfsr9_next <= "111111111" when lfsr9 = "000000000" else
					  (lfsr9(0) xor lfsr9(4)) & lfsr9(8 downto 1);

	lfsr4_out <= lfsr4(0);
	lfsr5_out <= lfsr5(0);
	lfsr9_out <= lfsr9(0);

	output <= w;

end Behavioral;
