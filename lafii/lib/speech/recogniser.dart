import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:extract/extract.dart' as extract;
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:vosk_flutter_service/vosk_flutter_service.dart';

/// On-device speech to text. Vosk, bundled model, no network.
///
/// The app captures the microphone itself and feeds the recogniser directly.
/// The plugin's own capture uses Android's voice-recognition source, which
/// has no automatic gain; on many phones and on the emulator that arrives so
/// quiet the recogniser treats it as silence. Here the plain microphone
/// source is used with automatic gain, plus a capped software boost.
///
/// Audio exists only as in-memory chunks passed straight to the recogniser.
/// Nothing is written to storage, and the transcript lives only in this
/// object until [stop] returns it (invariant 10).
class Recogniser {
  Recogniser._();
  static final instance = Recogniser._();

  static const _asset = 'assets/models/vosk-model-small-en-us-0.15.zip';
  static const _sampleRate = 16000;

  /// Software gain never exceeds this, so noise is not blown up into speech.
  static const _maxGain = 12.0;

  final _vosk = VoskFlutterPlugin.instance();
  Future<Recognizer>? _recogniser;
  AudioRecorder? _mic;
  StreamSubscription<Uint8List>? _chunks;
  Future<void> _feeding = Future.value();
  final _heard = <String>[];

  /// Words heard but not matched to the vocabulary in the last session.
  int unrecognised = 0;

  /// Loudest raw input in the last session, in dB below full scale.
  /// Around -60 or lower means the microphone delivered near silence.
  double peakDb = -120;

  int _peak = 0;
  double _gain = 1;

  /// Unpacks the model on first use and creates the recogniser. Called at
  /// startup without awaiting. Does not touch the microphone.
  Future<Recognizer> warmUp() {
    final f = _recogniser ??= _load();
    // A failed load is not cached, so the next attempt tries again.
    f.catchError((Object _) {
      if (identical(_recogniser, f)) _recogniser = null;
      return f;
    });
    return f;
  }

  Future<Recognizer> _load() async {
    final path = await ModelLoader().loadFromAssets(_asset);
    final model = await _vosk.createModel(path);
    return _vosk.createRecognizer(
      model: model,
      sampleRate: _sampleRate,
      grammar: extract.vocabulary,
    );
  }

  String _text(String json) {
    try {
      final m = jsonDecode(json);
      final raw = (m is Map ? (m['text'] ?? '') : '').toString();
      unrecognised += '[unk]'.allMatches(raw).length;
      return raw.replaceAll('[unk]', '').replaceAll(RegExp(r'\s+'), ' ').trim();
    } catch (_) {
      return '';
    }
  }

  void _keep(String json) {
    if (kDebugMode) debugPrint('vosk result: $json');
    final t = _text(json);
    if (t.isNotEmpty) _heard.add(t);
  }

  /// Measures the chunk, raises quiet audio towards a usable level, and
  /// returns the 16-bit little-endian samples to feed the recogniser.
  Uint8List _level(Uint8List chunk) {
    final samples = ByteData.sublistView(chunk);
    final n = chunk.length ~/ 2;
    var chunkPeak = 0;
    for (var i = 0; i < n; i++) {
      final v = samples.getInt16(i * 2, Endian.little).abs();
      if (v > chunkPeak) chunkPeak = v;
    }
    if (chunkPeak > _peak) {
      _peak = chunkPeak;
      // Aim for peaks around half of full scale.
      _gain = _peak == 0 ? _maxGain : math.min(_maxGain, math.max(1, 16000 / _peak));
    }
    if (_gain <= 1.01) return chunk;
    final out = ByteData(n * 2);
    for (var i = 0; i < n; i++) {
      final v = (samples.getInt16(i * 2, Endian.little) * _gain).round().clamp(-32768, 32767);
      out.setInt16(i * 2, v, Endian.little);
    }
    return out.buffer.asUint8List();
  }

  /// Starts listening. Throws [MicrophoneAccessDeniedException] if the
  /// microphone is refused.
  Future<void> start() async {
    final mic = _mic ??= AudioRecorder();
    if (!await mic.hasPermission()) throw MicrophoneAccessDeniedException();
    final r = await warmUp();
    await r.reset();
    _heard.clear();
    unrecognised = 0;
    _peak = 0;
    _gain = 1;
    _feeding = Future.value();

    final stream = await mic.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: _sampleRate,
      numChannels: 1,
      autoGain: true,
      noiseSuppress: true,
      echoCancel: false,
      androidConfig: AndroidRecordConfig(audioSource: AndroidAudioSource.mic),
    ));
    _chunks = stream.listen((chunk) {
      final data = _level(chunk);
      // Feed in order; each call waits for the previous one.
      _feeding = _feeding.then((_) async {
        if (await r.acceptWaveformBytes(data)) _keep(await r.getResult());
      });
    });
  }

  /// Stops listening and returns everything heard.
  Future<String> stop() async {
    final mic = _mic;
    final r = _recogniser;
    if (mic == null || r == null) return '';
    await mic.stop();
    await _chunks?.cancel();
    _chunks = null;
    await _feeding;
    _keep(await (await r).getFinalResult());
    peakDb = _peak == 0 ? -120 : 20 * math.log(_peak / 32768) / math.ln10;
    if (kDebugMode) debugPrint('vosk peak ${peakDb.toStringAsFixed(1)} dB, gain $_gain');
    final text = _heard.join(' ');
    _heard.clear();
    return text;
  }

  /// Stops and throws away everything heard.
  Future<void> cancel() async {
    await _mic?.cancel();
    await _chunks?.cancel();
    _chunks = null;
    _heard.clear();
  }

  /// Debug builds only: feeds a 16 kHz mono 16-bit WAV straight into the
  /// recogniser, bypassing the microphone, and returns what it heard.
  Future<String> recogniseFile(String path) async {
    assert(kDebugMode);
    final r = await warmUp();
    final bytes = await File(path).readAsBytes();
    await r.reset();
    const header = 44;
    for (var i = header; i < bytes.length; i += 8000) {
      final end = i + 8000 < bytes.length ? i + 8000 : bytes.length;
      if (await r.acceptWaveformBytes(Uint8List.sublistView(bytes, i, end))) {
        debugPrint('vosk file result: ${await r.getResult()}');
      }
    }
    return r.getFinalResult();
  }
}
