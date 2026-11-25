-- Autores: Jonatas Medeiros & Guilherme Ferreira
-- ADC128S022 / DE0-Nano: controle SPI usando SCLK como clock
-- do serializador (borda de descida) e desserializador (subida).
-- Clock principal CLK = 50 MHz. MT_ADC = 16 -> SCLK = 1,5625 MHz.
-- Primeira descida de SCLK: LOAD_TX carrega o comando no MOSI.
-- Primeira subida: RX recebe o 1o bit; e assim ate a 16a subida.
-- LOAD_RX e um clear assincrono somente dos regs de recepcao.
-- RX_DONE fica em '1' ate LOAD_RX, e e sincronizado ao CLK 50 MHz.
-- START_SPI espera RX_DONE sincronizado zerar antes de iniciar novo frame.

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY adc_controller IS
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
END ENTITY adc_controller;

ARCHITECTURE comportamento OF adc_controller IS
-- Declaracao dos componentes
    COMPONENT serializador IS
    PORT (
        CLK      : IN  STD_LOGIC; -- SCLK do ADC (nao CLK de 50 MHz)
        RST      : IN  STD_LOGIC; -- reset assincrono neste dominio
        LOAD     : IN  STD_LOGIC; -- deve estar em '1' na 1a descida
        SHIFT_EN : IN  STD_LOGIC; -- habilitacao de nivel enquanto CS = 0
        DATA_IN  : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
        MOSI     : OUT STD_LOGIC;
        TX_DONE  : OUT STD_LOGIC
    );
    END COMPONENT;
    COMPONENT desserializador IS
    PORT (
        CLK       : IN  STD_LOGIC; -- SCLK do ADC (nao CLK de 50 MHz)
        RST       : IN  STD_LOGIC; -- reset assincrono neste dominio
        LOAD      : IN  STD_LOGIC; -- limpa/arma recepcao assincronamente
        SAMPLE_EN : IN  STD_LOGIC; -- habilitacao de nivel enquanto CS = 0
        MISO      : IN  STD_LOGIC; -- DOUT do ADC128S022
        DATA_OUT  : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
        RX_DONE   : OUT STD_LOGIC
    );
    END COMPONENT;

    TYPE state_type IS (IDLE, PREPARE, START_SPI, TRANSFER, FINISH);
    SIGNAL estado : state_type := IDLE;

    SIGNAL ch_atual : NATURAL RANGE 0 TO NUM_CANAIS-1 := 0;
    SIGNAL ch_prox  : NATURAL RANGE 0 TO NUM_CANAIS-1 := 0;
    SIGNAL ch_reg   : NATURAL RANGE 0 TO 7 := 0;
    SIGNAL ch_sel   : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');

    SIGNAL cs_intern   : STD_LOGIC := '1';
    SIGNAL sclk_intern : STD_LOGIC := '1'; -- repouso alto, 1a borda cai
    SIGNAL sclk_en     : STD_LOGIC := '0';
    SIGNAL count_Tadc  : NATURAL RANGE 0 TO MT_ADC-1 := 0;

    SIGNAL load_tx     : STD_LOGIC := '0';
    SIGNAL load_rx     : STD_LOGIC := '0';
    SIGNAL shift_en    : STD_LOGIC;
    SIGNAL sample_en   : STD_LOGIC;

    SIGNAL done_tx     : STD_LOGIC;
    SIGNAL done_rx     : STD_LOGIC;
    SIGNAL rx_done_meta : STD_LOGIC := '0';
    SIGNAL rx_done_sync : STD_LOGIC := '0';
    SIGNAL data_flag   : STD_LOGIC := '0';
    SIGNAL data_din    : STD_LOGIC;
    SIGNAL data_rx     : STD_LOGIC_VECTOR(15 DOWNTO 0);
