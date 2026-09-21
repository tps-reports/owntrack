import 'package:material_ui/material_ui.dart';
import 'package:owntrack/presentation/screens/settings/connection_settings_screen.dart';
import 'package:owntrack/presentation/screens/settings/tracking_settings_screen.dart';
import 'package:owntrack/presentation/screens/settings/identification_settings_screen.dart';
import 'package:owntrack/presentation/screens/waypoints/waypoints_screen.dart';
import 'package:owntrack/presentation/screens/regions/regions_screen.dart';
import 'package:owntrack/presentation/screens/settings/outbox_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: const SettingsContent(),
  );
}

/// Shared settings navigation for the map tab and the direct settings route.
class SettingsContent extends StatelessWidget {
  const SettingsContent({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.outbox),
          title: const Text('Outbox'),
          subtitle: const Text('Review, export and retry queued messages'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const OutboxScreen()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.wifi),
          title: const Text('Connection'),
          subtitle: const Text('MQTT and HTTP settings'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ConnectionSettingsScreen(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.location_on),
          title: const Text('Tracking'),
          subtitle: const Text('Location tracking preferences'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const TrackingSettingsScreen(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.person),
          title: const Text('Identification'),
          subtitle: const Text('Device and tracker ID'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const IdentificationSettingsScreen(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.place),
          title: const Text('Waypoints'),
          subtitle: const Text('Manage saved waypoints'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const WaypointsScreen()),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.location_searching),
          title: const Text('Regions'),
          subtitle: const Text('Manage geofence regions'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const RegionsScreen()),
            );
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.info),
          title: const Text('About'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            _showAboutDialog(context);
          },
        ),
      ],
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'OwnTracks',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2025 OwnTracks\nMIT License',
      children: [
        const SizedBox(height: 16),
        const Text(
          'A unified Flutter implementation of OwnTracks for Android and iOS.',
        ),
      ],
    );
  }
}
