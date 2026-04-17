// =============================================================================
// tb_environment.sv
// Testbench VUnit (SystemVerilog) para el IP Core SMPTE SDI v3.0 (PG071)
// DUT: v_smpte_sdi_v3_0_14  (v_smpte_sdi_v3_0_vl_rfs.v)
// Modo: 3G-SDI Level A — 1920x1080p @ 60 Hz (148.5 MHz, SMPTE 424M)
//
// FUNCION: tx_txdata.hex -> dut.rx_data_in -> rx_ds1a/rx_ds2a -> dut.tx_video_a_y_in/c_in -> tx_txdata (environment) -> validation.rx_data_in -> rx_ds1a/rx_ds2a (decodificado)
//
// Estimulos: tx_txdata_sim.hex    (stream SDI codificado, 20 bits/ciclo)
// Capturas:  out_rx_y.hex              (rx_ds1a  — Y decodificada)
//            out_rx_c.hex              (rx_ds2a  — C decodificada)
//            out_tx_environment.hex       (tx_txdata — stream re-codificado)
//            out_tx_ds1a_diag.hex      (tx_ds1a_out — Y pre-scrambler)
//            out_tx_ds2a_diag.hex      (tx_ds2a_out — C pre-scrambler)
//            out_validation_rx_y.hex   (rx_ds1a  — Y decodificada)
//            out_validation_rx_c.hex   (rx_ds2a  — C decodificada)

`include "vunit_defines.svh"

`timescale 1ns / 1ps

