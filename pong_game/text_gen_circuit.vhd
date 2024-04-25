library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- the test generation circuit will generate the text for the game 
-- it consists of four messages:
-- >> display the score (upto 9) for each player using font size 32x16
-- >> display the rules for each player (what buttons to press etc.) using regular font
-- >> display the name of the game (PONG) using font size 128x64
-- >> display the game over message using font size 64x32
entity text_gen_circuit is
	port(
		clk: in std_logic;
		pixel_x, pixel_y: in std_logic_vector(9 downto 0);
		-- the one digit score is given as input
		p1_score: in std_logic_vector(3 downto 0);
		p2_score: in std_logic_vector(3 downto 0);
		-- concatenation of the on status of all messages
		text_on: out std_logic_vector(5 downto 0);
		text_rgb: out std_logic_vector(7 downto 0)
		);
end text_gen_circuit;

architecture arch of text_gen_circuit is
	signal pix_x, pix_y: unsigned(9 downto 0);
	-- address to the font ROM which is the concatenation of the character address with the row address
	signal rom_addr: std_logic_vector(10 downto 0);
	-- there are 127 characters in ASCII code which requires a 7-bit character address
	signal char_addr, name_char_addr, p1_score_char_addr, p2_score_char_addr, 
			 p1_rule_char_addr, p2_rule_char_addr, go_char_addr: std_logic_vector(6 downto 0);
	-- each character pattern in the ROM has 16 rows which requires a 4-bit row address
	signal row_addr, name_row_addr, p1_score_row_addr, p2_score_row_addr, 
			 p1_rule_row_addr, p2_rule_row_addr, go_row_addr: std_logic_vector(3 downto 0);
	-- each character pattern in the ROM has 8 columns which requires a 3-bit bit address
	signal bit_addr, name_bit_addr, p1_score_bit_addr, p2_score_bit_addr, 
			 p1_rule_bit_addr, p2_rule_bit_addr, go_bit_addr: std_logic_vector(2 downto 0);
	signal font_word: std_logic_vector(7 downto 0);
	signal font_bit: std_logic;
	-- status signals indicating whether the current pixel is part of any message
	signal p1_score_on, p2_score_on, name_on, p1_rule_on, p2_rule_on, over_on: std_logic;
	
	-- define a 2D memory unit to store the rules of the game
	type rule_rom_type is array(0 to 63) of std_logic_vector(6 downto 0);
	-- rules for player 1
	constant P1_RULE_ROM: rule_rom_type := (
		-- row 1
		"1001101",		-- M
		"1101111",		-- o
		"1110110",		-- v
		"1100101",		-- e
		"0100000",		-- 
		"1110000",		-- p
		"1100001",		-- a
		"1100100",		-- d
		"1100100",		-- d
		"1101100",		-- l
		"1100101",		-- e
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		--
		"0100000",		--		
		-- row 2
		"1110101",		-- u
		"1110000",		-- p
		"0100000",		-- 
		"1100001",		-- a
		"1101110",		-- n
		"1100100",		-- d
		"0100000",		-- 
		"1100100",		-- d
		"1101111",		-- o
		"1110111",		-- w
		"1101110",		-- n
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		--
		-- row 3
		"1110101",		-- u
		"1110011",		-- s
		"1101001",		-- i
		"1101110",		-- n
		"1100111",		-- g
		"0100000",		-- 
		"1100010",		-- b
		"1110101",		-- u
		"1110100",		-- t
		"1110100",		-- t
		"1101111",		-- o
		"1101110",		-- n
		"1110011",		-- s
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		--
		-- row 4
		"1010011",		-- S
		"1010111",		-- W
		"0110110",		-- 6
		"0100000",		-- 
		"1100001",		-- a
		"1101110",		-- n
		"1100100",		-- d
		"0100000",		-- 
		"1010011",		-- S
		"1010111",		-- W
		"0110010",		-- 2
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		--
		"0100000"		-- 
		);
	
	-- rules for player 2
	constant P2_RULE_ROM: rule_rom_type := (
		-- row 1
		"1001101",		-- M
		"1101111",		-- o
		"1110110",		-- v
		"1100101",		-- e
		"0100000",		-- 
		"1110000",		-- p
		"1100001",		-- a
		"1100100",		-- d
		"1100100",		-- d
		"1101100",		-- l
		"1100101",		-- e
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		--
		-- row 2
		"1110101",		-- u
		"1110000",		-- p
		"0100000",		-- 
		"1100001",		-- a
		"1101110",		-- n
		"1100100",		-- d
		"0100000",		-- 
		"1100100",		-- d
		"1101111",		-- o
		"1110111",		-- w
		"1101110",		-- n
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		--
		-- row 3
		"1110101",		-- u
		"1110011",		-- s
		"1101001",		-- i
		"1101110",		-- n
		"1100111",		-- g
		"0100000",		-- 
		"1100010",		-- b
		"1110101",		-- u
		"1110100",		-- t
		"1110100",		-- t
		"1101111",		-- o
		"1101110",		-- n
		"1110011",		-- s
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		--
		-- row 4
		"1010011",		-- S
		"1010111",		-- W
		"0110101",		-- 5
		"0100000",		-- 
		"1100001",		-- a
		"1101110",		-- n
		"1100100",		-- d
		"0100000",		-- 
		"1010011",		-- S
		"1010111",		-- W
		"0110001",		-- 1
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		-- 
		"0100000",		--
		"0100000"		-- 
		);
