import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/settings_service.dart';
import '../../l10n/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(l10n.settings, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.aiConfiguration, style: theme.textTheme.titleMedium),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: settings.baseUrl,
                  decoration: InputDecoration(
                    labelText: l10n.apiBaseUrl,
                    border: const OutlineInputBorder(),
                    helperText: 'e.g. https://api.openai.com',
                  ),
                  onChanged: (value) {
                    ref.read(settingsProvider.notifier).setBaseUrl(value);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: settings.modelName,
                  decoration: InputDecoration(
                    labelText: l10n.modelName,
                    border: const OutlineInputBorder(),
                    helperText: 'e.g. gpt-4-vision-preview, gemini-1.5-pro',
                  ),
                  onChanged: (value) {
                    ref.read(settingsProvider.notifier).setModelName(value);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: settings.apiKey,
                  decoration: InputDecoration(
                    labelText: l10n.apiKey,
                    border: const OutlineInputBorder(),
                    helperText: 'sk-...',
                  ),
                  obscureText: true,
                  onChanged: (value) {
                    ref.read(settingsProvider.notifier).setApiKey(value);
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: Text(l10n.autoGenerate),
                subtitle: Text(l10n.autoGenerateSubtitle),
                value: settings.autoGenerate,
                onChanged: (value) {
                  ref.read(settingsProvider.notifier).setAutoGenerate(value);
                },
              ),
              SwitchListTile(
                title: Text(l10n.pseudoKBMode),
                subtitle: Text(l10n.pseudoKBModeSubtitle),
                value: settings.enablePseudoKBMode,
                onChanged: (value) {
                  ref.read(settingsProvider.notifier).setEnablePseudoKBMode(value);
                },
              ),
              if (settings.autoGenerate)
                ListTile(
                  title: Text(l10n.debounceDelay),
                  subtitle: Text(l10n.debounceDelaySubtitle(settings.debounceSeconds)),
                  trailing: SizedBox(
                    width: 150,
                    child: Slider(
                      value: settings.debounceSeconds.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: '${settings.debounceSeconds}s',
                      onChanged: (value) {
                        ref.read(settingsProvider.notifier).setDebounceSeconds(value.round());
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reading Direction', style: theme.textTheme.titleMedium),
                const SizedBox(height: 16),
                SegmentedButton<ReadingDirection>(
                  segments: const [
                    ButtonSegment(
                      value: ReadingDirection.vertical,
                      label: Text('Vertical'),
                      icon: Icon(Icons.swap_vert),
                    ),
                    ButtonSegment(
                      value: ReadingDirection.horizontal,
                      label: Text('Horizontal'),
                      icon: Icon(Icons.swap_horiz),
                    ),
                  ],
                  selected: {settings.readingDirection},
                  onSelectionChanged: (Set<ReadingDirection> newSelection) {
                    ref.read(settingsProvider.notifier).setReadingDirection(newSelection.first);
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
