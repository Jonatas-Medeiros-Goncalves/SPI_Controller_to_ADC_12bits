-- Testbench integrado para ModelSim 10.5b / VHDL-2008.
-- Modelo simples do ADC128S022: DIN amostrado na subida de SCLK;
-- DOUT atualizado na descida; canal pedido vale no frame seguinte.

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY tb_adc_controller_sclk IS
END ENTITY;

ARCHITECTURE simulacao OF tb_adc_controller_sclk IS
    COMPONENT ad_controller IS
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
    CONSTANT CLK_PERIOD : TIME := 20 ns;
    SIGNAL CLK        : STD_LOGIC := '0';
    SIGNAL RST        : STD_LOGIC := '1';
    SIGNAL ENABLE     : STD_LOGIC := '0';
    SIGNAL ADC_CS     : STD_LOGIC;
    SIGNAL ADC_SCLK   : STD_LOGIC;
    SIGNAL ADC_DIN    : STD_LOGIC;
    SIGNAL ADC_DOUT   : STD_LOGIC := 'Z';
    SIGNAL DATA_OUT   : STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL CHANNEL_ID : INTEGER RANGE 0 TO 7;
    SIGNAL DATA_VALID : STD_LOGIC;

    FUNCTION amostra(CONSTANT canal : NATURAL)
        RETURN STD_LOGIC_VECTOR IS
    BEGIN
        CASE canal IS
            WHEN 0 => RETURN x"0123";
            WHEN 1 => RETURN x"0456";
            WHEN 2 => RETURN x"0789";
            WHEN OTHERS => RETURN x"0000";
        END CASE;
    END FUNCTION;
BEGIN
    CLK <= NOT CLK AFTER CLK_PERIOD / 2;

    UUT : ad_controller
        GENERIC MAP (NUM_CANAIS => 3, MT_ADC => 16)
        PORT MAP (
            CLK => CLK, RST => RST, ENABLE => ENABLE,
            ADC_CS => ADC_CS, ADC_SCLK => ADC_SCLK,
            ADC_DIN => ADC_DIN, ADC_DOUT => ADC_DOUT,
            DATA_OUT => DATA_OUT, CHANNEL_ID => CHANNEL_ID,
            DATA_VALID => DATA_VALID
        );

    -- ADC comportamental, sem atraso analogico, adequado para validar
    -- contagem de bordas, ordem dos bits e pipeline de canais.
    MODELO_ADC : PROCESS(ADC_CS, ADC_SCLK)
        VARIABLE canal_selecionado : NATURAL RANGE 0 TO 7 := 0;
        VARIABLE palavra          : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"0123";
        VARIABLE comando          : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
        VARIABLE quedas           : NATURAL RANGE 0 TO 16 := 0;
        VARIABLE subidas          : NATURAL RANGE 0 TO 16 := 0;
    BEGIN
        IF rising_edge(ADC_CS) THEN
            IF NOW > 0 ns THEN
                ASSERT subidas = 16
                    REPORT "ERRO: CS desativado sem 16 bordas de subida"
                    SEVERITY ERROR;
                ASSERT quedas = 16
                    REPORT "ERRO: CS desativado sem 16 bordas de descida"
                    SEVERITY ERROR;
            END IF;
            ADC_DOUT <= 'Z';

        ELSIF falling_edge(ADC_CS) THEN
            quedas  := 0;
            subidas := 0;
            comando := (OTHERS => '0');
            palavra := amostra(canal_selecionado);
            ADC_DOUT <= 'Z';

        ELSIF ADC_CS = '0' AND falling_edge(ADC_SCLK) THEN
            IF quedas < 16 THEN
                ADC_DOUT <= palavra(15 - quedas);
                quedas := quedas + 1;
            ELSE
                ASSERT FALSE REPORT "ERRO: 17a borda de descida" SEVERITY ERROR;
            END IF;

        ELSIF ADC_CS = '0' AND rising_edge(ADC_SCLK) THEN
            IF subidas < 16 THEN
                comando(15 - subidas) := ADC_DIN;
                IF subidas = 15 THEN
                    -- O comando vale para a PROXIMA transacao.
                    canal_selecionado := TO_INTEGER(UNSIGNED(comando(13 DOWNTO 11)));
                END IF;
                subidas := subidas + 1;
            ELSE
                ASSERT FALSE REPORT "ERRO: 17a borda de subida" SEVERITY ERROR;
            END IF;
        END IF;
    END PROCESS;

    ESTIMULOS : PROCESS
        VARIABLE canal_esperado : NATURAL;
    BEGIN
        WAIT FOR 80 ns;
        WAIT UNTIL rising_edge(CLK);
        RST <= '0';
        ENABLE <= '1';

        FOR n IN 0 TO 7 LOOP
            WAIT UNTIL rising_edge(DATA_VALID);
            WAIT FOR 1 ns;
            canal_esperado := n MOD 3;

            ASSERT CHANNEL_ID = canal_esperado
                REPORT "ERRO CHANNEL_ID no frame " & INTEGER'IMAGE(n+1)
                SEVERITY ERROR;
            ASSERT DATA_OUT = amostra(canal_esperado)
                REPORT "ERRO DATA_OUT no frame " & INTEGER'IMAGE(n+1)
                SEVERITY ERROR;
            REPORT "Frame " & INTEGER'IMAGE(n+1) &
                   " correto; canal " & INTEGER'IMAGE(canal_esperado)
                SEVERITY NOTE;
        END LOOP;

        ENABLE <= '0';
        WAIT FOR 3 us;
        ASSERT ADC_CS = '1' AND ADC_SCLK = '1'
            REPORT "ERRO: CS/SCLK nao retornaram ao repouso alto"
            SEVERITY ERROR;
        REPORT "FIM: 8 frames verificados. Confira ASSERT ERROR no Transcript"
            SEVERITY NOTE;
        WAIT;
    END PROCESS;
END ARCHITECTURE simulacao;

