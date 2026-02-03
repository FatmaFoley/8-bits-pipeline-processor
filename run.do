vlib work
vlog top.v testbench.v
vsim -voptargs=+acc work.testbench

add wave -divider "=== GLOBAL ==="
add wave testbench.CLK
add wave testbench.RESET_IN
add wave testbench.OUT_PORT
add wave testbench.IN_PORT
add wave testbench.INTR_IN
add wave testbench.processor.fetch_stage.pcF
add wave testbench.processor.mem_stage.pcM

add wave -divider "=== PIPELINE ==="
add wave testbench.processor.fetch_stage.instrF
add wave testbench.processor.fetch_stage.instrD
add wave testbench.processor.execute_stage.instrEX
add wave testbench.processor.execute_stage.instrM
add wave testbench.processor.instrWB

add wave -divider "=== REGFILE ==="
add wave testbench.processor.decode_stage.RF.regfile
add wave testbench.processor.decode_stage.CCR_Reg.ccr_out
add wave testbench.processor.decode_stage.CU.loop_en

add wave -divider "=== M ==="
add wave testbench.processor.mem_stage.Data_Mem.mem
add wave testbench.processor.mem_stage.D_mem_wenM

run -all
#quit -sim

