-- Autores: Jonatas Medeiros & Guilherme Ferreira
-- Testbench do desserializador
-- Reproduz o controlador gerando LOAD e SAMPLE_EN em bordas de subida
-- do mesmo clock de 50 MHz. O DUT reconhece os sinais na borda seguinte.

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY tb_desserializador IS
END ENTITY;

ARCHITECTURE simulacao OF tb_desserializador IS
    CONSTANT CLK_PERIOD : TIME := 20 ns;   -- 50 MHz
    CONSTANT BIT_PERIOD : TIME := 640 ns;  -- Intervalo entre amostragens

    SIGNAL CLK       : STD_LOGIC := '0';
    SIGNAL RST       : STD_LOGIC := '0';
    SIGNAL LOAD      : STD_LOGIC := '0';
    SIGNAL SAMPLE_EN : STD_LOGIC := '0';
    SIGNAL MISO      : STD_LOGIC := '0';
    SIGNAL DATA_OUT  : STD_LOGIC_VECTOR(15 DOWNTO 0);
BEGIN
    CLK <= NOT CLK AFTER CLK_PERIOD / 2;

    UUT : ENTITY work.desserializador
        PORT MAP (
            CLK       => CLK,
            RST       => RST,
            LOAD      => LOAD,
            SAMPLE_EN => SAMPLE_EN,
            MISO      => MISO,
            DATA_OUT  => DATA_OUT
        );

    ESTIMULOS : PROCESS
        -- LOAD e gerado numa borda de subida e reconhecido pelo DUT
        -- na proxima borda de subida, como no adc_controller.
        PROCEDURE preparar_recepcao IS
        BEGIN
            WAIT UNTIL rising_edge(CLK);
            LOAD      <= '1';
            SAMPLE_EN <= '0';

            WAIT UNTIL rising_edge(CLK);
            LOAD <= '0';
            WAIT FOR 1 ns;
        END PROCEDURE;

        -- Gera um pulso SAMPLE_EN com 1 ciclo de 50 MHz de duracao.
        -- O DUT recebe MISO na segunda borda de subida.
        -- O intervalo entre capturas sucessivas e de 640 ns.
        PROCEDURE capturar_bit(CONSTANT b : IN STD_LOGIC) IS
        BEGIN
            WAIT UNTIL rising_edge(CLK);
            MISO      <= b;
            SAMPLE_EN <= '1';

            WAIT UNTIL rising_edge(CLK);
            SAMPLE_EN <= '0';
            WAIT FOR 1 ns;

            -- Aguarda antes da proxima chamada da procedure.
            WAIT FOR BIT_PERIOD - 2 * CLK_PERIOD - 1 ns;
        END PROCEDURE;

        -- Verifica que DATA_OUT so muda ao receber o 16o bit.
        PROCEDURE receber_palavra(
            CONSTANT palavra  : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
            CONSTANT anterior : IN STD_LOGIC_VECTOR(15 DOWNTO 0)
        ) IS
        BEGIN
            preparar_recepcao;
            ASSERT DATA_OUT = anterior
                REPORT "ERRO: LOAD alterou DATA_OUT" SEVERITY ERROR;

            FOR i IN 15 DOWNTO 0 LOOP
                capturar_bit(palavra(i));

                IF i > 0 THEN
                    ASSERT DATA_OUT = anterior
                        REPORT "ERRO: DATA_OUT mudou antes da 16a captura; indice " &
                               INTEGER'IMAGE(i)
                        SEVERITY ERROR;
                ELSE
                    ASSERT DATA_OUT = palavra
                        REPORT "ERRO: palavra recebida incorreta na 16a captura"
                        SEVERITY ERROR;
                END IF;
            END LOOP;
        END PROCEDURE;
    BEGIN
        -- RESET inicial (sincrono, ativo em nivel alto).
        RST <= '1';
        WAIT UNTIL rising_edge(CLK);
        WAIT UNTIL rising_edge(CLK);
        RST <= '0';
        WAIT FOR 1 ns;

        ASSERT DATA_OUT = x"0000"
            REPORT "ERRO: reset inicial nao zerou DATA_OUT"
            SEVERITY ERROR;

        -- Teste 1: formato tipico do ADC128S022: 0000 + 12 bits.
        REPORT "TESTE 1: recebendo 0x0AC5" SEVERITY NOTE;
        receber_palavra(x"0AC5", x"0000");

        -- Dois pulsos extras nao podem mudar uma palavra completa.
        REPORT "TESTE 2: bloqueio do 17o e do 18o SAMPLE_EN" SEVERITY NOTE;
        capturar_bit('0');
        capturar_bit('1');
        ASSERT DATA_OUT = x"0AC5"
            REPORT "ERRO: SAMPLE_EN extra alterou DATA_OUT"
            SEVERITY ERROR;

        -- Teste 3: novo LOAD nao apaga o resultado anterior.
        REPORT "TESTE 3: recebendo 0x0001" SEVERITY NOTE;
        receber_palavra(x"0001", x"0AC5");

        -- Teste 4: ADC com os 12 bits de conversao iguais a 1.
        REPORT "TESTE 4: recebendo 0x0FFF" SEVERITY NOTE;
        receber_palavra(x"0FFF", x"0001");

        -- Teste 5: padrao generico para testar o primeiro e ultimo bits.
        -- (Nao representa um frame real do ADC128S022: os 4 MSBs sao 0.)
        REPORT "TESTE 5: recebendo 0x8001" SEVERITY NOTE;
        receber_palavra(x"8001", x"0FFF");

        -- Teste 6: iniciar um frame, abortar e reiniciar com LOAD.
        REPORT "TESTE 6: LOAD interrompe recepcao incompleta" SEVERITY NOTE;
        preparar_recepcao;
        FOR i IN 1 TO 5 LOOP
            capturar_bit('1');
        END LOOP;
        ASSERT DATA_OUT = x"8001"
            REPORT "ERRO: recepcao parcial alterou DATA_OUT"
            SEVERITY ERROR;

        receber_palavra(x"0000", x"8001");

        -- Teste 7: reset durante uma recepcao parcial.
        REPORT "TESTE 7: reset durante recepcao" SEVERITY NOTE;
        preparar_recepcao;
        capturar_bit('1');
        capturar_bit('0');
        WAIT UNTIL rising_edge(CLK);
        RST <= '1';
        WAIT UNTIL rising_edge(CLK);
        RST <= '0';
        WAIT FOR 1 ns;
        ASSERT DATA_OUT = x"0000"
            REPORT "ERRO: reset nao zerou DATA_OUT"
            SEVERITY ERROR;

        -- Teste 8: verifica se o componente volta a receber apos reset.
        REPORT "TESTE 8: recebendo 0xFFFF apos reset" SEVERITY NOTE;
        receber_palavra(x"FFFF", x"0000");

        REPORT "FIM DOS TESTES: todos os ASSERTs foram verificados" SEVERITY NOTE;
        WAIT;
    END PROCESS;
END ARCHITECTURE;