# SPI Controller for ADC128S022 | DE0-Nano

Controlador **SPI em VHDL** para aquisição sequencial de até **oito canais** do conversor **ADC128S022**, presente na placa **Terasic DE0-Nano**. O projeto contém a lógica digital destinada à FPGA, um **modelo comportamental do ADC** e um **testbench integrado** executado no **ModelSim 10.5b**.

> **Status:** validação funcional realizada anteriormente com 10 frames e oito canais, incluindo mudança de entrada analógica simulada. A versão reorganizada nesta pasta troca **apenas nomes de entidade e forma de instanciação**; sua simulação deve ser executada novamente após a atualização. **Síntese, timing no TimeQuest e teste no hardware ainda estão pendentes.**

## Visão geral

```mermaid
flowchart LR
    CLK["CLK 50 MHz"] --> CTRL["adc_controller<br/>FSM + divisor de clock"]
    CTRL -->|"SCLK, LOAD_TX"| TX["serializador<br/>borda de descida"]
    CTRL -->|"SCLK, LOAD_RX"| RX["desserializador<br/>borda de subida"]
    CTRL -->|"CS, SCLK"| ADC["ADC128S022<br/>8 canais, 12 bits"]
    TX -->|"DIN / MOSI"| ADC
    ADC -->|"DOUT / MISO"| RX
    RX -->|"DATA_OUT, RX_DONE"| CTRL
    CTRL --> OUT["DATA_OUT + CHANNEL_ID + DATA_VALID"]
```

A FPGA gera o clock SPI (`ADC_SCLK`) a partir do clock principal de 50 MHz. O ADC recebe um comando de seleção de canal em `DIN`, devolvendo em `DOUT` uma palavra de **16 bits**: quatro zeros iniciais e os **12 bits válidos**. O endereço transmitido em um frame define o canal convertido **no frame seguinte**.

## Nomes dos arquivos

Os módulos usam os nomes originais **sem o sufixo `_sclk`**:
`adc_controller.vhd`, `serializador.vhd` e `desserializador.vhd`.
O sufixo foi utilizado indevidamente em uma versão anterior do pacote.
O script `simular_modelsim.do` procura esses nomes em `rtl/`, `sim/` e na **raiz** do repositório.

## Organização do repositório

```text
.
├── README.md
├── rtl/
│   ├── adc_controller.vhd
│   ├── serializador.vhd
│   └── desserializador.vhd
├── sim/
│   ├── adc128s022_model.vhd
│   ├── tb_adc128s022_integrado.vhd
│   └── simular_modelsim.do
├── quartus/
│   ├── [Top-Level VHDL existente na pasta]
│   └── [CSV de atribuicoes do Pin Planner]
└── docs/
    ├── guia-arquivos.md
    ├── arquitetura.md
    ├── protocolo-spi.md
    ├── validacao.md
    └── implementacao-fisica.md
```

### O que faz cada arquivo?

| Arquivo | Papel | Sintetizável? |
|---|---|---|
| [`rtl/adc_controller.vhd`](rtl/adc_controller.vhd) | Entidade `adc_controller`: FSM, comando de canais, `CS`, `SCLK` e sincronização de `RX_DONE` | Sim, sujeito à validação de timing |
| [`rtl/serializador.vhd`](rtl/serializador.vhd) | Entidade `serializador`: apresenta os 16 bits do comando em `DIN`, nas descidas de SCLK | Sim |
| [`rtl/desserializador.vhd`](rtl/desserializador.vhd) | Entidade `desserializador`: captura `DOUT` nas subidas de SCLK e gera `RX_DONE` | Sim |
| [`sim/adc128s022_model.vhd`](sim/adc128s022_model.vhd) | **Modelo do ADC**: emula os oito canais e os tempos digitais da interface; recebe tensões do tipo `REAL` | **Não** |
| [`sim/tb_adc128s022_integrado.vhd`](sim/tb_adc128s022_integrado.vhd) | **Testbench (`tb`)**: conecta controlador e ADC simulado, aplica tensões e confere as respostas por `ASSERT` | **Não** |
| [`sim/simular_modelsim.do`](sim/simular_modelsim.do) | **Script ModelSim**: compila, inicia a simulação e adiciona sinais à janela Wave | Não se aplica |
| [`quartus/`](quartus/) — Top-Level | Arquivo VHDL de integração para utilização da DE0-Nano; instancia o controlador e estabelece as conexões externas da FPGA | Sim |
| [`quartus/`](quartus/) — CSV do Pin Planner | Tabela exportada do Quartus com as atribuições de pinos, para importar ao criar outro projeto | Não se aplica |

**Terminologia:** `tb` significa *testbench*, `DUT` significa *Device Under Test* (o controlador sob teste) e `U_ADC` é a instância do ADC virtual. O **modelo do ADC não é o testbench**: ele é um componente de simulação usado *pelo* testbench.

