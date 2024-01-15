----------------------------------------------------------------------
-- 
----------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity MIDI is
  port (
    i_clock : in  std_logic;
    KEY     : in  std_logic_vector(3 downto 0);
    SW      : in  std_logic_vector(9 downto 0);
    GPIO_0  : in  std_logic_vector(35 downto 0);
    HEX0    : out std_logic_vector(6 downto 0);
    HEX1    : out std_logic_vector(6 downto 0);
    HEX2    : out std_logic_vector(6 downto 0);
    HEX3    : out std_logic_vector(6 downto 0);
	LEDG	: out std_logic_vector(7 downto 0);
	UART_TXD : out std_logic
    );
end MIDI;

architecture behave of MIDI is

  component touches is
    port (
      i_clk    : in  std_logic;
      i_clear  : in  std_logic;			-- remise à 0 de o_chgtT
      i_touche : in  std_logic;         -- entrée touche
      o_chgtT    	: out std_logic;    -- '1' si chgt détecté, '0' sinon
      o_valT    	: out std_logic     -- valeur de la touche
      );
  end component touches;

  component module_fifo_regs_with_flags is
    generic (
      g_WIDTH    : natural := 8;
      g_DEPTH    : integer := 32;
      g_AF_LEVEL : integer := 29;
      g_AE_LEVEL : integer := 3  -- mettre un multiple de 3 pour le chargement multiple
      ); 
    port (
      i_rst_sync : in std_logic;
      i_clk      : in std_logic;

      -- FIFO Write Interface
      i_wr_en   : in  std_logic;        -- charger les donées
      i_wr3_en  : in  std_logic;        -- charger les donées
      i_wr_data : in  std_logic_vector((g_WIDTH*3)-1 downto 0);  -- données
      o_af      : out std_logic;        --      presque plein
      o_full    : out std_logic;        --      plein

      -- FIFO Read Interface
      i_rd_en   : in  std_logic;        -- donnée lue, dépiler
      o_rd_data : out std_logic_vector(g_WIDTH-1 downto 0);  -- données
      o_ae      : out std_logic;        -- presque vide
      o_empty   : out std_logic         -- vide
      );
  end component module_fifo_regs_with_flags;


  component uart_tx is
    generic (
      g_CLKS_PER_BIT : integer := 434   -- Needs to be set correctly : 50MHZ / 31250 bauds
      );
    port (
      i_clk       : in  std_logic;
      i_tx_dv     : in  std_logic;
      i_tx_byte   : in  std_logic_vector(7 downto 0);
      o_tx_active : out std_logic;
      o_tx_serial : out std_logic;
      o_tx_done   : out std_logic
      );
  end component uart_tx;

  component uart_rx is
    generic (
      g_CLKS_PER_BIT : integer := 434   -- Needs to be set correctly : 50MHZ / 31250 bauds
      );
    port (
      i_clk       : in  std_logic;
      i_rx_serial : in  std_logic;
      o_rx_dv     : out std_logic;
      o_rx_byte   : out std_logic_vector(7 downto 0)
      );
  end component uart_rx;

  component module_bin2bcd is
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
  end component module_bin2bcd;
  
  component h27segments is
    port (
      i_7s : in  std_logic_vector(4 downto 0);
      o_7s : out std_logic_vector(7 downto 0)
      );
  end component h27segments;

  
  constant  NUM_INPUTS     : integer := 151;
  constant c_CLKS_PER_BIT : integer := 435;
  constant	BIN_WIDTH  	:  positive := 8;
  constant	BCD_WIDTH:  positive := 12;
  constant c_WIDTH    : natural := 8;
  constant c_DEPTH    : integer := 32;
  constant c_AF_LEVEL : integer := 29;
  constant c_AE_LEVEL : integer := 3;

  signal s_inTouches   : std_logic_vector(151 downto 0) := (others => '0');  -- 152 touches à 1 si changement
  signal s_chgTouches   : std_logic_vector(151 downto 0) := (others => '0');  -- 152 touches à 1 si changement
  signal s_valTouches   : std_logic_vector(151 downto 0) := (others => '0');  -- 152 touches à 1 si touche enfoncée
  signal s_clearTouches   : std_logic_vector(151 downto 0) := (others => '0');  -- 152 touches à 1 si changement

  signal s_balayTouches : integer range 0 to 151         := 0;
  signal i_CHGTT        : std_logic;
  signal i_VALT		    : std_logic;
  signal i_CHGTT1        : std_logic;
  signal i_VALT1		    : std_logic;
  signal i_TOUCHE       : std_logic;
  signal i_CLEAR        : std_logic :='0';
  signal i_CLEAR1        : std_logic :='0';


  signal r_Hex_Encoding : std_logic_vector(7 downto 0) := (others => '0');
  signal s_Hex_Encoding : std_logic_vector(7 downto 0) := (others => '0');
  signal t_Hex_Encoding : std_logic_vector(7 downto 0) := (others => '0');
  signal u_Hex_Encoding : std_logic_vector(7 downto 0) := (others => '0');

  signal r_TX_ACTIVE : std_logic := '0';
  signal r_TX_DV     : std_logic                    := '0';
  signal r_TX_BYTE   : std_logic_vector(7 downto 0) := (others => '0');
  signal w_TX_SERIAL : std_logic;
  signal w_TX_DONE   : std_logic;
  signal w_RX_DV     : std_logic;
  signal w_RX_BYTE   : std_logic_vector(7 downto 0) := (others => '0');
  signal r_RX_SERIAL : std_logic                    := '1';
  signal r_TXwaitDone : std_logic;

  -- FIFO control
  signal s_RST_SYNC : std_logic := '1';

  -- FIFO Write Interface
  signal s_WR_EN   : std_logic := '0';  -- charger les données
  signal s_WR3_EN  : std_logic := '0';  -- charger les données *3
  signal s_WR_DATA : std_logic_vector((c_WIDTH*3)-1 downto 0);  -- données
  signal s_AF      : std_logic;         --      presque plein
  signal s_FULL    : std_logic;         --      plein
  -- FIFO Read Interface
  signal s_RD_EN   : std_logic;         -- donnée lue, dépiler
  signal s_RD_DATA : std_logic_vector(c_WIDTH-1 downto 0);  -- données
  signal s_AE      : std_logic;         -- presque vide
  signal s_EMPTY   : std_logic;

  signal bin :  std_logic_vector (BIN_WIDTH - 1 downto 0);
  signal bcd :  std_logic_vector (BCD_WIDTH - 1 downto 0);
  


  -- They all run continuously even if the switches are
  -- not selecting their particular output.
