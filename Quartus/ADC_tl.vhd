-- Autores: Jônatas e Guilherme
-- Arquivo Top-level do ADC de 12 bits do D0-Nano

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY ADC_tl IS
		PORT(
			CLK        : IN  STD_LOGIC; -- clock da FPGA: 50 MHz
			RST        : IN  STD_LOGIC; -- reset ativo alto
			ENABLE     : IN  STD_LOGIC; -- habilita varredura continua
			ADC_DOUT   : IN  STD_LOGIC; -- saida do adc que vai para o fpga
			ADC_CS     : OUT STD_LOGIC; -- chip select do adc
			ADC_SCLK   : OUT STD_LOGIC; -- clock que vai para o adc
			ADC_DIN    : OUT STD_LOGIC  -- saída da leitura do adc para o fpga
    );
END ENTITY ADC_tl;

ARCHITECTURE comportamento OF ADC_tl IS

-- Declaracao do componente ADC SPI.

COMPONENT adc_controller IS 
		GENERIC (
			NUM_CANAIS : INTEGER RANGE 1 TO 8 := 3;
			MT_ADC     : POSITIVE := 16  -- ciclos de CLK por meio SCLK
		);
		PORT (
			CLK        : IN  STD_LOGIC; -- clock da FPGA: 50 MHz
			RST        : IN  STD_LOGIC; -- reset ativo alto
			ENABLE     : IN  STD_LOGIC; -- habilita varredura continua
			ADC_CS     : OUT STD_LOGIC;
			ADC_SCLK   : OUT STD_LOGIC;
			ADC_DIN    : OUT STD_LOGIC;
			ADC_DOUT   : IN  STD_LOGIC;
			DATA_OUT   : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
			CHANNEL_ID : OUT INTEGER RANGE 0 TO 7;
			DATA_VALID : OUT STD_LOGIC
    );
END COMPONENT;

-- Declaracao dos sinais auxiliares.

SIGNAL data_out_sig   : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
SIGNAL data_unsigned     :	UNSIGNED(15 DOWNTO 0) := (OTHERS => '0');
SIGNAL channel_id_sig : INTEGER RANGE 0 TO 7 := 0;
SIGNAL data_valid_sig : STD_LOGIC := '0';

BEGIN
	adc01: adc_controller
				GENERIC MAP(
					NUM_CANAIS => 1,
					MT_ADC => 16
				)
				PORT MAP(
				CLK        => CLK,
				RST        => NOT RST,
				ENABLE     => ENABLE,
				ADC_CS     => ADC_CS,
				ADC_SCLK   => ADC_SCLK,
				ADC_DIN    => ADC_DIN,
				ADC_DOUT   => ADC_DOUT,
				DATA_OUT   => data_out_sig,
				CHANNEL_ID => channel_id_sig,
				DATA_VALID => data_valid_sig
				);
	data_unsigned <= UNSIGNED(data_out_sig);
END ARCHITECTURE comportamento;
