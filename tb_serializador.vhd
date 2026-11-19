-- Autores: Jonatas Medeiros & Guilherme Ferreira
-- Testbench para serializador.vhd
-- Simula um controlador que registra LOAD, DATA_IN e SHIFT_EN
-- na mesma borda de subida do clock principal (50 MHz).

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY tb_serializador IS
END ENTITY;

ARCHITECTURE comportamento OF tb_serializador IS

    COMPONENT serializador IS
        PORT (
            CLK      : IN  STD_LOGIC;
            RST      : IN  STD_LOGIC;
            LOAD     : IN  STD_LOGIC;
            SHIFT_EN : IN  STD_LOGIC;
            DATA_IN  : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
            MOSI     : OUT STD_LOGIC;
            TX_DONE  : OUT STD_LOGIC
        );
    END COMPONENT;

    CONSTANT CLK_PERIOD : TIME := 20 ns; -- 50 MHz

    SIGNAL CLK      : STD_LOGIC := '0';
    SIGNAL RST      : STD_LOGIC := '1';
    SIGNAL LOAD     : STD_LOGIC := '0';
    SIGNAL SHIFT_EN : STD_LOGIC := '0';
    SIGNAL DATA_IN  : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
    SIGNAL MOSI     : STD_LOGIC;
    SIGNAL TX_DONE  : STD_LOGIC;

