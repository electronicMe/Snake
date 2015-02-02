--
--  Snake.vhd
--  The Medusa Project
--
--  Created by Sebastian Mach on 06.01.15.
--  Copyright (c) 2015. All rights reserved.
--


library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.Arrays_pkg.all;






entity Snake is

	generic (

		-- The number of servos connected to the I/O Board.
		-- WARNING: when changing this value, the constants "c_servoPorts", "c_centerCorrections" and "c_activateServo"
		--          have to be updated too!
		numServos : integer := 26

	);

	port (
		CLOCK_50 : in  std_logic;
		SW       : in  std_logic_vector(9  downto 0);
		LEDG     : out std_logic_vector(9  downto 0);
		GPIO_0   : inout std_logic_vector(31 downto 0);
		GPIO_1   : inout std_logic_vector(31 downto 0)
	);

end Snake;






architecture Snake_a of Snake is

	function to_std_logic(i : in integer) return std_logic is
	begin

	    if i = 0 then
	        return '0';
	    end if;

	    return '1';

	end function;






	--========================================================================--
	-- CONSTANT DEFINITIONS                                                   --
	--========================================================================--


	-- The maximum value of the counter output
	-- WARNING: when changing this value, the "SinusLUT.vhd" file has to be updated as well! The "array_const" array
	--          must contain exactly "c_counterMaxValue" values.
	constant c_counterMaxValue : integer := 4096;


	-- Contains the GPIO port of each servo. Ports lower than 100 mean GPIO_0 and higher than or
	-- equal to 100 mean GPIO_1
	constant c_servoPorts : INT_ARRAY(numServos - 1 downto 0) :=  (   106,	-- S1
																		024,	-- S2
																		109,	-- S3
																		025,	-- S4
																		108,	-- S5
																		023,	-- S6
																		111,	-- S7
																		022,	-- S8
																		110,	-- S9
																		021,	-- S10
																		113,	-- S11
																		020,	-- S12
																		112,	-- S13
																		019,	-- S14
																		114,	-- S15
																		018,	-- S16
																		122,	-- S17
																		008,	-- S18
																		125,	-- S19
																		009,	-- S20
																		124,	-- S21
																		007,	-- S22
																		127,	-- S23
																		006,	-- S24
																		126,	-- S25
																		005		-- S26
																	);






	--========================================================================--
	-- SIGNAL DEFINITIONS                                                     --
	--========================================================================--


	-- Global active low reset signal.
	signal s_RESET           : std_logic;


	-- Each '1' bit activates the corresponding servo. Servos in ascending order: Servo S1 to Servo S26.
	signal s_activateServo   : std_logic_vector(numServos - 1 downto 0) := ('1',	-- S1
																			'1',	-- S2
																			'0',	-- S3
																			'0',	-- S4
																			'0',	-- S5
																			'0',	-- S6
																			'0',	-- S7
																			'0',	-- S8
																			'0',	-- S9
																			'0',	-- S10
																			'0',	-- S11
																			'0',	-- S12
																			'0',	-- S13
																			'0',	-- S14
																			'0',	-- S15
																			'0',	-- S16
																			'0',	-- S17
																			'0',	-- S18
																			'0',	-- S19
																			'0',	-- S20
																			'0',	-- S21
																			'0',	-- S22
																			'0',	-- S23
																			'0',	-- S24
																			'0',	-- S25
																			'0'	-- S26
																			);

	-- Each '1' bit activates the corresponding counter. Counters in ascending order: Counter 0 to Counter 25
	signal s_activateCounter : std_logic_vector(numServos - 1 downto 0) := (others => '1');

	-- Contains the center correction of each servo. Servos in ascending order: Servo S1 to Servo S26.
	signal s_centerCorrections : INT_ARRAY(numServos - 1 downto 0) := (   0,		-- S1
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
	signal s_initCounterVals : INT_ARRAY(numServos - 1 downto 0) := (     0,		-- S1
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
	signal s_damping : INT_ARRAY(numServos - 1 downto 0) := (             0,			-- S1
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
	signal s_pwmSignal       : std_logic_vector(numServos - 1 downto 0);

	-- The LUT output signal of the look up table. Is mapped over UARTCommander to s_dutycycle
	signal s_LUT             : INT_ARRAY(numServos - 1 downto 0);

	-- The dutycycle output signal from the UARTCommunicator. Is mapped to the servos.
	signal s_dutycycle       : INT_ARRAY(numServos - 1 downto 0);

	-- The tick signal generated from the prescaler. Drives the counters.
	signal s_TICK            : std_logic;

	-- Alternative tick signal from the UARTCommander. Drives the counters.
	signal s_step            : std_logic;

	-- The output value from the counters. Drives the look up tables.
	signal s_counter         : INT_ARRAY(numServos - 1 downto 0);


	signal RX                : std_logic;
	signal TX                : std_logic;






begin

	--==========================================================================--
	-- SIGNALS                                                                  --
	--==========================================================================--

	-- GPIO_1(0) = J5_2 = RX
	-- GPIO_1(1) = J5_4 = TX
	-- GND       = J5_12
	GPIO_1(0) <= 'Z';
	RX        <= GPIO_1(0);
	LEDG(0)   <= GPIO_1(0);

	GPIO_1(1) <= TX;
	LEDG(1)   <= TX;

	s_RESET <= SW(1);

	--LEDG(2) <= '0';
	--LEDG(3) <= (SW(0) XOR (s_pwmSignal(0) AND s_activateServo(0)));    -- S1
	--LEDG(4) <= (SW(0) XOR (s_pwmSignal(1) AND s_activateServo(1)));    -- S2
	--LEDG(5) <= '1';
	--LEDG(6) <= '0';
	--LEDG(7) <= '1';
	--LEDG(8) <= '0';






	--==========================================================================--
	-- SERVO MAPPING                                                            --
	--==========================================================================--

	-- Disabled to fit on DE0 Board
	--GEN_SERVOMAP: for i in 0 to (numServos - 1) generate

	--	PORT0_SEL: if (c_servoPorts(i) < 100) generate
	--		-- GPIO_0
	--		GPIO_0(c_servoPorts(i)) <= (SW(0) XOR (s_activateServo(i) AND s_pwmSignal(i)));
	--	end generate PORT0_SEL;

	--	PORT1_SEL: if (c_servoPorts(i) >= 100) generate
	--		-- GPIO_1
	--		GPIO_1(c_servoPorts(i) - 100) <= (SW(0) XOR (s_activateServo(i) AND s_pwmSignal(i)));
	--	end generate PORT1_SEL;

	--end generate GEN_SERVOMAP;






	--==========================================================================--
	-- SUPPORTING COMPONENTS                                                    --
	--==========================================================================--

	uartCommunicator: entity work.UARTCommunicator(UARTCommunicator_a) generic map (BAUD_RATE_g        => 115200,
																					  CLOCK_FREQUENCY_g  => 50000000,
																					  numServos_g        => numServos,
																					  bufferSize_g       => 255
																					 )
																		port map    (CLK               => CLOCK_50,
																					  RESET_n           => s_RESET,

																					  activateServo     => s_activateServo,
																					  activateCounter   => s_activateCounter,
																					  centerCorrections => s_centerCorrections,
																					  initCounterVals   => s_initCounterVals,
																					  damping           => s_damping,
																					  LUT               => s_LUT,
																					  dutycycle         => s_dutycycle,
																					  step              => s_step,
																					  counter           => s_counter,

																					  RX                => RX,
																					  TX                => TX,

																					  debug             => LEDG(9 downto 2),
																					  debug2            => SW(9 downto 2)
																					 );



	--==========================================================================--
	-- PRESCALER                                                                --
	--==========================================================================--

	--prescaler: entity work.prescaler(prescaler_a)	generic map (scale   => 150000)
	--												port map     (CLK     => CLOCK_50,
	--												 			   RESET_n => s_RESET,
	--															   TICK    => s_TICK
	--															  );



	--==========================================================================--
	-- COUNTERS                                                                 --
	--==========================================================================--

	--GEN_COUNTERS: for i in 0 to (numServos - 1) generate

	--	counter_x: entity work.counter(counter_a)	generic map (maxValue_g   => c_counterMaxValue)
	--												port map     (CLK          => ((s_TICK AND s_activateCounter(i)) OR s_step),
	--															   RESET_n      => s_RESET,
	--															   initialValue => s_initCounterVals(i),
	--															   TC           => s_counter(i)
	--															  );

	--end generate GEN_COUNTERS;



	--==========================================================================--
	-- LOOK UP TABLE                                                            --
	--==========================================================================--

	--SinusLUT: entity work.SinusLUT(SinusLUT_a)	generic map	(numberOfLUTs_g => numServos )
	--											port map     (LUT_IN         => s_counter,
	--														   LUT_OUT        => s_LUT
	--														  );





	--==========================================================================--
	-- SERVOS                                                                   --
	--==========================================================================--


	--GEN_SERVOS: for i in 0 to (numServos - 1) generate

	--	servo_x: entity work.PWMServo(PWMServo_a)	port map	(CLK               => CLOCK_50,
	--															   RESET_n           => s_RESET,
	--															   DUTYCYCLE         => s_dutycycle(i),

	--															   PWMOut            => s_pwmSignal(i),
	--															   reduction_g       => s_damping(i),

	--															   INVERT_HORN       => to_std_logic((i mod 2)),
	--															   CENTER_CORRECTION => (s_centerCorrections(i) * 1000)
	--															  );

	--end generate GEN_SERVOS;



end Snake_a;
