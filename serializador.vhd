-- Autores: Jonatas Medeiros & Guilherme Ferreira
-- Versao SCLK: o ADC e o serializador usam o MESMO SCLK.
-- O primeiro falling_edge carrega a palavra (LOAD = '1').
-- Os 15 falling_edges seguintes avancam D14 ... D0 em MOSI.
-- TX_DONE fica em '1' quando D0 foi apresentado (16a descida),
-- ate o proximo LOAD ou RST. Ele NAO indica que o ADC ja capturou D0.

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY serializador IS
    PORT (
        CLK      : IN  STD_LOGIC; -- SCLK do ADC (nao CLK de 50 MHz)
        RST      : IN  STD_LOGIC; -- reset assincrono neste dominio
        LOAD     : IN  STD_LOGIC; -- deve estar em '1' na 1a descida
        SHIFT_EN : IN  STD_LOGIC; -- habilitacao de nivel enquanto CS = 0
        DATA_IN  : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
        MOSI     : OUT STD_LOGIC;
        TX_DONE  : OUT STD_LOGIC
    );
END ENTITY serializador;

ARCHITECTURE comportamento OF serializador IS
    SIGNAL shift_reg : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
    SIGNAL bit_count : NATURAL RANGE 0 TO 15 := 0;
    SIGNAL done_reg  : STD_LOGIC := '0';
BEGIN
    PROCESS(CLK, RST)
    BEGIN
        IF RST = '1' THEN
            shift_reg <= (OTHERS => '0');
            bit_count <= 0;
            done_reg  <= '0';

        ELSIF falling_edge(CLK) THEN
            IF LOAD = '1' THEN
                -- Primeira descida do frame: apresenta D15.
                shift_reg <= DATA_IN;
                bit_count <= 0;
                done_reg  <= '0';

            ELSIF SHIFT_EN = '1' THEN
                IF bit_count < 15 THEN
                    shift_reg <= shift_reg(14 DOWNTO 0) & '0';
                    bit_count <= bit_count + 1;
                    IF bit_count = 14 THEN
                        -- O deslocamento agora coloca D0 em MOSI.
                        done_reg <= '1';
                    END IF;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    MOSI    <= shift_reg(15);
    TX_DONE <= done_reg;
END ARCHITECTURE comportamento;

