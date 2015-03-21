--
--  Buffer_pkg.vhd
--  The Medusa Project
--
--  Created by Sebastian Mach on 21.03.15.
--  Copyright (c) 2015. All rights reserved.
--


library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

use work.Snake_pkg.all;



package Buffer_pkg is

    type buffer_t is record
        -- Holds the buffer content
        bufferContent : string(1 to bufferSize_c);

        -- A pointer to the element in bufferContent to read/write from/to
        bufferPointer : positive;

        -- Holds the number of elements in bufferContent
        contentSize   : integer range 0 to bufferSize_c;
    end record;

end Buffer_pkg;
