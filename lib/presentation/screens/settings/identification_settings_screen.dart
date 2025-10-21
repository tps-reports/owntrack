import 'package:flutter/material.dart';

/// Identification settings screen for device and tracker ID configuration
class IdentificationSettingsScreen extends StatefulWidget {
  const IdentificationSettingsScreen({super.key});

  @override
  State<IdentificationSettingsScreen> createState() =>
      _IdentificationSettingsScreenState();
}

class _IdentificationSettingsScreenState
    extends State<IdentificationSettingsScreen> {
  final TextEditingController _deviceIdController = TextEditingController();
  final TextEditingController _trackerIdController =
      TextEditingController(text: 'XX');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Identification'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: 'Save',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Device Identification',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'These IDs identify your device in the OwnTracks network',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _deviceIdController,
                    decoration: const InputDecoration(
                      labelText: 'Device ID',
                      hintText: 'e.g., username',
                      border: OutlineInputBorder(),
                      helperText: 'Your username or device identifier',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _trackerIdController,
                    decoration: const InputDecoration(
                      labelText: 'Tracker ID',
                      hintText: 'XX',
                      border: OutlineInputBorder(),
                      helperText: '2-character tracker identifier (e.g., P1, XX)',
                    ),
                    maxLength: 2,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Topic Structure',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your MQTT topic will be:',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'owntracks/${_deviceIdController.text.isEmpty ? "username" : _deviceIdController.text}/${_trackerIdController.text.isEmpty ? "XX" : _trackerIdController.text}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontFamily: 'monospace',
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _saveSettings() {
    // TODO: Save settings to repository
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved')),
    );
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _deviceIdController.dispose();
    _trackerIdController.dispose();
    super.dispose();
  }
}
