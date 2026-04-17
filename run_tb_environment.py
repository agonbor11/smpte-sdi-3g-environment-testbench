#!/usr/bin/env python3
"""
run_tb_environment.py — Runner VUnit para tb_environment.sv
Loopback RX -> TX + instancia de validación que decodifica de nuevo el TX:
  tx_txdata_sim.hex -> dut.RX -> dut.TX -> validation.RX

Uso:
  export VUNIT_SIMULATOR=modelsim
  python run_tb_environment.py
  python run_tb_environment.py --gui

Entradas:
  tx_txdata_sim.hex          ← stream SDI 20 bits/ciclo

Salidas (en vunit_out/test_output/.../):
  out_rx_y.hex               ← rx_ds1a — Y decodificada por RX principal
  out_rx_c.hex               ← rx_ds2a — C decodificada por RX principal
  out_tx_environment.hex     ← tx_txdata — stream re-codificado por TX
  out_tx_ds1a_diag.hex       ← tx_ds1a_out — Y pre-scrambler
  out_tx_ds2a_diag.hex       ← tx_ds2a_out — C pre-scrambler
  out_validation_rx_y.hex    ← val_rx_ds1a — Y re-decodificada por validation
  out_validation_rx_c.hex    ← val_rx_ds2a — C re-decodificada por validation
"""

import sys
from pathlib import Path

ROOT        = Path(__file__).parent.resolve()       # .../python/verilog/environment/

DUT_SRC = ROOT / "v_smpte_sdi_v3_0_vl_rfs.v"
TB_FILE = ROOT / "tb_environment.sv"
TXDATA  = ROOT / "tx_txdata_sim.hex"

TOTAL_LINES    = 1125
TOTAL_SAMPLES  = 2200
TOTAL_WORDS    = TOTAL_LINES * TOTAL_SAMPLES      # 2 475 000 (stream SDI completo)
ACTIVE_LINES   = 1080
ACTIVE_SAMPLES = 1920
ACTIVE_WORDS   = ACTIVE_LINES * ACTIVE_SAMPLES    # 2 073 600 (solo active video)


def pre_config(output_path: str) -> bool:
    """Verifica que tx_txdata_sim.hex existe antes de lanzar la simulación."""
    if not TXDATA.exists():
        print(f"[ERROR] Estímulo no encontrado: {TXDATA}")
        print("        Genera primero con run_txdata_gen.py en tx_txdata_generation/")
        return False

    count = sum(1 for ln in open(TXDATA) if ln.strip())
    if count != TOTAL_WORDS:
        print(f"[ERROR] {TXDATA.name} tiene {count} palabras, esperado {TOTAL_WORDS}")
        return False

    print(f"[pre_config] Usando estímulo: {TXDATA.name} ({count} palabras)")
    return True


def post_check(output_path: str) -> bool:
    """Verifica las 7 salidas: el stream con TOTAL_WORDS exacto y los 6
    ficheros de muestras activas consistentes entre si (mismo count y
    multiplo de ACTIVE_SAMPLES=1920)."""
    out_path = Path(output_path)

    stream_file = "out_tx_environment.hex"
    active_files = [
        "out_rx_y.hex",
        "out_rx_c.hex",
        "out_tx_ds1a_diag.hex",
        "out_tx_ds2a_diag.hex",
        "out_validation_rx_y.hex",
        "out_validation_rx_c.hex",
    ]

    ok = True

    # Stream SDI: cuenta exacta.
    f = out_path / stream_file
    if not f.exists():
        print(f"[post_check] FALLO: no encontrado {f}")
        ok = False
    else:
        count = sum(1 for ln in open(f) if ln.strip())
        if count != TOTAL_WORDS:
            print(f"[post_check] FALLO {stream_file}: esperado {TOTAL_WORDS}, obtenido {count}")
            ok = False
        else:
            print(f"[post_check] OK {stream_file} — {count} palabras")

    # Ficheros activos: exactamente ACTIVE_WORDS (1920 x 1080 = 2 073 600)
    for name in active_files:
        f = out_path / name
        if not f.exists():
            print(f"[post_check] FALLO: no encontrado {f}")
            ok = False
            continue
        count = sum(1 for ln in open(f) if ln.strip())
        if count != ACTIVE_WORDS:
            print(f"[post_check] FALLO {name}: esperado {ACTIVE_WORDS}, obtenido {count}")
            ok = False
        else:
            print(f"[post_check] OK {name} — {count} muestras")

    if ok:
        print(f"\n[post_check] Ficheros listos en: {out_path}")

    return ok


def main():
    for f in (DUT_SRC, TB_FILE):
        if not f.exists():
            sys.exit(f"[ERROR] Fichero no encontrado: {f}")

    from vunit import VUnit

    vu = VUnit.from_argv(vhdl_standard="2008", compile_builtins=False)
    vu.add_vhdl_builtins()
    vu.add_verilog_builtins()

    sdi = vu.add_library("sdi")
    sdi.add_source_file(str(DUT_SRC))
    sdi.add_source_file(str(TB_FILE))

    sdi.set_compile_option("modelsim.vlog_flags",
                           ["-suppress", "2583",
                            "-suppress", "13314"])

    tb = sdi.test_bench("tb_environment")
    tb.add_config(
        name="loopback_3g",
        generics={
            "G_TXDATA"             : str(TXDATA),
            "G_OUT_Y"              : "out_rx_y.hex",
            "G_OUT_C"              : "out_rx_c.hex",
            "G_OUT_TX"             : "out_tx_environment.hex",
            "g_out_diag1"          : "out_tx_ds1a_diag.hex",
            "g_out_diag2"          : "out_tx_ds2a_diag.hex",
            "G_OUT_VALIDATION_Y"   : "out_validation_rx_y.hex",
            "G_OUT_VALIDATION_C"   : "out_validation_rx_c.hex",
        },
        pre_config=pre_config,
        post_check=post_check,
    )

    vu.main()


if __name__ == "__main__":
    main()
