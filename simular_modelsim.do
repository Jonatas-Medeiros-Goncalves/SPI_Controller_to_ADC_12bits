# ADC128S022 - DE0-Nano | ModelSim 10.5b
# Execute da raiz do projeto: do sim/simular_modelsim.do
# Tambem aceita os VHDLs na raiz, sem as pastas rtl/ e sim/.
# A declaracao COMPONENT e os PORT MAP ficam nos arquivos VHDL, nao no .do.

# Pasta que contem este .do e raiz logica do projeto.
set script_dir [file normalize [file dirname [info script]]]
if {[file tail $script_dir] eq "sim"} {
    set raiz [file normalize [file join $script_dir ..]]
} else {
    set raiz $script_dir
}

# Biblioteca local independente das instalacoes anteriores do ModelSim.
catch {quit -sim}
set lib_dir [file join $raiz modelsim_work]
if {![file isdirectory $lib_dir]} {
    vlib $lib_dir
}
vmap work $lib_dir

# Busca o nome exato em rtl/, sim/ ou na raiz do repositorio.
proc encontrar_fonte {raiz nome} {
    foreach pasta [list [file join $raiz rtl] [file join $raiz sim] $raiz] {
        set caminho [file join $pasta $nome]
        if {[file isfile $caminho]} { return $caminho }
    }
    error "Arquivo nao encontrado: $nome. Verifique a pasta do projeto."
}

# Ordem de compilacao: TX, RX, controlador, modelo do ADC, testbench.
foreach nome {
    serializador.vhd
    desserializador.vhd
    adc_controller.vhd
    adc128s022_model.vhd
    tb_adc128s022_integrado.vhd
} {
    set fonte [encontrar_fonte $raiz $nome]
    puts "COMPILANDO: $fonte"
    if {[catch {vcom -2008 $fonte} mensagem]} {
        error "Falha compilando $nome: $mensagem"
    }
}

# Este work. identifica a biblioteca do testbench, nao uma
# instancia VHDL direta do tipo ENTITY work.alguma_coisa.
vsim -t 1ps work.tb_adc128s022_integrado
view wave

add wave -divider "SPI externo"
add wave sim:/tb_adc128s022_integrado/CLK
add wave sim:/tb_adc128s022_integrado/ADC_CS
add wave sim:/tb_adc128s022_integrado/ADC_SCLK
add wave sim:/tb_adc128s022_integrado/ADC_DIN
add wave sim:/tb_adc128s022_integrado/ADC_DOUT

add wave -divider "Dados e validacao"
add wave -radix unsigned sim:/tb_adc128s022_integrado/CHANNEL_ID
add wave -radix hexadecimal sim:/tb_adc128s022_integrado/DATA_OUT
add wave sim:/tb_adc128s022_integrado/DATA_VALID

add wave -divider "FSM e handshake"
add wave sim:/tb_adc128s022_integrado/DUT/estado
add wave sim:/tb_adc128s022_integrado/DUT/sclk_en
add wave sim:/tb_adc128s022_integrado/DUT/load_tx
add wave sim:/tb_adc128s022_integrado/DUT/load_rx
add wave sim:/tb_adc128s022_integrado/DUT/done_rx
add wave sim:/tb_adc128s022_integrado/DUT/rx_done_sync

run 140 us
wave zoom full
puts "SIMULACAO CONCLUIDA. Verifique o Transcript: sem ASSERT ERROR."
