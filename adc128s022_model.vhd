-- Modelo COMPORTAMENTAL (somente simulacao) do ADC128S022 - DE0-Nano.
-- Compativel com ModelSim 10.5b; usar VHDL-2008.
--
-- Interface externa igual aos quatro fios do ADC: CS, SCLK, DIN, DOUT.
-- AIN0..AIN7: tensoes em volts (tipo REAL; SOMENTE para testbench).
-- Primeira amostra apos a inicializacao do modelo: canal IN0.
-- O comando recebido em DIN seleciona o canal da proxima transacao.
-- Cada transacao suportada: CS=0 e 16 quedas + 16 subidas de SCLK.
-- SCLK em repouso alto; DOUT e atualizado nas quedas, DIN nas subidas.
-- DOUT: 4 zeros iniciais, depois os 12 bits da conversao (MSB primeiro).
-- A tensao e quantizada na 4a queda de SCLK (transicao track/hold).
--
-- Este modelo nao e sintetizavel. Nao modela ruído, INL/DNL,
-- metastabilidade, impedancia analogica nem o comportamento continuo
-- de multiplos frames com CS permanentemente baixo.

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY adc128s022_model IS
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
END ENTITY adc128s022_model;

ARCHITECTURE simulacao OF adc128s022_model IS
    SIGNAL dout_reg : STD_LOGIC := 'Z';

    -- Conversao ideal unipolar. O codigo satura em 0 e 4095.
    -- REAL -> INTEGER arredonda ao inteiro mais proximo em VHDL.
    FUNCTION quantizar(
        CONSTANT tensao : REAL;
        CONSTANT vref   : REAL
    ) RETURN STD_LOGIC_VECTOR IS
        VARIABLE codigo : INTEGER RANGE 0 TO 4095;
    BEGIN
        IF tensao <= 0.0 THEN
            codigo := 0;
        ELSIF tensao >= vref THEN
            codigo := 4095;
        ELSE
            codigo := INTEGER(4096.0 * tensao / vref);
            IF codigo > 4095 THEN
                codigo := 4095;
            END IF;
        END IF;
        RETURN STD_LOGIC_VECTOR(TO_UNSIGNED(codigo, 12));
    END FUNCTION;
BEGIN
    ASSERT VREF_V > 0.0
        REPORT "ADC128S022_MODEL: VREF_V deve ser positivo"
        SEVERITY FAILURE;

    DOUT <= dout_reg;

    PROCESS(CS, SCLK)
        VARIABLE canal_ativo   : INTEGER RANGE 0 TO 7 := 0;
        VARIABLE comando      : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
        VARIABLE codigo_12    : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
        VARIABLE quedas       : INTEGER RANGE 0 TO 16 := 0;
        VARIABLE subidas      : INTEGER RANGE 0 TO 16 := 0;
        VARIABLE frame_ativo  : BOOLEAN := FALSE;
    BEGIN
        IF falling_edge(CS) THEN
            frame_ativo := TRUE;
            comando := (OTHERS => '0');
            codigo_12 := (OTHERS => '0');
            quedas := 0;
            subidas := 0;
            -- O nivel de DOUT passa a ser valido enquanto CS = 0.
            dout_reg <= '0' AFTER T_EN;

        ELSIF rising_edge(CS) THEN
            IF frame_ativo THEN
                ASSERT quedas = 16
                    REPORT "ADC128S022_MODEL: CS subiu sem 16 descidas de SCLK"
                    SEVERITY ERROR;
                ASSERT subidas = 16
                    REPORT "ADC128S022_MODEL: CS subiu sem 16 subidas de SCLK"
                    SEVERITY ERROR;
            END IF;
            frame_ativo := FALSE;
            dout_reg <= 'Z' AFTER T_DIS;

        ELSIF CS = '0' AND falling_edge(SCLK) THEN
            IF quedas >= 16 THEN
                ASSERT FALSE
                    REPORT "ADC128S022_MODEL: mais de 16 descidas com CS baixo"
                    SEVERITY ERROR;
            ELSE
                -- A entrada analogica e retida na transicao track/hold.
                IF quedas = 3 THEN
                    CASE canal_ativo IS
                        WHEN 0 => codigo_12 := quantizar(AIN0, VREF_V);
                        WHEN 1 => codigo_12 := quantizar(AIN1, VREF_V);
                        WHEN 2 => codigo_12 := quantizar(AIN2, VREF_V);
                        WHEN 3 => codigo_12 := quantizar(AIN3, VREF_V);
                        WHEN 4 => codigo_12 := quantizar(AIN4, VREF_V);
                        WHEN 5 => codigo_12 := quantizar(AIN5, VREF_V);
                        WHEN 6 => codigo_12 := quantizar(AIN6, VREF_V);
                        WHEN 7 => codigo_12 := quantizar(AIN7, VREF_V);
                        WHEN OTHERS => codigo_12 := (OTHERS => '0');
                    END CASE;
                END IF;

                IF quedas < 4 THEN
                    -- Quedas 1 a 4: quatro zeros iniciais.
                    dout_reg <= '0' AFTER T_DACC;
                ELSE
                    -- Quedas 5 a 16: DB11, DB10, ..., DB0.
                    dout_reg <= codigo_12(15 - quedas) AFTER T_DACC;
                END IF;
                quedas := quedas + 1;
            END IF;

        ELSIF CS = '0' AND rising_edge(SCLK) THEN
            IF subidas >= 16 THEN
                ASSERT FALSE
                    REPORT "ADC128S022_MODEL: mais de 16 subidas com CS baixo"
                    SEVERITY ERROR;
            ELSE
                -- Bits transmitidos em DIN: 15 ... 0, MSB primeiro.
                comando(15 - subidas) := DIN;
                subidas := subidas + 1;

                IF subidas = 16 THEN
                    -- ADD2, ADD1, ADD0 sao os bits 13:11.
                    -- O endereco entra em vigor no PROXIMO frame.
                    ASSERT (comando(13) = '0' OR comando(13) = '1') AND
                           (comando(12) = '0' OR comando(12) = '1') AND
                           (comando(11) = '0' OR comando(11) = '1')
                        REPORT "ADC128S022_MODEL: DIN contem X/Z em ADD2:ADD0"
                        SEVERITY ERROR;
                    canal_ativo := TO_INTEGER(UNSIGNED(comando(13 DOWNTO 11)));
                END IF;
            END IF;
        END IF;
    END PROCESS;
END ARCHITECTURE simulacao;

