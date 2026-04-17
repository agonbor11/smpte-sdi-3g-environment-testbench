# SMPTE SD/HD/3G-SDI 3.0 Environment Testbench

Este repositorio contiene un entorno de verificación basado en **VUnit** diseñado para validar la integridad y el comportamiento del IP Core **SMPTE SD/HD/3G-SDI v3.0**.

## 🚀 Funcionalidad Principal
El testbench implementa un escenario de simulación en **loopback (RX → TX)** utilizando el DUT `v_smpte_sdi_v3_0_14`. El flujo de datos sigue este proceso:

1.  **Carga de Estímulos:** Lee un stream 3G-SDI pre-codificado desde un archivo fuente (`tx_txdata_sim.hex`).
2.  **Procesamiento:** El receptor (RX) del DUT decodifica el stream, el cual se re-inyecta inmediatamente al transmisor (TX) para su re-codificación.
3.  **Validación:** Un segundo bloque de recepción (bloque de validación) procesa la salida final para asegurar que no haya degradación de datos.
4.  **Generación de Resultados:** Se extraen diagnósticos detallados y archivos de datos (.hex) para análisis externo.

## 📂 Estructura del Proyecto
*   **`tb_environment.sv`**: Testbench principal desarrollado en SystemVerilog.
*   **`run_tb_environment.py`**: Script de ejecución (Runner) basado en VUnit para automatizar la simulación.
*   **`sdi_image_rec_3g_sdi.py`**: Script de post-procesamiento para reconstruir la imagen desde datos capturados.
*   **`v_smpte_sdi_v3_0_vl_rfs.v`**: Archivo fuente del IP Core que integra las funcionalidades RX y TX.
*   **`tx_txdata_sim.hex`**: Vector de prueba con tráfico 3G-SDI real.
*   **`vunit_out/`**: Directorio generado automáticamente con logs y resultados de simulación.


## ⚙️ Ejecución de la Simulación
Para lanzar el entorno de verificación y generar los archivos de salida, ejecuta el siguiente comando en la raíz del proyecto:

```bash
python3 run_tb_environment.py
```

## 🖼️ Post-procesamiento y Visualización
Para facilitar la verificación visual, el proyecto incluye el script **`sdi_image_rec_3g_sdi.py`**. Este procesa los ficheros `.hex` (muestras de luminancia y crominancia) y **reconstruye la imagen original** capturada.

### Ejemplos de uso:

**1. Reconstrucción de la salida del Loopback:**
```bash
python3 sdi_image_rec_3g_sdi.py \
  --y-file vunit_out/test_output/sdi.tb_environment.loopback_3g.loopback_3g_d58718e24db367d69b3332b7664ade57702f2cc7/out_rx_y.hex \
  --c-file vunit_out/test_output/sdi.tb_environment.loopback_3g.loopback_3g_d58718e24db367d69b3332b7664ade57702f2cc7/out_rx_c.hex \
  --output rx_del_loopback.png
```

**2. Reconstrucción de diagnósticos internos (TX):**
```bash
python3 sdi_image_rec_3g_sdi.py \
 --y-file vunit_out/test_output/sdi.tb_environment.loopback_3g.loopback_3g_d58718e24db367d69b3332b7664ade57702f2cc7/out_tx_ds1a_diag.hex \
 --c-file vunit_out/test_output/sdi.tb_environment.loopback_3g.loopback_3g_d58718e24db367d69b3332b7664ade57702f2cc7/out_tx_ds2a_diag.hex \
 --output diag_del_loopback.png
```
**3. Reconstrucción del bloque de validación final:**
```bash
python3 sdi_image_rec_3g_sdi.py \
  --y-file vunit_out/test_output/sdi.tb_environment.loopback_3g.loopback_3g_d58718e24db367d69b3332b7664ade57702f2cc7/out_validation_rx_y.hex \
  --c-file vunit_out/test_output/sdi.tb_environment.loopback_3g.loopback_3g_d58718e24db367d69b3332b7664ade57702f2cc7/out_validation_rx_c.hex \
  --output out_validation.png
```
