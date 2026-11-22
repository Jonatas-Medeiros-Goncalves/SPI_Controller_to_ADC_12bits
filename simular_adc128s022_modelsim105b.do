# Simulacao do ADC128S022 + controlador usando o SCLK nos registradores
# ModelSim 10.5b. Execute na pasta que contem os 5 arquivos .vhd.
# Compila arquivos com -2008 (evita recursos incompatíveis com VHDL-93).
vlib work
vmap work work
vcom -2008 serializador.vhd
vcom -2008 desserializador.vhd
vcom -2008 adc_controller.vhd
vcom -2008 adc128s022_model.vhd
vcom -2008 tb_adc128s022_integrado.vhd
vsim -t 1ps work.tb_adc128s022_integrado

add wave sim:/tb_adc128s022_integrado/CLK
add wave sim:/tb_adc128s022_integrado/ADC_CS
add wave sim:/tb_adc128s022_integrado/ADC_SCLK
add wave sim:/tb_adc128s022_integrado/ADC_DIN
add wave sim:/tb_adc128s022_integrado/ADC_DOUT
add wave -radix unsigned sim:/tb_adc128s022_integrado/CHANNEL_ID
add wave -radix hexadecimal sim:/tb_adc128s022_integrado/DATA_OUT
add wave sim:/tb_adc128s022_integrado/DATA_VALID
add wave sim:/tb_adc128s022_integrado/DUT/load_tx
add wave sim:/tb_adc128s022_integrado/DUT/load_rx
add wave sim:/tb_adc128s022_integrado/DUT/done_rx
add wave sim:/tb_adc128s022_integrado/VIN0
add wave sim:/tb_adc128s022_integrado/VIN1
add wave sim:/tb_adc128s022_integrado/VIN2
add wave sim:/tb_adc128s022_integrado/VIN3
add wave sim:/tb_adc128s022_integrado/VIN4
add wave sim:/tb_adc128s022_integrado/VIN5
add wave sim:/tb_adc128s022_integrado/VIN6
add wave sim:/tb_adc128s022_integrado/VIN7

run 140 us
wave zoom full
