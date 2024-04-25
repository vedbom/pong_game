library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity mod10_counter is
	port(
		clk, reset: in std_logic;
		-- signals for incrementing and clearing the counter
		d_inc, d_clr: in std_logic;
		dig: out std_logic_vector(3 downto 0)
		);
end mod10_counter;

architecture arch of mod10_counter is
	signal dig_reg, dig_next: unsigned(3 downto 0);
begin
	-- registers
	process(clk, reset)
	begin
		if (reset = '1') then
			dig_reg <= (others=>'0');
		elsif (clk'event and clk = '1') then
			dig_reg <= dig_next;
		end if;
	end process;
	
	-- next state logic
	dig_next <= (others=>'0') when d_clr = '1' or dig_reg = 9 else
					dig_reg + 1 when d_inc = '1' else
					dig_reg;
					
	-- output logic
	dig <= std_logic_vector(dig_reg);
end arch;

