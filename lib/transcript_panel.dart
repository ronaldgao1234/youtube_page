import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'player_manager.dart';
import 'prefs.dart';
import 'subtitle_sync.dart';
import 'theme.dart';
import 'transcript_notifier.dart';

class TranscriptPanel extends ConsumerStatefulWidget {
  const TranscriptPanel({super.key});

  @override
  ConsumerState<TranscriptPanel> createState() => _TranscriptPanelState();
}

class _TranscriptPanelState extends ConsumerState<TranscriptPanel> {
  final ItemScrollController _itemController = ItemScrollController();
  final ItemPositionsListener _positionsListener =
      ItemPositionsListener.create();

  Timer? _followDelayTimer;

  // True while WE are driving a scroll. Used to ignore the scroll
  // notifications our own programmatic scrolls generate, so they're
  // never mistaken for user drags. Also gates overlapping glides so a
  // new target doesn't cancel-and-restart an in-flight one (which stutters).
  bool _autoScrolling = false;

  // True while the user is dragging the transcript. While true, we don't
  // auto-follow the active segment.
  bool _isUserScrolling = false;

  bool _didInitialSnap = false;

  static const _followDelay = Duration(seconds: 2);
  static const _snapDuration = Duration(milliseconds: 600);
  static const _activeAlign = 0.4; // 0=top, 0.5=middle. Slightly above center.

  // Translations show for the active segment plus this many on each side,
  // giving a moving window of (2 * _halfWindow + 1) = 9 translated segments.
  static const _halfWindow = 4;

  // ── Scroll helpers ──────────────────────────────────────────────────────

  Future<void> _scrollTo(int index, {bool instant = false}) async {
    if (!_itemController.isAttached) return;
    // Let an in-flight glide finish rather than cancel/restart it (the
    // restart is what produces a micro-stutter). Instant jumps always win
    // because they're user-initiated (initial snap / tap) and must land now.
    if (_autoScrolling && !instant) return;
    _autoScrolling = true;
    try {
      if (instant) {
        _itemController.jumpTo(index: index, alignment: _activeAlign);
        // jumpTo is synchronous but still emits notifications on the next
        // frame; hold the guard until that frame passes.
        await Future<void>.delayed(Duration.zero);
      } else {
        // Linear curve blends consecutive hops into a near-continuous
        // downward drift while playing; easeOut decelerated into each
        // target and read as a recoil when the next target arrived.
        await _itemController.scrollTo(
          index: index,
          alignment: _activeAlign,
          duration: _snapDuration,
          curve: Curves.linear,
        );
      }
    } finally {
      _autoScrolling = false;
    }
  }

  /// Reacts to every sync state change. Only acts when the active segment
  /// actually changes. Highlight is driven separately by the provider, so
  /// this is purely about moving the list.
  void _onSyncChange(SubtitleSyncState? prev, SubtitleSyncState next) {
    if (next.segmentIndex < 0) return;

    final segmentChanged = prev?.segmentIndex != next.segmentIndex;
    if (!segmentChanged) return;

    // Don't fight the user while they're scrolling.
    if (_isUserScrolling) return;

    // Near the list ends the segment physically can't reach alignment 0.4
    // (not enough content past it), so a scrollTo there would clamp — and a
    // clamped scroll re-resolving against a window-edge height change is the
    // edge bounce. In this zone the segment is already on screen anyway, so
    // just don't follow. The user still sees it; we simply stop nudging.
    final total = ref.read(transcriptNotifierProvider).segments.length;
    final nearEdge =
        next.segmentIndex < _halfWindow ||
        next.segmentIndex >= total - _halfWindow;
    if (nearEdge) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollTo(next.segmentIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SubtitleSyncState>(subtitleSyncProvider, _onSyncChange);

    final tsState = ref.watch(transcriptNotifierProvider);
    final prefs = ref.watch(prefsProvider);
    final sync = ref.watch(subtitleSyncProvider);

    if (tsState.status == TranscriptStatus.loading ||
        tsState.status == TranscriptStatus.initial) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    if (tsState.status == TranscriptStatus.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tsState.errorMessage ?? 'Error loading transcript',
              style: AppText.sans(size: 14, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () =>
                  ref.read(transcriptNotifierProvider.notifier).refresh(),
              child: Text(
                'Retry',
                style: AppText.sans(size: 14, color: AppColors.accent),
              ),
            ),
          ],
        ),
      );
    }

    final segments = tsState.segments;
    final activeSeg = sync.segmentIndex;
    final activeWord = sync.wordIndex;

    // ── Initial snap once both transcript & sync have a valid index. ──────
    if (!_didInitialSnap && segments.isNotEmpty && activeSeg >= 0) {
      _didInitialSnap = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollTo(activeSeg, instant: true);
      });
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        // Ignore everything our own programmatic scrolls produce.
        if (_autoScrolling) return false;

        final isDrag =
            (n is ScrollStartNotification && n.dragDetails != null) ||
            (n is ScrollUpdateNotification && n.dragDetails != null);

        if (isDrag) {
          _isUserScrolling = true;
          _followDelayTimer?.cancel();
        } else if (n is ScrollEndNotification) {
          // Re-arm auto-follow 2s after the finger lifts. The timer ONLY
          // clears the flag — it never scrolls. The next genuine segment
          // change drives the actual scroll. This is what prevents the
          // self-sustaining bounce.
          _followDelayTimer?.cancel();
          _followDelayTimer = Timer(_followDelay, () {
            _isUserScrolling = false;
          });
        }
        return false;
      },
      child: ScrollablePositionedList.builder(
        itemCount: segments.length,
        itemScrollController: _itemController,
        itemPositionsListener: _positionsListener,
        // Small constant slack — same in portrait and landscape (a viewport
        // fraction made portrait's tall pane over-scroll badly). The first/
        // last couple of segments won't sit exactly at 0.4, but _onSyncChange
        // skips the follow scroll near the ends, so there's no clamped
        // scrollTo to re-resolve and thus no edge bounce.
        padding: const EdgeInsets.symmetric(vertical: 24),
        itemBuilder: (context, i) {
          final isActive = i == activeSeg;

          // A moving band of translations centered on the active segment.
          final inWindow =
              activeSeg >= 0 && (i - activeSeg).abs() <= _halfWindow;

          final showTranslation =
              prefs.translationMode == TranslationMode.allSegments ||
              (prefs.translationMode == TranslationMode.activeOnly && inWindow);

          return _SegmentRow(
            segment: segments[i],
            isActive: isActive,
            activeWordIndex: isActive ? activeWord : -1,
            fontSize: prefs.fontSize,
            showTranslation: showTranslation,
            onTapSegment: () => _onSegmentTap(i, segments[i].startTime),
          );
        },
      ),
    );
  }

  Future<void> _onSegmentTap(int index, Duration startTime) async {
    // Seek without pausing — the video keeps its current play state.
    await PlayerManager.instance.controller.seekTo(
      seconds: startTime.inMicroseconds / 1e6,
      allowSeekAhead: true,
    );
    // User explicitly chose this row — resume following immediately and
    // snap to it now.
    _followDelayTimer?.cancel();
    _isUserScrolling = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollTo(index, instant: true);
    });
  }

  @override
  void dispose() {
    _followDelayTimer?.cancel();
    super.dispose();
  }
}

