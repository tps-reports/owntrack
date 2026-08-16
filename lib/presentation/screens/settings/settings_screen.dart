import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:owntrack/core/utils/platform_utils.dart';
import 'package:owntrack/domain/providers/app_providers.dart';

/// Settings screen for app configuration
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.wifi),
            title: const Text('Connection'),
            subtitle: const Text('MQTT and HTTP settings'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Navigate to connection settings
            },
          ),
          ListTile(
            leading: const Icon(Icons.location_on),
            title: const Text('Location'),
            subtitle: const Text('Tracking and reporting settings'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Navigate to location settings
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notifications'),
            subtitle: const Text('Notification preferences'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Navigate to notification settings
            },
          ),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Security'),
            subtitle: const Text('Encryption and privacy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Navigate to security settings
            },
          ),
          const Divider(),
          if (PlatformUtils.isWeb) ...[
            ListTile(
              leading: const Icon(Icons.phone_android),
              title: const Text('Open in Mobile App'),
              subtitle: const Text('Launch the mobile app with your settings'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () async {
                final appLauncher = ref.read(appLauncherServiceProvider);
                final scaffoldMessenger = ScaffoldMessenger.of(context);

                // Show loading indicator
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Launching mobile app...'),
                    duration: Duration(seconds: 2),
                  ),
                );

                final success = await appLauncher.launchAppWithSettings();

                if (!success) {
                  scaffoldMessenger.hideCurrentSnackBar();
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Unable to launch app. Please try again.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
            const Divider(),
          ],
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Show about dialog
            },
          ),
        ],
      ),
    );
  }
}