## Implementação na DE0-Nano com Quartus Prime

A pasta [`quartus/`](quartus/) reúne **dois arquivos de apoio à implementação física**: o **Top-Level** do projeto e um arquivo **CSV com as atribuições do Pin Planner**. Eles tornam mais simples recriar o projeto no Quartus Prime sem precisar configurar manualmente todos os sinais da placa.

> **Atenção:** o CSV facilita a configuração dos pinos, mas **não é um projeto Quartus completo**. O arquivo `.qsf` do projeto é gerado/atualizado pelo Quartus após a importação. Os arquivos da pasta `sim/` são para o ModelSim e **não devem ser usados como Top-Level sintetizável**.

### Passo 1 — Criar um projeto Quartus

1. Abra o **Quartus Prime** e selecione **File → New Project Wizard**.
2. Escolha uma pasta de trabalho e um nome para o projeto.
3. Configure a **Top-Level Entity** com o nome da `ENTITY` declarada no arquivo VHDL da pasta `quartus/` (não necessariamente o nome do arquivo).
4. Selecione a FPGA da DE0-Nano: **Cyclone IV E — EP4CE22F17C6N**.
5. Finalize a criação do projeto.

### Passo 2 — Adicionar os arquivos VHDL

Em **Project → Add/Remove Files in Project**, adicione:

- Os três módulos sintetizáveis de `rtl/`: `adc_controller.vhd`, `serializador.vhd` e `desserializador.vhd`.
- O **arquivo VHDL Top-Level** já incluído em `quartus/`.

O Top-Level **instancia** o `adc_controller` e conecta sua interface aos sinais externos da DE0-Nano. Dentro do controlador estão as instâncias dos módulos de serialização e desserialização. Assim, a hierarquia de síntese é:

```mermaid
flowchart TD
    TOP["Top-Level (quartus/)"] --> CTRL["adc_controller (rtl/)"]
    CTRL --> TX["serializador (rtl/)"]
    CTRL --> RX["desserializador (rtl/)"]
    TOP --> FPGA["Portas físicas da DE0-Nano"]
```

Após adicionar os arquivos, confirme em **Assignments → Settings → General** que a *Top-Level Entity* é a entidade do VHDL em `quartus/`. Execute **Processing → Start → Start Analysis & Elaboration** para verificar se os módulos e as portas são reconhecidos.

### Passo 3 — Importar o CSV do Pin Planner

1. Na janela principal do Quartus, selecione **Assignments → Import Assignments**.
2. Escolha o **arquivo `.csv` existente em `quartus/`** e confirme.
3. Abra **Assignments → Pin Planner** para conferir as atribuições importadas.
4. Verifique se os **nomes das portas do Top-Level** correspondem aos nomes dos sinais no CSV e se não há conflitos de localização.

O objetivo é **evitar a atribuição manual repetitiva** dos pinos. Uma importação concluída pode apresentar a mensagem `Import completed` indicando quantas atribuições foram lidas e gravadas. Isso **não garante**, por si só, que o projeto esteja corretamente configurado: ainda é necessário verificar o Pin Planner e compilar.

**Pinos de referência da DE0-Nano** (devem corresponder aos nomes utilizados no seu Top-Level e ao CSV):

| Função | Pino físico FPGA |
|---|---|
| Oscilador de 50 MHz | `PIN_R8` |
| `ADC_CS_N` | `PIN_A10` |
| `ADC_SCLK` | `PIN_B14` |
| `ADC_SADDR` (DIN/MOSI do ADC) | `PIN_B10` |
| `ADC_SDAT` (DOUT/MISO do ADC) | `PIN_A9` |

*Fonte dos pinos: DE0-Nano User Manual, seção 3.6 (ADC) e seção 3.8 (clock). Os nomes acima são os nomes da placa e podem não coincidir exatamente com os nomes das portas do seu VHDL.*

### Passo 4 — Compilar e verificar o projeto

1. Execute **Processing → Start Compilation**.
2. Confira mensagens de erro e avisos, especialmente atribuições de pinos e sinais não conectados.
3. Analise a temporização no **TimeQuest**, considerando o clock principal de 50 MHz e o SCLK gerado pelo controlador.
4. Depois da compilação bem-sucedida e da verificação das restrições, use o **Programmer** para carregar o `.sof` na DE0-Nano e realizar os testes físicos.

**Limitação atual:** os dez frames aprovados no ModelSim demonstram o funcionamento **em simulação**; não substituem o fechamento de temporização e os testes com o ADC real.

---

## Como executar no ModelSim 10.5b

Na pasta raiz do repositório, abra o ModelSim e execute na janela **Transcript**:

```tcl
do sim/simular_modelsim.do
```

