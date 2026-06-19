/// ─────────────────────────────────────────────────────────────
///                     PLAYER PAGE CONFIG
///   Edit the two constants below to point at your video and
///   choose between the inline toy transcript and the bundled
///   asset file.
/// ─────────────────────────────────────────────────────────────

/// Paste the YouTube video ID here (the part after `?v=` in the URL).
const String kVideoId = 'dQw4w9WgXcQ';

/// Where the transcript JSON comes from.
///   `.toy`   → use `kToyTranscriptJson` defined in `toy_transcript.dart`
///              (good for UI iteration without a real transcript yet).
///   `.asset` → load `assets/transcription.json` from the app bundle.
const TranscriptSource kTranscriptSource = TranscriptSource.toy;

enum TranscriptSource { toy, asset }
