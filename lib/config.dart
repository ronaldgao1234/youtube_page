/// ─────────────────────────────────────────────────────────────
///                     PLAYER PAGE CONFIG
///   Edit the constants below to point at your video, choose the
///   transcript source, and tune the layout / visible controls
///   (handy for recording clean marketing footage).
/// ─────────────────────────────────────────────────────────────

/// Paste the YouTube video ID here (the part after `?v=` in the URL).
const String kVideoId = 'dQw4w9WgXcQ';

/// Where the transcript JSON comes from.
///   `.toy`   → use `kToyTranscriptJson` defined in `toy_transcript.dart`
///              (good for UI iteration without a real transcript yet).
///   `.asset` → load `assets/transcription.json` from the app bundle.
const TranscriptSource kTranscriptSource = TranscriptSource.toy;

enum TranscriptSource { toy, asset }

// ─────────────────────────────────────────────────────────────
//                    TRANSCRIPT LAYOUT
// ─────────────────────────────────────────────────────────────

/// Vertical anchor for the active segment, 0 = top, 0.5 = middle.
/// Lower values keep the active line higher up the panel — handy when you
/// want to crop a recording to just the video + the first few segments.
const double kActiveAlign = 0.22;

/// Horizontal breathing room on each side of the transcript text.
/// Larger = the transcript feels more centered / inset.
const double kTranscriptHorizontalPadding = 28;

/// Vertical gap between transcript segments.
const double kSegmentSpacing = 10;

/// Landscape column split between the left (video + controls) column and
/// the right (transcript) column. These are relative flex weights, not
/// percentages — e.g. 65/35 means the left column gets 65 parts of width
/// for every 35 the transcript gets. Use any positive numbers.
const int kLandscapeLeftFlex = 65;
const int kLandscapeTranscriptFlex = 35;

// ─────────────────────────────────────────────────────────────
//                    TRANSCRIPT DISPLAY (fixed)
//   These were previously user-adjustable; now set here directly.
// ─────────────────────────────────────────────────────────────

/// Transcript (Spanish word) font size, in logical pixels.
const double kFontSize = 26;

/// Translation (English line) font size, in logical pixels.
const double kTranslationFontSize = 18;

/// Which translation(s) to show.
///   `.activeOnly`   → only the moving window around the active segment.
///   `.allSegments`  → every segment's translation, always.
const TranscriptTranslationMode kTranslationMode =
    TranscriptTranslationMode.activeOnly;

enum TranscriptTranslationMode { activeOnly, allSegments }

// ─────────────────────────────────────────────────────────────
//                    VISIBLE CONTROLS
//   Toggle chrome off for clean recordings.
// ─────────────────────────────────────────────────────────────

/// Show the seekbar (position slider + timestamps). Default OFF.
const bool kShowSeekbar = false;
