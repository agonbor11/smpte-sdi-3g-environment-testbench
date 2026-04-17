#!/usr/bin/env python3
"""
sdi_image_rec_3g_sdi.py
=======================
Recupera la imagen desde los ficheros out_3g_sdi_y.hex / out_3g_sdi_c.hex
generados por tb_sdi_loopback_3g_sdi (3G-SDI Level A 1080p60, 1920×1080 activo).

Busca automáticamente los ficheros en el directorio de salida de VUnit:
  vunit_out/test_output/sdi.tb_sdi_loopback_3g_sdi.loopback_3g_sdi_*/

Uso:
  python sdi_image_rec_3g_sdi.py
  python sdi_image_rec_3g_sdi.py --output recovered.png
  python sdi_image_rec_3g_sdi.py --input-dir /ruta/manual/al/directorio
  python sdi_image_rec_3g_sdi.py --y-file path/to/out_3g_sdi_y.hex --c-file path/to/out_3g_sdi_c.hex
  python sdi_image_rec_3g_sdi.py --y-file path/to/out_3g_sdi_y.hex --c-file path/to/out_3g_sdi_c.hex --output recovered.png

Requirements:
  pip install Pillow numpy
"""

import argparse
import sys
import numpy as np
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    sys.exit('[ERROR] Pillow not installed. Run: pip install Pillow')

# ── Formato 3G-SDI Level A 1080p60 ───────────────────────────────────────────
FORMAT = {
    'total_lines':    1125,
    'total_samples':  2200,
    'active_lines':   1080,
    'active_samples': 1920,
    'first_active':     42,
    'desc': '3G-SDI Level A — 1920×1080p 60 Hz @ 148.5 MHz (SMPTE 424M)',
}

# ── Directorio VUnit ──────────────────────────────────────────────────────────
VUNIT_OUT   = Path(__file__).parent / 'vunit_out' / 'test_output'
TEST_PREFIX = 'sdi.tb_sdi_loopback_3g_sdi.loopback_3g_sdi'


def find_output_dir() -> Path:
    if not VUNIT_OUT.exists():
        sys.exit(f'[ERROR] Directorio VUnit no encontrado: {VUNIT_OUT}\n'
                 f'       Ejecuta run_3g_sdi.py antes de este script.')

    candidates = sorted(
        VUNIT_OUT.glob(f'{TEST_PREFIX}*/'),
        key=lambda p: p.stat().st_mtime,
        reverse=True
    )

    if not candidates:
        sys.exit(f'[ERROR] No se encontró ningún resultado de loopback_3g_sdi en:\n'
                 f'       {VUNIT_OUT}\n'
                 f'       Ejecuta run_3g_sdi.py primero.')

    chosen = candidates[0]
    print(f'Directorio: {chosen}')
    return chosen


def read_hex(path: Path, stream_words: int, active_words: int) -> tuple[np.ndarray, str]:
    """Lee el fichero hex y detecta el formato:
       - 'stream' : stream SDI completo (1125 x 2200 palabras).
       - 'active' : solo muestras activas (1080 x 1920 palabras).
       Devuelve (data, modo)."""
    print(f'Leyendo  : {path}')
    if not path.exists():
        sys.exit(f'[ERROR] Fichero no encontrado: {path}')

    try:
        data = np.array(
            [int(line.strip(), 16) for line in path.open() if line.strip()],
            dtype=np.uint16,
        )
    except ValueError as exc:
        sys.exit(f'[ERROR] Valor hex inválido en {path}: {exc}')

    n = len(data)
    if n == stream_words:
        return data, 'stream'
    if n == active_words:
        return data, 'active'
    sys.exit(
        f'[ERROR] {path.name}: tamaño {n:,} palabras no corresponde a '
        f'stream completo ({stream_words:,}) ni a active-only ({active_words:,}).'
    )


