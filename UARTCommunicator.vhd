--
--  UARTCommunicator.vhd
--  The Medusa Project
--
--  Created by Sebastian Mach on 06.01.15.
--  Copyright (c) 2015. All rights reserved.
--


library IEEE;
use IEEE.std_logic_1164.all;
use work.Arrays_pkg.all;
use std.textio.all;






entity UARTCommunicator is

generic (
	BAUD_RATE_g       : positive := 115200;
	CLOCK_FREQUENCY_g : positive := 50000000;
	numServos_g       : integer  := 26;

	bufferSize_g      : positive := 255
);
port (
	CLK               : in std_logic;
	RESET_n           : in std_logic;

	activateServo     : inout std_logic_vector(numServos_g - 1 downto 0);
	activateCounter   : inout std_logic_vector(numServos_g - 1 downto 0);
	centerCorrections : inout INT_ARRAY(numServos_g - 1 downto 0);
	initCounterVals   : inout INT_ARRAY(numServos_g - 1 downto 0);
	damping           : inout INT_ARRAY(numServos_g - 1 downto 0);
	LUT               : in    INT_ARRAY(numServos_g - 1 downto 0);
	dutycycle         : inout INT_ARRAY(numServos_g - 1 downto 0);
	step              : out   std_logic;
	counter           : in    INT_ARRAY(numServos_g - 1 downto 0)
);

end UARTCommunicator;






architecture UARTCommunicator_a of UARTCommunicator is



	--==========================================================================--
	-- TYPE DEFINITIONS                                                         --
	--==========================================================================--

	type runMode is (runMode_stopped, runMode_centering, runMode_singleStep, runMode_running);

	type buffer_t is record
		-- Holds the buffer content
		bufferContent       : string(1 to bufferSize_g);

		-- A pointer to the element in bufferContent to read/write from/to
		inputBufferPointer  : positive;

		-- Holds the number of elements in bufferContent
		inputBufferSize     : integer range 0 to bufferSize_g;
	end record;






	--==========================================================================--
	-- SIGNALS                                                                  --
	--==========================================================================--

	signal s_runMode : runMode;

	signal inBuffer  : buffer_t;
	signal outBuffer : buffer_t;






	--==========================================================================--
	-- PROCEDURES                                                               --
	--==========================================================================--

	procedure setActivateServo ( variable newValue: in std_logic_vector(numServos_g - 1 downto 0) ) is
	begin
		activateServo <= newValue;
	end procedure setActivateServo;

	procedure setActivateCounter ( variable newValue: inout std_logic_vector(numServos_g - 1 downto 0) ) is
		activateCounter <= newValue;
	end procedure setActivateCounter;






begin






	--==========================================================================--
	-- RUN MODE PROCESS                                                         --
	--==========================================================================--
	p_runMode: process(s_runMode)
	begin

		case s_runMode is
			when runMode_stopped    =>
				setActivateServo( (others <= '0') );
			when runMode_centering  =>

			when runMode_singleStep =>

			when runMode_running    =>

		end case;

	end process;





end UARTCommunicator_a;
