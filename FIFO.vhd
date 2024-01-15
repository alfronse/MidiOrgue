-------------------------------------------------------------------------------
-- File Downloaded from http://www.nandland.com
--
-- Description: Creates a Synchronous FIFO made out of registers.
--              Generic: g_WIDTH sets the width of the FIFO created.
--              Generic: g_DEPTH sets the depth of the FIFO created.
--
--              Total FIFO register usage will be width * depth
--              Note that this fifo should not be used  to cross clock domains.
--              (Read and write clocks NEED TO BE the same clock domain)
--
--              FIFO Full Flag will assert as soon as last word is written.
--              FIFO Empty Flag will assert as soon as last word is read.
--
--              FIFO is 100% synthesizable.  It uses assert statements which do
--              not synthesize, but will cause your simulation to crash if you
--              are doing something you shouldn't be doing (reading from an
--              empty FIFO or writing to a full FIFO).
--
--              With Flags = Has Almost Full (AF)/Almost Empty (AE) Flags
--              These are settable via Generics: g_AF_LEVEL and g_AE_LEVEL
--              g_AF_LEVEL: Goes high when # words in FIFO is > this number.
--              g_AE_LEVEL: Goes high when # words in FIFO is < this number.
-------------------------------------------------------------------------------
 
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 
entity module_fifo_regs_with_flags is
  generic (
    g_WIDTH    : natural := 8;
    g_DEPTH    : integer := 32;
    g_AF_LEVEL : integer := 29;
    g_AE_LEVEL : integer := 3											-- mettre un multiple de 3 pour le chargement multiple
    );
  port (
    i_rst_sync : in std_logic;
    i_clk      : in std_logic;
 
    -- FIFO Write Interface
    i_wr_en   : in  std_logic;										-- charger les donées
    i_wr3_en   : in  std_logic;										-- charger les donées
    i_wr_data : in  std_logic_vector((g_WIDTH*3)-1 downto 0);	-- données
    o_af      : out std_logic;										--	presque plein
    o_full    : out std_logic;										--	plein
 
    -- FIFO Read Interface
    i_rd_en   : in  std_logic;										-- donnée lue, dépiler
    o_rd_data : out std_logic_vector(g_WIDTH-1 downto 0);	-- données
    o_ae      : out std_logic;										-- presque vide
    o_empty   : out std_logic											-- '1' quand vide sinon '0'
    );
end module_fifo_regs_with_flags;
 
architecture rtl of module_fifo_regs_with_flags is
 
  type t_FIFO_DATA is array (0 to g_DEPTH-1) of std_logic_vector(g_WIDTH-1 downto 0);
  signal r_FIFO_DATA : t_FIFO_DATA := (others => (others => '0'));
 
  signal r_WR_INDEX   : integer range 0 to g_DEPTH-1 := 0;
  signal r_RD_INDEX   : integer range 0 to g_DEPTH-1 := 0;
 
  -- # Words in FIFO, has extra range to allow for assert conditions
  signal r_FIFO_COUNT : integer range -1 to g_DEPTH+1 := 0;
 
  signal w_FULL  : std_logic;
  signal w_EMPTY : std_logic;
   