def sdi_ycbcr_to_rgb(Y: np.ndarray,
                     Cb422: np.ndarray,
                     Cr422: np.ndarray) -> np.ndarray:
    """
    Convierte YCbCr 4:2:2 BT.709 10-bit studio swing → RGB uint8 (H, W, 3).

    E'y  = (Y  -  64) / 876
    E'Cb = (Cb - 512) / 896
    E'Cr = (Cr - 512) / 896
    R = E'y                  + 1.5748 · E'Cr
    G = E'y - 0.1873 · E'Cb - 0.4681 · E'Cr
    B = E'y + 1.8556 · E'Cb
    """
    ey  = (Y.astype(np.float32)     -  64.0) / 876.0
    ecb = (Cb422.astype(np.float32) - 512.0) / 896.0
    ecr = (Cr422.astype(np.float32) - 512.0) / 896.0

    ecb_full = np.repeat(ecb, 2, axis=1)
    ecr_full = np.repeat(ecr, 2, axis=1)

    r = ey + 1.5748 * ecr_full
    g = ey - 0.1873 * ecb_full - 0.4681 * ecr_full
    b = ey + 1.8556 * ecb_full

    r = np.clip(np.round(r * 255.0), 0, 255).astype(np.uint8)
    g = np.clip(np.round(g * 255.0), 0, 255).astype(np.uint8)
    b = np.clip(np.round(b * 255.0), 0, 255).astype(np.uint8)

    return np.stack([r, g, b], axis=2)


def main() -> None:
    parser = argparse.ArgumentParser(
        description='Reconstruye la imagen desde out_3g_sdi_y/c.hex del loopback 3G-SDI',
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument('--input-dir', '-i', default=None,
                        help='Directorio con out_3g_sdi_y.hex y out_3g_sdi_c.hex.')
    parser.add_argument('--y-file', default=None,
                        help='Ruta directa al fichero out_3g_sdi_y.hex (tiene precedencia sobre --input-dir).')
    parser.add_argument('--c-file', default=None,
                        help='Ruta directa al fichero out_3g_sdi_c.hex (tiene precedencia sobre --input-dir).')
    parser.add_argument('--output', '-o', default='reconstructed_3g_sdi.png',
                        help='Fichero de imagen de salida (default: reconstructed_3g_sdi.png)')
    args = parser.parse_args()

    fmt    = FORMAT
    TL     = fmt['total_lines']
    TS     = fmt['total_samples']
    AL     = fmt['active_lines']
    AS     = fmt['active_samples']
    FA     = fmt['first_active']
    total  = TL * TS
    active = AL * AS

    print(f'Formato  : 3G-SDI Level A — {AS}×{AL} activo  ({TL}×{TS} total, first_active={FA})')
    print(f'           {fmt["desc"]}')
    print(f'Frame    : {TL} líneas × {TS} muestras = {total:,} palabras/stream')

    # Si se proporcionan archivos directos, usarlos; sino buscar en input_dir
    if args.y_file and args.c_file:
        y_path = Path(args.y_file)
        c_path = Path(args.c_file)
    else:
        input_dir = Path(args.input_dir) if args.input_dir else find_output_dir()
        y_path = input_dir / 'out_3g_sdi_y.hex'
        c_path = input_dir / 'out_3g_sdi_c.hex'

    y_raw, y_mode = read_hex(y_path, total, active)
    c_raw, c_mode = read_hex(c_path, total, active)

    if y_mode != c_mode:
        sys.exit(f'[ERROR] Y y C tienen formatos distintos ({y_mode} vs {c_mode}).')

    print(f'Modo     : {y_mode}')

    if y_mode == 'stream':
        y_frame = y_raw.reshape(TL, TS)
        c_frame = c_raw.reshape(TL, TS)
        row0    = FA - 1
        y_act   = y_frame[row0 : row0 + AL, :AS]
        c_act   = c_frame[row0 : row0 + AL, :AS]
    else:  # active-only: ya viene recortado y alineado en Cb
        y_act = y_raw.reshape(AL, AS)
        c_act = c_raw.reshape(AL, AS)

    Cb422 = c_act[:, 0::2]
    Cr422 = c_act[:, 1::2]

    print(f'\nConvirtiendo YCbCr 4:2:2 BT.709 10-bit → RGB 8-bit  ({AS}×{AL} px)…')
    img_array = sdi_ycbcr_to_rgb(y_act, Cb422, Cr422)

    out_path = Path(args.output)
    Image.fromarray(img_array, mode='RGB').save(out_path)
    print(f'Guardado : {out_path}  ({AS}×{AL} px)')
    print('\nHecho.')


if __name__ == '__main__':
    main()
