-- Testbench integrado: adc_controller real do projeto + ADC128S022 comportamental.
-- 8 canais de tensao REAL, atraso de 1 frame na escolha do canal,
-- 16 ciclos SPI por frame, saturacao e atualizacao de entrada entre frames.
-- ModelSim 10.5b: compile com vcom -2008.

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY tb_adc128s022_integrado IS
END ENTITY;

ARCHITECTURE teste OF tb_adc128s022_integrado IS
-- Componentes
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
    COMPONENT adc128s022_model IS
    GENERIC (
        VREF_V  : REAL := 3.3;     -- Referencia/VA simulada (volts)
        T_EN    : TIME := 30 ns;  -- CS baixo -> DOUT habilitado
        T_DACC  : TIME := 27 ns;  -- Descida SCLK -> DOUT valido
        T_DIS   : TIME := 20 ns   -- CS alto -> DOUT em alta impedancia
    );
    PORT (
        CS       : IN  STD_LOGIC;
        SCLK     : IN  STD_LOGIC;
        DIN      : IN  STD_LOGIC;
        DOUT     : OUT STD_LOGIC;
        AIN0     : IN REAL;
        AIN1     : IN REAL;
        AIN2     : IN REAL;
        AIN3     : IN REAL;
        AIN4     : IN REAL;
        AIN5     : IN REAL;
        AIN6     : IN REAL;
        AIN7     : IN REAL
    );
    END COMPONENT;

    CONSTANT CLK_PERIOD : TIME := 20 ns;    -- CLK FPGA: 50 MHz
    CONSTANT VREF_V     : REAL := 3.3;

    SIGNAL CLK        : STD_LOGIC := '0';
    SIGNAL RST        : STD_LOGIC := '1';
    SIGNAL ENABLE     : STD_LOGIC := '0';
    SIGNAL ADC_CS     : STD_LOGIC;
    SIGNAL ADC_SCLK   : STD_LOGIC;
    SIGNAL ADC_DIN    : STD_LOGIC;
    SIGNAL ADC_DOUT   : STD_LOGIC;
    SIGNAL DATA_OUT   : STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL CHANNEL_ID : INTEGER RANGE 0 TO 7;
    SIGNAL DATA_VALID : STD_LOGIC;
    SIGNAL terminado  : BOOLEAN := FALSE;

    -- Tensoes escolhidas para produzir codigos ADC conhecidos.
    SIGNAL VIN0 : REAL := VREF_V *  291.0 / 4096.0; -- 0x123
    SIGNAL VIN1 : REAL := VREF_V * 1110.0 / 4096.0; -- 0x456
    SIGNAL VIN2 : REAL := VREF_V * 1929.0 / 4096.0; -- 0x789
    SIGNAL VIN3 : REAL := VREF_V * 2748.0 / 4096.0; -- 0xABC
    SIGNAL VIN4 : REAL := VREF_V * 3567.0 / 4096.0; -- 0xDEF
    SIGNAL VIN5 : REAL := 3.5;                     -- satura 0xFFF
    SIGNAL VIN6 : REAL := VREF_V *    1.0 / 4096.0; -- 0x001
    SIGNAL VIN7 : REAL := VREF_V * 2080.0 / 4096.0; -- 0x820

    TYPE palavras_tipo IS ARRAY (0 TO 7) OF STD_LOGIC_VECTOR(15 DOWNTO 0);
    CONSTANT ESPERADO : palavras_tipo := (
        x"0123", x"0456", x"0789", x"0ABC",
        x"0DEF", x"0FFF", x"0001", x"0820"
    );
