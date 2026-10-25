import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../l10n/generated/app_localizations.dart';

class LanguagePicker extends StatelessWidget {
  const LanguagePicker({
    required this.locale,
    required this.onChanged,
    this.iconOnly = true,
    super.key,
  });

  final Locale locale;
  final Future<void> Function(Locale locale) onChanged;
  final bool iconOnly;

  static const _languages = [
    (code: 'en', label: 'English'),
    (code: 'hi', label: 'हिन्दी'),
    (code: 'pa', label: 'ਪੰਜਾਬੀ'),
  ];

  @override
  Widget build(BuildContext context) {
    final strings = appStrings(context);
    return IconButton(
      tooltip: strings.language,
      onPressed: () => _showPicker(context, strings),
      icon: iconOnly
          ? const Icon(Icons.translate_rounded)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.translate_rounded),
                const SizedBox(width: 6),
                Text(locale.languageCode.toUpperCase()),
              ],
            ),
    );
  }

  Future<void> _showPicker(
    BuildContext context,
    AppLocalizations strings,
  ) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                strings.language,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (final language in _languages)
              ListTile(
                leading: Icon(
                  locale.languageCode == language.code
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                title: Text(language.label),
                onTap: () => Navigator.pop(context, language.code),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected == null || !context.mounted) return;
    try {
      await onChanged(Locale(selected));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save language preference: $error')),
      );
    }
  }
}
