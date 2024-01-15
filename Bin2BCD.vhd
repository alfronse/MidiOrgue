library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity module_bin2bcd is
    generic 
    (
        BIN_WIDTH : integer := 4; -- width of the binary
        BCD_WIDTH : integer := 4  -- width of the bcd must be a multiple of 4
    );
    port 
    (
        bin : in std_logic_vector (BIN_WIDTH - 1 downto 0); --
        bcd : out std_logic_vector (BCD_WIDTH - 1 downto 0) --
    );
end module_bin2bcd;

architecture module_bin2bcd_ar of module_bin2bcd is
begin
    -- double dabble
    process (bin)
        variable tmp : unsigned (BCD_WIDTH - 1 downto 0);
    begin
        tmp := (others => '0');
        
        for i in BIN_WIDTH - 1 downto 0 loop
			-- correct every bcd digit greater than 5 before shifting
            for j in 1 to (BCD_WIDTH / 4) loop  
                if tmp ((4 * j - 1) downto (4 * j - 4)) > 4 then
                    tmp ((4 * j - 1) downto (4 * j - 4)) := tmp ((4 * j - 1)  downto (4 * j - 4)) + 3;
                end if;
            end loop;
            
			-- shift and add the new bit
            tmp := tmp (BCD_WIDTH - 2 downto 0) & bin(i);                     
        end loop;
        
        bcd <= std_logic_vector (tmp);    
    end process;
end module_bin2bcd_ar;