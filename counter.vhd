--
--  counter.vhd
--  The Medusa Project
--
--  Created by Sebastian Mach on 06.01.15.
--  Copyright (c) 2015. All rights reserved.
--


library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;



entity counter is

	generic (
		maxValue_g     : integer -- maximum count value
	);
	port(
		CLK          : in  std_logic;
		RESET_n      : in  std_logic;

		initialValue : integer := 0; -- the initial value after reset

		TC           : out integer range 0 to maxValue_g := initialValue
	);

end counter;



architecture counter_a of counter is

signal counter: integer range 0 to maxValue_g := initialValue;

begin

	p_count: process(CLK, RESET_n)
	begin

		if(RESET_n = '0') then counter <= initialValue;
		elsif rising_edge(CLK) then

			if (counter >= maxValue_g) then
				counter <= 0;
			else
				counter <= counter + 1;
			end if;
		
		end if;
	
	end process;

	TC <= counter;

end counter_a;
