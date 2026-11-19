-- Autores: Jonatas Medeiros & Guilherme Ferreira
-- Controlador de ADC com protocolo SPI


LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY ad_controller IS
    GENERIC (
        NUM_CANAIS : INTEGER RANGE 1 TO 8 := 3; -- numero de canais que serao lidos (sempre em sequencia)
	MT_ADC      : NATURAL := 320 -- Tempo do meio periodo da frequencia do adc
    );

    PORT (
        CLK        : IN  STD_LOGIC; -- Clock FPGA: 50 MHz
        RST        : IN  STD_LOGIC; -- Reset sincrono
        ENABLE     : IN  STD_LOGIC; -- Habilita varredura

        -- Interface SPI
        ADC_CS     : OUT STD_LOGIC;
        ADC_SCLK   : OUT STD_LOGIC;
        ADC_DIN    : OUT STD_LOGIC;
        ADC_DOUT   : IN  STD_LOGIC;

        -- Resultado da conversao
        DATA_OUT   : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
        CHANNEL_ID : OUT INTEGER RANGE 0 TO 7;
        DATA_VALID : OUT STD_LOGIC
    );
END ENTITY;

ARCHITECTURE comportamento OF ad_controller IS
-- Definicao dos estados da FSM
	TYPE state_type IS (
        IDLE,
        PREPARE,
        START_SPI,
        TRANSFER,
        FINISH
		);
-- Sinal que armazena o estado atual
	SIGNAL estado      : state_type := IDLE;
-- Sinais de controle dos canais
	SIGNAL ch_atual    : NATURAL RANGE 0 TO NUM_CANAIS := 0;
	SIGNAL ch_prox	   : NATURAL RANGE 0 TO NUM_CANAIS := 0;
-- Sinais auxiliares: 
	SIGNAL data_word   : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
	SIGNAL sclk_intern : STD_LOGIC := '0';
	SIGNAL cs_intern   : STD_LOGIC := '1';
	SIGNAL count_Tadc  : NATURAL RANGE 0 TO MT_ADC*2 := 0;
	SIGNAL channel     : NATURAL RANGE 1 TO 8 := 1;
	SIGNAL ch_sel      : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
	SIGNAL frst_time   : STD_LOGIC := '1'; -- Identificacao da primeira iteracao, vem com o canal 0 habilitado.
	SIGNAL cont_PISO   : NATURAL RANGE 0 TO 15 := 0;
	SIGNAL cont_SIPO   : NATURAL RANGE 0 TO 15 := 15;
	SIGNAL sclk_reg    : STD_LOGIC := '1';
	SIGNAL load_tx 	   : STD_LOGIC := '0';
	SIGNAL load_rx     : STD_LOGIC := '0';

BEGIN

-- Processo para criar a frequencia de 1,5625 MHz.
	PROCESS(CLK)
	BEGIN
		IF rising_egdge(CLK) THEN
			IF RST = '1' THEN
				count_Tadc <= 0;
				-- sclk_intern <= '0';
			ELSIF sclk_intern = '1' THEN
				IF cont_Tadc < MT_ADC THEN
					
				END IF;
			END IF;
		END IF;


	END PROCESS
	PROCESS(CLK)
	BEGIN
		IF rising_edge(CLK) THEN
			IF RST = '1' THEN
            			cont_PISO <= 0;
                		sclk_reg <= '1';
				cont_SIPO <= 15;
				frst_time <= '1';
            		ELSE
                		--IF contador = 15 THEN
                			--contador <= 0;
                			--sclk_reg <= NOT sclk_reg;
                		--ELSE
               				--contador <= contador + 1;
                		--END IF;
			END IF;
		END IF;
	END PROCESS;

-- FSM para controle das fases de operacao do SPI
	PROCESS(CLK)
	BEGIN
	IF rising_edge(CLK) THEN
		IF RST = '1' THEN
			estado <= IDLE;
		ELSE
			CASE (estado)
				WHEN IDLE =>
					IF ENABLE = '1' THEN
						estado <= PREPARE;
					ELSE
						estado <= IDLE;
					END IF;
					cs_intern <= '1';
				WHEN PREPARE =>
					IF ch_atual = NUM_CANAIS - 1 THEN
						ch_prox := 0;
					ELSE
						ch_prox := ch_atual + 1;
					END IF;
					ch_sel <= "00" & STD_LOGIC_VECTOR(TO_UNSIGNED(ch_prox,3)) & "00000000000";
					load_tx <= '1';
					load_rx <= '1';
					estado <= START_SPI;
				WHEN START_SPI =>
					load_tx <= '0';
					load_rx <= '0';
					estado <= TRANSFER;
				WHEN TRANSFER =>
					IF THEN 
					
					END IF;
					estado <= FINISH;
				WHEN FINISH =>
					estado <= IDLE;
			END CASE;
	END PROCESS;
	END IF;
	
 -- FSM para controle da selecao dos canais
	PROCESS(channel)
	BEGIN
		CASE channel IS
		WHEN 1 =>
			ch_sel <= "000
			
		END CASE;
	END PROCESS;

END comportamento;
