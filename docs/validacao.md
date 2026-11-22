# Validação funcional no ModelSim

[← README](../README.md) · [Guia de arquivos](guia-arquivos.md) · [Protocolo SPI](protocolo-spi.md) · [Implementação física →](implementacao-fisica.md)

## Testbench, modelo e script: qual é a diferença?

- **Testbench (`tb_...vhd`):** é o programa de teste que gera estímulos e confere automaticamente se o resultado está correto. O prefixo `tb` é uma convenção para *testbench*.
- **Modelo comportamental (`adc128s022_model.vhd`):** imita o circuito integrado do ADC durante a simulação. Não é um testbench isolado: é um componente usado **dentro** do testbench integrado.
- **Script (`.do`):** fornece comandos ao ModelSim para compilar, carregar, exibir e executar o teste.

Consulte o [tutorial de arquivos e terminologias](guia-arquivos.md) para visualizar como essas peças se relacionam.

## Ferramentas e arquivos

- **ModelSim 10.5b**, compilação VHDL-2008 (`vcom -2008`)
- `sim/adc128s022_model.vhd`: modelo comportamental, com 8 entradas `REAL` e tempos simulados de DOUT
- `sim/tb_adc128s022_integrado.vhd`: testbench que verifica canal e amostra recebida
- `sim/simular_modelsim.do`: compilação, sinais de onda e execução

## Execução

No console ModelSim, com o **diretório atual na raiz do repositório**:

```tcl
do sim/simular_modelsim.do
```

O testbench inclui `ASSERT` para validar `CHANNEL_ID`, `DATA_OUT`, espaçamento mínimo entre dois `DATA_VALID` e retorno de CS/SCLK ao repouso após desabilitação. O modelo do ADC também verifica que CS não sobe antes das **16 descidas e 16 subidas** de SCLK.

## Resultado registrado

Resultado informado após a correção do handshake, em 22/11/2026. São **10 frames sem mensagens de erro** no log apresentado:

| Frame | Canal | Dado decimal | Hexadecimal |
|---:|---:|---:|---|
| 1 | IN0 | 291 | `0x0123` |
| 2 | IN1 | 1110 | `0x0456` |
| 3 | IN2 | 1929 | `0x0789` |
| 4 | IN3 | 2748 | `0x0ABC` |
| 5 | IN4 | 3567 | `0x0DEF` |
| 6 | IN5 | 4095 | `0x0FFF` |
| 7 | IN6 | 1 | `0x0001` |
| 8 | IN7 | 2080 | `0x0820` |
| 9 | IN0 | 801 | `0x0321` |
| 10 | IN1 | 1110 | `0x0456` |

A alteração de IN0, de 291 para 801, demonstra que a simulação reconheceu uma nova tensão de entrada após uma volta completa.

![Forma de onda de simulação](images/ondas_modelsim.png)

## Como reconhecer um teste aprovado

- O *Transcript* deve mostrar `Frame 1 OK` até `Frame 10 OK`.
- Não deve haver `** Error:` nem falha por *timeout*.
- Cada frame deve manter `ADC_CS` em nível baixo durante exatamente 16 ciclos de `ADC_SCLK`.
- `CHANNEL_ID` e `DATA_OUT` devem atualizar de modo coerente com `DATA_VALID`.
- O testbench encerra sua sequência após conferir a parada com `ENABLE=0`.

> O arquivo de simulação foi organizado para o GitHub, mas **não executei uma nova rodada do ModelSim após reorganizar os caminhos**. O resultado acima é o log previamente apresentado para esta versão lógica do controlador.

## Testes ainda recomendados

| Teste | Objetivo | Situação |
|---|---|---|
| Reset durante `TRANSFER` | Evitar travamento ou frame parcialmente válido | Não demonstrado |
| `ENABLE=0` durante o frame | Confirmar término normal do frame e parada | Verificação simples no testbench; ampliar cenários |
| `NUM_CANAIS` em 1 e 3 | Confirmar limites e retorno circular | Não demonstrado nesta sequência |
| Reinicialização com ADC já ativo | Verificar alinhamento do pipeline de canais | Não demonstrado |
| Síntese/TimeQuest | Verificar clocks, caminhos e restrições | Pendente |
| Hardware DE0-Nano | Validar tensões e temporização física | Pendente |

**Critério de encerramento da etapa atual:** validação **funcional básica em simulação**. Isso não equivale a validar o circuito na FPGA.