begin

 
  -- Instantiate touche 1
  -- TOUCHE_1_INST : touches
    -- port map (
      -- i_clk    => i_clock,
      -- i_clear  => i_CLEAR,	-- 1 pour remise à 0 de o_chgtT
      -- i_touche => SW(0),
	  -- o_chgtT	=> i_CHGTT, -- 1 si changement détecté
	  -- o_valT    => i_VALT -- val
      -- );

-- Instantiate touche 2
  -- TOUCHE_2_INST : touches
    -- port map (
      -- i_clk    => i_clock,
      -- i_clear  => i_CLEAR1,	-- 1 pour remise à 0 de o_chgtT
      -- i_touche => SW(1),
	  -- o_chgtT	=> i_CHGTT1, -- 1 si changement détecté
	  -- o_valT    => i_VALT1 -- val
      -- );
 touches_Assignment: for jj in 0 to NUM_INPUTS-1 generate
    TOUCHE_1_INST : touches
      port map (
      i_clk    => i_clock,
      i_clear  => s_clearTouches(jj),	-- 1 pour remise à 0 de o_chgtT
      i_touche => s_inTouches(jj),
	  o_chgtT	=> s_chgTouches(jj), -- 1 si changement détecté
	  o_valT    => s_valTouches(jj) -- val
        );
  end generate touches_Assignment;
 
  -- Instantiate UART transmitter
  UART_TX_INST : uart_tx
    generic map (
      g_CLKS_PER_BIT => c_CLKS_PER_BIT
      )
    port map (
      i_clk       => i_clock,
      i_tx_dv     => r_TX_DV,
      i_tx_byte   => r_TX_BYTE,
      o_tx_active => r_TX_ACTIVE,
      o_tx_serial => w_TX_SERIAL,
      o_tx_done   => w_TX_DONE
      );

  -- Instantiate UART Receiver
  UART_RX_INST : uart_rx
    generic map (
      g_CLKS_PER_BIT => c_CLKS_PER_BIT
      )
    port map (
      i_clk       => i_clock,
      i_rx_serial => r_RX_SERIAL,
      o_rx_dv     => w_RX_DV,
      o_rx_byte   => w_RX_BYTE
      );

  -- Instantiate FIFO
  FIFO_INST : module_fifo_regs_with_flags
    generic map(
      g_WIDTH    => c_WIDTH,
      g_DEPTH    => c_DEPTH,
      g_AF_LEVEL => c_AF_LEVEL,
      g_AE_LEVEL => c_AE_LEVEL  -- mettre un multiple de 3 pour le chargement multiple
      )
    port map(
      i_rst_sync => SW(9), -- s_RST_SYNC,
      i_clk      => i_clock,

      -- FIFO Write Interface
      i_wr_en   => s_WR_EN,             -- charger les donées
      i_wr3_en  => s_WR3_EN,            -- charger les donées par 3 * 8
      i_wr_data => s_WR_DATA,           -- données
      o_af      => s_AF,                --      presque plein
      o_full    => s_FULL,              --      plein

      -- FIFO Read Interface
      i_rd_en   => s_RD_EN,             -- donnée lue, dépiler
      o_rd_data => s_RD_DATA,           -- données
      o_ae      => s_AE,                -- presque vide
      o_empty   => s_EMPTY              -- '1' quand vide sinon '0'
      );

 -- instantiate Bin to BCD
  Binary_to_BCD_1 : module_bin2bcd
    generic map (
      BIN_WIDTH    => BIN_WIDTH,
      BCD_WIDTH => BCD_WIDTH)
    port map (
      bin    => bin,
      bcd     => bcd);


    s_inTouches(63) <= SW(9);
    s_inTouches(64) <= SW(8);
    s_inTouches(65) <= SW(7);
    s_inTouches(66) <= SW(6);
    s_inTouches(67) <= SW(5);
    s_inTouches(68) <= SW(4);
    s_inTouches(69) <= SW(3);
    s_inTouches(70) <= SW(2);
    s_inTouches(71) <= SW(1);
    s_inTouches(72) <= SW(0);
    s_inTouches(73) <= KEY(3);
    s_inTouches(74) <= KEY(2);
    s_inTouches(75) <= KEY(1);
    s_inTouches(76) <= KEY(0);
    s_inTouches(77) <= GPIO_0(0);
    s_inTouches(78) <= GPIO_0(1);
    s_inTouches(79) <= GPIO_0(2);
    s_inTouches(80) <= GPIO_0(3);
    s_inTouches(81) <= GPIO_0(4);
    s_inTouches(82) <= GPIO_0(5);
    s_inTouches(83) <= GPIO_0(6);
    s_inTouches(84) <= GPIO_0(7);
    s_inTouches(85) <= GPIO_0(8);
    s_inTouches(86) <= GPIO_0(9);
    s_inTouches(87) <= GPIO_0(10);
    s_inTouches(88) <= GPIO_0(11);
    s_inTouches(89) <= GPIO_0(12);
    s_inTouches(90) <= GPIO_0(13);
    s_inTouches(91) <= GPIO_0(14);
    s_inTouches(92) <= GPIO_0(15);
    s_inTouches(93) <= GPIO_0(16);
    s_inTouches(94) <= GPIO_0(17);
    s_inTouches(95) <= GPIO_0(18);
    s_inTouches(96) <= GPIO_0(19);
    s_inTouches(97) <= GPIO_0(20);
    s_inTouches(98) <= GPIO_0(21);
    s_inTouches(99) <= GPIO_0(22);
    s_inTouches(100) <= GPIO_0(23);
   -- i_CLEAR  <= s_clearTouches(69); 
   -- s_chgTouches(69)<= i_CHGTT;
   -- s_valTouches(69)<= i_VALT;
   -- i_CLEAR1  <= s_clearTouches(68); 
   -- s_chgTouches(68)<= i_CHGTT1;
   -- s_valTouches(68)<= i_VALT1;
  
  

  --balaye les touches. si changement, charge le registre d'émission
  p_BalTouch : process (i_clock) is
  begin
    if rising_edge(i_clock) then
      -- if (SW(9)='1') then
        -- For ii in 70 to 151 loop
         -- s_valTouches(ii) <= '0';
        -- End loop;
      -- end if;
      
      if (s_balayTouches = 151) then
        s_balayTouches <= 0;
      else
        s_balayTouches <= s_balayTouches +1;
      end if;
      
	  -- if i_CHGTT ='1' and s_FULL ='0' then --and i_CHGTT1 ='0' then
		-- s_WR_EN  <= '1';		-- cde FIFO chgt 3 octets
        -- s_balayTouches <= s_balayTouches +1; 
        -- s_WR_DATA <= std_logic_vector(to_unsigned(s_balayTouches, 24));
      -- elsif i_CHGTT1 ='1' and i_CHGTT ='0' and s_AF = '0' then      
        -- s_balayTouches <= s_balayTouches +1; 
         -- s_WR3_EN  <= '1';		-- cde FIFO chgt 3 octets
         -- s_WR_DATA <= x"ABCD" & std_logic_vector(to_unsigned(s_balayTouches, 8));
      -- else 
         -- s_WR_EN  <= '0';
         -- s_WR3_EN  <= '0';
      -- els
      s_clearTouches(s_balayTouches)<='0';
     -- s_clearTouches(s_balayTouches-1)<='0';
      s_WR3_EN  <= '0';
      if s_chgTouches(s_balayTouches) = '1' then
        s_WR_DATA <= std_logic_vector(to_unsigned(49, 8)) & "0" & std_logic_vector(to_unsigned(s_balayTouches, 7)) & "100" & s_valTouches(s_balayTouches) & "0000" ;
          --         Vélocité 49                                 numéro de la touche                                  Note   On=1 / Off=0                    canal
        s_WR3_EN  <= '1';		-- cde FIFO chgt 3 octets
		s_clearTouches(s_balayTouches)<='1';	-- reset prise en compte chgt
      end if;
    end if;
  end process p_BalTouch;

