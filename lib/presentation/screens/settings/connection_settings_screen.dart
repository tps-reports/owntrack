import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:owntrack/core/constants/app_constants.dart';
import 'package:owntrack/domain/providers/app_providers.dart';

/// Connection settings screen for MQTT and HTTP configuration
class ConnectionSettingsScreen extends ConsumerStatefulWidget {
  const ConnectionSettingsScreen({super.key});

  @override
  ConsumerState<ConnectionSettingsScreen> createState() =>
      _ConnectionSettingsScreenState();
}

class _ConnectionSettingsScreenState extends ConsumerState<ConnectionSettingsScreen> {
  String _connectionMode = AppConstants.connectionModeMqtt;

  // MQTT settings
  final TextEditingController _mqttHostController = TextEditingController();
  final TextEditingController _mqttPortController =
      TextEditingController(text: '1883');
  final TextEditingController _mqttUsernameController =
      TextEditingController();
  final TextEditingController _mqttPasswordController =
      TextEditingController();
  final TextEditingController _mqttClientIdController =
      TextEditingController();
  bool _mqttUseTls = false;

  // HTTP settings
  final TextEditingController _httpUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final settingsRepo = ref.read(settingsRepositoryProvider);

    setState(() {
      _connectionMode = settingsRepo.getConnectionMode();
      _mqttHostController.text = settingsRepo.getMqttHost();
      _mqttPortController.text = settingsRepo.getMqttPort().toString();
      _mqttUseTls = settingsRepo.getMqttUseTls();
      _mqttUsernameController.text = settingsRepo.getMqttUsername();
      _mqttPasswordController.text = settingsRepo.getMqttPassword();
      _mqttClientIdController.text = settingsRepo.getMqttClientId();
      _httpUrlController.text = settingsRepo.getHttpUrl();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connection'),
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
          // Connection mode selector
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connection Mode',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: AppConstants.connectionModeMqtt,
                        label: Text('MQTT'),
                        icon: Icon(Icons.cloud),
                      ),
                      ButtonSegment(
                        value: AppConstants.connectionModeHttp,
                        label: Text('HTTP'),
                        icon: Icon(Icons.http),
                      ),
                    ],
                    selected: {_connectionMode},
                    onSelectionChanged: (selected) {
                      setState(() {
                        _connectionMode = selected.first;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // MQTT settings
          if (_connectionMode == AppConstants.connectionModeMqtt) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MQTT Broker',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _mqttHostController,
                      decoration: const InputDecoration(
                        labelText: 'Host',
                        hintText: 'mqtt.example.com',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _mqttPortController,
                      decoration: const InputDecoration(
                        labelText: 'Port',
                        hintText: '1883',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Use TLS/SSL'),
                      subtitle: const Text('Secure connection (port 8883)'),
                      value: _mqttUseTls,
                      onChanged: (value) {
                        setState(() {
                          _mqttUseTls = value;
                          _mqttPortController.text = value ? '8883' : '1883';
                        });
                      },
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
                      'Authentication',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _mqttUsernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        hintText: 'Optional',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _mqttPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        hintText: 'Optional',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _mqttClientIdController,
                      decoration: const InputDecoration(
                        labelText: 'Client ID',
                        hintText: 'Auto-generated if empty',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // HTTP settings
          if (_connectionMode == AppConstants.connectionModeHttp) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HTTP Endpoint',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _httpUrlController,
                      decoration: const InputDecoration(
                        labelText: 'URL',
                        hintText: 'https://example.com/owntracks',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The complete URL to your OwnTracks HTTP endpoint',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Test connection button
          FilledButton.icon(
            onPressed: _testConnection,
            icon: const Icon(Icons.network_check),
            label: const Text('Test Connection'),
          ),
        ],
      ),
    );
  }

  void _saveSettings() async {
    final settingsRepo = ref.read(settingsRepositoryProvider);

    // Save connection mode
    await settingsRepo.setConnectionMode(_connectionMode);

    // Save MQTT settings
    await settingsRepo.setMqttHost(_mqttHostController.text);
    await settingsRepo.setMqttPort(int.tryParse(_mqttPortController.text) ?? 1883);
    await settingsRepo.setMqttUseTls(_mqttUseTls);
    await settingsRepo.setMqttUsername(_mqttUsernameController.text);
    await settingsRepo.setMqttPassword(_mqttPasswordController.text);
    await settingsRepo.setMqttClientId(_mqttClientIdController.text);

    // Save HTTP settings
    await settingsRepo.setHttpUrl(_httpUrlController.text);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
      Navigator.of(context).pop();
    }
  }

  void _testConnection() {
    // TODO: Test connection with services
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Testing connection...')),
    );
  }

  @override
  void dispose() {
    _mqttHostController.dispose();
    _mqttPortController.dispose();
    _mqttUsernameController.dispose();
    _mqttPasswordController.dispose();
    _mqttClientIdController.dispose();
    _httpUrlController.dispose();
    super.dispose();
  }
}
