--
--  UARTCommunicator.vhd
--  The Medusa Project
--
--  Created by Sebastian Mach on 06.01.15.
--  Copyright (c) 2015. All rights reserved.
--
--  Resources:
--  .) http://www.stefanvhdl.com/vhdl/vhdl/txt_util.vhd
--  .) http://de.wikibooks.org/wiki/VHDL#records
--  .) http://www.mrc.uidaho.edu/mrc/people/jff/vhdl_info/txt_util.vhd
--  .) http://cseweb.ucsd.edu/~tweng/cse143/VHDLReference/04.pdf
--  .) http://courses.cs.washington.edu/courses/cse477/00sp/projectwebs/groupb/Anita/WorkingFolder5-24-2330pm/ToPS2/LedRegister/LEDREG/CONV.VHD
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
	counter           : in    INT_ARRAY(numServos_g - 1 downto 0);

	TX                : out   std_logic;
	RX                : in    std_logic;

	debug             : out   std_logic_vector(7 downto 0)
);

end UARTCommunicator;






architecture UARTCommunicator_a of UARTCommunicator is



	--========================================================================--
	-- TYPE DEFINITIONS                                                       --
	--========================================================================--

	type runMode is (runMode_stopped, runMode_centering, runMode_singleStep, runMode_running);
	type uartSendState is (uartSendState_start, uartSendState_send, uartSendState_write, uartSendState_waitForACK);

	type buffer_t is record
		-- Holds the buffer content
		bufferContent : string(1 to bufferSize_g);

		-- A pointer to the element in bufferContent to read/write from/to
		bufferPointer : positive;

		-- Holds the number of elements in bufferContent
		contentSize   : integer range 0 to bufferSize_g;
	end record;






	--========================================================================--
	-- SIGNALS                                                                --
	--========================================================================--

	signal s_runMode       : runMode       := runMode_stopped;
	signal s_uartSendState : uartSendState := uartSendState_start;


	------------------------------------------------------------------UART INPUT
	signal inBuffer                : buffer_t  := ((others => '0'), 1, 0);
	signal processInBuffer         : std_logic := '0';
	signal lastSentInBufferPointer : positive  := 1;
	constant commandTerminator     : character := CR;


	-----------------------------------------------------------------UART OUTPUT
	signal outBuffer        : buffer_t  := ((others => '0'), 1, 0);
	signal sendBuffer       : buffer_t  := ((others => '0'), 1, 0);
	signal readyToSend      : std_logic := '0';
	signal commandProcessed : std_logic := '0';


	----------------------------------------------------------------UART Signals
	signal DATA_STREAM_IN      : std_logic_vector(7 downto 0) := (others => '0');
	signal DATA_STREAM_IN_STB  : std_logic := '0';
	signal DATA_STREAM_IN_ACK  : std_logic;
	signal DATA_STREAM_OUT     : std_logic_vector(7 downto 0);
	signal DATA_STREAM_OUT_STB : std_logic;
	signal DATA_STREAM_OUT_ACK : std_logic := '1';






	--========================================================================--
	-- FUNCTIONS                                                              --
	--========================================================================--


	-- From STD_LOGIC_VECTOR to CHARACTER converter
	-- Source: http://courses.cs.washington.edu/courses/cse477/00sp/projectwebs/groupb/Anita/WorkingFolder5-24-2330pm/ToPS2/LedRegister/LEDREG/CONV.VHD
	function CONV (X :STD_LOGIC_VECTOR (7 downto 0)) return CHARACTER is
		constant XMAP :INTEGER :=0;
		variable TEMP :INTEGER :=0;
	begin
		for i in X'RANGE loop
			TEMP:=TEMP*2;
			case X(i) is
				when '0' | 'L'  => null;
				when '1' | 'H'  => TEMP :=TEMP+1;
				when others     => TEMP :=TEMP+XMAP;
			end case;
		end loop;
		return CHARACTER'VAL(TEMP);
	end CONV;


	-- From CHARACTER to STD_LOGIC_VECTOR (7 downto 0) converter
	-- Source: http://courses.cs.washington.edu/courses/cse477/00sp/projectwebs/groupb/Anita/WorkingFolder5-24-2330pm/ToPS2/LedRegister/LEDREG/CONV.VHD
	function CONV (X :CHARACTER) return STD_LOGIC_VECTOR is
		variable RESULT :STD_LOGIC_VECTOR (7 downto 0);
		variable TEMP   :INTEGER :=CHARACTER'POS(X);
	begin
		for i in RESULT'REVERSE_RANGE loop
			case TEMP mod 2 is
				when 0 => RESULT(i):='0';
				when 1 => RESULT(i):='1';
				when others => null;
			end case;
			TEMP:=TEMP/2;
		end loop;
		return RESULT;
	end CONV;


	------------------------------------------------------------- compareStrings
	-- Compares two strings, also with different sizes.
	-- Retrurns TRUE if the two strings are equal (case sensitive).
	-- If one string is longer than the other, this function returns TRUE
	-- when the rest of the longer string is filled with NUL values
	function compareStrings (str1: string;
							  str2: string
							 ) return boolean is
		variable loopCount : positive;
		variable char1     : character;
		variable char2     : character;
	begin
		if (str1'length < str2'length) then
			loopCount := str2'length;
		else -- if str1'length > str2'length OR str1'length = str2'length
			loopCount := str1'length;
		end if;

		for i in 1 to loopCount loop
			if (i > str1'length) then
				char1 := NUL;
			else
				char1 := str1(i);
			end if;


			if (i > str2'length) then
				char2 := NUL;
			else
				char2 := str2(i);
			end if;


			if NOT ((char1 = NUL) OR (char2 = NUL) OR (char1 = char2)) then
				return FALSE;
			end if;

			return TRUE;
		end loop;
	end compareStrings;








	--========================================================================--
	-- PROCEDURES                                                             --
	--========================================================================--


	------------------------------------------------------------setActivateServo
	procedure setActivateServo ( constant index    : in integer range 0 to (numServos_g - 1);
								  constant newValue : in std_logic
								) is
	begin
		activateServo(index) <= newValue;
	end procedure setActivateServo;


	----------------------------------------------------------setActivateCounter
	procedure setActivateCounter ( constant index    : in integer range 0 to (numServos_g - 1);
									constant newValue : in std_logic
								  ) is
	begin
		activateCounter(index) <= newValue;
	end procedure setActivateCounter;


	-------------------------------------------------------------------setString
	procedure setString ( variable theString : inout string;
						   constant newValue  : in    string
						 ) is
	begin
		theString := (others => NUL);

		for i in 1 to newValue'length loop
			theString(i) := newValue(i);
		end loop;
	end procedure setString;


	-------------------------------------------------------------appendCharacter
	-- Writes data to the position of the buffer pointer and sets the pointer
	-- to the next character
	procedure appendCharacter ( signal   theBuffer : inout buffer_t;
								 variable data      : in    character
							   ) is
	begin
		if (theBuffer.contentSize < bufferSize_g) then
			theBuffer.bufferContent(theBuffer.bufferPointer) <= data;
			theBuffer.bufferPointer <= theBuffer.bufferPointer + 1;
			theBuffer.contentSize   <= theBuffer.contentSize   + 1;
		end if;
	end procedure appendCharacter;


	-----------------------------------------------------------------resetBuffer
	procedure resetBuffer( signal theBuffer : out buffer_t) is
	begin
		theBuffer <= ((others => '0'), 1, 0);
	end procedure resetBuffer;


	------------------------------------------------------------------readBuffer
	-- Reads the character at the position of the buffer pointer and sets the
	-- pointer to the next character
	procedure readBuffer( signal theBuffer : inout buffer_t;
						   signal data      : out   std_logic_vector(7 downto 0)
						 ) is
	begin

		if (theBuffer.bufferPointer <= theBuffer.contentSize) then
			data <= CONV(theBuffer.bufferContent(theBuffer.bufferPointer));
			theBuffer.bufferPointer <= theBuffer.bufferPointer + 1;
		else
			data <= (others => '0');
		end if;

	end procedure readBuffer;


	-----------------------------------------------------------------writeBuffer
	procedure writeBuffer( signal   theBuffer : inout buffer_t;
							variable data      : in     string
						  ) is
		variable bufferPointer : natural := 1;
		variable contentSize   : natural := 0;
	begin

		-- check for buffer overflow
		if (data'length <= bufferSize_g) then

			theBuffer.bufferContent <= (others => NUL);

			copyLoop: for i in 1 to data'length loop
				exit copyLoop when (data(i) = NUL);

				theBuffer.bufferContent(bufferPointer) <= data(i);
				bufferPointer := bufferPointer + 1;
				contentSize   := contentSize   + 1;
			end loop;

			theBuffer.bufferPointer <= bufferPointer;
			theBuffer.contentSize   <= contentSize;
		end if;

	end procedure writeBuffer;


	------------------------------------------------------------------copyBuffer
	-- Copies the source buffer to the destination buffer and sets the pointer
	-- of the destination buffer to 1
	procedure copyBuffer( signal sourceBuffer      : in buffer_t;
						   signal destinationBuffer : out buffer_t
						 ) is
	begin
		destinationBuffer.bufferContent <= sourceBuffer.bufferContent;
		destinationBuffer.contentSize   <= sourceBuffer.contentSize;
		destinationBuffer.bufferPointer <= 1;
	end procedure copyBuffer;






begin

	--========================================================================--
	-- SUPPORTING COMPONENTS                                                  --
	--========================================================================--

	uart: entity work.UART(RTL) generic map (BAUD_RATE           => BAUD_RATE_g,
											   CLOCK_FREQUENCY     => CLOCK_FREQUENCY_g)
								 port map    (CLOCK               => CLK,
											   RESET               => NOT RESET_n,
											   DATA_STREAM_IN      => DATA_STREAM_IN,
											   DATA_STREAM_IN_STB  => DATA_STREAM_IN_STB,
											   DATA_STREAM_IN_ACK  => DATA_STREAM_IN_ACK,
											   DATA_STREAM_OUT     => DATA_STREAM_OUT,
											   DATA_STREAM_OUT_STB => DATA_STREAM_OUT_STB,
											   DATA_STREAM_OUT_ACK => DATA_STREAM_OUT_ACK,
											   TX                  => TX,
											   RX                  => RX
											  );






	--========================================================================--
	-- RUN MODE PROCESS                                                       --
	--========================================================================--
	p_runMode: process(s_runMode)
	begin

		case s_runMode is
			when runMode_stopped    => -------------------------runMode_stopped
				for i in 0 to (numServos_g - 1) loop
					setActivateServo  ( i, '1' );
					setActivateCounter( i, '0' );
				end loop;
			when runMode_centering  => -----------------------runMode_centering
				for i in 0 to (numServos_g - 1) loop
					setActivateServo  ( i, '1' );
					setActivateCounter( i, '0' );
				end loop;
			when runMode_singleStep => ----------------------runMode_singleStep
				for i in 0 to (numServos_g - 1) loop
					setActivateServo  ( i, '1' );
					setActivateCounter( i, '0' );
				end loop;
			when runMode_running    => -------------------------runMode_running
				for i in 0 to (numServos_g - 1) loop
					setActivateServo  ( i, '1' );
					setActivateCounter( i, '1' );
				end loop;
		end case; -----------------------------------------------------end case

	end process;






	--==========================================================================--
	-- UART RECEIVER PROCESS                                                    --
	--==========================================================================--
	p_uartReceiver: process(CLK, RESET_n)
		variable receivedCharacter : character := NUL;
	begin

		if (RESET_n = '0') then
			resetBuffer(inBuffer);
			DATA_STREAM_OUT_ACK <= '0';
			processInBuffer     <= '0';
		elsif rising_edge(CLK) then

			-- clear in buffer if a command was processed
			if (commandProcessed = '1') then
				resetBuffer(inBuffer);
			end if;


			DATA_STREAM_OUT_ACK <= '0';
			processInBuffer     <= '0';


			if (DATA_STREAM_OUT_STB = '1') then

				-- Tell uart we finished receiving the character
				DATA_STREAM_OUT_ACK <= '1';

				-- Receive character
				receivedCharacter := CONV(DATA_STREAM_OUT);

				-- Check if character is command terminator
				if (receivedCharacter = commandTerminator) then
					-- Finished receiving command. Trigger command processing
					processInBuffer <= '1';
				else
					-- Command not finished yet. Write character into input buffer.
					appendCharacter(inBuffer, receivedCharacter);
				end if;

			end if;
		end if;

	end process;






	--========================================================================--
	-- UART SENDER PROCESS                                                    --
	--========================================================================--
	p_uartSender: process(CLK, RESET_n)
	begin

		if (RESET_n = '0') then
			resetBuffer(sendBuffer);
			DATA_STREAM_IN_STB <= '0';
			s_uartSendState    <= uartSendState_start;
		elsif rising_edge(CLK) then

			case s_uartSendState is
				when uartSendState_start      =>-------------uartSendState_send
					if (readyToSend = '1') then
						copyBuffer(outBuffer, sendBuffer);
						s_uartSendState <= uartSendState_send;
					end if;
				when uartSendState_send       =>-------------uartSendState_send
					if (sendBuffer.bufferPointer > sendBuffer.contentSize) then
						s_uartSendState <= uartSendState_start;
					elsif (DATA_STREAM_IN_ACK = '0') then
						s_uartSendState <= uartSendState_write;
					end if;
				when uartSendState_write      =>------------uartSendState_write
					readBuffer(sendBuffer, DATA_STREAM_IN);
					DATA_STREAM_IN_STB      <= '1';
					s_uartSendState         <= uartSendState_waitForACK;
				when uartSendState_waitForACK =>-------uartSendState_waitForACK
					if (DATA_STREAM_IN_ACK = '1') then
						s_uartSendState    <= uartSendState_send;
						DATA_STREAM_IN_STB <= '0';
					end if;
			end case; -------------------------------------------------end case

		end if;

	end process;






	--========================================================================--
	-- COMMAND PROCESSER                                                      --
	--========================================================================--
	p_commandProcessor: process(CLK, RESET_n)
		variable command : string(1 to bufferSize_g) := (others => NUL);
		variable data    : string(1 to bufferSize_g) := (others => NUL);
	begin

		if (RESET_n = '0') then
			resetBuffer(outBuffer);
			readyToSend             <= '0';
			lastSentInBufferPointer <= 1;
		elsif rising_edge(CLK) then
			readyToSend      <= '0';
			commandProcessed <= '0';

			if (processInBuffer = '1') then

				-- process new command

				command := inBuffer.bufferContent;

				if compareStrings(command, "hello") then
					setString(data, "Hello there :D");
					writeBuffer(outBuffer, data);
					readyToSend      <= '1';
					commandProcessed <= '1';
				elsif compareStrings(command, "ping") then
					setString(data, "pong");
					writeBuffer(outBuffer, data);
					readyToSend      <= '1';
					commandProcessed <= '1';
				end if;

			elsif (inBuffer.bufferPointer /= lastSentInBufferPointer) then

				-- echo last received character

				lastSentInBufferPointer <= inBuffer.bufferPointer;
				data(1)                 := inBuffer.bufferContent(inBuffer.bufferPointer - 1);
				data(2)                 := NUL;
				writeBuffer(outBuffer, data);
				readyToSend             <= '1';

			end if;

		end if;

	end process;



end UARTCommunicator_a;
