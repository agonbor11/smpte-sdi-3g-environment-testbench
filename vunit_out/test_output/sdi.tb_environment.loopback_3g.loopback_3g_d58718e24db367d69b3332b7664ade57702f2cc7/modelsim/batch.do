onerror {quit -code 1}
source "/home/usuario/Escritorio/trabajo_del_equipo/python/verilog/environment/vunit_out/test_output/sdi.tb_environment.loopback_3g.loopback_3g_d58718e24db367d69b3332b7664ade57702f2cc7/modelsim/common.do"
set failed [vunit_load]
if {$failed} {quit -code 1}
set failed [vunit_run]
if {$failed} {quit -code 1}
quit -code 0
