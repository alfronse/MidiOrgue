library ieee;
use ieee.std_logic_1164.ALL;

entity h27segments is
  port (
	 i_7s 			   : in STD_LOGIC_VECTOR(4 DOWNTO 0);
	 o_7s			  		: out std_logic_vector(7 downto 0)
    );
end h27segments;
 
architecture behave of h27segments is
begin
   with i_7s(4 downto 0) select
	 o_7s <= 	
		X"C0" when "00000", --0
		X"F9" when "00001", --1
		X"A4" when "00010", --2
		X"B0" when "00011", --3
		X"99" when "00100", -- 4    
		X"92" when "00101", --5
		X"82" when "00110", --6
		X"F8" when "00111", --7
		X"80" when "01000", --8
		X"90" when "01001", --9
		X"88" when "01010", --A
		X"83" when "01011", --B
		X"C6" when "01100", --C
		X"A1" when "01101", --D
		X"86" when "01110", --E
		X"0E" when "01111", --F
		X"09" when "10000", -- H
		X"2B" when "10001", -- n
		X"0C" when "10010", -- P
		X"0F" when "10011", -- t
		X"21" when "10100", -- u
		X"FF" when others ;
end behave;

