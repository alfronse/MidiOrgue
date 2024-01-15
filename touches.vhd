library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity touches is 
    port (
        i_clk       : in std_logic;
        i_clear     : in std_logic;		-- '1' pour remise à '0' de o_chgtT
        i_touche    : in std_logic;		-- entrée touche
        o_chgtT    	: out std_logic;	-- '1' si chgt détecté, '0' sinon
        o_valT    	: out std_logic		-- valeur de la touche
    );
end touches;

architecture rtl of touches is

signal r_touche : std_logic := '0';
signal r_change   : std_logic := '0';

 begin
    -- process (i_clk)
    -- begin
        -- if (rising_edge(i_clk)) then
            -- if  i_touche = r_touche then -- front montant touche 
                -- r_change<='0';
			-- else 
				-- r_change <='1';
		    -- end if;			 
			-- r_touche    <= i_touche;
        -- end if;
    -- end process;
	
	
    process (i_clk, i_touche, r_touche)
    begin
        if (rising_edge(i_clk)) then
            if (i_clear = '1') then								-- clear après lecture
                r_change	<='0';
            elsif i_touche = '1' and r_touche='0' then -- front montant touche /*and */
                r_change<='1';
            elsif i_touche = '0' and r_touche='1' then -- front descendant touche /*and r_touche='1' */
                r_change<='1';
		    end if;			 
			r_touche    <= i_touche;
        end if;
    end process;
	
	
    o_chgtT    <= r_change;
	o_valT		<= i_touche;
	
	
end rtl;