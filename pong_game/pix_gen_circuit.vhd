library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- the pixel generation circuit generates the RGB signals while the VGA synchronizer circuit ...
-- generates the hsync and vsync signals
-- there are three main types of pixel generator circuits:
-- >> bit-mapped (the RGB value for each pixel in the screen is stored in memory)
-- >> tile-mapped (predefined tile patterns are stored in memory)
-- >> object-mapped (a circuit is used to draw objects directly to the screen)
-- the following module uses an object-mapped scheme to draw all components of a Pong game

entity pix_gen_circuit is
	port(
		clk, reset: in std_logic;
		-- btn(1) and btn(0) will move the paddle up and down for player 1
		-- btn(3) and btn(2) will move the paddle up and down for player 2
		btn: in std_logic_vector(3 downto 0);
		video_on: in std_logic;
		-- pause and reset all animated objects when this signal is asserted
		graph_still: in std_logic;
		pixel_x, pixel_y: in std_logic_vector(9 downto 0);
		-- concatenation of the on status signal of all objects
		graph_on: out std_logic_vector(3 downto 0);
		-- the following signals are asserted for one clock cycle when a player misses the ball
		p1_miss, p2_miss: out std_logic;
		graph_rgb: out std_logic_vector(7 downto 0)
		);
end pix_gen_circuit;

-- make changes to the architecture to allow for animations
architecture arch of pix_gen_circuit is
	signal pix_x, pix_y: unsigned(9 downto 0);
	
	-- update the position of the game objects after every frame has been drawn ...
	-- this happens at a rate of 60 Hz
	-- create a tick signal that lasts for one clock cycle every 1/60 of a second
	signal refr_tick: std_logic;
	
	-- boundaries of the display area
	constant MAX_X: integer := 640;
	constant MAX_Y: integer := 480;
	
	-- vertical stripe
	constant WALL_X_L: integer := 318;				-- left boundary
	constant WALL_X_R: integer := 321;				-- right boundary
	
	-- rectangular bars that serves as the paddles
	-- velocity of the paddle
	constant BAR_V: integer := 4;
	constant BAR_Y_SIZE: integer := 100;
	----------------------------------------------------------------------------
	-- Player 1
	----------------------------------------------------------------------------
	constant P1_BAR_X_L: integer := 600;
	constant P1_BAR_X_R: integer := 603;
	-- the top and bottom boundaries will change when the paddle is animated ...
	-- so make them signals instead of constants
	signal p1_bar_y_t: unsigned(9 downto 0);
	signal p1_bar_y_b: unsigned(9 downto 0);
	-- register to keep track of the top boundary of the paddle
	signal p1_bar_y_reg, p1_bar_y_next: unsigned(9 downto 0);
	----------------------------------------------------------------------------
	-- Player 1
	----------------------------------------------------------------------------
	constant P2_BAR_X_L: integer := 37;
	constant P2_BAR_X_R: integer := 40;
	-- the top and bottom boundaries will change when the paddle is animated ...
	-- so make them signals instead of constants
	signal p2_bar_y_t: unsigned(9 downto 0);
	signal p2_bar_y_b: unsigned(9 downto 0);
	-- register to keep track of the top boundary of the paddle
	signal p2_bar_y_reg, p2_bar_y_next: unsigned(9 downto 0);
	
	-- size and boundaries of the ball
	constant BALL_SIZE: integer := 8;
	-- left and right boundaries of moving ball
	signal ball_x_l: unsigned(9 downto 0);
	signal ball_x_r: unsigned(9 downto 0);
	signal ball_y_t: unsigned(9 downto 0);
	signal ball_y_b: unsigned(9 downto 0);
	-- register to keep track of the left boundary of the ball
	signal ball_x_reg, ball_x_next: unsigned(9 downto 0);
	-- register to keep track of the top boundary of the ball
	signal ball_y_reg, ball_y_next: unsigned(9 downto 0);
	-- registers to keep track of the change in speed/direction of the ball
	signal x_delta_reg, x_delta_next: unsigned(9 downto 0);
	signal y_delta_reg, y_delta_next: unsigned(9 downto 0);
	-- constants that store the magnitude of the ball velocity (positive or negative)
	constant BALL_V_P: unsigned(9 downto 0) := to_unsigned(1, 10);
	constant BALL_V_N: unsigned(9 downto 0) := unsigned(to_signed(-1, 10));
	
	-- signals for determining whether the objects should be shown for the current pixel
	signal wall_on, p1_bar_on, p2_bar_on, ball_on: std_logic;
	
	-- RGB signals from the objects that determine their color
	signal wall_rgb, p1_bar_rgb, p2_bar_rgb, ball_rgb: std_logic_vector(7 downto 0);
	
	-- pattern ROM for ball
	type rom_type is array(0 to 7) of std_logic_vector(0 to 7);
	
	-- define a constant which is the initial value of the pattern ROM
	-- need to create a circuit that decodes the scan coordinates to retrieve ...
	-- the corresponding ROM bit
	constant BALL_ROM: rom_type :=
	(
		"00111100",
		"01111110",
		"11111111",
		"11111111",
		"11111111",
		"11111111",
		"01111110",
		"00111100"
		);
	-- rom_addr corresponds to a row in the ROM pattern
	signal rom_addr, rom_col: unsigned(2 downto 0);
	signal rom_data: std_logic_vector(7 downto 0);
	signal rom_bit: std_logic;
	signal rd_ball_on: std_logic;