begin
	pix_x <= unsigned(pixel_x);
	pix_y <= unsigned(pixel_y);
	
	-- instantiate the font ROM
	font_unit: entity work.font_rom(arch) port map(clk => clk, addr => rom_addr, data => font_word);
	
	------------------------------------------------------------------------------------
	-- score message:
	-- >> display at the top of the screen for both players
	-- >> use 32x16 font
	------------------------------------------------------------------------------------
	
	-- Note: 
	-- the screen with a resolution of 480x640 can fit a 15x40 array of characters
	-- the MSB's of pix_y and pix_x are the indexes of the character in the array
	-- the LSB's of pix_y and pix_x are the row and bit addresses
	-- pix_y(4 downto 0) is equivalent to pix_y%32 
	-- pix_y(9 downto 5) is equivalent to pix_y/32 (integer division) up to 31
	-- pix_x(3 downto 0) is equivalent to pix_x%16
	-- pix_x(9 downto 4) is equivalent to pix_x/16 (integer division) up to 63
	
	-- the score for player 1 should be displayed at the top right of the screen
	-- assert the on status signal for the area where the score will be displayed
	p1_score_on <= '1' when pix_y(9 downto 5) = 0 and 
								   pix_x(9 downto 4) >= 21 and pix_x(9 downto 4) < 39 else '0';
	-- the default font size used in the font ROM is 16x8
	-- shift the row and bit addresses by 1 bit to increase the font size from 16x8 to 32x16
	p1_score_row_addr <= std_logic_vector(pix_y(4 downto 1));
	p1_score_bit_addr <= std_logic_vector(pix_x(3 downto 1));
	-- select the character address by using the position of the pixel in the x axis
	with pix_x(9 downto 4) select p1_score_char_addr <= 
		"1010000" when "010101", 	-- P
		"1101100" when "010110", 	-- l
		"1100001" when "010111",	-- a
		"1111001" when "011000",	-- y
		"1100101" when "011001",	-- e
		"1110010" when "011010",	-- r
		"0100000" when "011011", 	--
		"0110001" when "011100",	-- 1
		"0100000" when "011101", 	--
		"1110011" when "011110",	-- s
		"1100011" when "011111",	-- c
		"1101111" when "100000",	-- o
		"1110010" when "100001",	-- r
		"1100101" when "100010",	-- e
		"0111010" when "100011", 	-- :
		"0100000" when "100100", 	--
		"011" & p1_score when "100101", -- player 1 score
		"0100000" when others;
		
	-- the score for player 2 should be displayed at the top left of the screen
	-- assert the on status signal for the area where the score will be displayed
	p2_score_on <= '1' when pix_y(9 downto 5) = 0 and 
								   pix_x(9 downto 4) >= 0 and pix_x(9 downto 4) < 18 else '0';
	-- the default font size used in the font ROM is 16x8
	-- shift the row and bit addresses by 1 bit to increase the font size from 16x8 to 32x16
	p2_score_row_addr <= std_logic_vector(pix_y(4 downto 1));
	p2_score_bit_addr <= std_logic_vector(pix_x(3 downto 1));
	-- select the character address by using the position of the pixel in the x axis
	with pix_x(9 downto 4) select p2_score_char_addr <= 
		"1010000" when "000000", 	-- P
		"1101100" when "000001", 	-- l
		"1100001" when "000010",	-- a
		"1111001" when "000011",	-- y
		"1100101" when "000100",	-- e
		"1110010" when "000101",	-- r
		"0100000" when "000110", 	--
		"0110010" when "000111",	-- 2
		"0100000" when "001000", 	--
		"1110011" when "001001",	-- s
		"1100011" when "001010",	-- c
		"1101111" when "001011",	-- o
		"1110010" when "001100",	-- r
		"1100101" when "001101",	-- e
		"0111010" when "001110", 	-- :
		"0100000" when "001111", 	--
		"011" & p2_score when "010000", -- player 2 score
		"0100000" when others;
	
	------------------------------------------------------------------------------------
	-- rules message:
	-- >> display at the center of the screen for both players
	-- >> use 16x8 font
	-- >> the message contains 4 rows of text with 16 characters each
	------------------------------------------------------------------------------------
	
	-- Note:
	-- the screen with a resolution of 480x640 can fit a 30x80 array of characters
	-- the MSB's of pix_y and pix_x are the indexes of the character in the array
	-- the LSB's of pix_y and pix_x are the row and bit addresses
	-- pix_y(3 downto 0) is equivalent to pix_y%16 
	-- pix_y(9 downto 4) is equivalent to pix_y/16 (integer division) up to 63
	-- pix_x(2 downto 0) is equivalent to pix_x%8
	-- pix_x(9 downto 3) is equivalent to pix_x/8 (integer division) up to 127
	
	-- the rules for player 1 should be displayed on the right side of the screen
	-- assert the on status signal for the area where the rules will be displayed
	p1_rule_on <= '1' when pix_y(9 downto 4) >= 20 and pix_y(9 downto 4) < 24 and
								  pix_x(9 downto 3) >= 48 and pix_x(9 downto 3) < 64 else '0';
	p1_rule_row_addr <= std_logic_vector(pix_y(3 downto 0));
	p1_rule_bit_addr <= std_logic_vector(pix_x(2 downto 0));
	-- concatenate pix_y(5 downto 4) and pix_x(6 downto 3) to form the character address
	-- pix_y(5 downto 4) is equivalent to pix_y/16 upto 3, which can accomodate 4 rows of the message
	-- pix_x(6 downto 3) is equivalent to pix_x/8 upto 15, which can accomodate the 16 characters per row in the message
	-- convert to integer from std_logic_vector data type
	p1_rule_char_addr <= P1_RULE_ROM(to_integer(pix_y(5 downto 4) & pix_x(6 downto 3)));
	
	-- the rules for player 2 should be displayed on the left side of the screen
	-- assert the on status signal for the area where the rules will be displayed
	p2_rule_on <= '1' when pix_y(9 downto 4) >= 20 and pix_y(9 downto 4) < 24 and
								  pix_x(9 downto 3) >= 16 and pix_x(9 downto 3) < 32 else '0';
	p2_rule_row_addr <= std_logic_vector(pix_y(3 downto 0));
	p2_rule_bit_addr <= std_logic_vector(pix_x(2 downto 0));
	-- concatenate pix_y(5 downto 4) and pix_x(6 downto 3) to form the character address
	-- pix_y(5 downto 4) is equivalent to pix_y/16 upto 3, which can accomodate 4 rows of the message
	-- pix_x(6 downto 3) is equivalent to pix_x/8 upto 15, which can accomodate the 16 characters per row in the message
	-- convert to integer from std_logic_vector data type
	p2_rule_char_addr <= P2_RULE_ROM(to_integer(pix_y(5 downto 4) & pix_x(6 downto 3)));
	
	------------------------------------------------------------------------------------
	-- name message:
	-- >> display at the center of the screen
	-- >> use 128x64 font
	------------------------------------------------------------------------------------
	
	-- Note:
	-- the screen with a resolution of 480x640 can fit a 3.75x10 array of characters
	-- the MSB's of pix_y and pix_x are the indexes of the character in the array
	-- the LSB's of pix_y and pix_x are the row and bit addresses
	-- pix_y(6 downto 0) is equivalent to pix_y%128 
	-- pix_y(9 downto 7) is equivalent to pix_y/128 (integer division) up to 7
	-- pix_x(5 downto 0) is equivalent to pix_x%64
	-- pix_x(9 downto 6) is equivalent to pix_x/64 (integer division) up to 15
	
	-- the name of the game should be displayed in the center of the screen
	-- assert the on status signal for the area where the name will be displayed
	name_on <= '1' when pix_y(9 downto 7) = 1 and
							  pix_x(9 downto 6) >= 3 and pix_x(9 downto 6) < 7 else '0';
	-- the default font size used in the font ROM is 16x8
	-- shift the row and bit addresses by 3 bits to increase the font size from 16x8 to 128x64
	name_row_addr <= std_logic_vector(pix_y(6 downto 3));
	name_bit_addr <= std_logic_vector(pix_x(5 downto 3));
	-- select the character address by using the position of the pixel in the x axis
	with pix_x(9 downto 6) select name_char_addr <=
		"1010000" when "0011",	-- P
		"1001111" when "0100",	-- O
		"1001110" when "0101",	-- N
		"1000111" when "0110",	-- G
		"0100000" when others;	--
		
	------------------------------------------------------------------------------------
	-- game over message:
	-- >> display at the bottom of the screen
	-- >> use 64x32 font
	------------------------------------------------------------------------------------
	
	-- Note:
	-- the screen with a resolution of 480x640 can fit a 7.5x20 array of characters
	-- the MSB's of pix_y and pix_x are the indexes of the character in the array
	-- the LSB's of pix_y and pix_x are the row and bit addresses
	-- pix_y(5 downto 0) is equivalent to pix_y%64 
	-- pix_y(9 downto 6) is equivalent to pix_y/64 (integer division) up to 15
	-- pix_x(4 downto 0) is equivalent to pix_x%32
	-- pix_x(9 downto 5) is equivalent to pix_x/32 (integer division) up to 32
	
	-- the game over message should be displayed at the bottom of the screen
	-- assert the on status signal for the area where the game over message will be displayed
	over_on <= '1' when pix_y(9 downto 6) = 6 and
							  pix_x(9 downto 5) >= 5 and pix_x(9 downto 5) < 14 else '0';
	-- the default font size used in the font ROM is 16x8
	-- shift the row and bit addresses by 2 bits to increase the font size from 16x8 to 64x32
	go_row_addr <= std_logic_vector(pix_y(5 downto 2));
	go_bit_addr <= std_logic_vector(pix_x(4 downto 2));
	-- select the character address by using the position of the pixel in the x axis
	with pix_x(9 downto 5) select go_char_addr <=
		"1000111" when "00101",	-- G
		"1100001" when "00110", -- a
		"1101101" when "00111", -- m
		"1100101" when "01000", -- e
		"0100000" when "01001", --
		"1001111" when "01010", -- O
		"1110110" when "01011", -- v
		"1100101" when "01100", -- e
		"1110010" when "01101", -- r
		"0100000" when others;	--
	
	------------------------------------------------------------------------------------
	-- multiplexer for font ROM addresses and rgb
	------------------------------------------------------------------------------------
	-- the multiplexer circuit determines which message is given priority and placed in the foreground
	process(p1_score_char_addr, p1_score_row_addr, p1_score_bit_addr,
			  p2_score_char_addr, p2_score_row_addr, p2_score_bit_addr,
			  p1_rule_char_addr, p1_rule_row_addr, p1_rule_bit_addr,
			  p2_rule_char_addr, p2_rule_row_addr, p2_rule_bit_addr,
			  name_char_addr, name_row_addr, name_bit_addr,
			  go_char_addr, go_row_addr, go_bit_addr,
			  p1_score_on, p2_score_on, p1_rule_on, p2_rule_on,
			  name_on, over_on, pix_x, pix_y, font_bit)
	begin
		text_rgb <= "11111100";					-- yellow background
		if p1_score_on = '1' then
			char_addr <= p1_score_char_addr;
			row_addr <= p1_score_row_addr;
			bit_addr <= p1_score_bit_addr;
			if font_bit = '1' then
				text_rgb <= "00000000";			-- score in black
			end if;
		elsif p2_score_on = '1' then
			char_addr <= p2_score_char_addr;
			row_addr <= p2_score_row_addr;
			bit_addr <= p2_score_bit_addr;
			if font_bit = '1' then
				text_rgb <= "00000000";			-- score in black
			end if;
		elsif p1_rule_on = '1' then
			char_addr <= p1_rule_char_addr;
			row_addr <= p1_rule_row_addr;
			bit_addr <= p1_rule_bit_addr;
			if font_bit = '1' then
				text_rgb <= "00000000";			-- rules in black
			end if;
		elsif p2_rule_on = '1' then
			char_addr <= p2_rule_char_addr;
			row_addr <= p2_rule_row_addr;
			bit_addr <= p2_rule_bit_addr;
			if font_bit = '1' then
				text_rgb <= "00000000";			-- rules in black
			end if;
		elsif over_on = '1' then
			char_addr <= go_char_addr;
			row_addr <= go_row_addr;
			bit_addr <= go_bit_addr;
			if font_bit = '1' then
				text_rgb <= "00000000";			-- game over message in black
			end if;
		elsif name_on = '1' then
			char_addr <= name_char_addr;
			row_addr <= name_row_addr;
			bit_addr <= name_bit_addr;
			if font_bit = '1' then
				text_rgb <= "11100000";			-- name in red
			end if;
		else
			char_addr <= (others=>'0');
			row_addr <= (others=>'0');
			bit_addr <= (others=>'0');
			text_rgb <= "11111100";
		end if;
	end process;
	
	-- output logic
	-- concatenate the on status signals together
	text_on <= p1_score_on & p2_score_on & p1_rule_on & p2_rule_on & name_on & over_on;
	
	------------------------------------------------------------------------------------
	-- font ROM interface
	------------------------------------------------------------------------------------
	-- the address to the font ROM is the concatenation of the character and row addresses
	rom_addr <= char_addr & row_addr;
	-- the bit address is used to retrieve the individual pixel state within a row of the character pattern
	-- take the inverse of the bit address because the pixels on a screen ...
	-- increase from left to right while the data type of the ROM is std_logic_vector ...
	-- where the indices of each bit decrease from left to right
	font_bit <= font_word(to_integer(unsigned(not bit_addr)));
end arch;

