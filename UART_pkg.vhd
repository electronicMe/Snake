--
--  Arrays_pkg.vhd
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
use std.textio.all;
use ieee.numeric_std.all;

use work.Snake_pkg.all;
use work.Buffer_pkg.all;



package UART_pkg is

	type command_t is record
		command : string(1 to bufferSize_c);
		id      : integer range 0 to numServos_c - 1;
		value   : integer;
	end record;






    --========================================================================--
    -- FUNCTION DEFINITIONS                                                   --
    --========================================================================--

    function CONV (X :STD_LOGIC_VECTOR (7 downto 0)) return CHARACTER;

    function CONV (X :CHARACTER) return STD_LOGIC_VECTOR;

    function compareStrings (str1: string;
							 str2: string
							) return boolean;

    function stringToInt (str: string(1 to bufferSize_c)) return integer;

    function stringToInt16 (str: string(1 to 2);
                            min: integer;
                            max: integer
                           ) return integer;






   --========================================================================--
   -- PROCEDURE DEFINITIONS                                                  --
   --========================================================================--

    procedure setString ( variable theString : inout string;
						  constant newValue  : in    string
						);

    procedure appendCharacter ( signal   theBuffer : inout buffer_t;
    							variable data      : in    character
    						  );

    procedure resetBuffer( signal theBuffer : out buffer_t);

    procedure readBuffer( signal theBuffer : inout buffer_t;
    					  signal data      : out   std_logic_vector(7 downto 0)
    					);

    procedure writeBuffer( signal   theBuffer : inout buffer_t;
    					   variable data      : in     string
    					 );

    procedure answerCommand ( constant answer : in    string;
    						  signal   outb   : inout buffer_t;
    						  signal   rts    : out   std_logic;
    						  signal   cp     : out   std_logic
    						);

    procedure copyBuffer( signal sourceBuffer      : in buffer_t;
    					  signal destinationBuffer : out buffer_t
    					);

    procedure parseInput( signal   input   : in string;
    					  variable command : out command_t
    					);


end UART_pkg;






package body UART_pkg is



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



	---------------------------------------------------------------- stringToInt
	function stringToInt (str: string(1 to bufferSize_c)) return integer is
		variable value          : integer := 1;
		variable coefficient    : integer := 1;
		variable index          : integer range 1 to bufferSize_c := 1;
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
		if ((theBuffer.contentSize < bufferSize_c) AND (data /= LF)) then
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
		if (data'length <= bufferSize_c) then

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
		variable data : string(1 to bufferSize_c) := (others => NUL);
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
		variable stringBuffer : string(1 to bufferSize_c) := (others => NUL);

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
		command.id := stringToInt16(input(commandLength + 2 to commandLength + 3), 0, numServos_c - 1);


		-- get value from input
		command.value := stringToInt16(input(commandLength + 5 to commandLength + 6), INTEGER'low, INTEGER'high);

	end procedure parseInput;

end package body;
