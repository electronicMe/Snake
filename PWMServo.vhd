--
--  PWMServo.vhd
--  The Medusa Project
--
--  Created by Sebastian Mach on 06.01.15.
--  Copyright (c) 2015. All rights reserved.
--


library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.numeric_std.ALL;



entity PWMServo is
generic (
	frequency_g     : integer   :=       20; -- typ       20, in ns
	periode_g       : integer   := 20000000; -- typ 20000000, in ns, must be devidable by frequency_g
	minOn_g         : integer   :=  1000000; -- typ  1000000, in ns, must be devidable by frequency_g, must be smaller than maxOn_g
	maxOn_g         : integer   :=  2000000; -- typ  2000000, in ns, must be devidable by frequency_g, must be bigger than minOn_g
	
	dutyCycleMax_g  : integer   :=     1023  -- typ 1023, the maximum value of the dutycycle
);
port (
	CLK               : in std_logic;
	RESET_n           : in std_logic;
	DUTYCYCLE         : in integer;
	
	PWMOut            : out std_logic;
	reduction_g     : in integer   :=        0; -- typ        0, in ns, must be smaller than ((maxOn_g - minOn_g) / 2)
											 -- calculate damping of the altitude:    reduction_g = (((maxOn_g - minOn_g) / 200) * dumpingInPercent)
	
	INVERT_HORN       : in std_logic := '0'; -- typ '0', if '1', servo horn angle will be inverted
	CENTER_CORRECTION : in integer   :=  0   -- typ 0, in ns, used to correct the center of the servo horn. Modifies the on periode additive.
);
end PWMServo;



architecture PWMServo_a of PWMServo is

type state_type is (sON, sOFF);

signal periodeTimer: integer range 0 to periode_g; -- contains the time of the periode in ns
signal onTimer     : integer range 0 to maxOn_g;   -- contains the time of the on time in ns

signal outState      : state_type;

begin

	p_state: process(RESET_n, CLK)
	begin
	
		if (RESET_n = '0') then
			
			periodeTimer <= 0;
			onTimer      <= 0;
			outState     <= sOFF;
			
		else
			if ((CLK = '1') AND (CLK'event)) then
				
				periodeTimer <= periodeTimer + frequency_g;
				onTimer      <= onTimer      + frequency_g;
				
				if (periodeTimer >= periode_g) then
					-- periode is over. reset counters
					periodeTimer <= 0;
					onTimer      <= 0;
					outState     <= sON;
				else
					
					-- if output is on, check if ON periode is probably over
					if (outState = sON) then
					
						-- check if ON periode is over
						if (onTimer > minOn_g) then
						
							-- minimum on time is over. check if dutycycle is over
							if (INVERT_HORN = '0') then
								if (onTimer > ((((((maxOn_g - reduction_g) - (minOn_g + reduction_g)) / dutyCycleMax_g) * DUTYCYCLE) + minOn_g) + CENTER_CORRECTION)) then
									-- on periode is over
									outState <= sOFF;
								end if;
							else
								if (onTimer > ((((((maxOn_g - reduction_g) - (minOn_g + reduction_g)) / dutyCycleMax_g) * (dutyCycleMax_g - DUTYCYCLE)) + minOn_g) + CENTER_CORRECTION)) then
									-- on periode is over
									outState <= sOFF;
								end if;
							end if;
							
						end if;
						
					end if;
				end if;
			
			end if;
		end if;
	
	end process;
	
	
	
	p_PWM: process(outState)
	begin
	
		case outState is
			when sON => PWMOut <= '1';
			when others => PWMOut <= '0';
		end case;
		
	end process;

end architecture;


