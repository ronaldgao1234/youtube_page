import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config.dart';

// ── DATA MODELS ────────────────────────────────────────────────────────────

class Word {
  final String text;
  final Duration start;
  final Duration end;
  const Word({required this.text, required this.start, required this.end});
}

class TranscriptSegment {
  final List<Word> words;
  final String translation;
  final Duration startTime;
  const TranscriptSegment({
    required this.words,
    required this.translation,
    required this.startTime,
  });
}

enum TranscriptStatus { initial, loading, loaded, error }

class TranscriptState {
  final TranscriptStatus status;
  final List<TranscriptSegment> segments;
  final String? errorMessage;

  const TranscriptState._({
    required this.status,
    this.segments = const [],
    this.errorMessage,
  });

  const TranscriptState.initial() : this._(status: TranscriptStatus.initial);
  const TranscriptState.loading() : this._(status: TranscriptStatus.loading);
  const TranscriptState.loaded(List<TranscriptSegment> s)
    : this._(status: TranscriptStatus.loaded, segments: s);
  const TranscriptState.error(String msg)
    : this._(status: TranscriptStatus.error, errorMessage: msg);
}

// ── NOTIFIER ───────────────────────────────────────────────────────────────

class TranscriptNotifier extends Notifier<TranscriptState> {
  @override
  TranscriptState build() {
    _load();
    return const TranscriptState.initial();
  }

  /// Convenience accessor used by `SubtitleSyncNotifier`.
  List<TranscriptSegment> get segments => state.segments;

  Future<void> refresh() => _load();

  Future<void> _load() async {
    state = const TranscriptState.loading();
    try {
      final raw = switch (kTranscriptSource) {
        TranscriptSource.toy => await rootBundle.loadString(
          'assets/toy_transcript.json',
        ),
        TranscriptSource.asset => await rootBundle.loadString(
          'assets/transcription.json',
        ),
      };

      final data = json.decode(raw) as Map<String, dynamic>;
      final segs = (data['segments'] as List).cast<Map<String, dynamic>>();

      final parsed = <TranscriptSegment>[];
      for (final s in segs) {
        final seg = _parseSegment(s);
        if (seg.words.isEmpty && seg.translation.isEmpty) continue;
        parsed.add(seg);
      }

      state = TranscriptState.loaded(parsed);
    } catch (e) {
      state = TranscriptState.error(e.toString());
    }
  }

  Duration _dur(dynamic s) =>
      Duration(microseconds: (((s ?? 0) as num) * 1e6).round());

  TranscriptSegment _parseSegment(Map<String, dynamic> s) {
    final translation = s['translation'] as String? ?? '';
    final wordsJson = (s['words'] as List?) ?? const [];

    final words = wordsJson.map((w) {
      final m = w as Map<String, dynamic>;
      return Word(
        text: m['word'] as String? ?? '',
        start: _dur(m['start']),
        end: _dur(m['end']),
      );
    }).toList()..sort((a, b) => a.start.compareTo(b.start));

    return TranscriptSegment(
      words: words,
      translation: translation,
      startTime: _dur(s['start']),
    );
  }
}

final transcriptNotifierProvider =
    NotifierProvider<TranscriptNotifier, TranscriptState>(
      TranscriptNotifier.new,
    );
