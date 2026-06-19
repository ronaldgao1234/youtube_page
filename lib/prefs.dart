import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TranslationMode { activeOnly, allSegments }

class TranscriptPrefs {
  final double fontSize;
  final TranslationMode translationMode;

  const TranscriptPrefs({
    required this.fontSize,
    required this.translationMode,
  });

  TranscriptPrefs copyWith({
    double? fontSize,
    TranslationMode? translationMode,
  }) {
    return TranscriptPrefs(
      fontSize: fontSize ?? this.fontSize,
      translationMode: translationMode ?? this.translationMode,
    );
  }
}

/// Cycle order for the font-size button.
const List<double> kFontSizePresets = [16, 20, 24, 28];
const double kDefaultFontSize = 20;
const TranslationMode kDefaultTranslationMode = TranslationMode.activeOnly;

class PrefsNotifier extends Notifier<TranscriptPrefs> {
  SharedPreferences? _prefs;

  static const _kFontSize        = 'transcript_font_size';
  static const _kTranslationMode = 'transcript_translation_mode';

  @override
  TranscriptPrefs build() {
    _init(); // fire-and-forget; UI gets defaults instantly and rebuilds when loaded
    return const TranscriptPrefs(
      fontSize: kDefaultFontSize,
      translationMode: kDefaultTranslationMode,
    );
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    state = TranscriptPrefs(
      fontSize: _prefs!.getDouble(_kFontSize) ?? kDefaultFontSize,
      translationMode: TranslationMode.values[
          _prefs!.getInt(_kTranslationMode) ?? kDefaultTranslationMode.index],
    );
  }

  Future<void> cycleFontSize() async {
    final idx = kFontSizePresets.indexOf(state.fontSize);
    final next = kFontSizePresets[(idx + 1) % kFontSizePresets.length];
    state = state.copyWith(fontSize: next);
    await _prefs?.setDouble(_kFontSize, next);
  }

  Future<void> setTranslationMode(TranslationMode mode) async {
    state = state.copyWith(translationMode: mode);
    await _prefs?.setInt(_kTranslationMode, mode.index);
  }
}

final prefsProvider =
    NotifierProvider<PrefsNotifier, TranscriptPrefs>(PrefsNotifier.new);
