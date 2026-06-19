import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'audio_controls.dart';
import 'config.dart';
import 'player_manager.dart';
import 'subtitle_sync.dart';
import 'theme.dart';
import 'transcript_notifier.dart';
import 'transcript_panel.dart';
import 'video_overlay.dart';
import 'prefs.dart';

class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({super.key});

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  late final YoutubePlayerController _ctrl;

  @override
  void initState() {
    super.initState();
    // Initialize the controller (paused — kicks off load, no autoplay).
    _ctrl = PlayerManager.instance.controllerFor(kVideoId);

    // Touch providers so they start listening / loading.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(transcriptNotifierProvider);
      ref.read(prefsProvider);
      ref.read(subtitleSyncProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerControllerProvider(
      controller: _ctrl,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          // Bottom handled per-layout so the portrait control bar can paint
          // its background through the home-indicator inset.
          bottom: false,
          child: OrientationBuilder(
            builder: (context, orientation) {
              return orientation == Orientation.landscape
                  ? const _LandscapeLayout()
                  : const _PortraitLayout();
            },
          ),
        ),
      ),
    );
  }
}

// ── Video block: iframe + play/pause overlay ──────────────────────────────

class _VideoBlock extends ConsumerWidget {
  final BorderRadius borderRadius;

  const _VideoBlock({required this.borderRadius});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = ref.watch(
      subtitleSyncProvider.select((s) => s.isPlaying),
    );

    return ClipRRect(
      borderRadius: borderRadius,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          children: [
            Positioned.fill(
              child: YoutubePlayer(
                controller: PlayerManager.instance.controller,
                aspectRatio: 16 / 9,
                autoFullScreen: false, // ← don't take over the screen on rotate
                enableFullScreenOnVerticalDrag:
                    false, // ← don't fullscreen on swipe-up
              ),
            ),
            PlayOverlay(
              isVisible: !isPlaying,
              onTap: () {
                if (isPlaying) {
                  PlayerManager.instance.pause();
                } else {
                  PlayerManager.instance.play();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Landscape: left column (centered video + controls) | right transcript ─

class _LandscapeLayout extends StatelessWidget {
  const _LandscapeLayout();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 65,
          child: Center(
            // LayoutBuilder gives us a bounded width to hand to the column,
            // so AudioControls' Expanded slider has finite width constraints
            // (Center alone would loosen them and throw).
            child: LayoutBuilder(
              builder: (context, constraints) {
                final blockWidth =
                    constraints.maxWidth - 24; // horizontal breathing room
                return SizedBox(
                  width: blockWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      _VideoBlock(
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                      ),
                      SizedBox(height: 12),
                      AudioControls(),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        Container(width: 1, color: AppColors.border),
        const Expanded(flex: 35, child: TranscriptPanel()),
      ],
    );
  }
}

// ── Portrait: video → transcript → controls (top to bottom) ───────────────

class _PortraitLayout extends StatelessWidget {
  const _PortraitLayout();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: _VideoBlock(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        const Expanded(child: TranscriptPanel()),
        Container(
          // Background fills through the home-indicator inset; the controls
          // themselves stay above it via the bottom padding.
          padding: EdgeInsets.only(bottom: bottomInset),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border, width: 1)),
          ),
          child: const AudioControls(),
        ),
      ],
    );
  }
}
