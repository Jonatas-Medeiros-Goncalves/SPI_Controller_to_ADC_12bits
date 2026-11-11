-- Autores: Jonatas Medeiros & Guilherme Ferreira
-- Controlador de ADC com protocolo SPI


LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY ad_controller IS
    GENERIC (
        NUM_CANAIS : INTEGER RANGE 1 TO 8 := 4
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
-- Sinais auxiliares: 
	SIGNAL data_word : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
	SIGNAL ch_sel    : NATURAL RANGE 1 TO 8 := 1;
	SIGNAL frst_time : STD_LOGIC := '1'; -- Identificacao da primeira iteracao, vem com o canal 0 habilitado.
	SIGNAL cont_PISO  : NATURAL RANGE 0 TO 15 := 0;
	SIGNAL cont_SIPO  : NATURAL RANGE 0 TO 15 := 15;
	SIGNAL sclk_reg  : STD_LOGIC := '1';

BEGIN

-- Processo para criar a frequencia de 1,5625 MHz.
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
 
-- Maquina Mealy para leitura
	PROCESS (sclk_reg)
	BEGIN
		IF rising_edge(sclk_reg) THEN
			
		END IF;
	END PROCESS;

END comportamento;
