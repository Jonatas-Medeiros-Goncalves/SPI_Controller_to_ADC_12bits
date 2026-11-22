# Checklist para implementação física na DE0-Nano

[← README](../README.md) · [Validação funcional](validacao.md)

A simulação VHDL demonstra a lógica digital do controlador com o **modelo comportamental** do ADC128S022. Para declarar a implementação **validada em hardware**, ainda é necessário realizar as etapas abaixo.

## 1. Preparar o projeto no Quartus

- [ ] Selecionar o dispositivo exato da DE0-Nano usado no laboratório.
- [ ] Adicionar somente os arquivos de `rtl/` à síntese (o ADC comportamental e o testbench são exclusivamente para simulação).
- [ ] Definir `ad_controller` como entidade *top-level* ou instanciá-la no módulo principal.
- [ ] Declarar o clock de 50 MHz e as restrições de temporização adequadas.
- [ ] Configurar os pinos `ADC_CS`, `ADC_SCLK`, `ADC_DIN` e `ADC_DOUT` conforme o manual **da revisão específica** da placa.

## 2. Rever os domínios de clock

Esta implementação usa `sclk_intern` **como clock interno** do serializador (borda de descida) e do desserializador (borda de subida), além de enviá-lo ao ADC.

- [ ] Modelar SCLK como **clock gerado** nas restrições SDC e verificar sua relação com os 50 MHz.
- [ ] Verificar o reconhecimento do clock gerado pelo TimeQuest, incluindo caminhos entre bordas opostas.
- [ ] Avaliar o roteamento de clock gerado e se o dispositivo implementa o circuito com os recursos de clock adequados.
- [ ] Verificar setup/hold no caminho físico ADC ↔ FPGA com tempos e limites do datasheet.
- [ ] Revisar a passagem do sinal `RX_DONE` de SCLK para 50 MHz; o código utiliza dois registradores sincronizadores.
- [ ] Analisar os sinais `LOAD_RX`/`LOAD_TX` e eventuais requisitos de recuperação/remoção quando usados nos registradores dos domínios derivados.

**Não considerar o projeto fisicamente validado apenas porque a simulação funcional passou.**

## 3. Teste de bancada sugerido

1. Colocar a placa em reset e verificar `ADC_CS=1`, `ADC_SCLK=1` em repouso.
2. Habilitar uma varredura de apenas um canal inicialmente.
3. Monitorar `DATA_VALID` e conferir `CHANNEL_ID`.
4. Aplicar uma tensão conhecida **dentro da faixa permitida pelo ADC e pela placa**.
5. Comparar o valor digital obtido com a referência analógica efetivamente utilizada no hardware.
6. Repetir com vários canais e transições de tensão.

## 4. Critério de conclusão

Só marcar como completo quando a implementação estiver sintetizada, sem violações relevantes de temporização, e houver resultados reprodutíveis com o ADC físico.

**Referências:** [ADC128S022 — Texas Instruments](https://www.ti.com/product/ADC128S022); manual da DE0-Nano correspondente à placa usada.
