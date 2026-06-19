import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config.dart';
import 'player_manager.dart';
import 'subtitle_sync.dart';
import 'theme.dart';
import 'transcript_notifier.dart';

/// The (optional) seekbar + button row. Reused in both portrait and
/// landscape layouts. The seekbar is shown only when [kShowSeekbar] is true;
/// the font-size and translation-toggle buttons have been removed (those
/// settings are now fixed in config).
class AudioControls extends ConsumerStatefulWidget {
  const AudioControls({super.key});

  @override
  ConsumerState<AudioControls> createState() => _AudioControlsState();
}

class _AudioControlsState extends ConsumerState<AudioControls> {
  /// While the user is dragging the slider this holds the local drag value.
  /// `null` when idle — slider then mirrors `sync.position`.
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final sync = ref.watch(subtitleSyncProvider);
    final segments = ref.watch(transcriptNotifierProvider).segments;

    final totalSecs = sync.duration.inMicroseconds / 1e6;
    final hasDuration = totalSecs > 0;
    final livePosSecs = sync.position.inMicroseconds / 1e6;
    final displaySecs = _dragValue ?? livePosSecs;
    final displayPos = Duration(microseconds: (displaySecs * 1e6).round());

    final canPrev = sync.segmentIndex > 0;
    final canNext =
        sync.segmentIndex >= 0 && sync.segmentIndex < segments.length - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Seekbar row (optional) ─────────────────────────────────────
          if (kShowSeekbar)
            Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    _fmt(displayPos),
                    style: AppText.sans(size: 12, color: AppColors.muted),
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.accent,
                      inactiveTrackColor: AppColors.border,
                      thumbColor: AppColors.accent,
                      overlayColor: AppColors.accentDim,
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 7,
                        pressedElevation: 0,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 16,
                      ),
                    ),
                    child: Slider(
                      min: 0,
                      max: hasDuration ? totalSecs : 1,
                      value: hasDuration
                          ? displaySecs.clamp(0, totalSecs).toDouble()
                          : 0,
                      onChangeStart: hasDuration
                          ? (v) {
                              ref
                                  .read(subtitleSyncProvider.notifier)
                                  .setScrubbing(true);
                              setState(() => _dragValue = v);
                            }
                          : null,
                      onChanged: hasDuration
                          ? (v) => setState(() => _dragValue = v)
                          : null,
                      onChangeEnd: hasDuration
                          ? (v) async {
                              await PlayerManager.instance.controller.seekTo(
                                seconds: v,
                                allowSeekAhead: true,
                              );
                              ref
                                  .read(subtitleSyncProvider.notifier)
                                  .setScrubbing(false);
                              setState(() => _dragValue = null);
                            }
                          : null,
                    ),
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    hasDuration ? _fmt(sync.duration) : '--:--',
                    textAlign: TextAlign.right,
                    style: AppText.sans(size: 12, color: AppColors.muted),
                  ),
                ),
              ],
            ),
          // ── Button row ─────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _CircleBtn(
                icon: Icons.skip_previous,
                enabled: canPrev,
                onTap: canPrev
                    ? () => _seekToSegment(segments, sync.segmentIndex - 1)
                    : null,
              ),
              _CircleBtn(
                icon: sync.isPlaying ? Icons.pause : Icons.play_arrow,
                large: true,
                onTap: () {
                  if (sync.isPlaying) {
                    PlayerManager.instance.pause();
                  } else {
                    PlayerManager.instance.play();
                  }
                },
              ),
              _CircleBtn(
                icon: Icons.skip_next,
                enabled: canNext,
                onTap: canNext
                    ? () => _seekToSegment(segments, sync.segmentIndex + 1)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _seekToSegment(List<TranscriptSegment> segments, int idx) {
    final t = segments[idx].startTime;
    PlayerManager.instance.controller.seekTo(
      seconds: t.inMicroseconds / 1e6,
      allowSeekAhead: true,
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;
  final bool large;

  const _CircleBtn({
    required this.icon,
    this.onTap,
    this.enabled = true,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = large ? 52.0 : 40.0;
    final iconSize = large ? 30.0 : 22.0;
    final color = enabled
        ? (large ? AppColors.accent : AppColors.text)
        : AppColors.muted;
    final bg = large ? AppColors.accentDim : Colors.transparent;

    return InkResponse(
      onTap: onTap,
      radius: size * 0.7,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
        child: Icon(icon, size: iconSize, color: color),
      ),
    );
  }
}