module tb_environment;

  // ---------------------------------------------------------------------------
  // Parametros (VUnit los inyecta como overrides)
  // ---------------------------------------------------------------------------
  parameter string output_path = "./";
  parameter string G_TXDATA    = "tx_txdata_sim.hex";
  parameter string G_OUT_Y     = "out_rx_y.hex";
  parameter string G_OUT_C     = "out_rx_c.hex";
  parameter string G_OUT_TX    = "out_tx_loopback.hex";
  parameter string g_out_diag1  = "out_tx_ds1a_diag.hex";
  parameter string g_out_diag2  = "out_tx_ds2a_diag.hex";
  parameter string G_OUT_VALIDATION_Y = "out_validation_rx_y.hex";
  parameter string G_OUT_VALIDATION_C = "out_validation_rx_c.hex";

  // ---------------------------------------------------------------------------
  // Constantes 3G-SDI Level A 1080p60
  // ---------------------------------------------------------------------------
  localparam real   CLK_HALF    = 3.367;          // ns  (6.734 ns periodo = 148.5 MHz)
  localparam integer RESET_CYCLES  = 32;
  localparam integer TOTAL_LINES   = 1125;
  localparam integer TOTAL_SAMPLES = 2200;
  localparam integer TOTAL_WORDS   = TOTAL_LINES * TOTAL_SAMPLES;  // 2 475 000
  localparam integer FIRST_ACTIVE  = 42;
  localparam integer SIM_FRAMES    = 3;
  localparam integer CAPTURE_FRAME = 2;

  // ---------------------------------------------------------------------------
  // Reloj
  // ---------------------------------------------------------------------------
  reg clk = 0;
  always #(CLK_HALF) clk = ~clk;

  // ---------------------------------------------------------------------------
  // Resets
  // ---------------------------------------------------------------------------
  reg rx_rst = 1;
  reg tx_rst = 1;

  // ---------------------------------------------------------------------------
  // Memoria de estimulos (cargada con $readmemh)
  // ---------------------------------------------------------------------------
  reg [19:0] txdata_mem [0:TOTAL_WORDS-1];
  reg [19:0] rx_data_in = 20'd0;

  // ---------------------------------------------------------------------------
  // Senales RX )
  // ---------------------------------------------------------------------------
  wire [9:0]  rx_ds1a, rx_ds2a;
  wire [10:0] rx_line_a;
  wire        rx_mode_locked;
  wire        rx_t_locked;
  wire        rx_eav, rx_sav, rx_trs;
  wire        rx_crc_err_a;
  wire [1:0]  rx_mode;

  // ---------------------------------------------------------------------------
  // Senales de loopback (RX -> TX)
  // ---------------------------------------------------------------------------
  reg  [9:0]  tx_y_s    = 10'd0;
  reg  [9:0]  tx_c_s    = 10'd0;
  reg  [10:0] tx_line_s = 11'd1;

  // ---------------------------------------------------------------------------
  // Senales TX 
  // ---------------------------------------------------------------------------
  wire [19:0] tx_txdata_lb;
  wire [9:0]  tx_ds1a_diag;
  wire [9:0]  tx_ds2a_diag;

  // ---------------------------------------------------------------------------
  // Senales del modulo validation (segundo decodificador RX)
  // ---------------------------------------------------------------------------
  wire [9:0]  val_rx_ds1a, val_rx_ds2a;
  wire [10:0] val_rx_line_a;
  wire        val_rx_mode_locked;
  wire        val_rx_t_locked;
  wire        val_rx_crc_err_a;
  wire [1:0]  val_rx_mode;
  wire        val_rx_sav, val_rx_eav, val_rx_trs;

  // =========================================================================
  // INSTANCIA UNICA: RX Y TX SIMULTANEOS (loopback)
  // RX decodifica datos SDI entrada, TX re-codifica datos decodificados
  // =========================================================================
  v_smpte_sdi_v3_0_14 #(
    .INCLUDE_RX_EDH_PROCESSOR ("FALSE"),
    .C_FAMILY                 ("virtex7")
  ) dut (
    // --- RX activo ---
    .rx_rst              (rx_rst),
    .rx_usrclk           (clk),
    .rx_data_in          (rx_data_in),
    .rx_sd_data_in       (rx_data_in[19:10]),
    .rx_sd_data_strobe   (1'b1),
    .rx_frame_en         (1'b1),
    .rx_mode_en          (3'b100),        // solo 3G habilitado
    .rx_mode             (rx_mode),
    .rx_mode_hd          (),
    .rx_mode_sd          (),
    .rx_mode_3g          (),
    .rx_mode_detect_en   (1'b0),          // modo forzado
    .rx_mode_locked      (rx_mode_locked),
    .rx_forced_mode      (2'b10),         // forzar 3G
    .rx_bit_rate         (1'b0),
    .rx_t_locked         (rx_t_locked),
    .rx_t_family         (),
    .rx_t_rate           (),
    .rx_t_scan           (),
    .rx_level_b_3g       (),
    .rx_ce_sd            (),
    .rx_nsp              (),
    .rx_line_a           (rx_line_a),
    .rx_a_vpid           (),
    .rx_a_vpid_valid     (),
    .rx_b_vpid           (),
    .rx_b_vpid_valid     (),
    .rx_crc_err_a        (rx_crc_err_a),
    .rx_ds1a             (rx_ds1a),
    .rx_ds2a             (rx_ds2a),
    .rx_eav              (rx_eav),
    .rx_sav              (rx_sav),
    .rx_trs              (rx_trs),
    .rx_line_b           (),
    .rx_dout_rdy_3g      (),
    .rx_crc_err_b        (),
    .rx_ds1b             (),
    .rx_ds2b             (),
    .rx_edh_errcnt_en    (16'h0000),
    .rx_edh_clr_errcnt   (1'b0),
    .rx_edh_ap           (),
    .rx_edh_ff           (),
    .rx_edh_anc          (),
    .rx_edh_ap_flags     (),
    .rx_edh_ff_flags     (),
    .rx_edh_anc_flags    (),
    .rx_edh_packet_flags (),
    .rx_edh_errcnt       (),
    // --- TX activo ---
    .tx_rst              (tx_rst),
    .tx_usrclk           (clk),
    .tx_ce               (3'b111),
    .tx_din_rdy          (1'b1),
    .tx_mode             (2'b10),         // 3G
    .tx_level_b_3g       (1'b0),          // Level A
    .tx_insert_crc       (1'b1),
    .tx_insert_ln        (1'b1),
    .tx_insert_edh       (1'b0),
    .tx_insert_vpid      (1'b1),
    .tx_overwrite_vpid   (1'b1),
    .tx_video_a_y_in     (tx_y_s),
    .tx_video_a_c_in     (tx_c_s),
    .tx_video_b_y_in     (10'd0),
    .tx_video_b_c_in     (10'd0),
    .tx_line_a           (tx_line_s),
    .tx_line_b           (11'd0),
    .tx_vpid_byte1       (8'h89),         // SMPTE 352 para 1080p60 3G-A
    .tx_vpid_byte2       (8'h06),
    .tx_vpid_byte3       (8'h08),
    .tx_vpid_byte4a      (8'h02),
    .tx_vpid_byte4b      (8'h00),
    .tx_vpid_line_f1     (FIRST_ACTIVE - 1),
    .tx_vpid_line_f2     (11'd0),
    .tx_vpid_line_f2_en  (1'b0),
    .tx_ds1a_out         (tx_ds1a_diag),
    .tx_ds2a_out         (tx_ds2a_diag),
    .tx_ds1b_out         (),
    .tx_ds2b_out         (),
    .tx_use_dsin         (1'b0),
    .tx_ds1a_in          (10'd0),
    .tx_ds2a_in          (10'd0),
    .tx_ds1b_in          (10'd0),
    .tx_ds2b_in          (10'd0),
    .tx_sd_bitrep_bypass (1'b1),
    .tx_txdata           (tx_txdata_lb),
    .tx_ce_align_err     ()
  );

  // =========================================================================
  // INSTANCIA VALIDATION: decodifica de nuevo tx_txdata_lb -> Y/C
  // Solo se usa la parte RX; la TX queda inactiva en reset.
  // =========================================================================
  v_smpte_sdi_v3_0_14 #(
    .INCLUDE_RX_EDH_PROCESSOR ("FALSE"),
    .C_FAMILY                 ("virtex7")
  ) validation (
    // --- RX activo (entrada: tx_txdata_lb del dut) ---
    .rx_rst              (rx_rst),
    .rx_usrclk           (clk),
    .rx_data_in          (tx_txdata_lb),
    .rx_sd_data_in       (tx_txdata_lb[19:10]),
    .rx_sd_data_strobe   (1'b1),
    .rx_frame_en         (1'b1),
    .rx_mode_en          (3'b100),
    .rx_mode             (val_rx_mode),
    .rx_mode_hd          (),
    .rx_mode_sd          (),
    .rx_mode_3g          (),
    .rx_mode_detect_en   (1'b0),
    .rx_mode_locked      (val_rx_mode_locked),
    .rx_forced_mode      (2'b10),
    .rx_bit_rate         (1'b0),
    .rx_t_locked         (val_rx_t_locked),
    .rx_t_family         (),
    .rx_t_rate           (),
    .rx_t_scan           (),
    .rx_level_b_3g       (),
    .rx_ce_sd            (),
    .rx_nsp              (),
    .rx_line_a           (val_rx_line_a),
    .rx_a_vpid           (),
    .rx_a_vpid_valid     (),
    .rx_b_vpid           (),
    .rx_b_vpid_valid     (),
    .rx_crc_err_a        (val_rx_crc_err_a),
    .rx_ds1a             (val_rx_ds1a),
    .rx_ds2a             (val_rx_ds2a),
    .rx_eav              (val_rx_eav),
    .rx_sav              (val_rx_sav),
    .rx_trs              (val_rx_trs),
    .rx_line_b           (),
    .rx_dout_rdy_3g      (),
    .rx_crc_err_b        (),
    .rx_ds1b             (),
    .rx_ds2b             (),
    .rx_edh_errcnt_en    (16'h0000),
    .rx_edh_clr_errcnt   (1'b0),
    .rx_edh_ap           (),
    .rx_edh_ff           (),
    .rx_edh_anc          (),
    .rx_edh_ap_flags     (),
    .rx_edh_ff_flags     (),
    .rx_edh_anc_flags    (),
    .rx_edh_packet_flags (),
    .rx_edh_errcnt       (),
    // --- TX inactivo ---
    .tx_rst              (1'b1),
    .tx_usrclk           (clk),
    .tx_ce               (3'b111),
    .tx_din_rdy          (1'b1),
    .tx_mode             (2'b10),
    .tx_level_b_3g       (1'b0),
    .tx_insert_crc       (1'b0),
    .tx_insert_ln        (1'b0),
    .tx_insert_edh       (1'b0),
    .tx_insert_vpid      (1'b0),
    .tx_overwrite_vpid   (1'b0),
    .tx_video_a_y_in     (10'd0),
    .tx_video_a_c_in     (10'd0),
    .tx_video_b_y_in     (10'd0),
    .tx_video_b_c_in     (10'd0),
    .tx_line_a           (11'd0),
    .tx_line_b           (11'd0),
    .tx_vpid_byte1       (8'h00),
    .tx_vpid_byte2       (8'h00),
    .tx_vpid_byte3       (8'h00),
    .tx_vpid_byte4a      (8'h00),
    .tx_vpid_byte4b      (8'h00),
    .tx_vpid_line_f1     (11'd0),
    .tx_vpid_line_f2     (11'd0),
    .tx_vpid_line_f2_en  (1'b0),
    .tx_ds1a_out         (),
    .tx_ds2a_out         (),
    .tx_ds1b_out         (),
    .tx_ds2b_out         (),
    .tx_use_dsin         (1'b0),
    .tx_ds1a_in          (10'd0),
    .tx_ds2a_in          (10'd0),
    .tx_ds1b_in          (10'd0),
    .tx_ds2b_in          (10'd0),
    .tx_sd_bitrep_bypass (1'b1),
    .tx_txdata           (),
    .tx_ce_align_err     ()
  );

  // =========================================================================
  // MUX de loopback: datos dut.RX -> dut.TX
  // Filtra X's del decoder RX con $isunknown (seguridad en simulacion).
  // Sin este filtro, un solo X entra al scrambler TX (que no tiene reset)
  // y lo corrompe permanentemente.
  // =========================================================================
  // La estrategia es: RX sale de reset en frame 0, TX sale en frame 1
  // Esto asegura que cuando TX empiece, tenga datos limpios de RX.
  // =========================================================================
  wire rx_data_clean = rx_mode_locked
                     & !$isunknown(rx_ds1a)
                     & !$isunknown(rx_ds2a)
                     & !$isunknown(rx_line_a);

  always @(posedge clk) begin
    if (rx_data_clean) begin
      tx_y_s    <= rx_ds1a;
      tx_c_s    <= rx_ds2a;
      tx_line_s <= rx_line_a;
    end else begin
      tx_y_s    <= 10'd0;
      tx_c_s    <= 10'd0;
      tx_line_s <= 11'd1;
    end
  end

  // =========================================================================
  // Gating de captura: exactamente 1920 muestras por linea, empezando en Cb.
  //
  // El IP Xilinx asserta rx_sav durante varios ciclos del TRS de SAV
  // (en la practica los 4: 3FF,000,000,XYZ). Por eso NO podemos usar el
  // flanco de subida de rx_sav ni un nivel alto: capturariamos 000/XYZ.
  //
  // Estrategia: detectar el flanco de BAJADA de rx_sav. Justo despues de
  // ese flanco, la palabra que sale por rx_ds1a/ds2a es la primera muestra
  // activa (Cb por construccion SMPTE). Capturamos 1920 muestras a partir
  // de ahi con un contador. Valido sea cual sea la anchura del pulso SAV.
  // =========================================================================
  reg        rx_sav_d       = 1'b0;
  reg        rx_cap_r       = 1'b0;
  reg [11:0] rx_cnt         = 12'd0;
  wire       rx_sav_fall    = rx_sav_d & ~rx_sav;
  wire       rx_line_in_act = (rx_line_a >= 11'd42) & (rx_line_a <= 11'd1121);
  wire       rx_in_active   = (rx_cap_r | rx_sav_fall) & rx_line_in_act;

  reg        val_sav_d      = 1'b0;
  reg        val_cap_r      = 1'b0;
  reg [11:0] val_cnt        = 12'd0;
  wire       val_sav_fall    = val_sav_d & ~val_rx_sav;
  wire       val_line_in_act = (val_rx_line_a >= 11'd42) & (val_rx_line_a <= 11'd1121);
  wire       val_in_active   = (val_cap_r | val_sav_fall) & val_line_in_act;

  always @(posedge clk) begin
    rx_sav_d <= rx_sav;
    if (rx_rst) begin
      rx_cap_r <= 1'b0;
      rx_cnt   <= 12'd0;
    end else if (rx_sav_fall) begin
      rx_cap_r <= 1'b1;
      rx_cnt   <= 12'd1;   // muestra 0 (Cb) se captura via rx_sav_fall
    end else if (rx_cap_r) begin
      if (rx_cnt == 12'd1919) begin
        rx_cap_r <= 1'b0;
        rx_cnt   <= 12'd0;
      end else begin
        rx_cnt <= rx_cnt + 12'd1;
      end
    end
  end

  always @(posedge clk) begin
    val_sav_d <= val_rx_sav;
    if (rx_rst) begin
      val_cap_r <= 1'b0;
      val_cnt   <= 12'd0;
    end else if (val_sav_fall) begin
      val_cap_r <= 1'b1;
      val_cnt   <= 12'd1;
    end else if (val_cap_r) begin
      if (val_cnt == 12'd1919) begin
        val_cap_r <= 1'b0;
        val_cnt   <= 12'd0;
      end else begin
        val_cnt <= val_cnt + 12'd1;
      end
    end
  end

  // =========================================================================
  // Test VUnit
  // =========================================================================
  `TEST_SUITE begin
    `TEST_CASE("loopback_3g") begin
      integer fd_y, fd_c, fd_tx, fd_diag1, fd_diag2, fd_val_y, fd_val_c;
      integer cap_count, err_count;
      integer cap_count_rx_act, cap_count_val_act;
      integer frame, word;
      integer x_count_f0, x_count_f1, x_count_f2;
      reg     lock_prev;

      // Cargar estimulos desde fichero hex
      $readmemh(G_TXDATA, txdata_mem);

      // Abrir ficheros de salida
      fd_y     = $fopen({output_path, G_OUT_Y},     "w");
      fd_c     = $fopen({output_path, G_OUT_C},     "w");
      fd_tx    = $fopen({output_path, G_OUT_TX},    "w");
      fd_diag1 = $fopen({output_path, g_out_diag1}, "w");
      fd_diag2 = $fopen({output_path, g_out_diag2}, "w");
      fd_val_y = $fopen({output_path, G_OUT_VALIDATION_Y}, "w");
      fd_val_c = $fopen({output_path, G_OUT_VALIDATION_C}, "w");

      if (!fd_y || !fd_c || !fd_tx || !fd_diag1 || !fd_diag2 || !fd_val_y || !fd_val_c) begin
        $display("[TB] ERROR: no se pudo abrir algun fichero de salida");
        $finish;
      end

      // Fase de reset: RX sale primero, TX permanece en reset durante frame 0
      rx_rst = 1;
      tx_rst = 1;
      repeat (RESET_CYCLES) @(posedge clk);
      rx_rst = 0;            // RX sale de reset
      // TX sigue en reset — se suelta al inicio de frame 1
      @(posedge clk);

      cap_count         = 0;
      cap_count_rx_act  = 0;
      cap_count_val_act = 0;
      err_count         = 0;
      x_count_f0        = 0;
      x_count_f1        = 0;
      x_count_f2        = 0;
      lock_prev         = 0;

      // Bucle de frames
      for (frame = 0; frame < SIM_FRAMES; frame = frame + 1) begin
        $display("[TB] === Frame %0d inicio ===", frame);

        // Soltar TX del reset al inicio del frame 1
        // (el RX ya lleva un frame completo con datos limpios)
        if (frame == 1) begin
          tx_rst = 0;
          $display("[TB] tx_rst liberado al inicio de frame 1");
        end

        for (word = 0; word < TOTAL_WORDS; word = word + 1) begin
          rx_data_in <= txdata_mem[word];
          @(posedge clk);

          // Diagnostico: detectar transicion de rx_mode_locked
          if (rx_mode_locked !== lock_prev) begin
            $display("[TB] frame=%0d word=%0d rx_mode_locked: %b -> %b",
                     frame, word, lock_prev, rx_mode_locked);
            lock_prev = rx_mode_locked;
          end

          // Diagnostico: primeras 30 palabras de cada frame
          if (word < 30)
            $display("[TB] f=%0d w=%0d  rx_in=%05h  ds1a=%03h  ds2a=%03h  ln_a=%04h  tx_y=%03h  tx_c=%03h  tx_ln=%04h  txdata=%05h  diag=%03h  lock=%b",
                     frame, word, rx_data_in, rx_ds1a, rx_ds2a, rx_line_a, tx_y_s, tx_c_s, tx_line_s, tx_txdata_lb, tx_ds1a_diag, rx_mode_locked);

          // Contar X's por frame
          if ($isunknown(tx_txdata_lb)) begin
            if (frame == 0) x_count_f0 = x_count_f0 + 1;
            if (frame == 1) x_count_f1 = x_count_f1 + 1;
            if (frame == 2) x_count_f2 = x_count_f2 + 1;
          end

          if (frame == CAPTURE_FRAME) begin
            // Stream SDI completo: sin gating (captura 2200 x 1125 palabras)
            $fwrite(fd_tx, "%05h\n", tx_txdata_lb);
            cap_count = cap_count + 1;

            // RX principal + diag TX: gated por SAV/EAV del RX principal
            // (el diag TX viene del loopback del RX, misma referencia temporal)
            if (rx_in_active) begin
              $fwrite(fd_y,     "%03h\n", rx_ds1a);
              $fwrite(fd_c,     "%03h\n", rx_ds2a);
              $fwrite(fd_diag1, "%03h\n", tx_ds1a_diag);
              $fwrite(fd_diag2, "%03h\n", tx_ds2a_diag);
              cap_count_rx_act = cap_count_rx_act + 1;
            end

            // Validation: gated por su propio SAV/EAV (primera muestra C = Cb)
            if (val_in_active) begin
              $fwrite(fd_val_y, "%03h\n", val_rx_ds1a);
              $fwrite(fd_val_c, "%03h\n", val_rx_ds2a);
              cap_count_val_act = cap_count_val_act + 1;
            end

            if (rx_crc_err_a)
              err_count = err_count + 1;
          end
        end
      end

      // Cerrar ficheros
      $fclose(fd_y);
      $fclose(fd_c);
      $fclose(fd_tx);
      $fclose(fd_diag1);
      $fclose(fd_diag2);
      $fclose(fd_val_y);
      $fclose(fd_val_c);

      // Informe
      $display("[TB] Palabras capturadas (stream):   %0d", cap_count);
      $display("[TB] Muestras activas RX principal:  %0d", cap_count_rx_act);
      $display("[TB] Muestras activas validation:    %0d", cap_count_val_act);
      $display("[TB] Errores CRC en RX:              %0d", err_count);
      $display("[TB] rx_mode_locked:                 %0b", rx_mode_locked);
      $display("[TB] val_rx_mode_locked:             %0b", val_rx_mode_locked);
      $display("[TB] X's en tx_txdata — frame0: %0d  frame1: %0d  frame2: %0d",
               x_count_f0, x_count_f1, x_count_f2);

      `CHECK_EQUAL(cap_count, TOTAL_WORDS)

      if (err_count != 0)
        $display("[TB] WARNING: %0d errores CRC (discontinuidad al reiniciar fichero)", err_count);
      if (!rx_mode_locked)
        $display("[TB] WARNING: rx_mode_locked no asertado");
    end
  end

  // Watchdog generoso para 3 frames de 2.475M ciclos
  `WATCHDOG(200ms);

endmodule
