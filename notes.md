NOTES
=====

Start VSIM from Terminal
------------------------

(Link)[http://stackoverflow.com/questions/17222216/get-current-timestamp-vhdl]

Code:


    entity seed_tb is
      generic(SEED : natural := 0);
    end entity;

    architecture sim of seed_tb is
    begin
      assert FALSE report "SEED = " & integer'image(SEED) severity NOTE;
    end architecture;


    > vlib work
    > vcom seed_tb.vhd
    > vsim seed_tb -c -gSEED=`date +%s` -do "run; exit"