BEGIN
    ASSERT (MT_ADC >= 8 AND MT_ADC <= 31)
        REPORT "Com CLK=50MHz, MT_ADC deve ficar entre 8 e 31 para SCLK de 0,8 a 3,2 MHz"
        SEVERITY FAILURE;

    -- Clock derivado REGISTRADO; apenas ele alimenta a saida ADC_SCLK
    -- e as portas CLK dos dois componentes SPI.
    PROCESS(CLK)
    BEGIN
        IF rising_edge(CLK) THEN
            IF RST = '1' THEN
                count_Tadc  <= 0;
                sclk_intern <= '1';
            ELSIF sclk_en = '1' THEN
                IF count_Tadc = MT_ADC-1 THEN
                    count_Tadc  <= 0;
                    sclk_intern <= NOT sclk_intern;
                ELSE
                    count_Tadc <= count_Tadc + 1;
                END IF;
            ELSE
                count_Tadc  <= 0;
                sclk_intern <= '1';
            END IF;
        END IF;
    END PROCESS;

    -- Clock domain crossing (RX_DONE: SCLK -> CLK 50 MHz).
    -- RX_DONE permanece alto ate LOAD_RX: nao e um pulso curto.
    PROCESS(CLK)
    BEGIN
        IF rising_edge(CLK) THEN
            IF RST = '1' THEN
                rx_done_meta <= '0';
                rx_done_sync <= '0';
            ELSE
                rx_done_meta <= done_rx;
                rx_done_sync <= rx_done_meta;
            END IF;
        END IF;
    END PROCESS;

    -- As habilitacoes sao NIVEIS (nao pulsos de 20 ns):
    -- o proprio SCLK determina os instantes de deslocamento/captura.
    shift_en  <= NOT cs_intern;
    sample_en <= NOT cs_intern;

    PROCESS(CLK)
        VARIABLE proximo_canal : NATURAL RANGE 0 TO 7;
    BEGIN
        IF rising_edge(CLK) THEN
            IF RST = '1' THEN
                estado    <= IDLE;
                cs_intern <= '1';
                sclk_en   <= '0';
                load_tx   <= '0';
                load_rx   <= '0';
                data_flag <= '0';
                ch_atual  <= 0;
                ch_prox   <= 0;
                ch_reg    <= 0;
                ch_sel    <= (OTHERS => '0');
            ELSE
                data_flag <= '0'; -- pulso de 1 CLK quando amostra valida

                CASE estado IS
                    WHEN IDLE =>
                        cs_intern <= '1';
                        sclk_en   <= '0';
                        load_tx   <= '0';
                        load_rx   <= '0';
                        IF ENABLE = '1' THEN
                            estado <= PREPARE;
                        END IF;

                    WHEN PREPARE =>
                        -- O ADC devolve o canal da transacao anterior;
                        -- este comando escolhe o canal da proxima.
                        IF ch_atual = NUM_CANAIS-1 THEN
                            proximo_canal := 0;
                        ELSE
                            proximo_canal := ch_atual + 1;
                        END IF;
                        ch_prox <= proximo_canal;
                        ch_sel <= "00" &
                                  STD_LOGIC_VECTOR(TO_UNSIGNED(proximo_canal, 3)) &
                                  "00000000000";

                        -- Recepcao limpa mesmo com SCLK estacionado.
                        -- TX_LOAD aguarda a PRIMEIRA descida de SCLK.
                        load_tx <= '1';
                        load_rx <= '1';
                        cs_intern <= '1';
                        sclk_en   <= '0';
                        estado <= START_SPI;

                    WHEN START_SPI =>
                        -- Handshake entre dominios de clock:
                        -- o RX_DONE do frame ANTERIOR deve ser reconhecido
                        -- como zero no dominio de CLK antes de iniciar
                        -- outro frame. LOAD_RX ja foi ativado em PREPARE e
                        -- limpa RX_DONE assincronamente, mas o sincronizador
                        -- leva dois ciclos de CLK para refletir isso.
                        -- Sem esta espera, a FSM poderia encerrar TRANSFER
                        -- imediatamente por um RX_DONE antigo.
                        IF rx_done_sync = '0' THEN
                            cs_intern <= '0';
                            sclk_en   <= '1';
                            estado    <= TRANSFER;
                        END IF;

                    WHEN TRANSFER =>
                        -- No 1o falling_edge(SCLK), TX ve LOAD='1'
                        -- e disponibiliza D15. Desativa LOAD somente
                        -- no clock de 50 MHz SEGUINTE a essa descida.
                        IF load_tx = '1' AND sclk_intern = '0' THEN
                            load_tx <= '0';
                            load_rx <= '0';
                        END IF;

                        -- RX_DONE se torna 1 apos a 16a subida;
                        -- os dois FFs sincronizam ate CLK de 50 MHz.
                        -- SCLK esta alto e para antes da 17a descida.
                        IF rx_done_sync = '1' THEN
                            sclk_en <= '0';
                            estado <= FINISH;
                        END IF;

                    WHEN FINISH =>
                        cs_intern <= '1';
                        sclk_en   <= '0';
                        load_tx   <= '0';
                        load_rx   <= '0';
                        ch_reg    <= ch_atual;
                        ch_atual  <= ch_prox;
                        data_flag <= '1';
                        estado    <= IDLE;
                END CASE;
            END IF;
        END IF;
    END PROCESS;

    U_TX : serializador
        PORT MAP (
            CLK      => sclk_intern,
            RST      => RST,
            LOAD     => load_tx,
            SHIFT_EN => shift_en,
            DATA_IN  => ch_sel,
            MOSI     => data_din,
            TX_DONE  => done_tx
        );

    U_RX : desserializador
        PORT MAP (
            CLK       => sclk_intern,
            RST       => RST,
            LOAD      => load_rx,
            SAMPLE_EN => sample_en,
            MISO      => ADC_DOUT,
            DATA_OUT  => data_rx,
            RX_DONE   => done_rx
        );

    ADC_CS     <= cs_intern;
    ADC_SCLK   <= sclk_intern;
    ADC_DIN    <= data_din;
    DATA_OUT   <= data_rx;
    CHANNEL_ID <= ch_reg;
    DATA_VALID <= data_flag;
END ARCHITECTURE comportamento;