O script usa `vcom -2008` para compilar, nesta ordem:

1. Serializador e desserializador (`rtl/`).
2. Controlador principal (`rtl/`).
3. Modelo comportamental do ADC (`sim/`).
4. Testbench integrado (`sim/`).

Depois carrega o testbench, apresenta as principais ondas e executa **140 µs**. A biblioteca é criada em `modelsim_work/` **dentro do projeto** para evitar a utilização de uma biblioteca `work` antiga ou mapeada para o diretório do Intel FPGA. **Não envie `modelsim_work/` ao GitHub**: é um produto da compilação.

O comando do script `vsim work.tb_adc128s022_integrado` usa `work` **apenas para indicar a biblioteca da simulação**. No VHDL, as instâncias foram escritas por `COMPONENT` e `PORT MAP`, sem `ENTITY work...`.

### O que observar

Os sinais principais são `ADC_CS`, `ADC_SCLK`, `ADC_DIN`, `ADC_DOUT`, `DATA_OUT`, `CHANNEL_ID` e `DATA_VALID`. Para cada transação:

- `CS` fica baixo durante **16 ciclos** de SCLK.
- O serializador opera nas **descidas**; o desserializador captura nas **subidas**.
- `DATA_VALID` sinaliza que `DATA_OUT` e `CHANNEL_ID` correspondem à amostra concluída.
- `RX_DONE` é sincronizado para o clock de 50 MHz, evitando encerrar prematuramente o frame seguinte.

No teste integrado, a sequência esperada é:

| Frame | Canal | Código decimal | Hexadecimal |
|---|---:|---:|---|
| 1 | 0 | 291 | `0123` |
| 2 | 1 | 1110 | `0456` |
| 3 | 2 | 1929 | `0789` |
| 4 | 3 | 2748 | `0ABC` |
| 5 | 4 | 3567 | `0DEF` |
| 6 | 5 | 4095 | `0FFF` |
| 7 | 6 | 1 | `0001` |
| 8 | 7 | 2080 | `0820` |
| 9 | 0 | 801 | `0321` (IN0 atualizado) |
| 10 | 1 | 1110 | `0456` |

Esse é o **resultado de referência do teste anterior**, não uma afirmação de que o pacote reorganizado já foi executado no ModelSim.

## Interface do controlador

| Porta/genérico | Função |
|---|---|
| `CLK` | Clock principal da FPGA, 50 MHz |
| `RST` | Reset ativo alto |
| `ENABLE` | Habilita a varredura contínua |
| `ADC_CS` | Seleção do conversor, ativa em zero |
| `ADC_SCLK` | Clock SPI (repouso em nível alto) |
| `ADC_DIN` | Comando enviado ao ADC |
| `ADC_DOUT` | Resposta serial recebida do ADC |
| `DATA_OUT[15:0]` | Quatro zeros e código de 12 bits |
| `CHANNEL_ID` | Identificação do canal da amostra atual |
| `DATA_VALID` | Pulso de validação da amostra |
| `NUM_CANAIS` | Genérico: 1–8 canais (no testbench, 8) |
| `MT_ADC` | Genérico: quantidade de ciclos do CLK por **meio período** de SCLK (16 por padrão) |

Com `CLK = 50 MHz` e `MT_ADC = 16`, a frequência nominal é **1,5625 MHz**, e um frame de 16 ciclos dura **10,24 µs**, sem contar o intervalo entre transações.

## Instanciação por componentes: qual a diferença?

O controlador declara `COMPONENT serializador` e `COMPONENT desserializador`, conectando-os com `PORT MAP`. O testbench declara `COMPONENT adc_controller` e `COMPONENT adc128s022_model`.

Isso **não altera o circuito** em relação à instanciação direta `ENTITY work...`, desde que nomes e interfaces estejam consistentes e todas as entidades/arquiteturas estejam compiladas. O nome padronizado neste repositório é **`adc_controller`**, inclusive na declaração `ENTITY adc_controller IS`, evitando o desencontro anterior entre `ad_controller` e `adc_controller`.

## Documentação e limitações

- [Guia dos arquivos e termos](docs/guia-arquivos.md)
- [Arquitetura e FSM](docs/arquitetura.md)
- [Protocolo SPI](docs/protocolo-spi.md)
- [Testes e critérios de validação](docs/validacao.md)
- [Validação física pendente](docs/implementacao-fisica.md)

A implementação usa **SCLK como clock dos registradores** e contém uma travessia de domínio de clock (`RX_DONE` de SCLK para 50 MHz). É indispensável conferir restrições, rotas de clock e *setup/hold* no Quartus/TimeQuest antes de declarar o hardware validado.

**Referência principal:** [Texas Instruments — ADC128S022](https://www.ti.com/product/ADC128S022).
