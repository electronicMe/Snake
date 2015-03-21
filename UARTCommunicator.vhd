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
--  .) DataTypes - http://cseweb.ucsd.edu/~tweng/cse143/VHDLReference/04.pdf
--  .) http://courses.cs.washington.edu/courses/cse477/00sp/projectwebs/groupb/Anita/WorkingFolder5-24-2330pm/ToPS2/LedRegister/LEDREG/CONV.VHD
--


library IEEE;
use IEEE.std_logic_1164.all;
use work.Arrays_pkg.all;
use std.textio.all;
use ieee.numeric_std.all;






entity UARTCommunicator is

generic (
	BAUD_RATE_g       : positive := 115200;
	CLOCK_FREQUENCY_g : positive := 50000000;
	numServos_g       : integer  := 26;

	bufferSize_g      : positive := 10
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
	counter           : in    INT_ARRAY(numServos_g - 1 downto 0);

	step              : out   std_logic;
	reset             : out   std_logic;

	TX                : out   std_logic;
	RX                : in    std_logic

	--debug             : out   std_logic_vector(7 downto 0);
	--debug2            : out   std_logic
);

end UARTCommunicator;






architecture UARTCommunicator_a of UARTCommunicator is



	--========================================================================--
	-- TYPE DEFINITIONS                                                       --
	--========================================================================--

	type runMode is (			runMode_stopped,
								runMode_centering,
								runMode_singleStep,
								runMode_running
					);

	type commandMode is (		commandMode_home,
								commandMode_set,
								commandMode_get
						);

	type commandSubMode is (	commandSubMode_runMode,
								commandSubMode_servo,
								commandSubMode_counter,
								commandSubMode_centerCorrection,
								commandSubMode_initCounterValue,
								commandSubMode_damping,
								commandSubMode_lut,
								commandSubMode_dutycycle
						   );

	type uartSendState is (		uartSendState_start,
								uartSendState_send,
								uartSendState_write,
								uartSendState_waitForACK
						  );

	type buffer_t is record
		-- Holds the buffer content
		bufferContent : string(1 to bufferSize_g);

		-- A pointer to the element in bufferContent to read/write from/to
		bufferPointer : positive;

		-- Holds the number of elements in bufferContent
		contentSize   : integer range 0 to bufferSize_g;
	end record;

	type command_t is record
		command : string(1 to bufferSize_g);
		id      : integer range 0 to numServos_g - 1;
		value   : integer;
	end record;






	--========================================================================--
	-- SIGNALS                                                                --
	--========================================================================--

	signal RESET_nn                 : std_logic;

	signal s_runMode                : runMode        := runMode_stopped;
	signal s_commandMode            : commandMode    := commandMode_home;
	signal s_commandSubMode         : commandSubMode := commandSubMode_runMode;
	signal s_uartSendState          : uartSendState  := uartSendState_start;
	signal s_commandProcessWasReset : std_logic      := '1';


	------------------------------------------------------------------UART INPUT
	signal inBuffer                : buffer_t  := ((others => '0'), 1, 0);
	signal processInBuffer         : std_logic := '0';
	signal lastSentInBufferPointer : positive  :=  1;
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


			if (char1 /= char2) then
				return FALSE;
			end if;
		end loop;

		return TRUE;
	end compareStrings;



	---------------------------------------------------------- stringFromRunMode
	function stringFromRunMode (rm: runMode) return string is
	begin

		if (rm = runMode_running) then
			return "running";
		elsif (rm = runMode_stopped) then
			return "stopped";
		elsif (rm = runMode_singleStep) then
			return "singleStep";
		elsif (rm = runMode_centering) then
			return "centering";
		else
			return "?";
		end if;
	end stringFromRunMode;



	------------------------------------------------------ stringFromCommandMode
	function stringFromCommandMode (cm: commandMode) return string is
	begin

		if (cm = commandMode_home) then
			return "home";
		elsif (cm = commandMode_set) then
			return "set ";
		elsif (cm = commandMode_get) then
			return "get ";
		else
			return "?   ";
		end if;
	end stringFromCommandMode;



	--------------------------------------------------- stringFromCommandSubMode
	function stringFromCommandSubMode (csm: commandSubMode) return string is
	begin

		if (csm = commandSubMode_runMode) then
			return "runMode";
		elsif (csm = commandSubMode_servo) then
			return "servo";
		elsif (csm = commandSubMode_counter) then
			return "counter";
		elsif (csm = commandSubMode_centerCorrection) then
			return "centerCorrection";
		elsif (csm = commandSubMode_initCounterValue) then
			return "initCounterValue";
		elsif (csm = commandSubMode_damping) then
			return "damping";
		elsif (csm = commandSubMode_lut) then
			return "lut";
		elsif (csm = commandSubMode_dutycycle) then
			return "dutycycle";
		elsif (csm = commandSubMode_counter) then
			return "counter";
		else
			return "?";
		end if;
	end stringFromCommandSubMode;



	---------------------------------------------------------------- stringToInt
	function stringToInt (str: string(1 to bufferSize_g)) return integer is
		variable value          : integer := 1;
		variable coefficient    : integer := 1;
		variable index          : integer range 1 to bufferSize_g := 1;
		variable characterValue : integer := 0;
	begin
		--debug(1) <= '1';

		--for i in 0 to (str'length - 1) loop
		--	index := str'length - i;
		--	characterValue := CHARACTER'POS(str(index)) - 48;

		--	if ((characterValue >= 0) AND (characterValue <= 10)) then
		--		value := value + (characterValue * coefficient);
		--		coefficient := coefficient * 10;
		--	end if;

		--end loop;

		--debug(6) <= '1';

		return value;
	end stringToInt;



	-------------------------------------------------------------- stringToInt16
	function stringToInt16 (str: string(1 to 2);
                            min: integer;
                            max: integer
                           ) return integer is
		variable valueVector : std_logic_vector(15 downto 0);
		variable byte1       : std_logic_vector(7 downto 0);
		variable byte2       : std_logic_vector(7 downto 0);
        variable value       : integer;
	begin
		byte1 := std_logic_vector(to_unsigned(CHARACTER'POS(str(1)), 8));
		byte2 := std_logic_vector(to_unsigned(CHARACTER'POS(str(2)), 8));

		valueVector := byte1 & byte2;

		value := to_integer(signed(valueVector));

        if (value < min) then
            return min;
        elsif (value > max) then
            return max;
        else
            return value;
        end if;
	end stringToInt16;








	--========================================================================--
	-- PROCEDURES                                                             --
	--========================================================================--


	-------------------------------------------------------------------setString
	procedure setString ( variable theString : inout string;
						  constant newValue  : in    string
						 ) is
	begin
		for i in 1 to theString'length loop
			if (i < newValue'length) then
				theString(i) := newValue(i);
			else
				theString(i) := NUL;
			end if;
		end loop;
	end procedure setString;


	-------------------------------------------------------------appendCharacter
	-- Writes data to the position of the buffer pointer and sets the pointer
	-- to the next character
	procedure appendCharacter ( signal   theBuffer : inout buffer_t;
								 variable data      : in    character
							   ) is
	begin
		if ((theBuffer.contentSize < bufferSize_g) AND (data /= LF)) then
			theBuffer.bufferContent(theBuffer.bufferPointer) <= data;
			theBuffer.bufferPointer <= theBuffer.bufferPointer + 1;
			theBuffer.contentSize   <= theBuffer.contentSize   + 1;
		end if;
	end procedure appendCharacter;


	-----------------------------------------------------------------resetBuffer
	procedure resetBuffer( signal theBuffer : out buffer_t) is
	begin
		theBuffer <= ((others => NUL), 1, 0);
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


	---------------------------------------------------------------answerCommand
	-- This procedure should only be called by the p_commandProcessor process
	-- to send an aswer of a command
	procedure answerCommand ( constant answer : in    string;
							  signal   outb   : inout buffer_t;
							  signal   rts    : out   std_logic;
							  signal   cp     : out   std_logic
							) is
		variable data : string(1 to bufferSize_g) := (others => NUL);
	begin
		setString(data, CR & LF & answer & CR & LF & '>');
		writeBuffer(outb, data);
		rts <= '1';
		cp  <= '1';
	end procedure answerCommand;


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


	------------------------------------------------------------------parseInput
	procedure parseInput( signal   input   : in string;
						  variable command : out command_t
						) is
		variable stringBuffer : string(1 to bufferSize_g) := (others => NUL);

		variable commandLength : integer := 0;
		variable idLength      : integer := 0;
		variable valueLength   : integer := 0;
	begin

		-- get command from input
		commandLoop: for i in 1 to input'length loop
			-- loop until space or NUL character
			exit commandLoop when (input(i) = ' ');
            exit commandLoop when (input(i) = NUL);

			stringBuffer(i) := input(i);
			commandLength := i;
		end loop;

		command.command := stringBuffer;


		-- get id from input
		command.id := stringToInt16(input(commandLength + 2 to commandLength + 3), 0, numServos_g - 1);


		-- get value from input
		command.value := stringToInt16(input(commandLength + 5 to commandLength + 6), INTEGER'low, INTEGER'high);

	end procedure parseInput;



begin

	RESET_nn <= NOT RESET_n;

	--========================================================================--
	-- SUPPORTING COMPONENTS                                                  --
	--========================================================================--

	uart: entity work.UART(RTL) generic map (  BAUD_RATE           => BAUD_RATE_g,
											   CLOCK_FREQUENCY     => CLOCK_FREQUENCY_g)
								 port map    ( CLOCK               => CLK,
											   RESET               => RESET_nn,
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
			when runMode_stopped    => --------------------------runMode_stopped
				--for i in 0 to (numServos_g - 1) loop
                --    activateServo(i) <= '1';
                --    activateCounter(i) <= '0';
                --end loop;
			when runMode_centering  => ------------------------runMode_centering
				--for i in 0 to (numServos_g - 1) loop
                --    activateServo(i) <= '1';
                --    activateCounter(i) <= '0';
				--end loop;
			when runMode_singleStep => -----------------------runMode_singleStep
				--for i in 0 to (numServos_g - 1) loop
                --    activateServo(i) <= '1';
                --    activateCounter(i) <= '0';
				--end loop;
			when runMode_running    => --------------------------runMode_running
				--for i in 0 to (numServos_g - 1) loop
                --    activateServo(i) <= '1';
                --    activateCounter(i) <= '1';
                --end loop;
		end case; ------------------------------------------------------end case

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

			DATA_STREAM_OUT_ACK <= '0';
			processInBuffer     <= '0';

			-- clear in buffer if a command was processed
			if (commandProcessed = '1') then
				resetBuffer(inBuffer);
			elsif ((DATA_STREAM_OUT_STB = '1') AND (DATA_STREAM_OUT_ACK = '0')) then

				-- Receive character
				receivedCharacter := CONV(DATA_STREAM_OUT);

				-- Tell uart we finished receiving the character
				DATA_STREAM_OUT_ACK <= '1';

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
		variable command : command_t;
		variable data    : string(1 to bufferSize_g) := (others => NUL);
	begin

		if (RESET_n = '0') then

            -- Reset supporting signals to standard values
            resetBuffer(outBuffer);
			readyToSend               <= '0';
			lastSentInBufferPointer   <=  1;
			s_commandProcessWasReset  <= '1';
			reset                     <= '0';
			step                      <= '0';

            -- Reset robot command signals to standard values
            activateServo             <= (others => '0');
            activateCounter           <= (others => '0');
            centerCorrections         <= (others =>  0 );
            initCounterVals           <= (others =>  0 );
            damping                   <= (others =>  0 );

		elsif rising_edge(CLK) then
			readyToSend      <= '0';
			commandProcessed <= '0';
			step             <= '0';


			-- Send Startup Message if process was reset recently
			if (s_commandProcessWasReset = '1') then
				s_commandProcessWasReset <= '0';
				--setString(data, "This program was written by Sebastian Mach - TGM 2014-2015 5AHEL - All Rights Reserved" & CR & LF & '>');
				writeBuffer(outBuffer, data);
				readyToSend      <= '1';
			end if;


			if (processInBuffer = '1') then

                -- only for debugging purposes. remove when synthesizing for FPGA
                -- write(OUTPUT, "==================================================" & CR & "Received Command: " & command.command & " id: " & integer'image(command.id) & " value: " & integer'image(command.value) & CR);


				-- process new command
				--debug(0) <= '1';
				parseInput(inBuffer.bufferContent, command);
				--debug(7) <= '1';
				---------------------------------------------------------- hello
				if compareStrings(command.command, "hello") then
					answerCommand("Hello there :D", outBuffer ,readyToSend, commandProcessed);

				----------------------------------------------------------- ping
				elsif compareStrings(command.command, "ping") then
					answerCommand("pong", outBuffer, readyToSend, commandProcessed);
					--debug2 <= '1';

				----------------------------------------------------------- help
				elsif compareStrings(command.command, "help") then
					answerCommand("read the documentation for more information", outBuffer, readyToSend, commandProcessed);

				----------------------------------------------------------- home
				elsif compareStrings(command.command, "home") then
					s_commandMode <= commandMode_home;
					answerCommand("new mode: home", outBuffer, readyToSend, commandProcessed);

				------------------------------------------------------------ set
				elsif compareStrings(command.command, "set") then
					s_commandMode <= commandMode_set;
					answerCommand("new mode: set", outBuffer, readyToSend, commandProcessed);

				------------------------------------------------------------ get
				elsif compareStrings(command.command, "get") then
					s_commandMode <= commandMode_get;
					answerCommand("new mode: get", outBuffer, readyToSend, commandProcessed);

				---------------------------------------------------------- reset
				elsif compareStrings(command.command, "reset") then
					reset <= '1';
					answerCommand("reset now", outBuffer, readyToSend, commandProcessed);

				----------------------------------------------------------- tick
				elsif compareStrings(command.command, "tick") then
					step <= '1';
					answerCommand("tick now", outBuffer, readyToSend, commandProcessed);

                ----------------------------------------------------------- test
				elsif compareStrings(command.command, "test") then
					answerCommand("id = " & integer'image(command.id) & " value = " & integer'image(command.value), outBuffer, readyToSend, commandProcessed);

				--========================================================== get
				elsif (s_commandMode = commandMode_get) then

					---------------------------------------------------- runMode
					if compareStrings(command.command, "runMode") then
						answerCommand("runMode = " & stringFromRunMode(s_runMode), outBuffer, readyToSend, commandProcessed);

					------------------------------------------------------ servo
					elsif compareStrings(command.command, "servo") then

						if ((command.id < 0) OR (command.id > numServos_g - 1)) then
							answerCommand("get servo: invalid id", outBuffer, readyToSend, commandProcessed);
						else
							answerCommand("activateServo " & integer'image(command.id) & " = ?", outBuffer, readyToSend, commandProcessed);
						end if;


					---------------------------------------------------- counter
					elsif compareStrings(command.command, "counter") then

						if ((command.id < 0) OR (command.id > numServos_g - 1)) then
							answerCommand("get counter: invalid id", outBuffer, readyToSend, commandProcessed);
						else
							answerCommand("activateCounter " & integer'image(command.id) & " = ?", outBuffer, readyToSend, commandProcessed);
						end if;



					------------------------------------------- centerCorrection
					elsif compareStrings(command.command, "centerCorrection") then

						if ((command.id < 0) OR (command.id > numServos_g - 1)) then
							answerCommand("get centerCorrection: invalid id", outBuffer, readyToSend, commandProcessed);
						else
							answerCommand("centerCorrection " & integer'image(command.id) & " = " & integer'image(centerCorrections(command.id)), outBuffer, readyToSend, commandProcessed);
						end if;


					------------------------------------------- initCounterValue
					elsif compareStrings(command.command, "initCounterValue") then

						if ((command.id < 0) OR (command.id > numServos_g - 1)) then
							answerCommand("get initCounterValue: invalid id", outBuffer, readyToSend, commandProcessed);
						else
							answerCommand("get initCounterValue: not implemented yet", outBuffer, readyToSend, commandProcessed);
						end if;


					---------------------------------------------------- damping
					elsif compareStrings(command.command, "damping") then

						if ((command.id < 0) OR (command.id > numServos_g - 1)) then
							answerCommand("get damping: invalid id", outBuffer, readyToSend, commandProcessed);
						else
							answerCommand("get damping: not implemented yet", outBuffer, readyToSend, commandProcessed);
						end if;


					-------------------------------------------------------- LUT
					elsif compareStrings(command.command, "LUT") then

						if ((command.id < 0) OR (command.id > numServos_g - 1)) then
							answerCommand("get LUT: invalid id", outBuffer, readyToSend, commandProcessed);
						else
							answerCommand("get LUT: not implemented yet", outBuffer, readyToSend, commandProcessed);
						end if;


					-------------------------------------------------- dutycycle
					elsif compareStrings(command.command, "dutycycle") then

						if ((command.id < 0) OR (command.id > numServos_g - 1)) then
							answerCommand("get dutycycle: invalid id", outBuffer, readyToSend, commandProcessed);
						else
							answerCommand("get dutycycle: not implemented yet", outBuffer, readyToSend, commandProcessed);
						end if;


					else
						answerCommand("Unknown Command", outBuffer, readyToSend, commandProcessed);

					end if;

				--========================================================== set
				elsif (s_commandMode = commandMode_set) then

					---------------------------------------------------- runMode
					if compareStrings(command.command, "runMode") then
						answerCommand("set runMode: not implemented yet", outBuffer, readyToSend, commandProcessed);


					------------------------------------------------------ servo
					elsif compareStrings(command.command, "servo") then

                        if ((command.id < 0) OR (command.id > numServos_g - 1)) then
							answerCommand("set servo: invalid id", outBuffer, readyToSend, commandProcessed);
						else
                            if (command.value = 0) then
                                activateServo(command.id) <= '0';
                            else
                                activateServo(command.id) <= '1';
                            end if;
							answerCommand("OK", outBuffer, readyToSend, commandProcessed);
						end if;



					---------------------------------------------------- counter
					elsif compareStrings(command.command, "counter") then
						answerCommand("set counter: not implemented yet", outBuffer, readyToSend, commandProcessed);


					------------------------------------------- centerCorrection
					elsif compareStrings(command.command, "centerCorrection") then
						answerCommand("set centerCorrection: not implemented yet", outBuffer, readyToSend, commandProcessed);


					------------------------------------------- initCounterValue
					elsif compareStrings(command.command, "initCounterValue") then
						answerCommand("set initCounterValue: not implemented yet", outBuffer, readyToSend, commandProcessed);


					---------------------------------------------------- damping
					elsif compareStrings(command.command, "damping") then
						answerCommand("set damping: not implemented yet", outBuffer, readyToSend, commandProcessed);


					-------------------------------------------------- dutycycle
					elsif compareStrings(command.command, "dutycycle") then
						answerCommand("set dutycycle: not implemented yet", outBuffer, readyToSend, commandProcessed);


					else
						answerCommand("Unknown Command", outBuffer, readyToSend, commandProcessed);

					end if;

				end if;

			elsif ((inBuffer.bufferPointer /= lastSentInBufferPointer) AND (inBuffer.bufferPointer - 1 > 0)) then

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
