import 'package:flutter/material.dart';

/// Sits as a Positioned.fill over the YouTube iframe. The whole video area
/// is a tap target that toggles play/pause; a translucent veil + icon fades
/// in when paused, out when playing.
class PlayOverlay extends StatelessWidget {
  final bool isVisible;       // show veil/icon (true when paused)
  final VoidCallback onTap;   // toggle play/pause

  const PlayOverlay({
    super.key,
    required this.isVisible,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Show instantly when pausing, fade out when resuming playback.
    final duration =
        isVisible ? Duration.zero : const Duration(milliseconds: 250);

    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1) Always-on tap catcher (works whether the veil is visible or not)
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onTap,
          ),
          // 2) Visual veil + icon — never intercepts taps
          IgnorePointer(
            ignoring: true,
            child: AnimatedOpacity(
              opacity: isVisible ? 1 : 0,
              duration: duration,
              curve: Curves.easeOut,
              child: Container(
                color: Colors.black.withOpacity(0.35),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.play_arrow,
                  size: 72,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