begin
 
  p_CONTROL : process (i_clk) is
  begin
    if rising_edge(i_clk) then
      if i_rst_sync = '1' then
        r_FIFO_COUNT <= 0;
        r_WR_INDEX   <= 0;
        r_RD_INDEX   <= 0;
      else
 
        -- Keeps track of the total number of words in the FIFO
        if (i_wr_en = '1' and i_rd_en = '0') then
          r_FIFO_COUNT <= r_FIFO_COUNT + 1;
        elsif (i_wr3_en = '1' and i_rd_en = '0') then
          r_FIFO_COUNT <= r_FIFO_COUNT + 3;
        elsif (i_wr_en = '0' and i_rd_en = '1') then
          r_FIFO_COUNT <= r_FIFO_COUNT - 1;
        end if;
 
        -- Keeps track of the write index (and controls roll-over)
        if (i_wr_en = '1' and w_FULL = '0') then
          if r_WR_INDEX = g_DEPTH-1 then
            r_WR_INDEX <= 0;
          else
            r_WR_INDEX <= r_WR_INDEX + 1;
          end if;
        elsif (i_wr3_en = '1' and r_FIFO_COUNT <= g_AF_LEVEL) then -- not almost full
          if r_WR_INDEX = g_DEPTH-3 then
            r_WR_INDEX <= 0;
          elsif r_WR_INDEX = g_DEPTH-2 then
            r_WR_INDEX <= 1;
          elsif r_WR_INDEX = g_DEPTH-1 then
            r_WR_INDEX <= 2;
          else
            r_WR_INDEX <= r_WR_INDEX + 3;
          end if;
        end if; 
 
        -- Keeps track of the read index (and controls roll-over)        
        if (i_rd_en = '1' and w_EMPTY = '0') then
          if r_RD_INDEX = g_DEPTH-1 then
            r_RD_INDEX <= 0;
          else
            r_RD_INDEX <= r_RD_INDEX + 1;
          end if;
        end if;
 
        -- Registers the input data when there is a write
        if i_wr_en = '1' then
          r_FIFO_DATA(r_WR_INDEX) <= i_wr_data(7 downto 0);
        elsif i_wr3_en = '1' then
          if r_WR_INDEX = g_DEPTH-2 then
            r_FIFO_DATA(r_WR_INDEX) <= i_wr_data(7 downto 0);
            r_FIFO_DATA(r_WR_INDEX+1) <= i_wr_data(15 downto 8);
            r_FIFO_DATA(0) <= i_wr_data(23 downto 16);
          elsif r_WR_INDEX = g_DEPTH-1 then
            r_FIFO_DATA(r_WR_INDEX) <= i_wr_data(7 downto 0);
            r_FIFO_DATA(0) <= i_wr_data(15 downto 8);
            r_FIFO_DATA(1) <= i_wr_data(23 downto 16);
          else -- r_WR_INDEX < g_DEPTH-3
            r_FIFO_DATA(r_WR_INDEX) <= i_wr_data(7 downto 0);
            r_FIFO_DATA(r_WR_INDEX+1) <= i_wr_data(15 downto 8);
            r_FIFO_DATA(r_WR_INDEX+2) <= i_wr_data(23 downto 16);
            end if;
        end if;
         
      end if;                           -- sync reset
      
      
    end if;                             -- rising_edge(i_clk)
  end process p_CONTROL;
 
   
       o_rd_data <= r_FIFO_DATA(r_RD_INDEX);
 
 
  w_FULL  <= '1' when r_FIFO_COUNT = g_DEPTH else '0';
  w_EMPTY <= '1' when r_FIFO_COUNT = 0       else '0';
 
  o_af <= '1' when r_FIFO_COUNT > g_AF_LEVEL else '0';
  o_ae <= '1' when r_FIFO_COUNT < g_AE_LEVEL else '0';
   
  o_full  <= w_FULL;
  o_empty <= w_EMPTY;
   
 
  -----------------------------------------------------------------------------
  -- ASSERTION LOGIC - Not synthesized
  -----------------------------------------------------------------------------
  -- synthesis translate_off
 
  p_ASSERT : process (i_clk) is
  begin
    if rising_edge(i_clk) then
      if i_wr_en = '1' and w_FULL = '1' then
        report "ASSERT FAILURE - MODULE_REGISTER_FIFO: FIFO IS FULL AND BEING WRITTEN " severity failure;
      end if;
 
      if i_rd_en = '1' and w_EMPTY = '1' then
        report "ASSERT FAILURE - MODULE_REGISTER_FIFO: FIFO IS EMPTY AND BEING READ " severity failure;
      end if;
    end if;
  end process p_ASSERT;
 
  -- synthesis translate_on
     
   
end rtl;