import 'package:material_ui/material_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:owntrack/core/config/map_tiler_config.dart';
import 'package:owntrack/core/utils/app_logger.dart';
import 'package:owntrack/data/models/waypoint.dart';
import 'package:owntrack/domain/providers/app_providers.dart';
import 'package:owntrack/presentation/widgets/waypoint_form_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:owntrack/presentation/screens/contacts/contacts_screen.dart';
import 'package:owntrack/presentation/screens/regions/regions_screen.dart';
import 'package:owntrack/presentation/screens/settings/connection_settings_screen.dart';
import 'package:owntrack/presentation/screens/settings/identification_settings_screen.dart';
import 'package:owntrack/presentation/screens/settings/tracking_settings_screen.dart';
import 'package:owntrack/presentation/screens/waypoints/waypoints_screen.dart';

/// How the user chose to define a new waypoint's coordinates.
enum _WaypointSource { manual, map }

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

  /// True while the user is picking a waypoint location on the map.
  bool _placingWaypoint = false;

  /// The point tapped during placement, before it is confirmed.
  LatLng? _pendingPoint;

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
    final tiles = ref.watch(mapTilerConfigProvider);
    if (!tiles.isConfigured) {
      return _buildUnconfiguredTilesView();
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _defaultLocation,
            initialZoom: 13.0,
            minZoom: 3.0,
            maxZoom: 19.0,
            onTap: _placingWaypoint ? (_, point) => _onMapTapped(point) : null,
          ),
          children: [
            TileLayer(
              urlTemplate: tiles.urlTemplate,
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
        ),
        // Attribution is required: OSM data is ODbL-licensed and MapTiler's
        // terms require crediting both. Kept permanently visible and bottom
        // left — flutter_map's RichAttributionWidget collapses behind an "i"
        // badge in the bottom right, where the publish FAB covers it.
        Positioned(
          left: 8,
          bottom: 8,
          child: _buildAttributionBar(),
        ),
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: _placingWaypoint
              ? _buildPlacementBar()
              : Align(
                  alignment: Alignment.centerLeft,
                  child: _buildAddWaypointChip(),
                ),
        ),
      ],
    );
  }

  /// Permanent tile attribution, with both credits individually linked.
  Widget _buildAttributionBar() {
    final theme = Theme.of(context);
    final plain = theme.textTheme.bodySmall;
    final link = plain?.copyWith(
      decoration: TextDecoration.underline,
      color: theme.colorScheme.primary,
    );

    return Material(
      key: const Key('map-attribution'),
      color: theme.colorScheme.surface.withValues(alpha: 0.8),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('© ', style: plain),
            InkWell(
              onTap: () => _openUrl('https://www.maptiler.com/copyright/'),
              child: Text('MapTiler', style: link),
            ),
            Text(' © ', style: plain),
            InkWell(
              onTap: () =>
                  _openUrl('https://www.openstreetmap.org/copyright'),
              child: Text('OpenStreetMap contributors', style: link),
            ),
          ],
        ),
      ),
    );
  }

  /// Shown when no tile key was compiled in.
  ///
  /// An unconfigured map states the reason rather than presenting an empty
  /// grid that looks like a network failure.
  Widget _buildUnconfiguredTilesView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.map_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withValues(
                    alpha: 0.5,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              'Map tiles not configured',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Build with --dart-define=${MapTilerConfig.envVarName}=<key> to '
              'load map tiles.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      final launched = await launchUrl(uri);
      if (launched) return;
      throw StateError('launchUrl returned false');
    } catch (e) {
      AppLogger.e('Could not open $url: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $url')),
      );
    }
  }

  Widget _buildAddWaypointChip() {
    return ActionChip(
      avatar: const Icon(Icons.add_location_alt, size: 18),
      label: const Text('Add waypoint'),
      onPressed: _startAddWaypoint,
    );
  }

  /// Hint bar shown while the user is choosing a point on the map.
  Widget _buildPlacementBar() {
    final hasPoint = _pendingPoint != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.touch_app, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasPoint
                    ? 'Tap again to move, or confirm'
                    : 'Tap the map to place the waypoint',
              ),
            ),
            TextButton(
              key: const Key('waypoint-placement-cancel'),
              onPressed: _cancelPlacement,
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 4),
            FilledButton(
              key: const Key('waypoint-placement-confirm'),
              onPressed: hasPoint ? _confirmPlacement : null,
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
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

    // Crosshair for the point being placed, before it is confirmed
    final pending = _pendingPoint;
    if (pending != null) {
      markers.add(
        Marker(
          point: pending,
          width: 40,
          height: 40,
          child: Icon(
            Icons.add_location_alt,
            size: 40,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

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

  /// Asks how the user wants to define the waypoint, then routes to either
  /// manual entry or map placement. Both paths converge on [_saveWaypoint].
  Future<void> _startAddWaypoint() async {
    final choice = await showModalBottomSheet<_WaypointSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_location_alt),
              title: const Text('Enter coordinates'),
              subtitle: const Text('Type latitude and longitude'),
              onTap: () => Navigator.pop(context, _WaypointSource.manual),
            ),
            ListTile(
              leading: const Icon(Icons.touch_app),
              title: const Text('Pick on map'),
              subtitle: const Text('Tap a spot on the map'),
              onTap: () => Navigator.pop(context, _WaypointSource.map),
            ),
          ],
        ),
      ),
    );

    if (!mounted || choice == null) return;

    switch (choice) {
      case _WaypointSource.manual:
        final waypoint = await showWaypointFormDialog(context);
        await _saveWaypoint(waypoint);
      case _WaypointSource.map:
        setState(() {
          _placingWaypoint = true;
          _pendingPoint = null;
        });
    }
  }

  void _onMapTapped(LatLng point) {
    setState(() => _pendingPoint = point);
  }

  void _cancelPlacement() {
    setState(() {
      _placingWaypoint = false;
      _pendingPoint = null;
    });
  }

  Future<void> _confirmPlacement() async {
    final point = _pendingPoint;
    if (point == null) return;

    final waypoint = await showWaypointFormDialog(context, initialPoint: point);
    if (!mounted) return;

    _cancelPlacement();
    await _saveWaypoint(waypoint);
  }

  /// Persists a waypoint produced by either entry path.
  Future<void> _saveWaypoint(Waypoint? waypoint) async {
    if (waypoint == null) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(waypointsRepositoryProvider).addWaypoint(waypoint);
      ref.invalidate(waypointsStreamProvider);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Waypoint added')),
      );
    } catch (e) {
      AppLogger.e('Failed to save waypoint: $e');
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save waypoint: $e')),
      );
    }
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
