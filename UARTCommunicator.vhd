--
--  counter.vhd
--  The Medusa Project
--
--  Created by Sebastian Mach on 06.01.15.
--  Copyright (c) 2015. All rights reserved.
--


library IEEE;
use IEEE.std_logic_1164.all;
use work.Arrays_pkg.all;






entity UARTCommunicator is
generic (
	BAUD_RATE         : positive;
	CLOCK_FREQUENCY   : positive;
	numServos         : integer
);
port (
	CLK               : in std_logic;
	RESET_n           : in std_logic;

	activateServo     : inout std_logic_vector(numServos - 1 downto 0);
	activateCounter   : inout std_logic_vector(numServos - 1 downto 0);
	centerCorrections : inout INT_ARRAY(numServos - 1 downto 0);
	initCounterVals   : inout INT_ARRAY(numServos - 1 downto 0);
	damping           : inout INT_ARRAY(numServos - 1 downto 0);
	LUT               : out   INT_ARRAY(numServos - 1 downto 0);
	dutycycle         : inout INT_ARRAY(numServos - 1 downto 0);
	step              : out   std_logic;
	counter           : in    INT_ARRAY(numServos - 1 downto 0)
);


end UARTCommunicator;






architecture UARTCommunicator_a of UARTCommunicator is



	--========================================================================--
	-- TYPE DEFINITIONS                                                       --
	--========================================================================--

	type runMode is (runMode_stopped, runMode_centering, runMode_singleStep, runMode_running);










																					
																				
	--========================================================================--
	-- RUN MODE PROCESS                                                       --
	--========================================================================--


	p_runMode : process (CLK)
	begin

		if RESET_n = '0' then

		elsif rising_edge(CLK) then

			case s_runMode is
                    when runMode_stopped    =>
                    	c_activateServo <= (others => '0')
                    when runMode_centering  =>
                    	c_activateServo <= (others => '0')

                    when runMode_singleStep =>
                    	c_activateServo <= (others => '0')
                    when runMode_running    =>
                    	c_activateServo <= (others => '1')
            end case;

		end if;

	end process;





end UARTCommunicator_a;