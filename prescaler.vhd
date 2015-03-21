--
--  prescaler.vhd
--  The Medusa Project
--
--  Created by Sebastian Mach on 06.01.15.
--  Copyright (c) 2015. All rights reserved.
--


library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.numeric_std.ALL;



entity prescaler is
generic (
	scale   : natural
);
port (
	CLK     : in std_logic;
	RESET_n : in std_logic;
	TICK    : out std_logic
);
end prescaler;



architecture prescaler_a of prescaler is

	signal counter : natural := scale;

begin

	p_prescaler: process(CLK, RESET_n)
	begin

		if (RESET_n = '0') then
			TICK    <= '0';
			counter <= scale;
		elsif (CLK = '1' AND CLK'event) then
			if (counter < 1) then
				TICK <= '1';
				counter <= scale;
			else
				TICK    <= '0';
				counter <= counter - 1;
			end if;
		end if;

	end process;

end architecture;
