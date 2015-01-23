--
--  gentick.vhd
--  The Medusa Project
--
--  Created by Sebastian Mach on 06.01.15.
--  Copyright (c) 2015. All rights reserved.
--


library IEEE;
use IEEE.std_logic_1164.all;

entity gentick is
port (
  CLK    : in  std_logic;
  in_sig : in  std_logic;
  reset  : in  std_logic;
  tick   : out std_logic
);
end gentick;



architecture gentick_a of gentick is

type   state_type is (s_idle, s_tick, s_wait);
signal state      :  state_type;

begin

	p_control : process(reset, clk)
	begin
	
		if(reset = '0') then
			state <= s_idle;
		elsif(clk'event and clk='1') then
		
			case state is
				when s_idle =>
				
					if(in_sig = '0')then
						state <= s_tick;
					end if;
					
				when s_tick =>
				
					state <= s_wait;
					
				when s_wait =>
				
					if(in_sig = '1')then
						state <= s_idle;
					end if;
					
			end case;
			
		end if;
		
	end process;
	
	
	
	p_output : process(state)
	begin
	
		if(state = s_tick)then
			tick <= '1';
		else
			tick <= '0';
		end if;
		
	end process;
  
 end gentick_a;
