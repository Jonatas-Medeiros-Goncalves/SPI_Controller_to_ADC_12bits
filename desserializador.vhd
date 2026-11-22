-- Autores: Jonatas Medeiros & Guilherme Ferreira
-- Versao SCLK: recebe 16 bits nas 16 subidas de SCLK.
-- IMPORTANTE: LOAD e uma LIMPEZA ASSINCRONA do registrador de
-- recepcao/contador (pois SCLK fica parado entre os frames).
-- DATA_OUT conserva a amostra anterior durante a recepcao seguinte.
-- RX_DONE e um nivel RETIDO ate LOAD ou RST, apropriado para
-- ser sincronizado ao CLK de 50 MHz no adc_controller.

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY desserializador IS
    PORT (
        CLK       : IN  STD_LOGIC; -- SCLK do ADC (nao CLK de 50 MHz)
        RST       : IN  STD_LOGIC; -- reset assincrono neste dominio
        LOAD      : IN  STD_LOGIC; -- limpa/arma recepcao assincronamente
        SAMPLE_EN : IN  STD_LOGIC; -- habilitacao de nivel enquanto CS = 0
        MISO      : IN  STD_LOGIC; -- DOUT do ADC128S022
        DATA_OUT  : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
        RX_DONE   : OUT STD_LOGIC
    );
END ENTITY desserializador;

ARCHITECTURE comportamento OF desserializador IS
    SIGNAL bit_count : NATURAL RANGE 0 TO 16 := 0;
    SIGNAL shift_reg : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
    SIGNAL data_reg  : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
    SIGNAL done_reg  : STD_LOGIC := '0';
BEGIN
    -- LOAD precisa funcionar mesmo quando SCLK esta parado.
    PROCESS(CLK, RST, LOAD)
    BEGIN
        IF RST = '1' THEN
            bit_count <= 0;
            shift_reg <= (OTHERS => '0');
            done_reg  <= '0';
        ELSIF LOAD = '1' THEN
            bit_count <= 0;
            shift_reg <= (OTHERS => '0');
            done_reg  <= '0';
        ELSIF rising_edge(CLK) THEN
            IF SAMPLE_EN = '1' AND bit_count < 16 THEN
                shift_reg <= shift_reg(14 DOWNTO 0) & MISO;
                bit_count <= bit_count + 1;
                IF bit_count = 15 THEN
                    done_reg <= '1';
                END IF;
            END IF;
        END IF;
    END PROCESS;

    -- Registrador de saida separado para preservar a ultima leitura.
    PROCESS(CLK, RST)
    BEGIN
        IF RST = '1' THEN
            data_reg <= (OTHERS => '0');
        ELSIF rising_edge(CLK) THEN
            IF LOAD = '0' AND SAMPLE_EN = '1' AND bit_count = 15 THEN
                data_reg <= shift_reg(14 DOWNTO 0) & MISO;
            END IF;
        END IF;
    END PROCESS;

    DATA_OUT <= data_reg;
    RX_DONE  <= done_reg;
END ARCHITECTURE comportamento;

