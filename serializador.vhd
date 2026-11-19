-- Autores: Jonatas Medeiros & Guilherme Ferreira
-- Serializador: Recebe uma palavra de bits e envia bit a bit sincronizado 
-- com o clock e um pulso de habilitacao


LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY serializador IS
    PORT (
        CLK      : IN  STD_LOGIC; -- clock de entrada do FPGA 50MHz
        RST      : IN  STD_LOGIC; -- sinal de reset

        LOAD     : IN  STD_LOGIC; -- sinal de carregamento da nova palavra de bits
        SHIFT_EN : IN  STD_LOGIC; -- pulso para envio de cada bit da palavra

        DATA_IN  : IN  STD_LOGIC_VECTOR(15 DOWNTO 0); -- palavra de entrada
        MOSI     : OUT STD_LOGIC; -- bit de saida
        TX_DONE  : OUT STD_LOGIC  -- pulso de 1 CLK no 16o SHIFT_EN
    );
END ENTITY;

ARCHITECTURE comportamento OF serializador IS

    SIGNAL shift_reg : STD_LOGIC_VECTOR(15 DOWNTO 0)
                        := (OTHERS => '0');

    SIGNAL bit_count : NATURAL RANGE 0 TO 16 := 0;
    SIGNAL done_reg  : STD_LOGIC := '0';

BEGIN

    PROCESS(CLK)
    BEGIN
        IF rising_edge(CLK) THEN

            -- Valor padrao: DONE dura somente um CLK.
            done_reg <= '0';

            IF RST = '1' THEN
                shift_reg <= (OTHERS => '0');
                bit_count <= 0;

            ELSIF LOAD = '1' THEN

                -- Carrega a palavra inteira
                shift_reg <= DATA_IN;
                bit_count <= 0;

            ELSIF SHIFT_EN = '1' THEN

                -- Primeiro bit ja esta em MOSI; os 15 primeiros pulsos
                -- avancam a palavra ate o LSB.
                IF bit_count < 15 THEN

                    shift_reg <=
                        shift_reg(14 DOWNTO 0) & '0'; -- desloca o bit para a esquerda

                    bit_count <= bit_count + 1;

                ELSIF bit_count = 15 THEN
                    -- 16o pulso: ultimo bit foi enviado, sem desloca-lo.
                    bit_count <= 16;
                    done_reg <= '1';
                END IF;

            END IF;

        END IF;
    END PROCESS;

    -- MSB sempre disponivel na saida
    MOSI <= shift_reg(15);
    TX_DONE <= done_reg;

END ARCHITECTURE;


