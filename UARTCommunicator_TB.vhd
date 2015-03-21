--
--  UARTCommunicator_TB.vhd
--  The Medusa Project
--
--  Created by Sebastian Mach on 05.03.15.
--  Copyright (c) 2015. All rights reserved.
--
--  This is the testbench for the UARTCommunicator component.
--


library IEEE;
use IEEE.std_logic_1164.all;
use std.textio.all;
use ieee.numeric_std.all;

use work.Snake_pkg.all;
use work.Arrays_pkg.all;
--use work.UARTCommunicator.all;



entity UARTCommunicator_TB is

    generic (

        BAUD_PERIODE_g : time := 8680555 ps

	);

end UARTCommunicator_TB;



architecture UARTCommunicator_TB_a of UARTCommunicator_TB is

    --========================================================================--
    -- PROCEDURES                                                             --
    --========================================================================--

    procedure sendString(constant str      : in    string;
                         signal   TX       : out   std_logic;
                         signal   bitSent  : inout std_logic;
                         signal   wordSent : inout std_logic
                        ) is
        variable charVector: std_logic_vector(7 downto 0);
    begin

        write(OUTPUT, "Sending String: " & str);

        for i in 1 to str'length loop
            charVector := std_logic_vector(to_unsigned(CHARACTER'POS(str(i)), 8));

            TX <= '1'; -- bus idle
            wait for BAUD_PERIODE_g;

            TX <= '0'; -- start bit
            wait for BAUD_PERIODE_g;



            for j in 0 to charVector'length - 1 loop
                TX <= charVector(j);
                bitSent <= NOT bitSent;
                wait for BAUD_PERIODE_g;
            end loop;


            TX <= '1'; -- stop bit
            wordSent <= NOT wordSent;
            wait for BAUD_PERIODE_g;


		end loop;

    end;






    --========================================================================--
    -- PORTS FOR DE0 NANO BOARD                                               --
    -- TAKE A LOOK AT THE PORTS FROM 'Snake.vhd' FOR A REFERENCE .            --
    --                                                                        --
    -- THIS SIGNALS ARE DRIVEN BY A COMMAND PROCESS WHICH SIMULATES THE USER  --
    -- INPUT AND UART SIGNALS                                                 --
    --========================================================================--

    -- 50 MHz Clock Signal (20e-9 sec)
    signal CLOCK_50  : std_logic;






    --========================================================================--
	-- SIGNAL DEFINITIONS                                                     --
    -- TAKE A LOOK AT THE SIGNALS FROM 'UARTCommunicator.vhd' FOR A REFERENCE.--
	--========================================================================--


	-- Global active low reset signal caused by user
	signal s_RESET           : std_logic;
	-- Global active high reset signal caused by UARTCommunicator
	signal s_reset2          : std_logic;


	-- Each '1' bit activates the corresponding servo. Servos in ascending order: Servo S1 to Servo S26.
	signal s_activateServo   : std_logic_vector(numServos_c - 1 downto 0);-- := ('0',	-- S1
																		--	'0',	-- S2
																		--	'0',	-- S3
																		--	'0',	-- S4
																		--	'0',	-- S5
																		--	'0',	-- S6
																		--	'0',	-- S7
																		--	'0',	-- S8
																		--	'0',	-- S9
																		--	'0',	-- S10
																		--	'0',	-- S11
																		--	'0',	-- S12
																		--	'0',	-- S13
																		--	'0',	-- S14
																		--	'0',	-- S15
																		--	'0',	-- S16
																		--	'0',	-- S17
																		--	'0',	-- S18
																		--	'0',	-- S19
																		--	'0',	-- S20
																		--	'0',	-- S21
																		--	'0',	-- S22
																		--	'0',	-- S23
																		--	'0',	-- S24
																		--	'0',	-- S25
																		--	'0'		-- S26
																		--	);

	-- Each '1' bit activates the corresponding counter. Counters in ascending order: Counter 0 to Counter 25
	signal s_activateCounter : std_logic_vector(numServos_c - 1 downto 0) := (others => '0');

	-- Contains the center correction of each servo. Servos in ascending order: Servo S1 to Servo S26.
	signal s_centerCorrections : INT_ARRAY(numServos_c - 1 downto 0) := (     0,		-- S1
																			0,		-- S2
																			0,		-- S3
																			0,		-- S4
																			0,		-- S5
																			0,		-- S6
																			0,		-- S7
																			0,		-- S8
																			0,		-- S9
																			0,		-- S10
																			0,		-- S11
																			0,		-- S12
																			0,		-- S13
																			0,		-- S14
																			0,		-- S15
																			0,		-- S16
																			0,		-- S17
																			0,		-- S18
																			0,		-- S19
																			0,		-- S20
																			0,		-- S21
																			0,		-- S22
																			0,		-- S23
																			0,		-- S24
																			0,		-- S25
																			0		-- S26
																	);

	-- The initial value of each servo counter. Causes an phase shift. Servos in ascending order: Servo S1 to Servo S26.
	signal s_initCounterVals : INT_ARRAY(numServos_c - 1 downto 0) := (       0,		-- S1
																			0,		-- S2
																			0,	-- S3
																			0,	-- S4
																			683,	-- S5
																			683,	-- S6
																			0,	-- S7
																			0,	-- S8
																			1366,	-- S9
																			1366,	-- S10
																			0,	-- S11
																			0,	-- S12
																			2049,	-- S13
																			2049,	-- S14
																			0,	-- S15
																			0,	-- S16
																			2732,	-- S17
																			2732,	-- S18
																			0,	-- S19
																			0,	-- S20
																			3415,	-- S21
																			3415,	-- S22
																			0,	-- S23
																			0,	-- S24
																			0,		-- S25
																			0		-- S26
																	  );

	-- Contains the reduction of the PWM on and off times of the servos. Causes a damp of the altitution of the signal.
	signal s_damping : INT_ARRAY(numServos_c - 1 downto 0) := (               0,			-- S1
																			0,			-- S2
																			350000,		-- S3
																			350000,		-- S4
																			0,			-- S5
																			0,			-- S6
																			350000,		-- S7
																			350000,		-- S8
																			0,			-- S9
																			0,			-- S10
																			350000,		-- S11
																			350000,		-- S12
																			0,			-- S13
																			0,			-- S14
																			350000,		-- S15
																			350000,		-- S16
																			0,			-- S17
																			0,			-- S18
																			350000,		-- S19
																			350000,		-- S20
																			0,			-- S21
																			0,			-- S22
																			350000,		-- S23
																			350000,		-- S24
																			0,			-- S25
																			0			-- S26
															  );

	-- The PWM Signals for the servos
	signal s_pwmSignal       : std_logic_vector(numServos_c - 1 downto 0);

	-- The LUT output signal of the look up table. Is mapped over UARTCommander to s_dutycycle
	signal s_LUT             : INT_ARRAY(numServos_c - 1 downto 0);

	-- The dutycycle output signal from the UARTCommunicator. Is mapped to the servos.
	signal s_dutycycle       : INT_ARRAY(numServos_c - 1 downto 0);

	-- The tick signal generated from the prescaler. Drives the counters.
	signal s_TICK            : std_logic;
	-- The tick signal generated from the UARTCommunicator. Drives the counters.
	signal s_TICK2           : std_logic;

	-- Alternative tick signal from the UARTCommander. Drives the counters.
	signal s_step            : std_logic;

	-- The output value from the counters. Drives the look up tables.
	signal s_counter         : INT_ARRAY(numServos_c - 1 downto 0);


	signal s_RX              : std_logic;
	signal s_TX              : std_logic;
    signal s_uart_bitSent    : std_logic := '0';
    signal s_uart_wordSent   : std_logic := '0';

begin


    clock_p: process
    begin

        -- 20 ns = 50MHz

        CLOCK_50 <= '0';
        wait for 10 ns;

        CLOCK_50 <= '1';
        wait for 10 ns;

    end process;



    reset_p: process
    begin

        s_RESET <= '0';
        wait for 20 ns;

        s_RESET <= '1';
        wait;

    end process;



    uart_p: process
    begin

        s_TX <= '1'; -- Bus idle

        wait for 40 ns;

        --sendString("set" & CR, s_TX, s_uart_bitSent, s_uart_wordSent);

        --wait for 100 * BAUD_PERIODE_g;

        --                    SERVO ID MSB       SERVO ID LSB             VALUE MSB          VALUE LSB
        sendString("test " & CHARACTER'VAL(0) & CHARACTER'VAL(25) & " " & CHARACTER'VAL(0) & CHARACTER'VAL(128) & CR, s_TX, s_uart_bitSent, s_uart_wordSent);

        wait for 100 * BAUD_PERIODE_g;

        --                    SERVO ID MSB       SERVO ID LSB             VALUE MSB          VALUE LSB
        sendString("test " & CHARACTER'VAL(0) & CHARACTER'VAL(25) & " " & CHARACTER'VAL(0) & CHARACTER'VAL(255) & CR, s_TX, s_uart_bitSent, s_uart_wordSent);

        wait for 100 * BAUD_PERIODE_g;

        --                    SERVO ID MSB       SERVO ID LSB             VALUE MSB          VALUE LSB
        sendString("test " & CHARACTER'VAL(0) & CHARACTER'VAL(25) & " " & CHARACTER'VAL(1) & CHARACTER'VAL(128) & CR, s_TX, s_uart_bitSent, s_uart_wordSent);


        wait;

    end process;






    uartCommunicator: entity work.UARTCommunicator(UARTCommunicator_a) generic map (BAUD_RATE_g        => 115200,
                                                                                    CLOCK_FREQUENCY_g  => 50000000
                                                                                   )
                                                        port map    ( CLK               => CLOCK_50,
                                                                      RESET_n           => s_RESET,

                                                                      activateServo     => s_activateServo,
                                                                      activateCounter   => s_activateCounter,
                                                                      centerCorrections => s_centerCorrections,
                                                                      initCounterVals   => s_initCounterVals,
                                                                      damping           => s_damping,
                                                                      LUT               => s_LUT,
                                                                      dutycycle         => s_dutycycle,
                                                                      counter           => s_counter,

                                                                      step              => s_TICK2,
                                                                      reset             => s_reset2,

                                                                      RX                => s_TX,
                                                                      TX                => s_RX
                                                                     );

end UARTCommunicator_TB_a;