BEGIN
    CLK <= NOT CLK AFTER CLK_PERIOD / 2;

    DUT : adc_controller
        GENERIC MAP (
            NUM_CANAIS => 8,
            MT_ADC     => 16
        )
        PORT MAP (
            CLK        => CLK,
            RST        => RST,
            ENABLE     => ENABLE,
            ADC_CS     => ADC_CS,
            ADC_SCLK   => ADC_SCLK,
            ADC_DIN    => ADC_DIN,
            ADC_DOUT   => ADC_DOUT,
            DATA_OUT   => DATA_OUT,
            CHANNEL_ID => CHANNEL_ID,
            DATA_VALID => DATA_VALID
        );

    U_ADC : adc128s022_model
        GENERIC MAP (
            VREF_V => VREF_V,
            T_EN   => 30 ns,
            T_DACC => 27 ns,
            T_DIS  => 20 ns
        )
        PORT MAP (
            CS   => ADC_CS,
            SCLK => ADC_SCLK,
            DIN  => ADC_DIN,
            DOUT => ADC_DOUT,
            AIN0 => VIN0,
            AIN1 => VIN1,
            AIN2 => VIN2,
            AIN3 => VIN3,
            AIN4 => VIN4,
            AIN5 => VIN5,
            AIN6 => VIN6,
            AIN7 => VIN7
        );

    ESTIMULOS : PROCESS
        VARIABLE canal_esperado : INTEGER RANGE 0 TO 7;
        VARIABLE dado_esperado  : STD_LOGIC_VECTOR(15 DOWNTO 0);
        VARIABLE frame_correto  : BOOLEAN;
        VARIABLE t_anterior    : TIME := 0 ns;
    BEGIN
        WAIT FOR 80 ns;
        WAIT UNTIL rising_edge(CLK);
        RST <= '0';
        ENABLE <= '1';

        -- Verifica uma volta completa de 8 canais + duas novas leituras.
        FOR frame IN 0 TO 9 LOOP
            WAIT UNTIL rising_edge(DATA_VALID);
            WAIT FOR 1 ns;
            canal_esperado := frame MOD 8;

            IF frame = 8 THEN
                dado_esperado := x"0321";
            ELSE
                dado_esperado := ESPERADO(canal_esperado);
            END IF;

            -- Garante que nao houve um falso DATA_VALID entre frames.
            IF frame > 0 THEN
                ASSERT NOW - t_anterior >= 10 us
                    REPORT "ERRO: DATA_VALID voltou antes de completar um frame SPI"
                    SEVERITY ERROR;
            END IF;
            t_anterior := NOW;

            frame_correto := (CHANNEL_ID = canal_esperado) AND
                            (DATA_OUT = dado_esperado);

            ASSERT CHANNEL_ID = canal_esperado
                REPORT "ERRO no CHANNEL_ID do frame " & INTEGER'IMAGE(frame + 1) &
                       "; canal esperado = " & INTEGER'IMAGE(canal_esperado) &
                       "; recebido = " & INTEGER'IMAGE(CHANNEL_ID)
                SEVERITY ERROR;

            ASSERT DATA_OUT = dado_esperado
                REPORT "ERRO DATA_OUT no frame " & INTEGER'IMAGE(frame + 1) &
                       "; esperado decimal = " &
                       INTEGER'IMAGE(TO_INTEGER(UNSIGNED(dado_esperado))) &
                       "; recebido decimal = " &
                       INTEGER'IMAGE(TO_INTEGER(UNSIGNED(DATA_OUT)))
                SEVERITY ERROR;

            IF frame_correto THEN
                REPORT "Frame " & INTEGER'IMAGE(frame + 1) &
                       " OK; canal " & INTEGER'IMAGE(canal_esperado) &
                       "; amostra decimal = " &
                       INTEGER'IMAGE(TO_INTEGER(UNSIGNED(DATA_OUT)))
                    SEVERITY NOTE;
            ELSE
                REPORT "Frame " & INTEGER'IMAGE(frame + 1) &
                       " REPROVADO" SEVERITY ERROR;
            END IF;

            IF frame = 7 THEN
                -- Altera IN0 ANTES da proxima conversao de IN0.
                VIN0 <= VREF_V * 801.0 / 4096.0; -- 0x321
            END IF;
        END LOOP;

        ENABLE <= '0';
        WAIT FOR 3 us;
        ASSERT ADC_CS = '1' AND ADC_SCLK = '1'
            REPORT "ERRO: CS/SCLK nao retornaram ao repouso alto"
            SEVERITY ERROR;

        terminado <= TRUE;
        REPORT "FIM: 10 frames verificados, 8 canais, canal IN0 atualizado."
            SEVERITY NOTE;
        WAIT;
    END PROCESS;

    -- Evita que uma falha na FSM deixe a simulacao presa para sempre.
    TIMEOUT_TESTE : PROCESS
    BEGIN
        WAIT FOR 140 us;
        ASSERT terminado
            REPORT "TIMEOUT: nao ocorreram 10 frames validos em 140 us"
            SEVERITY FAILURE;
        WAIT;
    END PROCESS;
END ARCHITECTURE teste;

