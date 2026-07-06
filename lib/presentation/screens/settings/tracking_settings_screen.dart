import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:owntrack/core/constants/app_constants.dart';
import 'package:owntrack/data/services/permission_service.dart';
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
  AppPermissionStatus _locationPermission = AppPermissionStatus.denied;
  AppPermissionStatus _notificationPermission = AppPermissionStatus.denied;
  bool _backgroundLocationGranted = false;
  bool _isCheckingPermissions = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkPermissions();
  }

  void _loadSettings() {
    final settingsRepo = ref.read(settingsRepositoryProvider);
    setState(() {
      _monitoringMode = settingsRepo.getMonitoringMode();
      _isTracking = ref.read(trackingEnabledProvider);
    });
  }

  Future<void> _checkPermissions() async {
    final permissionService = ref.read(permissionServiceProvider);

    final locationStatus = await permissionService.checkLocationPermission();
    final notificationStatus =
        await permissionService.checkNotificationPermission();
    final backgroundLocationStatus =
        await permissionService.checkBackgroundLocationPermission();

    if (mounted) {
      setState(() {
        _locationPermission = locationStatus;
        _notificationPermission = notificationStatus;
        _backgroundLocationGranted = backgroundLocationStatus;
        _isCheckingPermissions = false;
      });
    }
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
                  RadioGroup<int>(
                    groupValue: _monitoringMode,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _monitoringMode = value;
                        });
                        _saveMonitoringMode(value);
                      }
                    },
                    child: Column(
                      children: [
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Permissions
          Card(
            child: _isCheckingPermissions
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.location_on),
                        title: const Text('Location Permission'),
                        subtitle: Text(_getPermissionSubtitle(_locationPermission)),
                        trailing: _buildPermissionTrailing(_locationPermission),
                        onTap: () => _requestLocationPermission(),
                      ),
                      ListTile(
                        leading: const Icon(Icons.gps_fixed),
                        title: const Text('Background Location'),
                        subtitle: Text(_backgroundLocationGranted
                            ? 'Granted - can track in background'
                            : 'Not granted - foreground only'),
                        trailing: Icon(
                          _backgroundLocationGranted
                              ? Icons.check_circle
                              : Icons.error_outline,
                          color: _backgroundLocationGranted
                              ? Colors.green
                              : Colors.orange,
                        ),
                        onTap: () => _requestBackgroundLocationPermission(),
                      ),
                      ListTile(
                        leading: const Icon(Icons.notifications),
                        title: const Text('Notification Permission'),
                        subtitle: Text(_getPermissionSubtitle(_notificationPermission)),
                        trailing:
                            _buildPermissionTrailing(_notificationPermission),
                        onTap: () => _requestNotificationPermission(),
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
    // First check if we have required permissions
    if (enabled && _locationPermission != AppPermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please grant location permission first'),
            backgroundColor: Colors.orange,
          ),
        );
        // Reset the toggle
        setState(() {
          _isTracking = false;
        });
      }
      return;
    }

    final trackingService = ref.read(trackingServiceProvider);

    if (enabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Starting location tracking...')),
        );
      }

      final started = await trackingService.startTracking();

      if (mounted) {
        if (started) {
          // Update state provider
          ref.read(trackingEnabledProvider.notifier).state = true;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location tracking started'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // Failed to start
          setState(() {
            _isTracking = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to start tracking. Check permissions and location services.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stopping location tracking...')),
        );
      }

      await trackingService.stopTracking();

      if (mounted) {
        // Update state provider
        ref.read(trackingEnabledProvider.notifier).state = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location tracking stopped'),
            backgroundColor: Colors.grey,
          ),
        );
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

  String _getPermissionSubtitle(AppPermissionStatus status) {
    switch (status) {
      case AppPermissionStatus.granted:
        return 'Granted';
      case AppPermissionStatus.denied:
        return 'Tap to request permission';
      case AppPermissionStatus.permanentlyDenied:
        return 'Denied - tap to open settings';
      case AppPermissionStatus.restricted:
        return 'Restricted by device policy';
    }
  }

  Widget _buildPermissionTrailing(AppPermissionStatus status) {
    switch (status) {
      case AppPermissionStatus.granted:
        return const Icon(Icons.check_circle, color: Colors.green);
      case AppPermissionStatus.denied:
        return const Icon(Icons.error_outline, color: Colors.orange);
      case AppPermissionStatus.permanentlyDenied:
        return const Icon(Icons.settings, color: Colors.red);
      case AppPermissionStatus.restricted:
        return const Icon(Icons.block, color: Colors.grey);
    }
  }

  Future<void> _requestLocationPermission() async {
    if (_locationPermission == AppPermissionStatus.permanentlyDenied) {
      _showOpenSettingsDialog('Location');
      return;
    }

    final permissionService = ref.read(permissionServiceProvider);
    final status = await permissionService.requestLocationPermission();

    if (mounted) {
      setState(() {
        _locationPermission = status;
      });

      if (status == AppPermissionStatus.granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission granted')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
      }
    }
  }

  Future<void> _requestBackgroundLocationPermission() async {
    final permissionService = ref.read(permissionServiceProvider);
    final status = await permissionService.requestBackgroundLocationPermission();

    if (mounted) {
      setState(() {
        _backgroundLocationGranted = status == AppPermissionStatus.granted;
      });

      if (status == AppPermissionStatus.granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Background location permission granted')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Background location permission denied')),
        );
      }
    }
  }

  Future<void> _requestNotificationPermission() async {
    if (_notificationPermission == AppPermissionStatus.permanentlyDenied) {
      _showOpenSettingsDialog('Notification');
      return;
    }

    final permissionService = ref.read(permissionServiceProvider);
    final status = await permissionService.requestNotificationPermission();

    if (mounted) {
      setState(() {
        _notificationPermission = status;
      });

      if (status == AppPermissionStatus.granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification permission granted')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification permission denied')),
        );
      }
    }
  }

  void _showOpenSettingsDialog(String permissionName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$permissionName Permission Required'),
        content: Text(
          '$permissionName permission has been permanently denied. Please enable it in app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final permissionService = ref.read(permissionServiceProvider);
              await permissionService.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