begin
	-- registers
	process(clk, reset)
	begin
		if (reset = '1') then
			p1_bar_y_reg <= "0000000010";
			p2_bar_y_reg <= "0000000010";
			ball_x_reg <= "0000000010";
			ball_y_reg <= "0000000010";
			x_delta_reg <= "0000000010";
			y_delta_reg <= "0000000010";
		elsif (clk'event and clk = '1') then
			p1_bar_y_reg <= p1_bar_y_next;
			p2_bar_y_reg <= p2_bar_y_next;
			ball_x_reg <= ball_x_next;
			ball_y_reg <= ball_y_next;
			x_delta_reg <= x_delta_next;
			y_delta_reg <= y_delta_next;
		end if;
	end process;

	pix_x <= unsigned(pixel_x);
	pix_y <= unsigned(pixel_y);
	
	-- create a reference tick when the screen is refreshed ...
	-- this happens when pix_y = 481 and pix_x = 0
	refr_tick <= '1' when (pix_y = 481 and pix_x = 0) else '0';
	
	-- check if the current pixel is within the boundaries of the wall
	wall_on <= '1' when (pix_x >= WALL_X_L) and (pix_x <= WALL_X_R) else '0';
	wall_rgb <= "00000011"; 		-- blue
	
	----------------------------------------------------------------------------
	-- Player 1
	----------------------------------------------------------------------------
	-- check if the current pixel is within the boundaries of the paddle
	p1_bar_y_t <= p1_bar_y_reg;
	p1_bar_y_b <= p1_bar_y_t + BAR_Y_SIZE - 1;
	p1_bar_on <= '1' when (pix_x >= P1_BAR_X_L) and (pix_x <= P1_BAR_X_R) and
								 (pix_y >= p1_bar_y_t) and (pix_y <= p1_bar_y_b) else '0';
	p1_bar_rgb <= "11100000";			-- red
	-- update the top boundary register (y axis position) of the paddle
	process(p1_bar_y_reg, p1_bar_y_b, P1_bar_y_t, refr_tick, btn(1 downto 0))
	begin
		-- maintain register value if reference tick is not triggered
		p1_bar_y_next <= p1_bar_y_reg;
		if (refr_tick = '1') then
			-- if the player presses the down button and the paddle doesn't go beneath the display area ...
			if (btn(0) = '1' and p1_bar_y_b < MAX_Y - 1 - BAR_V) then
				-- move the paddle down
				p1_bar_y_next <= p1_bar_y_reg + BAR_V;
			-- if the player presses the up button and the paddle doesn't go above the display area ...
			elsif (btn(1) = '1' and p1_bar_y_t > BAR_V) then
				-- move the paddle up
				p1_bar_y_next <= p1_bar_y_reg - BAR_V;
			end if;
		end if;
	end process;
	
	----------------------------------------------------------------------------
	-- Player 2
	----------------------------------------------------------------------------
	-- check if the current pixel is within the boundaries of the paddle
	p2_bar_y_t <= p2_bar_y_reg;
	p2_bar_y_b <= p2_bar_y_t + BAR_Y_SIZE - 1;
	p2_bar_on <= '1' when (pix_x >= P2_BAR_X_L) and (pix_x <= P2_BAR_X_R) and
								 (pix_y >= p2_bar_y_t) and (pix_y <= p2_bar_y_b) else '0';
	p2_bar_rgb <= "11100000";			-- red
	-- update the top boundary register (y axis position) of the paddle
	process(p2_bar_y_reg, p2_bar_y_b, p2_bar_y_t, refr_tick, btn(1 downto 0))
	begin
		-- maintain register value if reference tick is not triggered
		p2_bar_y_next <= p2_bar_y_reg;
		if (refr_tick = '1') then
			-- if the player presses the down button and the paddle doesn't go beneath the display area ...
			if (btn(2) = '1' and p2_bar_y_b < MAX_Y - 1 - BAR_V) then
				-- move the paddle down
				p2_bar_y_next <= p2_bar_y_reg + BAR_V;
			-- if the player presses the up button and the paddle doesn't go above the display area ...
			elsif (btn(3) = '1' and p2_bar_y_t > BAR_V) then
				-- move the paddle up
				p2_bar_y_next <= p2_bar_y_reg - BAR_V;
			end if;
		end if;
	end process;
	
	-- check if the current pixel is within the boundaries of the ball
	ball_x_l <= ball_x_reg;
	ball_x_r <= ball_x_l + BALL_SIZE - 1;
	ball_y_t <= ball_y_reg;
	ball_y_b <= ball_y_t + BALL_SIZE - 1;
	ball_on <= '1' when (pix_x >= ball_x_l) and (pix_x <= ball_x_r) and
							  (pix_y >= ball_y_t) and (pix_y <= ball_y_b) else '0';
	-- the 3 LSB's of pix_y and pix_x corresponds to a maximum of 7 pixels in the y or x axis
	-- if pix_y is in decimal format then pix_y%7 is equivalent to the 3 LSB's of pix_y converted to decimal
	-- subtracting the 3 LSB's of the top ball boundary from the 3 LSB's of pix_y yields the corresponding ROM row
	rom_addr <= pix_y(2 downto 0) - unsigned(ball_y_t(2 downto 0));
	-- subtracting the 3 LSB's of the left ball boundary from the 3 LSB's of pix_x yields the corresponding ROM col
	rom_col <= pix_x(2 downto 0) - unsigned(ball_x_l(2 downto 0));
	rom_data <= BALL_ROM(to_integer(rom_addr));
	rom_bit <= rom_data(to_integer(rom_col));
	rd_ball_on <= '1' when (ball_on = '1') and (rom_bit = '1') else '0';
	ball_rgb <= "00011100";			-- green
	-- update the top (y axis position) and left (x axis position) boundaries of the ball
	ball_x_next <= to_unsigned(MAX_X/2, 10) when graph_still = '1' else
					   ball_x_reg + x_delta_reg when refr_tick = '1' else ball_x_reg;
	ball_y_next <= to_unsigned(MAX_Y/2, 10) when graph_still = '1' else
					   ball_y_reg + y_delta_reg when refr_tick = '1' else ball_y_reg;
	process(x_delta_reg, y_delta_reg, ball_x_l, ball_x_r, ball_y_t, ball_y_b, 
	p1_bar_y_t, p1_bar_y_b, p2_bar_y_t, p2_bar_y_b)
	begin
		x_delta_next <= x_delta_reg;
		y_delta_next <= y_delta_reg;
		p1_miss <= '0';
		p2_miss <= '0';
		-- if the ball reaches the top of the display area ...
		if ball_y_t < 1 then
			-- reverse its y direction velocity
			y_delta_next <= BALL_V_P;
		-- if the ball reaches the bottom of the display area ...
		elsif ball_y_b > MAX_Y-1 then
			-- reverse its y direction velocity 
			y_delta_next <= BALL_V_N;
		-- if the ball reaches the left boundary of the paddle controlled by player 1 ...
		elsif (ball_x_r >= P1_BAR_X_L and ball_x_l < P1_BAR_X_L) then
			-- and it makes contact with the paddle ...
			if (p1_bar_y_t <= ball_y_b and p1_bar_y_b >= ball_y_t) then
				-- reverse its x direction velocity
				x_delta_next <= BALL_V_N;
			-- if it doesn't make contact ...
			else
				-- assert the miss signal for player 1
				p1_miss <= '1';
			end if;
		-- if the ball reaches the right boundary of the paddle controlled by player 2 ...
		elsif (ball_x_l <= P2_BAR_X_R and ball_x_r > P2_BAR_X_R) then
			-- and it makes contact with the paddle ...
			if (p2_bar_y_t <= ball_y_b and p2_bar_y_b >= ball_y_t) then
				-- reverse its x direction velocity
				x_delta_next <= BALL_V_P;
			-- if it doesn't make contact ...
			else
				-- assert the miss signal for player 2
				p2_miss <= '1';
			end if;
		end if;
	end process;
	
	-- RGB multiplexing circuit
	-- this circuit determines whether the objects will be in the foreground or the background
	process(video_on, wall_on, p1_bar_on, p2_bar_on, rd_ball_on, 
	wall_rgb, p1_bar_rgb, p2_bar_rgb, ball_rgb)
	begin
		if video_on = '0' then
			graph_rgb <= (others=>'0');
		else
			-- based on this priority list if the current pixel is within all three objects ...
			-- the paddles will be given priority and will be drawn over the ball
			if rd_ball_on = '1' then
				graph_rgb <= ball_rgb;
			elsif p1_bar_on = '1' then
				graph_rgb <= p1_bar_rgb;
			elsif p2_bar_on = '1' then
				graph_rgb <= p2_bar_rgb;
			elsif wall_on = '1' then
				graph_rgb <= wall_rgb;
			else
				graph_rgb <= "11111100";			-- yellow background
			end if;
		end if;
	end process;
	
	graph_on <= rd_ball_on & p1_bar_on & p2_bar_on & wall_on;
end arch;