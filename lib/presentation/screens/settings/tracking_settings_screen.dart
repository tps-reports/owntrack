import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:owntrack/core/constants/app_constants.dart';
import 'package:owntrack/domain/providers/app_providers.dart';

/// Tracking settings screen for location and monitoring configuration
class TrackingSettingsScreen extends ConsumerStatefulWidget {
  const TrackingSettingsScreen({super.key});

  @override
  ConsumerState<TrackingSettingsScreen> createState() =>
      _TrackingSettingsScreenState();
}

class _TrackingSettingsScreenState extends ConsumerState<TrackingSettingsScreen> {
  int _monitoringMode = AppConstants.monitoringModeSignificant;
  bool _isTracking = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final settingsRepo = ref.read(settingsRepositoryProvider);
    setState(() {
      _monitoringMode = settingsRepo.getMonitoringMode();
      _isTracking = ref.read(trackingEnabledProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracking'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Tracking status
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isTracking ? Icons.gps_fixed : Icons.gps_off,
                        color: _isTracking ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isTracking ? 'Tracking Active' : 'Tracking Stopped',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      Switch(
                        value: _isTracking,
                        onChanged: (value) {
                          setState(() {
                            _isTracking = value;
                          });
                          _toggleTracking(value);
                        },
                      ),
                    ],
                  ),
                  if (_isTracking) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Location tracking is active in ${_getModeName(_monitoringMode)} mode',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Monitoring mode
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monitoring Mode',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  _buildModeOption(
                    mode: AppConstants.monitoringModeQuiet,
                    icon: Icons.bedtime,
                    title: 'Quiet',
                    subtitle: 'Minimal tracking for battery saving',
                  ),
                  _buildModeOption(
                    mode: AppConstants.monitoringModeManual,
                    icon: Icons.touch_app,
                    title: 'Manual',
                    subtitle: 'Only when you publish manually',
                  ),
                  _buildModeOption(
                    mode: AppConstants.monitoringModeSignificant,
                    icon: Icons.directions_walk,
                    title: 'Significant',
                    subtitle: 'Balanced tracking (recommended)',
                  ),
                  _buildModeOption(
                    mode: AppConstants.monitoringModeMove,
                    icon: Icons.directions_run,
                    title: 'Move',
                    subtitle: 'Frequent updates for navigation',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Permissions
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.location_on),
                  title: Text('Location Permission'),
                  subtitle: Text('Required for location tracking'),
                  trailing: Icon(Icons.check_circle, color: Colors.green),
                ),
                const ListTile(
                  leading: Icon(Icons.notifications),
                  title: Text('Notification Permission'),
                  subtitle: Text('For background tracking alerts'),
                  trailing: Icon(Icons.check_circle, color: Colors.green),
                ),
                ListTile(
                  leading: const Icon(Icons.battery_charging_full),
                  title: const Text('Battery Optimization'),
                  subtitle: const Text('Disabled for reliable tracking'),
                  trailing: TextButton(
                    onPressed: () {
                      // TODO: Open battery settings
                    },
                    child: const Text('Configure'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeOption({
    required int mode,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _monitoringMode == mode;

    return RadioListTile<int>(
      value: mode,
      groupValue: _monitoringMode,
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _monitoringMode = value;
          });
          _saveMonitoringMode(value);
        }
      },
      title: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(title),
        ],
      ),
      subtitle: Text(subtitle),
      selected: isSelected,
    );
  }

  String _getModeName(int mode) {
    switch (mode) {
      case AppConstants.monitoringModeQuiet:
        return 'Quiet';
      case AppConstants.monitoringModeManual:
        return 'Manual';
      case AppConstants.monitoringModeSignificant:
        return 'Significant';
      case AppConstants.monitoringModeMove:
        return 'Move';
      default:
        return 'Unknown';
    }
  }

  void _toggleTracking(bool enabled) async {
    // Update state provider
    ref.read(trackingEnabledProvider.notifier).state = enabled;

    if (mounted) {
      if (enabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Starting location tracking...')),
        );
        // TODO: Start tracking service
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stopping location tracking...')),
        );
        // TODO: Stop tracking service
      }
    }
  }

  void _saveMonitoringMode(int mode) async {
    final settingsRepo = ref.read(settingsRepositoryProvider);
    await settingsRepo.setMonitoringMode(mode);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Monitoring mode set to ${_getModeName(mode)}')),
      );
    }
  }
}