-- controle de l'UART en émission 
    
  p_uart : process (i_clock) is
  begin
    if rising_edge(i_clock) then
       if s_EMPTY ='1' then
        r_TX_DV         <= '0';
        s_RD_EN         <= '0';
        r_TXwaitDone    <='0';
       elsif w_TX_DONE = '1' then
        r_TXwaitDone    <='0'; 
       elsif(r_TX_ACTIVE = '0' and s_EMPTY ='0' and r_TX_DV = '0' and r_TXwaitDone  ='0') then  -- chargement uart si pas d'émission en cours et FIFO non vide
         r_TX_DV   <= '1';
         s_RD_EN   <= '1';            -- dépiler FIFO
        r_TXwaitDone    <='1';
      else		--chargement actif un cycle
        r_TX_DV         <= '0';
        s_RD_EN         <= '0';
      end if;
    end if;
  end process p_uart;
  r_TX_BYTE <=  s_RD_DATA; -- données à envoyer = données FIFO

  
  UART_TXD  <= w_TX_SERIAL; 


-- debug, affichage sur 7 segments
	-- 0: tx passé à active
	LEDG(0) <= SW(0);
	LEDG(1) <= SW(1);
	LEDG(2) <= i_CHGTT;
	LEDG(3) <= i_CHGTT1;
    LEDG(4) <= s_WR3_EN;
	LEDG(5) <= s_EMPTY;	-- FIFO '1' vide, '0' non vide
	LEDG(6) <= s_RD_EN;
	LEDG(7) <= r_TX_DV;
	
	HEX0     <= "1111111"; -- s_check_send_uart; --"1" & Key(2) & Key(1) & "1" & i_CHGTT & i_VALT & s_check_send_uart;
	
    bin <= s_RD_DATA;

    r_RX_SERIAL <= w_TX_SERIAL;


  

	
  -- Instantiate 7seg 1
  SEG7_1_INST : h27segments
    port map (
      i_7s => '0' & bcd(3 downto 0),	
      o_7s => r_Hex_Encoding
      );
  HEX1 <= r_Hex_Encoding(6 downto 0);

  -- Instantiate 7seg 2
  SEG7_2_INST : h27segments
    port map (
      i_7s => '0' & bcd(7 downto 4),	
      o_7s => s_Hex_Encoding
      );
  HEX2 <= s_Hex_Encoding(6 downto 0);

  -- Instantiate 7seg 3
  SEG7_3_INST : h27segments
    port map (
      i_7s => '0' &	bcd(11 downto 8),
      o_7s => t_Hex_Encoding
      );
  HEX3 <= t_Hex_Encoding(6 downto 0);
  
end behave;