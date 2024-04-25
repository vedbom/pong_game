library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity VGA_sync is
	port(
		clk, reset: in std_logic;
		hsync, vsync: out std_logic;
		-- determines which portions of the horizontal and vertical scan lines the display should be on
		video_on: out std_logic;
		-- for sending the pixel clock to the pixel generation circuit
		p_tick: out std_logic;
		-- location of the current pixel on the screen
		pixel_x, pixel_y: out std_logic_vector(9 downto 0)
		);
end VGA_sync;

architecture arch of VGA_sync is
	-- the following values are from the 640x480 VGA industry standard
	constant HD: integer := 640;		-- horizontal display area
	constant HF: integer := 16;		-- horizontal front porch (left border)
	constant HB: integer := 48;		-- horizontal back porch (right border)
	constant HR: integer := 96;		-- horizontal retrace
	constant VD: integer := 480;		-- vertical display area
	constant VF: integer := 10;		-- vertical front porch (bottom border)
	constant VB: integer := 33;		-- vertical back porch (top border)
	constant VR: integer := 2;			-- vertical retrace
	
	-- pixel frequency for industry standard 640x480 VGA is 25 MHz
	-- the system clock is 100 MHz
	-- use a mod-4 counter to divide the system clock frequency by 4 to get 25 MHz
	-- mod-4 counter
	signal mod4_reg, mod4_next: unsigned(1 downto 0);
	
	-- the total number of pixels per line is HD+HF+HB+HR = 800
	-- the total number of lines per screen is VD+VF+VB+VR = 525
	-- a mod-9 counter is sufficient to keep track of the current pixel and line counters
	signal v_count_reg, v_count_next: unsigned(9 downto 0);
	signal h_count_reg, h_count_next: unsigned(9 downto 0);
	
	-- buffers are used for the h_sync and v_sync signals to prevent any glitches
	-- this also means the RGB signals should be buffered to stay synchronized with the scan signals
	-- output buffer
	signal v_sync_reg, v_sync_next: std_logic;
	signal h_sync_reg, h_sync_next: std_logic;
	
	-- status signals used to indicate the completion of the horizontal and vertical scans
	-- status signal
	signal h_end, v_end, pixel_tick: std_logic;
begin
	-- registers
	process(clk, reset)
	begin
		if (reset = '1') then
			mod4_reg <= (others=>'0');
			v_count_reg <= (others=>'0');
			h_count_reg <= (others=>'0');
			v_sync_reg <= '0';
			h_sync_reg <= '0';
		elsif (clk'event and clk='1') then
			mod4_reg <= mod4_next;
			v_count_reg <= v_count_next;
			h_count_reg <= h_count_next;
			v_sync_reg <= v_sync_next;
			h_sync_reg <= h_sync_next;
		end if;
	end process;
	
	-- mod-4 circuit to generate 25MHz enable tick
	mod4_next <= mod4_reg + 1;
	-- 25 MHz pixel tick
	pixel_tick <= '1' when mod4_reg=3 else '0';
	-- status
	h_end <= '1' when h_count_reg=(HD+HF+HB+HR-1) else '0';
	v_end <= '1' when v_count_reg=(VD+VF+VB+VR-1) else '0';
	
	-- mod-800 horizontal sync counter
	process(h_count_reg, h_end, pixel_tick)
	begin
		if (pixel_tick = '1') then
			if (h_end = '1') then
				h_count_next <= (others=>'0');
			else
				h_count_next <= h_count_reg + 1;
			end if;
		else
			h_count_next <= h_count_reg;
		end if;
	end process;
	
	-- mod-525 vertical sync counter
	process(v_count_reg, h_end, v_end, pixel_tick)
	begin
		if (pixel_tick = '1' and h_end = '1') then
			if (v_end = '1') then
				v_count_next <= (others=>'0');
			else
				v_count_next <= v_count_reg + 1;
			end if;
		else
			v_count_next <= v_count_reg;
		end if;
	end process;
	
	-- horizontal and vertical sync, buffered to avoid glitch
	h_sync_next <= '1' when (h_count_reg >= (HD+HF)) and (h_count_reg <= (HD+HF+HR-1)) else
						'0';
	v_sync_next <= '1' when (v_count_reg >= (VD+VF)) and (v_count_reg <= (VD+VF+VR-1)) else
						'0';
										
	-- video on/off
	video_on <= '1' when (h_count_reg < HD) and (v_count_reg < VD) else
					'0';
	
	-- output signal
	hsync <= h_sync_reg;
	vsync <= v_sync_reg;
	pixel_x <= std_logic_vector(h_count_reg);
	pixel_y <= std_logic_vector(v_count_reg);
	p_tick <= pixel_tick;
end arch;