// ── Segment row ───────────────────────────────────────────────────────────

class _SegmentRow extends StatelessWidget {
  final TranscriptSegment segment;
  final bool isActive;
  final int activeWordIndex;
  final double fontSize;
  final bool showTranslation;
  final VoidCallback onTapSegment;

  const _SegmentRow({
    required this.segment,
    required this.isActive,
    required this.activeWordIndex,
    required this.fontSize,
    required this.showTranslation,
    required this.onTapSegment,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Tapping the background (between words) seeks to this segment.
      behavior: HitTestBehavior.opaque,
      onTap: onTapSegment,
      // Plain Container, NOT AnimatedContainer: this widget's height is
      // determined by its content (words + optional translation). Animating
      // the highlight here would be fine for color, but we keep the height
      // change instantaneous so the list's scroll target never drifts
      // mid-animation — that drift was the source of the bounce.
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Stack(
          children: [
            // Highlight is a background fill behind the content. Animating
            // its color/opacity here never changes the row's measured size,
            // so the active-segment scroll target stays stable.
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.accentDim : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 4,
                    runSpacing: 6,
                    children: [
                      for (int w = 0; w < segment.words.length; w++)
                        _WordChip(
                          word: segment.words[w],
                          isActive: w == activeWordIndex,
                          fontSize: fontSize,
                          onTap: () {
                            // Active segment: tap a word → word popup.
                            // Inactive segment: tap a word → seek to segment.
                            if (isActive) {
                              _showWordDialog(context, segment.words[w]);
                            } else {
                              onTapSegment();
                            }
                          },
                        ),
                    ],
                  ),
                  // Non-reserved: the translation block only occupies space
                  // when shown, so rows outside the window are visibly
                  // shorter than translated rows inside the window.
                  if (showTranslation) ...[
                    const SizedBox(height: 8),
                    Text(
                      segment.translation,
                      style: AppText.sans(
                        size: fontSize * 0.7,
                        color: AppColors.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Word chip ────────────────────────────────────────────────────────────

class _WordChip extends StatelessWidget {
  final Word word;
  final bool isActive;
  final double fontSize;
  final VoidCallback onTap;

  const _WordChip({
    required this.word,
    required this.isActive,
    required this.fontSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(
            color: isActive ? AppColors.accent : Colors.transparent,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          word.text,
          style: AppText.sans(
            size: fontSize,
            color: AppColors.text,
            weight: FontWeight.w400,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

// ── Word dialog ──────────────────────────────────────────────────────────

Future<void> _showWordDialog(BuildContext context, Word word) async {
  final wasPlaying = PlayerManager.instance.isPlaying;
  if (wasPlaying) PlayerManager.instance.pause();

  await showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.6),
    builder: (_) => Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 36, 32, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              word.text,
              textAlign: TextAlign.center,
              style: AppText.serif(
                size: 56,
                weight: FontWeight.w500,
                color: AppColors.accent,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: AppText.sans(
                  size: 14,
                  color: AppColors.muted,
                  weight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  if (wasPlaying) PlayerManager.instance.play();
}
