import 'package:material_ui/material_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:owntrack/core/utils/app_logger.dart';
import 'package:owntrack/domain/providers/app_providers.dart';
import 'package:owntrack/presentation/screens/contacts/contacts_screen.dart';
import 'package:owntrack/presentation/screens/regions/regions_screen.dart';
import 'package:owntrack/presentation/screens/settings/connection_settings_screen.dart';
import 'package:owntrack/presentation/screens/settings/identification_settings_screen.dart';
import 'package:owntrack/presentation/screens/settings/tracking_settings_screen.dart';
import 'package:owntrack/presentation/screens/waypoints/waypoints_screen.dart';

/// Main map screen showing current location, friends, and regions
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();

  // Default location (San Francisco)
  static const LatLng _defaultLocation = LatLng(37.7749, -122.4194);

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(selectedNavigationIndexProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('OwnTracks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _centerOnCurrentLocation,
            tooltip: 'Center on my location',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              ref.read(selectedNavigationIndexProvider.notifier).setIndex(3);
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: _buildBody(selectedIndex),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          ref.read(selectedNavigationIndexProvider.notifier).setIndex(index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.people),
            label: 'Contacts',
          ),
          NavigationDestination(
            icon: Icon(Icons.place),
            label: 'Waypoints',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
      floatingActionButton: selectedIndex == 0
          ? FloatingActionButton(
              onPressed: _publishLocation,
              tooltip: 'Publish location',
              child: const Icon(Icons.send),
            )
          : null,
    );
  }

  Widget _buildBody(int selectedIndex) {
    switch (selectedIndex) {
      case 0:
        return _buildMapView();
      case 1:
        return _buildContactsView();
      case 2:
        return _buildWaypointsView();
      case 3:
        return _buildSettingsView();
      default:
        return _buildMapView();
    }
  }

  Widget _buildMapView() {
    return FlutterMap(
      mapController: _mapController,
      options: const MapOptions(
        initialCenter: _defaultLocation,
        initialZoom: 13.0,
        minZoom: 3.0,
        maxZoom: 19.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.cf.fivex.owntrack',
          maxZoom: 19,
          tileProvider: NetworkTileProvider(),
        ),
        // Regions layer (circles)
        CircleLayer(
          circles: _buildRegionCircles(),
        ),
        // Markers layer (friends, waypoints, current location)
        MarkerLayer(
          markers: _buildMarkers(),
        ),
      ],
    );
  }

  Widget _buildContactsView() {
    return const ContactsScreen();
  }

  Widget _buildWaypointsView() {
    return const WaypointsScreen();
  }

  Widget _buildSettingsView() {
    return ListView(
      children: [
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
          leading: const Icon(Icons.location_searching),
          title: const Text('Regions'),
          subtitle: const Text('Manage geofence regions'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const RegionsScreen(),
              ),
            );
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.info),
          title: const Text('About'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            _showAboutDialog();
          },
        ),
      ],
    );
  }

  void _showAboutDialog() {
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

  List<CircleMarker> _buildRegionCircles() {
    final regionsAsync = ref.watch(regionsStreamProvider);

    return regionsAsync.when(
      data: (regions) {
        return regions
            .where((r) => r.enabled)
            .map((region) => CircleMarker(
                  point: LatLng(region.lat, region.lon),
                  radius: region.radius,
                  color: Colors.blue.withValues(alpha: 0.3),
                  borderColor: Colors.blue,
                  borderStrokeWidth: 2,
                ))
            .toList();
      },
      loading: () => [],
      error: (_, _) => [],
    );
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // Add friend markers
    final friendsAsync = ref.watch(friendsStreamProvider);
    friendsAsync.whenData((friends) {
      for (final friend in friends) {
        if (friend.lat != null && friend.lon != null) {
          markers.add(
            Marker(
              point: LatLng(friend.lat!, friend.lon!),
              width: 60,
              height: 60,
              child: Column(
                children: [
                  Icon(
                    Icons.person_pin,
                    color: Theme.of(context).colorScheme.secondary,
                    size: 30,
                  ),
                  Text(
                    friend.displayName,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      backgroundColor: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }
      }
    });

    // Add waypoint markers
    final waypointsAsync = ref.watch(waypointsStreamProvider);
    waypointsAsync.whenData((waypoints) {
      for (final waypoint in waypoints) {
        final displayName = waypoint.description.isNotEmpty
            ? waypoint.description
            : 'WP';
        markers.add(
          Marker(
            point: LatLng(waypoint.lat, waypoint.lon),
            width: 60,
            height: 60,
            child: Column(
              children: [
                Icon(
                  Icons.place,
                  color: Theme.of(context).colorScheme.tertiary,
                  size: 30,
                ),
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    backgroundColor: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }
    });

    return markers;
  }

  Future<void> _centerOnCurrentLocation() async {
    final update = await ref.read(locationServiceProvider).getCurrentLocation();
    if (!mounted) return;

    if (update == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not determine your location. Check that location services '
            'are enabled and permission is granted.',
          ),
        ),
      );
      return;
    }

    _mapController.move(LatLng(update.latitude, update.longitude), 15.0);
  }

  Future<void> _publishLocation() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Publishing location...')),
    );

    try {
      await ref.read(trackingServiceProvider).publishCurrentLocation();
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Location published')),
        );
    } catch (e) {
      AppLogger.e('Manual location publish failed: $e');
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              e is StateError ? e.message : 'Could not publish location: $e',
            ),
          ),
        );
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}
