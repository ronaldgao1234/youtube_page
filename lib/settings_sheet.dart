import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'prefs.dart';
import 'theme.dart';

Future<void> showTranscriptSettingsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(prefsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // small grab indicator
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Translation display',
              style: AppText.serif(size: 20, weight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Where to show the English translation',
              style: AppText.sans(size: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 8),
            _ModeTile(
              label: 'Active segment only',
              subtitle: 'Translation appears under the line currently playing',
              value: TranslationMode.activeOnly,
              groupValue: prefs.translationMode,
              onChanged: (v) =>
                  ref.read(prefsProvider.notifier).setTranslationMode(v),
            ),
            _ModeTile(
              label: 'All segments',
              subtitle: 'Translation under every line in the transcript',
              value: TranslationMode.allSegments,
              groupValue: prefs.translationMode,
              onChanged: (v) =>
                  ref.read(prefsProvider.notifier).setTranslationMode(v),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final TranslationMode value;
  final TranslationMode groupValue;
  final ValueChanged<TranslationMode> onChanged;

  const _ModeTile({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentDim : AppColors.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.accent : AppColors.muted,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppText.sans(
                      size: 15,
                      weight: FontWeight.w500,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppText.sans(size: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
