--
--  UARTCommunicator.vhd
--  The Medusa Project
--
--  Created by Sebastian Mach on 06.01.15.
--  Copyright (c) 2015. All rights reserved.
--


library IEEE;
use IEEE.std_logic_1164.all;
use std.textio.all;
use ieee.numeric_std.all;

use work.Snake_pkg.all;
use work.Arrays_pkg.all;
use work.Buffer_pkg.all;
use work.UART_pkg.all;






entity UARTCommunicator is

generic (
	BAUD_RATE_g       : positive := 115200;
	CLOCK_FREQUENCY_g : positive := 50000000
);

port (
	CLK               : in std_logic;
	RESET_n           : in std_logic;

	activateServo     : inout std_logic_vector(numServos_c - 1 downto 0);
	activateCounter   : inout std_logic_vector(numServos_c - 1 downto 0);
	centerCorrections : inout INT_ARRAY(numServos_c - 1 downto 0);
	initCounterVals   : inout INT_ARRAY(numServos_c - 1 downto 0);
	damping           : inout INT_ARRAY(numServos_c - 1 downto 0);
	LUT               : in    INT_ARRAY(numServos_c - 1 downto 0);
	dutycycle         : inout INT_ARRAY(numServos_c - 1 downto 0);
	counter           : in    INT_ARRAY(numServos_c - 1 downto 0);

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






	--========================================================================--
	-- FUNCTION DEFINITIONS                                                   --
	--========================================================================--

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
				--for i in 0 to (numServos_c - 1) loop
                --    activateServo(i) <= '1';
                --    activateCounter(i) <= '0';
                --end loop;
			when runMode_centering  => ------------------------runMode_centering
				--for i in 0 to (numServos_c - 1) loop
                --    activateServo(i) <= '1';
                --    activateCounter(i) <= '0';
				--end loop;
			when runMode_singleStep => -----------------------runMode_singleStep
				--for i in 0 to (numServos_c - 1) loop
                --    activateServo(i) <= '1';
                --    activateCounter(i) <= '0';
				--end loop;
			when runMode_running    => --------------------------runMode_running
				--for i in 0 to (numServos_c - 1) loop
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
		variable data    : string(1 to bufferSize_c) := (others => NUL);
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

						if ((command.id < 0) OR (command.id > numServos_c - 1)) then
							answerCommand("get servo: invalid id", outBuffer, readyToSend, commandProcessed);
						else
							answerCommand("activateServo " & integer'image(command.id) & " = ?", outBuffer, readyToSend, commandProcessed);
						end if;


					---------------------------------------------------- counter
					elsif compareStrings(command.command, "counter") then

						if ((command.id < 0) OR (command.id > numServos_c - 1)) then
							answerCommand("get counter: invalid id", outBuffer, readyToSend, commandProcessed);
						else
							answerCommand("activateCounter " & integer'image(command.id) & " = ?", outBuffer, readyToSend, commandProcessed);
						end if;



					------------------------------------------- centerCorrection
					elsif compareStrings(command.command, "centerCorrection") then

						if ((command.id < 0) OR (command.id > numServos_c - 1)) then
							answerCommand("get centerCorrection: invalid id", outBuffer, readyToSend, commandProcessed);
						else
							answerCommand("centerCorrection " & integer'image(command.id) & " = " & integer'image(centerCorrections(command.id)), outBuffer, readyToSend, commandProcessed);
						end if;


					------------------------------------------- initCounterValue
					elsif compareStrings(command.command, "initCounterValue") then

						if ((command.id < 0) OR (command.id > numServos_c - 1)) then
							answerCommand("get initCounterValue: invalid id", outBuffer, readyToSend, commandProcessed);
						else
							answerCommand("get initCounterValue: not implemented yet", outBuffer, readyToSend, commandProcessed);
						end if;


					---------------------------------------------------- damping
					elsif compareStrings(command.command, "damping") then

						if ((command.id < 0) OR (command.id > numServos_c - 1)) then
							answerCommand("get damping: invalid id", outBuffer, readyToSend, commandProcessed);
						else
							answerCommand("get damping: not implemented yet", outBuffer, readyToSend, commandProcessed);
						end if;


					-------------------------------------------------------- LUT
					elsif compareStrings(command.command, "LUT") then

						if ((command.id < 0) OR (command.id > numServos_c - 1)) then
							answerCommand("get LUT: invalid id", outBuffer, readyToSend, commandProcessed);
						else
							answerCommand("get LUT: not implemented yet", outBuffer, readyToSend, commandProcessed);
						end if;


					-------------------------------------------------- dutycycle
					elsif compareStrings(command.command, "dutycycle") then

						if ((command.id < 0) OR (command.id > numServos_c - 1)) then
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

                        if ((command.id < 0) OR (command.id > numServos_c - 1)) then
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
