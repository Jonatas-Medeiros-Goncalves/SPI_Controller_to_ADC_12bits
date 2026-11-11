-- Autores: Jonatas Medeiros & Guilherme Ferreira
-- Serializador: Recebe uma palavra de bits e envia bit a bit sincronizado com o clock e um pulso de habilitacao


LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY serializador IS
    PORT (
        CLK      : IN  STD_LOGIC; -- clock de entrada, entre  0.8 MHz e 3.2 MHz
        RST      : IN  STD_LOGIC; -- sinal de reset

        LOAD     : IN  STD_LOGIC; -- sinal de carregamento da nova palavra de bits
        SHIFT_EN : IN  STD_LOGIC; -- pulso para envio de cada bit da palavra

        DATA_IN  : IN  STD_LOGIC_VECTOR(15 DOWNTO 0); -- palavra de entrada
        MOSI     : OUT STD_LOGIC -- bit de saida
    );
END ENTITY;

ARCHITECTURE comportamento OF serializador IS

    SIGNAL shift_reg : STD_LOGIC_VECTOR(15 DOWNTO 0)
                        := (OTHERS => '0');

    SIGNAL bit_count : NATURAL RANGE 0 TO 15 := 0;

BEGIN

    PROCESS(CLK)
    BEGIN
        IF rising_edge(CLK) THEN

            IF RST = '1' THEN
                shift_reg <= (OTHERS => '0');
                bit_count <= 0;

            ELSIF LOAD = '1' THEN

                -- Carrega a palavra inteira
                shift_reg <= DATA_IN;
                bit_count <= 0;

            ELSIF SHIFT_EN = '1' THEN

                -- Executa no maximo 15 deslocamentos
                IF bit_count < 15 THEN

                    shift_reg <=
                        shift_reg(14 DOWNTO 0) & '0';

                    bit_count <= bit_count + 1;

                END IF;

            END IF;

        END IF;
    END PROCESS;

    -- MSB sempre disponivel na saida
    MOSI <= shift_reg(15);

END ARCHITECTURE;

