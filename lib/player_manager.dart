import 'package:youtube_player_iframe/youtube_player_iframe.dart';

/// Holds the single active YouTube controller for the page.
/// Same shape as the Chinese version, minus the language/probe bits.
class PlayerManager {
  PlayerManager._();
  static final PlayerManager instance = PlayerManager._();

  YoutubePlayerController? _controller;
  String? _videoId;

  YoutubePlayerController controllerFor(String videoId) {
    if (_controller != null && _videoId == videoId) return _controller!;
    _videoId = videoId;
    _controller = YoutubePlayerController(
      params: const YoutubePlayerParams(
        mute: false,
        showControls: false, // your overlay + AudioControls take over
        showFullscreenButton: false,
        strictRelatedVideos: true,
        enableCaption: false,
        playsInline: true,
      ),
    )..loadVideoById(videoId: videoId);
    return _controller!;
  }

  Future<void> seek(Duration target) async {
    final secs = target.inMicroseconds / 1e6;
    await _controller?.seekTo(seconds: secs, allowSeekAhead: true);
  }

  YoutubePlayerController get controller => _controller!;
  bool get isPlaying => _controller?.value.playerState == PlayerState.playing;

  void pause() => _controller?.pauseVideo();
  void play() => _controller?.playVideo();
}
