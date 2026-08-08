import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:just_waveform/just_waveform.dart';
import 'package:path/path.dart' as p;
import '../../../../core/services/local_audio_storage_service.dart';
import '../../../../core/services/app_storage_service.dart';

class WaveformEditorWidget extends StatefulWidget {
  final String audioPath;
  final int startPointMs;
  final int loopPointMs;
  final bool isPreviewPlaying;
  final int previewPositionMs;
  final double previewSpeed;
  final bool previewReverse;
  final VoidCallback onTogglePreview;
  final ValueChanged<int> onStartPointChanged;
  final ValueChanged<int> onLoopPointChanged;

  const WaveformEditorWidget({
    super.key,
    required this.audioPath,
    required this.startPointMs,
    required this.loopPointMs,
    required this.isPreviewPlaying,
    required this.previewPositionMs,
    required this.previewSpeed,
    required this.previewReverse,
    required this.onTogglePreview,
    required this.onStartPointChanged,
    required this.onLoopPointChanged,
  });

  @override
  State<WaveformEditorWidget> createState() => _WaveformEditorWidgetState();
}

class _WaveformEditorWidgetState extends State<WaveformEditorWidget> {
  Waveform? _waveform;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWaveform();
  }

  @override
  void didUpdateWidget(covariant WaveformEditorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si cambió el archivo de audio, recargar la forma de onda
    if (oldWidget.audioPath != widget.audioPath) {
      setState(() {
        _waveform = null;
        _isLoading = true;
        _error = null;
      });
      _loadWaveform();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadWaveform() async {
    try {
      final actualPath = await LocalAudioStorageService.resolvePath(
        widget.audioPath,
      );
      final file = File(actualPath);
      if (!await file.exists()) {
        if (mounted) {
          setState(() {
            _error = 'Audio file not found';
            _isLoading = false;
          });
        }
        return;
      }

      final extDir = await AppStorageService.waveformDirectory();
      // Use the file name and length to avoid caching outdated forms
      final fileLen = await file.length();
      final wavePath = p.join(
        extDir.path,
        '${file.uri.pathSegments.last}_$fileLen.wave',
      );
      final waveFile = File(wavePath);

      if (!await waveFile.exists()) {
        try {
          await waveFile.parent.create(recursive: true);
          final progressStream = JustWaveform.extract(
            audioInFile: file,
            waveOutFile: waveFile,
          );
          await progressStream.last.timeout(
            const Duration(seconds: 30),
            onTimeout: () =>
                throw TimeoutException('Waveform extraction timed out'),
          );
        } catch (_) {
          // Fallback para plataformas sin plugin nativo (ej. Desktop Windows/macOS)
          final fallback = await _generateFallbackWaveform(file);
          if (mounted) {
            setState(() {
              _waveform = fallback;
              _isLoading = false;
              _error = fallback == null
                  ? 'No se pudo generar la forma de onda.'
                  : null;
            });
          }
          return;
        }
      }

      final waveform = await JustWaveform.parse(waveFile);
      if (mounted) {
        setState(() {
          _waveform = waveform;
          _isLoading = false;
        });
      }
    } catch (e) {
      final resolvedPath = await LocalAudioStorageService.resolvePath(
        widget.audioPath,
      );
      final fallback =
          await _generateFallbackWaveform(File(resolvedPath));
      if (mounted) {
        setState(() {
          _waveform = fallback;
          _isLoading = false;
          _error = fallback == null ? 'Error cargando forma de onda: $e' : null;
        });
      }
    }
  }

  static Future<Waveform?> _generateFallbackWaveform(File file) async {
    try {
      if (!await file.exists()) return null;
      final len = await file.length();
      final readLen = len > 2000000 ? 2000000 : len;
      final Uint8List bytes =
          Uint8List.fromList(await file.openRead(0, readLen).first);

      var sampleRate = 44100;
      var samplesPerPixel = 256;

      // Parse the WAV header so the fallback duration matches the real audio.
      // Otherwise the playhead/trimmer are scaled against a wrong duration and
      // the white bar "cuts off in the middle" before playback ends.
      var wavDataOffset = 0;
      if (bytes.length >= 44 &&
          bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46 && // "RIFF"
          bytes[8] == 0x57 &&
          bytes[9] == 0x41 &&
          bytes[10] == 0x56 &&
          bytes[11] == 0x45) {
        // "WAVE"
        final view = ByteData.sublistView(bytes);
        var offset = 12;
        int? blockAlign;
        int? dataSize;
        while (offset + 8 <= bytes.length) {
          final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
          final size = view.getUint32(offset + 4, Endian.little);
          final dataStart = offset + 8;
          if (id == 'fmt ' &&
              size >= 16 &&
              dataStart + 16 <= bytes.length) {
            sampleRate = view.getUint32(dataStart + 4, Endian.little);
            blockAlign = view.getUint16(dataStart + 12, Endian.little);
          } else if (id == 'data') {
            dataSize = size;
            wavDataOffset = dataStart;
            break;
          }
          offset = dataStart + size + (size.isOdd ? 1 : 0);
        }
        if (blockAlign != null &&
            blockAlign > 0 &&
            dataSize != null &&
            dataSize > 0) {
          final frames = dataSize ~/ blockAlign;
          if (frames > 0 && sampleRate > 0) {
            // Keep 200 visual points but stretch samplesPerPixel so that
            // duration = length * samplesPerPixel / sampleRate matches the file.
            samplesPerPixel = (frames / 200).ceil();
          }
        }
      }

      final numPoints = 200;
      final data = Int16List(numPoints);
      final sampleSource =
          wavDataOffset > 0 ? bytes.sublist(wavDataOffset) : bytes;
      if (sampleSource.isNotEmpty) {
        final step =
            (sampleSource.length / numPoints).floor().clamp(1, sampleSource.length);
        for (int i = 0; i < numPoints; i++) {
          final idx = (i * step).clamp(0, sampleSource.length - 1);
          final sampleByte = sampleSource[idx];
          final val = ((sampleByte - 128) * 128).clamp(-32768, 32767);
          data[i] = val;
        }
      }
      return Waveform(
        version: 1,
        flags: 0,
        sampleRate: sampleRate,
        samplesPerPixel: samplesPerPixel,
        length: data.length,
        data: data,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return SizedBox(
        height: 100,
        child: Center(
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }
    if (_waveform == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white24, width: 1.2),
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              CustomPaint(
                size: Size.infinite,
                painter: _WaveformPainter(waveform: _waveform!),
              ),
              _WaveformTrimmer(
                waveform: _waveform!,
                startPointMs: widget.startPointMs,
                loopPointMs: widget.loopPointMs,
                onStartChanged: widget.onStartPointChanged,
                onLoopChanged: widget.onLoopPointChanged,
              ),
              if (widget.isPreviewPlaying)
                _PlaybackHead(
                  positionMs: widget.previewPositionMs,
                  startPointMs: widget.startPointMs,
                  endPointMs: widget.loopPointMs > widget.startPointMs
                      ? widget.loopPointMs
                      : _waveform!.duration.inMilliseconds,
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: OutlinedButton.icon(
            onPressed: widget.onTogglePreview,
            icon: Icon(
              widget.isPreviewPlaying
                  ? Icons.stop_rounded
                  : Icons.play_arrow_rounded,
              size: 20,
            ),
            label: Text(
              widget.isPreviewPlaying
                  ? 'Detener preescucha'
                  : 'Escuchar edición',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.cyanAccent,
              side: const BorderSide(color: Colors.cyanAccent),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // ── Panel de ajuste milimétrico rápido y preciso ──
        Row(
          children: [
            // Inicio Controls
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.greenAccent.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'INICIO: ${widget.startPointMs} ms',
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _MsStepBtn(
                          label: '-50',
                          onPressed: () {
                            var n = (widget.startPointMs - 50).clamp(0, 999999);
                            widget.onStartPointChanged(n);
                          },
                        ),
                        const SizedBox(width: 4),
                        _MsStepBtn(
                          label: '-10',
                          onPressed: () {
                            var n = (widget.startPointMs - 10).clamp(0, 999999);
                            widget.onStartPointChanged(n);
                          },
                        ),
                        const SizedBox(width: 4),
                        _MsStepBtn(
                          label: '+10',
                          onPressed: () {
                            var maxEnd = widget.loopPointMs == 0
                                ? _waveform!.duration.inMilliseconds
                                : widget.loopPointMs;
                            var n = (widget.startPointMs + 10).clamp(
                              0,
                              maxEnd - 1,
                            );
                            widget.onStartPointChanged(n);
                          },
                        ),
                        const SizedBox(width: 4),
                        _MsStepBtn(
                          label: '+50',
                          onPressed: () {
                            var maxEnd = widget.loopPointMs == 0
                                ? _waveform!.duration.inMilliseconds
                                : widget.loopPointMs;
                            var n = (widget.startPointMs + 50).clamp(
                              0,
                              maxEnd - 1,
                            );
                            widget.onStartPointChanged(n);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Fin Controls
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'FIN: ${widget.loopPointMs == 0 ? _waveform!.duration.inMilliseconds : widget.loopPointMs} ms',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _MsStepBtn(
                          label: '-50',
                          onPressed: () {
                            var curEnd = widget.loopPointMs == 0
                                ? _waveform!.duration.inMilliseconds
                                : widget.loopPointMs;
                            var n = (curEnd - 50).clamp(
                              widget.startPointMs + 1,
                              999999,
                            );
                            widget.onLoopPointChanged(n);
                          },
                        ),
                        const SizedBox(width: 4),
                        _MsStepBtn(
                          label: '-10',
                          onPressed: () {
                            var curEnd = widget.loopPointMs == 0
                                ? _waveform!.duration.inMilliseconds
                                : widget.loopPointMs;
                            var n = (curEnd - 10).clamp(
                              widget.startPointMs + 1,
                              999999,
                            );
                            widget.onLoopPointChanged(n);
                          },
                        ),
                        const SizedBox(width: 4),
                        _MsStepBtn(
                          label: '+10',
                          onPressed: () {
                            var total = _waveform!.duration.inMilliseconds;
                            var curEnd = widget.loopPointMs == 0
                                ? total
                                : widget.loopPointMs;
                            var n = (curEnd + 10).clamp(
                              widget.startPointMs + 1,
                              total,
                            );
                            widget.onLoopPointChanged(n);
                          },
                        ),
                        const SizedBox(width: 4),
                        _MsStepBtn(
                          label: '+50',
                          onPressed: () {
                            var total = _waveform!.duration.inMilliseconds;
                            var curEnd = widget.loopPointMs == 0
                                ? total
                                : widget.loopPointMs;
                            var n = (curEnd + 50).clamp(
                              widget.startPointMs + 1,
                              total,
                            );
                            widget.onLoopPointChanged(n);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MsStepBtn extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _MsStepBtn({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _PlaybackHead extends StatelessWidget {
  const _PlaybackHead({
    required this.positionMs,
    required this.startPointMs,
    required this.endPointMs,
  });

  final int positionMs;
  final int startPointMs;
  final int endPointMs;

  @override
  Widget build(BuildContext context) {
    // The preview only sounds between startPoint and endPoint, so the head is
    // mapped over that region: at startPoint it sits at the left edge and it
    // sweeps to the right edge exactly when the clip finishes.
    final span = endPointMs - startPointMs;
    if (span <= 0) return const SizedBox.shrink();
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final ratio = ((positionMs - startPointMs) / span).clamp(0.0, 1.0);
          return Align(
            alignment: Alignment(-1 + (2 * ratio), 0),
            child: IgnorePointer(
              child: Container(
                width: 2,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.7),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final Waveform waveform;

  _WaveformPainter({required this.waveform});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.85)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final data = waveform.data;
    final maxSample = 32767.0;

    if (data.isEmpty) return;

    final step = data.length / size.width;

    path.moveTo(0, size.height / 2);

    for (int i = 0; i < size.width; i++) {
      final index = (i * step).floor().clamp(0, data.length - 1);
      final sample = data[index].abs() / maxSample;
      final y = (1.0 - sample) * size.height / 2;
      final y2 = (1.0 + sample) * size.height / 2;
      path.moveTo(i.toDouble(), y);
      path.lineTo(i.toDouble(), y2);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.waveform != waveform;
}

class _WaveformTrimmer extends StatelessWidget {
  final Waveform waveform;
  final int startPointMs;
  final int loopPointMs;
  final ValueChanged<int> onStartChanged;
  final ValueChanged<int> onLoopChanged;

  const _WaveformTrimmer({
    required this.waveform,
    required this.startPointMs,
    required this.loopPointMs,
    required this.onStartChanged,
    required this.onLoopChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalDuration = waveform.duration.inMilliseconds;
        if (totalDuration == 0) return const SizedBox.shrink();

        final startPx = (startPointMs / totalDuration) * constraints.maxWidth;
        final endPx = loopPointMs == 0
            ? constraints.maxWidth
            : (loopPointMs / totalDuration) * constraints.maxWidth;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            final tapPx = details.localPosition.dx;
            final tapMs = ((tapPx / constraints.maxWidth) * totalDuration)
                .clamp(0.0, totalDuration.toDouble())
                .toInt();

            final distToStart = (tapPx - startPx).abs();
            final distToEnd = (tapPx - endPx).abs();

            if (distToStart < distToEnd) {
              final maxEnd = loopPointMs == 0 ? totalDuration : loopPointMs;
              onStartChanged(tapMs.clamp(0, maxEnd - 1));
            } else {
              onLoopChanged(tapMs.clamp(startPointMs + 1, totalDuration));
            }
          },
          child: Stack(
            children: [
              // Start overlay (darkened)
              Positioned(
                left: 0,
                width: startPx.clamp(0, constraints.maxWidth),
                top: 0,
                bottom: 0,
                child: Container(color: Colors.black.withValues(alpha: 0.7)),
              ),
              // End overlay (darkened)
              Positioned(
                left: endPx.clamp(0, constraints.maxWidth),
                right: 0,
                top: 0,
                bottom: 0,
                child: Container(color: Colors.black.withValues(alpha: 0.7)),
              ),

              // ── START HANDLE (PERILLA Y BARRA VERDE NEÓN) ──
              Positioned(
                left: startPx.clamp(0, constraints.maxWidth) - 20,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) {
                    final newPx = startPx + details.delta.dx;
                    final newMs =
                        ((newPx / constraints.maxWidth) * totalDuration)
                            .clamp(0.0, totalDuration.toDouble())
                            .toInt();
                    final maxEnd = loopPointMs == 0
                        ? totalDuration
                        : loopPointMs;
                    if (newMs < maxEnd) {
                      onStartChanged(newMs);
                    }
                  },
                  child: SizedBox(
                    width: 40,
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        // Linea verticla de 4px neón
                        Center(
                          child: Container(
                            width: 4,
                            decoration: BoxDecoration(
                              color: Colors.greenAccent,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.greenAccent.withValues(
                                    alpha: 0.8,
                                  ),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Knob / Perilla visual superior
                        Positioned(
                          top: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.greenAccent,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: const [
                                BoxShadow(color: Colors.black54, blurRadius: 4),
                              ],
                            ),
                            child: const Text(
                              '◀ INICIO',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── END HANDLE (PERILLA Y BARRA ROJA NEÓN) ──
              Positioned(
                left: endPx.clamp(0, constraints.maxWidth) - 20,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) {
                    final newPx = endPx + details.delta.dx;
                    final newMs =
                        ((newPx / constraints.maxWidth) * totalDuration)
                            .clamp(0.0, totalDuration.toDouble())
                            .toInt();
                    if (newMs > startPointMs) {
                      onLoopChanged(newMs);
                    }
                  },
                  child: SizedBox(
                    width: 40,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        // Linea vertical de 4px neón
                        Center(
                          child: Container(
                            width: 4,
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.redAccent.withValues(
                                    alpha: 0.8,
                                  ),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Knob / Perilla visual inferior
                        Positioned(
                          bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: const [
                                BoxShadow(color: Colors.black54, blurRadius: 4),
                              ],
                            ),
                            child: const Text(
                              'FIN ▶',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
