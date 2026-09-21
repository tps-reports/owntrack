import 'package:flutter/material.dart';
import 'package:owntrack/core/utils/app_logger.dart';
import 'package:owntrack/data/repositories/settings_repository.dart';

/// Resolves startup credential conflicts without displaying credential values.
class CredentialConflictScreen extends StatefulWidget {
  const CredentialConflictScreen({
    super.key,
    required this.conflict,
    required this.onReload,
  });

  final CredentialMigrationConflict conflict;
  final VoidCallback onReload;

  @override
  State<CredentialConflictScreen> createState() =>
      _CredentialConflictScreenState();
}

class _CredentialConflictScreenState extends State<CredentialConflictScreen> {
  final Map<String, CredentialSource> _choices = {};
  bool _busy = false;
  bool _confirming = false;
  bool _failed = false;
  bool _completed = false;

  bool get _available => !_busy && !_failed && !_completed;
  bool get _completeChoices =>
      widget.conflict.conflicts.isNotEmpty &&
      widget.conflict.conflicts.every((item) => _choices.containsKey(item.key));

  String _sourceLabel(CredentialSource source) => switch (source) {
    CredentialSource.secure => 'Stored on this device',
    CredentialSource.legacy => 'Restored settings',
  };

  Future<void> _review() async {
    if (!_available || !_completeChoices) return;
    final choices = Map<String, CredentialSource>.unmodifiable(_choices);
    setState(() {
      _busy = true;
      _confirming = true;
    });
    var resolved = false;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Keep these credentials?'),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in widget.conflict.conflicts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${item.label}: ${_sourceLabel(choices[item.key]!)}',
                  ),
                ),
              const Text(
                'The unselected versions will be permanently discarded. '
                'Discarded encryption keys may be needed to recover older '
                'queued messages. Continue only if you have kept any copies '
                'you need.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Use chosen credentials'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      setState(() => _confirming = false);
      if (confirmed != true) return;
      await widget.conflict.resolve(choices);
      if (!mounted) return;
      setState(() => _completed = true);
      resolved = true;
    } catch (error, stack) {
      AppLogger.e('Credential recovery failed.', error.runtimeType, stack);
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _confirming = false;
        });
      }
    }
    if (mounted && resolved) widget.onReload();
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Choose saved credentials')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Your device has two different saved versions of these '
                  'credentials. Choose which version to keep for each item '
                  'before the app connects. No credential values are displayed.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Stored on this device: credentials already in this app’s '
                  'credential store.\n\nRestored settings: credentials found '
                  'in older or restored settings.',
                ),
                const SizedBox(height: 16),
                if (_busy && !_confirming) ...[
                  const LinearProgressIndicator(
                    semanticsLabel: 'Updating saved credentials',
                  ),
                  const SizedBox(height: 16),
                ],
                if (_failed) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      'Unable to update saved credentials. Reload saved '
                      'settings to check the current copies before trying '
                      'again. The app has not connected.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_completed) ...[
                  Semantics(
                    liveRegion: true,
                    child: const Text(
                      'Credentials updated. Reloading saved settings.',
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                for (final item in widget.conflict.conflicts)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              item.label,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          RadioGroup<CredentialSource>(
                            groupValue: _choices[item.key],
                            onChanged: (source) {
                              if (_available && source != null) {
                                setState(() => _choices[item.key] = source);
                              }
                            },
                            child: Column(
                              children: [
                                for (final source in CredentialSource.values)
                                  RadioListTile<CredentialSource>(
                                    key: ValueKey(
                                      'credential-${item.key}-${source.name}',
                                    ),
                                    value: source,
                                    enabled: _available,
                                    title: Text(_sourceLabel(source)),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                if (!_completeChoices)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text('Choose a source for every item to continue.'),
                  ),
                FilledButton(
                  onPressed: _available && _completeChoices ? _review : null,
                  child: const Text('Review choices'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: !_busy && !_completed ? widget.onReload : null,
                  child: const Text('Reload saved settings'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
