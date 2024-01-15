library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity touches is 
	port (
               	i_clk       	: in std_logic;
               	i_clear  	: in std_logic;    	-- '1' pour remise à '0' de o_chgtT
               	i_touche              : in std_logic;    	-- entrée touche
               	reset_n	: IN STD_LOGIC;               	--asynchronous active low reset
               	o_chgtT               	: out std_logic;  -- '1' tant que le chgt détecté n'a pas été consommé, '0' sinon
               	o_valT  	: out std_logic   	-- valeur de la touche
	);
end touches;
architecture rtl of touches is
	GENERIC(
	clk_freq               : INTEGER := 25_000_000;            --system clock frequency in Hz
	stable_time : INTEGER := 10);                    	--time button must remain stable in ms
	signal r_touche	: std_logic := '0';               	-- changement debounced touch détecté (1 cycle)
	signal r_change	: std_logic := '0';               	-- changement debounced touch sauvegardé
	SIGNAL flipflops               : STD_LOGIC_VECTOR(1 DOWNTO 0); --input flip flops
	SIGNAL counter_set       : STD_LOGIC := '0';                          	--sync reset to zero flip-flops
	signal touche_deb          : std_logic := '0';                               	-- touche sans rebonds
	
begin
	
	PROCESS(i_clk, reset_n)                                                                                             	-- filtrer l'entree touche ie detecter le chgt et signaler le chgt
	VARIABLE count :             INTEGER RANGE 0 TO clk_freq*stable_time/1000;          --counter for timing
	BEGIN
               	IF(reset_n = '0') THEN                                                                                   	--reset
                               	flipflops(1 DOWNTO 0) <= "00";                               	--clear input flipflops
                               	result <= '0';                                                                                                     	--clear result register
                               	r_touche             <= '0';                                                                                  	-- pas de chgt touche stable
               	ELSIF(i_clk'EVENT and i_clk = '1') THEN                  	--rising clock edge
                               	flipflops(0) <= button;                                                                  	--store button value in 1st flipflop
                               	flipflops(1) <= flipflops(0);                                          	--store 1st flipflop value in 2nd flipflop
                               	If(counter_set = '1') THEN                                                          	--reset counter because input is changing
                                               	count := 0;                                                                                                                        	--clear the counter
                                               	r_touche             <= '0';                                                                                   	-- pas de chgt touche stable
                               	ELSIF(count < clk_freq*stable_time/1000) THEN               --stable input time is not yet met
                                               	count := count + 1;                                                                                        	--increment counter
                                               	r_touche             <= '0';                                                                                   	-- pas de chgt touche stable
                               	ELSE                                                                                                                                    	--stable input time is met         ==> un changement de touche a eu lieu
                                               	result <= flipflops(1);                                                                    	--output the stable value
                                               	r_touche             <= '1';                                                                                   	-- chgt touche stable
                               	END IF; 
               	END IF;
	END PROCESS;
	process (i_clk, reset_n)                	-- sauvegarder le changement tant qu'il n'est pas consommé
	begin
               	IF(reset_n = '0') THEN                                                                                   	--reset
                                               	r_change            <='0';
               	elsif (rising_edge(i_clk)) then
                               	if (i_clear = '1') then                                                                                                     	-- clear après lecture
                                               	r_change            <='0';
                               	elsif r_touche = '1'then -- chgt touche stable
                                               	r_change <='1';
                               	end if;
               	end if;
	end process;
	o_chgtT               <= r_change;
	o_valT  <= result;
end rtl;