BEGIN

    UUT : serializador
        PORT MAP (
            CLK      => CLK,
            RST      => RST,
            LOAD     => LOAD,
            SHIFT_EN => SHIFT_EN,
            DATA_IN  => DATA_IN,
            MOSI     => MOSI,
            TX_DONE  => TX_DONE
        );

    CLK <= NOT CLK AFTER CLK_PERIOD / 2;

    PROCESS

        PROCEDURE verificar_bit (
            CONSTANT esperado : IN STD_LOGIC;
            CONSTANT contexto : IN STRING
        ) IS
        BEGIN
            ASSERT MOSI = esperado
                REPORT contexto & " | esperado=" & STD_LOGIC'IMAGE(esperado)
                        & " recebido=" & STD_LOGIC'IMAGE(MOSI)
                SEVERITY ERROR;
        END PROCEDURE;

        -- O procedimento imita um controlador sincronizado ao CLK.
        -- LOAD e DATA_IN sao registrados numa borda e reconhecidos
        -- pelo DUT na borda de subida seguinte.
        PROCEDURE testar_palavra (
            CONSTANT palavra : IN STD_LOGIC_VECTOR(15 DOWNTO 0)
        ) IS
        BEGIN
            REPORT "Iniciando transmissao de 16 bits"
    	    SEVERITY NOTE;

            WAIT UNTIL rising_edge(CLK);
            DATA_IN  <= palavra;
            LOAD     <= '1';
            SHIFT_EN <= '0';

            -- O DUT recebe LOAD=1 e DATA_IN na proxima borda.
            WAIT UNTIL rising_edge(CLK);
            LOAD <= '0';
            WAIT FOR 1 ns;

            verificar_bit(palavra(15), "MSB apos LOAD");
            ASSERT TX_DONE = '0'
                REPORT "ERRO: TX_DONE ativo durante LOAD" SEVERITY ERROR;

            -- 15 deslocamentos. Espaca cada SHIFT_EN em 32 ciclos
            -- de 50 MHz (= 640 ns), como exemplo de temporizacao SPI.
            FOR i IN 14 DOWNTO 0 LOOP

                -- Aguarda 31 bordas e registra SHIFT_EN=1.
                FOR k IN 1 TO 31 LOOP
                    WAIT UNTIL rising_edge(CLK);
                END LOOP;
                SHIFT_EN <= '1';

                -- O serializador reconhece SHIFT_EN na proxima borda.
                WAIT UNTIL rising_edge(CLK);
                SHIFT_EN <= '0';
                WAIT FOR 1 ns;

                verificar_bit(palavra(i),
                              "Bit " & INTEGER'IMAGE(i));
                ASSERT TX_DONE = '0'
                    REPORT "ERRO: TX_DONE antecipado no bit " & INTEGER'IMAGE(i)
                    SEVERITY ERROR;
            END LOOP;

            -- O 16o pulso finaliza sem descartar o LSB de MOSI.
            FOR k IN 1 TO 31 LOOP
                WAIT UNTIL rising_edge(CLK);
            END LOOP;
            SHIFT_EN <= '1';

            WAIT UNTIL rising_edge(CLK);
            SHIFT_EN <= '0';
            WAIT FOR 1 ns;
            verificar_bit(palavra(0), "LSB preservado na finalizacao");
            ASSERT TX_DONE = '1'
                REPORT "ERRO: faltou TX_DONE no 16o pulso"
                SEVERITY ERROR;

            -- DONE deve durar apenas um CLK.
            WAIT UNTIL rising_edge(CLK);
            WAIT FOR 1 ns;
            ASSERT TX_DONE = '0'
                REPORT "ERRO: TX_DONE durou mais de um CLK" SEVERITY ERROR;

            -- Um 17o pulso nao pode deslocar o LSB nem gerar outro DONE.
            SHIFT_EN <= '1';
            WAIT UNTIL rising_edge(CLK);
            SHIFT_EN <= '0';
            WAIT FOR 1 ns;
            verificar_bit(palavra(0), "LSB preservado apos 17o pulso");
            ASSERT TX_DONE = '0'
                REPORT "ERRO: TX_DONE repetido no 17o pulso" SEVERITY ERROR;

            -- Sem LOAD e sem SHIFT_EN, a saida deve permanecer estavel.
            FOR k IN 1 TO 5 LOOP
                WAIT UNTIL rising_edge(CLK);
                WAIT FOR 1 ns;
                verificar_bit(palavra(0), "MOSI estavel em repouso");
                ASSERT TX_DONE = '0'
                    REPORT "ERRO: TX_DONE ativo em repouso" SEVERITY ERROR;
            END LOOP;
        END PROCEDURE;

    BEGIN

        -- RESET sincrono
        WAIT UNTIL rising_edge(CLK);
        WAIT FOR 1 ns;
        verificar_bit('0', "RESET inicial");
        ASSERT TX_DONE = '0'
            REPORT "ERRO: TX_DONE ativo durante reset" SEVERITY ERROR;

        WAIT UNTIL rising_edge(CLK);
        RST <= '0';

        -- Testes de palavras comuns e com LSB=1.
        testar_palavra(x"B2D5");
        testar_palavra(x"8001");

        -- Comandos para o ADC128S022 (ADD2:ADD0 em 13:11).
        testar_palavra(x"0800"); -- IN1
        testar_palavra(x"2800"); -- IN5
        testar_palavra(x"0000"); -- IN0

        -- RESET durante uma transmissao
        REPORT "Teste de reset durante transmissao" SEVERITY NOTE;
        WAIT UNTIL rising_edge(CLK);
        DATA_IN <= x"FFFF";
        LOAD <= '1';

        WAIT UNTIL rising_edge(CLK);
        LOAD <= '0';
        WAIT FOR 1 ns;
        verificar_bit('1', "Carga antes do reset intermediario");

        WAIT UNTIL rising_edge(CLK);
        RST <= '1';
        WAIT UNTIL rising_edge(CLK);
        RST <= '0';
        WAIT FOR 1 ns;
        verificar_bit('0', "Reset durante transmissao");
        ASSERT TX_DONE = '0'
            REPORT "ERRO: TX_DONE ativo apos reset intermediario" SEVERITY ERROR;

        REPORT "FIM: verificacoes concluidas; confira se houve ASSERT ERROR acima"
            SEVERITY NOTE;
        WAIT;

    END PROCESS;

END ARCHITECTURE;

