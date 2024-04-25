library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity pong_game_top is
	port(
		clk, reset: in std_logic;
		btn: in std_logic_vector(3 downto 0);
		hsync, vsync: out std_logic;
		rgb: out std_logic_vector(7 downto 0)
		);
end pong_game_top;

architecture arch of pong_game_top is
	type state_type is (newgame, play, newball, over);
	signal state_reg, state_next: state_type;
	signal rgb_reg, rgb_next: std_logic_vector(7 downto 0);
	signal graph_rgb, text_rgb: std_logic_vector(7 downto 0);
	signal video_on: std_logic;
	
	-- push buttons on the Mimas v2 are active low so invert all the buttons
	signal not_reset: std_logic;
	signal not_btn: std_logic_vector(3 downto 0);
	
	signal pixel_x: std_logic_vector(9 downto 0);
	signal pixel_y: std_logic_vector(9 downto 0);
	signal pixel_tick: std_logic;
	signal graph_on: std_logic_vector(3 downto 0);
	signal text_on: std_logic_vector(5 downto 0);
	signal graph_still: std_logic;
	signal p1_miss, p2_miss: std_logic;
	signal p1_d_inc, p2_d_inc: std_logic;
	signal p1_score, p2_score: std_logic_vector(3 downto 0);
	signal d_clr: std_logic;
	signal timer_tick, timer_start, timer_up: std_logic;
begin
	-- instantiate the VGA synchronizer circuit
	vga_sync_unit: entity work.VGA_sync(arch) port map(clk => clk, reset => not_reset, 
	hsync => hsync, vsync => vsync, video_on => video_on, p_tick => pixel_tick, 
	pixel_x => pixel_x, pixel_y => pixel_y);
	
	-- instantiate the pixel generation circuit
	pix_gen_unit: entity work.pix_gen_circuit(arch) port map(clk => clk, reset => not_reset,
	video_on => video_on, pixel_x => pixel_x, pixel_y => pixel_y, graph_on => graph_on,
	graph_rgb => graph_rgb, btn => not_btn, graph_still => graph_still,
	p1_miss => p1_miss, p2_miss => p2_miss);

	-- instantiate the text generation circuit
	text_gen_unit: entity work.text_gen_circuit(arch) port map(clk => clk,
	pixel_x => pixel_x, pixel_y => pixel_y, p1_score => p1_score, p2_score => p2_score, 
	text_on => text_on, text_rgb => text_rgb);
	
	-- instantiate the mod10 counters for both players
	p1_mod10_counter_unit: entity work.mod10_counter(arch) port map(clk => clk, reset => not_reset,
	d_inc => p1_d_inc, d_clr => d_clr, dig => p1_score);
	p2_mod10_counter_unit: entity work.mod10_counter(arch) port map(clk => clk, reset => not_reset,
	d_inc => p2_d_inc, d_clr => d_clr, dig => p2_score);
	
	-- instantiate the timer circuit
	timer_tick <= '1' when pixel_x = "0000000000" and pixel_y = "0000000000" else '0';
	timer_unit: entity work.timer(arch) port map(clk => clk, reset => not_reset,
	timer_start => timer_start, timer_tick => timer_tick, timer_up => timer_up);
	
	-- push buttons on the Mimas v2 are active low so invert all the buttons
	not_reset <= not reset;
	not_btn <= not btn;
	
	-- registers
	process(clk, not_reset)
	begin
		if (not_reset = '1') then
			state_reg <= newgame;
			rgb_reg <= (others=>'0');
		elsif (clk'event and clk = '1') then
			state_reg <= state_next;
			-- since 'hsync' and 'vsync' are synchronized to 'pixel_tick' ...
			-- the rgb signal also has to be synchronized to 'pixel_tick'
			if (pixel_tick = '1') then
				rgb_reg <= rgb_next;
			end if;
		end if;
	end process;
	
	-- FSMD next state logic
	process(state_reg, not_btn, p1_miss, p2_miss, timer_up, p1_score, p2_score)
	begin
		-- default signal assignments
		graph_still <= '1';					-- do not animate the game objects
		timer_start <= '0';					-- do not start the timer
		p1_d_inc <= '0';						-- do not increment the score for player 1
		p2_d_inc <= '0';						-- do not increment the score for player 2
		d_clr <= '0';							-- do not clear the score counters
		state_next <= state_reg;			-- maintain the current game state
		case state_reg is
			when newgame =>
				-- clear the scores
				d_clr <= '1';
				-- if any of the buttons are pushed transition into the play state
				if (not_btn /= "0000") then
					state_next <= play;
				end if;
			when play =>
				-- start animating the game objects
				graph_still <= '0';
				-- if player 1 misses the ball ...
				if (p1_miss = '1') then
					-- start the count down timer
					timer_start <= '1';
					-- if player 2's score is less than the threshold to win ...
					if (p2_score < "0011") then
						-- increment player 2's score
						p2_d_inc <= '1';
						-- transition into the newball state
						state_next <= newball;
					else
						-- otherwise transition into the game over state
						state_next <= over;
					end if;
				end if;
				
				-- if player 2 misses the ball ...
				if (p2_miss = '1') then
					-- start the count down timer
					timer_start <= '1';
					-- if player 1's score is less than the threshold to win ...
					if (p1_score < "0011") then
						-- increment player 1's score
						p1_d_inc <= '1';
						-- transition into the newball state
						state_next <= newball;
					else
						-- otherwise transition into the game over state
						state_next <= over;
					end if;
				end if;
			when newball =>
				-- if the count down timer is finished and the buttons are pushed ...
				if (timer_up = '1' and not_btn /= "0000") then
					-- transition into the play state
					state_next <= play;
				end if;
			when over =>
				-- if the count down timer is finished ...
				if (timer_up = '1') then
					-- transition into the newgame state
					state_next <= newgame;
				end if;
		end case;
	end process;
	
	-- rgb multiplexing circuit
	process(state_reg, video_on, graph_on, graph_rgb, text_on, text_rgb)
	begin
		-- this part of the code is extremely important !!!
		-- rgb signals can only be non zero when the scan lines are in the display area
		-- the VGA port will not work as expected if this rule isn't followed !!!
		if (video_on = '0') then
			-- in the border areas display black
			rgb_next <= (others=>'0');
		else
			-- in the display area draw the objects based on the game state and the on status signals
			-- display the rules if in the newgame state ...
			-- or display the game over message if in the over state
			if (state_reg = newgame and (text_on(3) = '1' or text_on(2) = '1')) or
				(state_reg = over and text_on(0) = '1') then
				rgb_next <= text_rgb;
			-- always draw the game objects
			elsif (graph_on /= "0000") then
				rgb_next <= graph_rgb;
			-- always draw the score and name
			elsif (text_on(5) = '1' or text_on(4) = '1' or text_on(1) = '1') then
				rgb_next <= text_rgb;
			else
			-- all other pixels are in the background
				rgb_next <= "11111100";
			end if;
		end if;
	end process;
	
	-- output
	rgb <= rgb_reg;
end arch;
