
proc vunit_help {} {
    puts {List of VUnit commands:}
    puts {vunit_help}
    puts {  - Prints this help}
    puts {vunit_load [vsim_extra_args]}
    puts {  - Load design with correct generics for the test}
    puts {  - Optional first argument are passed as extra flags to vsim}
    puts {vunit_user_init}
    puts {  - Re-runs the user defined init file}
    puts {vunit_run}
    puts {  - Run test, must do vunit_load first}
    puts {vunit_compile}
    puts {  - Recompiles the source files}
    puts {vunit_restart}
    puts {  - Recompiles the source files}
    puts {  - and re-runs the simulation if the compile was successful}
}

proc vunit_run {} {
    if {[catch {_vunit_run} failed_or_err]} {
        echo $failed_or_err
        return true;
    }

    if {![is_test_suite_done]} {
        echo
        echo "Test Run Failed!"
        echo
        _vunit_run_failure;
        return true;
    }

    return false;
}

proc _vunit_source_init_files_after_load {} {
    return 0
}
proc _vunit_source_init_files_before_run {} {
    return 0
}

proc vunit_load {{vsim_extra_args ""}} {
    set vsim_failed [catch {
        eval vsim ${vsim_extra_args} {-modelsimini /home/usuario/Escritorio/trabajo_del_equipo/python/verilog/environment/vunit_out/modelsim/modelsim.ini -wlf {/home/usuario/Escritorio/trabajo_del_equipo/python/verilog/environment/vunit_out/test_output/sdi.tb_environment.loopback_3g.loopback_3g_d58718e24db367d69b3332b7664ade57702f2cc7/modelsim/vsim.wlf} -quiet -t ps -onfinish stop  -g/tb_environment/g_txdata=/home/usuario/Escritorio/trabajo_del_equipo/python/verilog/environment/tx_txdata_sim.hex -g/tb_environment/g_out_y=out_rx_y.hex -g/tb_environment/g_out_c=out_rx_c.hex -g/tb_environment/g_out_tx=out_tx_environment.hex -g/tb_environment/g_out_diag1=out_tx_ds1a_diag.hex -g/tb_environment/g_out_diag2=out_tx_ds2a_diag.hex -g/tb_environment/g_out_validation_y=out_validation_rx_y.hex -g/tb_environment/g_out_validation_c=out_validation_rx_c.hex -g/tb_environment/output_path=/home/usuario/Escritorio/trabajo_del_equipo/python/verilog/environment/vunit_out/test_output/sdi.tb_environment.loopback_3g.loopback_3g_d58718e24db367d69b3332b7664ade57702f2cc7/ -g/tb_environment/runner_cfg={"active python runner : true,enabled_test_cases : loopback_3g,output path : /home/usuario/Escritorio/trabajo_del_equipo/python/verilog/environment/vunit_out/test_output/sdi.tb_environment.loopback_3g.loopback_3g_d58718e24db367d69b3332b7664ade57702f2cc7/,tb path : /home/usuario/Escritorio/trabajo_del_equipo/python/verilog/environment/,use_color : true"} sdi.tb_environment   -L vunit_lib -L sdi}
    }]

    if {${vsim_failed}} {
       echo Command 'vsim ${vsim_extra_args} -modelsimini /home/usuario/Escritorio/trabajo_del_equipo/python/verilog/environment/vunit_out/modelsim/modelsim.ini -wlf {/home/usuario/Escritorio/trabajo_del_equipo/python/verilog/environment/vunit_out/test_output/sdi.tb_environment.loopback_3g.loopback_3g_d58718e24db367d69b3332b7664ade57702f2cc7/modelsim/vsim.wlf} -quiet -t ps -onfinish stop  -g/tb_environment/g_txdata=/home/usuario/Escritorio/trabajo_del_equipo/python/verilog/environment/tx_txdata_sim.hex -g/tb_environment/g_out_y=out_rx_y.hex -g/tb_environment/g_out_c=out_rx_c.hex -g/tb_environment/g_out_tx=out_tx_environment.hex -g/tb_environment/g_out_diag1=out_tx_ds1a_diag.hex -g/tb_environment/g_out_diag2=out_tx_ds2a_diag.hex -g/tb_environment/g_out_validation_y=out_validation_rx_y.hex -g/tb_environment/g_out_validation_c=out_validation_rx_c.hex -g/tb_environment/output_path=/home/usuario/Escritorio/trabajo_del_equipo/python/verilog/environment/vunit_out/test_output/sdi.tb_environment.loopback_3g.loopback_3g_d58718e24db367d69b3332b7664ade57702f2cc7/ -g/tb_environment/runner_cfg={"active python runner : true,enabled_test_cases : loopback_3g,output path : /home/usuario/Escritorio/trabajo_del_equipo/python/verilog/environment/vunit_out/test_output/sdi.tb_environment.loopback_3g.loopback_3g_d58718e24db367d69b3332b7664ade57702f2cc7/,tb path : /home/usuario/Escritorio/trabajo_del_equipo/python/verilog/environment/,use_color : true"} sdi.tb_environment   -L vunit_lib -L sdi' failed
       echo Bad flag from vsim_extra_args?
       return true
    }

    if {[_vunit_source_init_files_after_load]} {
        return true
    }

    global BreakOnAssertion
    set BreakOnAssertion 2

    global NumericStdNoWarnings
    set NumericStdNoWarnings 0

    global StdArithNoWarnings
    set StdArithNoWarnings 0

    
    return false
}

proc is_test_suite_done {} {
    set fd [open "/home/usuario/Escritorio/trabajo_del_equipo/python/verilog/environment/vunit_out/test_output/sdi.tb_environment.loopback_3g.loopback_3g_d58718e24db367d69b3332b7664ade57702f2cc7/vunit_results" "r"]
    set contents [read $fd]
    close $fd
    set lines [split $contents "
"]
    foreach line $lines {
        if {$line=="test_suite_done"} {
           return true;
        }
    }

    return false;
}


proc _vunit_run_failure {} {
    catch {
        # tb command can fail when error comes from pli
        echo "Stack trace result from 'tb' command"
        echo [tb]
        echo
        echo "Surrounding code from 'see' command"
        echo [see]
    }
}

proc _vunit_run {} {
    if {[_vunit_source_init_files_before_run]} {
        return true
    }

    proc on_break {} {
        resume
    }
    onbreak {on_break}

    run -all
}

proc _vunit_sim_restart {} {
    restart -f
}

proc vunit_compile {} {
    set cmd_show {/home/usuario/Escritorio/trabajo_del_equipo/python/venv/bin/python3 -u run_tb_environment.py --compile}
    puts "Re-compiling using command ${cmd_show}"

    set chan [open |[list {/home/usuario/Escritorio/trabajo_del_equipo/python/venv/bin/python3} {-u} {-c} {import sys;import subprocess;exit(subprocess.call(['/home/usuario/Escritorio/trabajo_del_equipo/python/venv/bin/python3', '-u', 'run_tb_environment.py', '--compile'], cwd='/home/usuario/Escritorio/trabajo_del_equipo/python/verilog/environment', bufsize=0, universal_newlines=True, stdout=sys.stdout, stderr=sys.stdout))}] r]

    while {[gets $chan line] >= 0} {
        puts $line
    }

    if {[catch {close $chan} error_msg]} {
        puts "Re-compile failed"
        puts ${error_msg}
        return true
    } else {
        puts "Re-compile finished"
        return false
    }
}

proc vunit_restart {} {
    if {![vunit_compile]} {
        _vunit_sim_restart
        vunit_run
    }
}
