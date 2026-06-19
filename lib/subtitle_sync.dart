import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'player_manager.dart';
import 'transcript_notifier.dart';

/// Snapshot of where we are in the transcript + playback meta.
/// Lives in this single state object so widgets watching it rebuild
/// only when the values they actually care about change.
@immutable
class SubtitleSyncState {
  final int segmentIndex;   // -1 before transcript loads
  final int wordIndex;      // -1 if no word yet
  final Duration position;  // current video position
  final Duration duration;  // total video duration (zero until metadata loads)
  final bool isPlaying;

  const SubtitleSyncState({
    required this.segmentIndex,
    required this.wordIndex,
    required this.position,
    required this.duration,
    required this.isPlaying,
  });

  const SubtitleSyncState.initial()
      : segmentIndex = -1,
        wordIndex = -1,
        position = Duration.zero,
        duration = Duration.zero,
        isPlaying = false;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SubtitleSyncState &&
          other.segmentIndex == segmentIndex &&
          other.wordIndex == wordIndex &&
          other.position == position &&
          other.duration == duration &&
          other.isPlaying == isPlaying);

  @override
  int get hashCode =>
      Object.hash(segmentIndex, wordIndex, position, duration, isPlaying);
}

class SubtitleSyncNotifier extends Notifier<SubtitleSyncState> {
  YoutubePlayerController get _ctrl => PlayerManager.instance.controller;

  StreamSubscription? _videoStateSub;
  StreamSubscription<YoutubePlayerValue>? _valueSub;

  Duration _pos = Duration.zero;
  bool _isScrubbing = false;

  // Tiny leads so highlights feel slightly ahead of the audio.
  static const _segmentLead = Duration(milliseconds: 150);
  static const _wordLead    = Duration(milliseconds: 250);

  /// Called by AudioControls while the user drags the seekbar.
  /// While `true`, the segment/word indices freeze (position keeps
  /// flowing so widgets that show position still update).
  void setScrubbing(bool v) {
    _isScrubbing = v;
    if (!v) _recompute(); // snap immediately when released
  }

  @override
  SubtitleSyncState build() {
    _videoStateSub = _ctrl.videoStateStream.listen((s) {
      _pos = s.position;
      _recompute();
    });
    _valueSub = _ctrl.listen((_) => _recompute());

    // Recompute when the transcript becomes available.
    ref.listen<TranscriptState>(transcriptNotifierProvider, (prev, next) {
      if (prev?.status != TranscriptStatus.loaded &&
          next.status == TranscriptStatus.loaded) {
        _recompute();
      }
    });

    ref.onDispose(() {
      _videoStateSub?.cancel();
      _valueSub?.cancel();
    });

    // Kick off a compute after the subscriptions are wired up, in case
    // the transcript is already loaded by the time we got here.
    Future.microtask(_recompute);

    return const SubtitleSyncState.initial();
  }

  void _recompute() {
    final val = _ctrl.value;
    final pos = _pos;
    final isPlaying = val.playerState == PlayerState.playing;
    final duration = val.metaData.duration;
    final segments = ref.read(transcriptNotifierProvider).segments;

    // No transcript yet — just keep position/duration/isPlaying flowing.
    if (segments.isEmpty) {
      _emit(SubtitleSyncState(
        segmentIndex: -1,
        wordIndex: -1,
        position: pos,
        duration: duration,
        isPlaying: isPlaying,
      ));
      return;
    }

    // Scrubbing: freeze indices, let position/duration/isPlaying through.
    if (_isScrubbing) {
      _emit(SubtitleSyncState(
        segmentIndex: state.segmentIndex,
        wordIndex: state.wordIndex,
        position: pos,
        duration: duration,
        isPlaying: isPlaying,
      ));
      return;
    }

    final segIdx  = _findSegmentIndex(segments, pos);
    final wordIdx = _findWordIndex(segments[segIdx].words, pos);

    _emit(SubtitleSyncState(
      segmentIndex: segIdx,
      wordIndex: wordIdx,
      position: pos,
      duration: duration,
      isPlaying: isPlaying,
    ));
  }

  void _emit(SubtitleSyncState next) {
    if (next != state) state = next;
  }

  /// Greatest segment whose `startTime - lead <= pos`. Clamps to 0..n-1.
  int _findSegmentIndex(List<TranscriptSegment> segs, Duration pos) {
    int lo = 0, hi = segs.length - 1, best = 0;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (segs[mid].startTime - _segmentLead <= pos) {
        best = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return best;
  }

  /// Word whose midpoint (minus a small lead) is the latest still <= pos.
  int _findWordIndex(List<Word> words, Duration pos) {
    if (words.isEmpty) return -1;
    int lo = 0, hi = words.length - 1, best = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final midT = words[mid].start +
          (words[mid].end - words[mid].start) ~/ 2 -
          _wordLead;
      if (midT <= pos) {
        best = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return best == -1 ? 0 : best;
  }
}

final subtitleSyncProvider =
    NotifierProvider<SubtitleSyncNotifier, SubtitleSyncState>(SubtitleSyncNotifier.new);
