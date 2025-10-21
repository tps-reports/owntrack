import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Main map screen showing current location, friends, and regions
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  int _selectedIndex = 0;

  // Default location (San Francisco)
  static const LatLng _defaultLocation = LatLng(37.7749, -122.4194);

  @override
  Widget build(BuildContext context) {
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
              setState(() => _selectedIndex = 3);
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
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
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: _publishLocation,
              tooltip: 'Publish location',
              child: const Icon(Icons.send),
            )
          : null,
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people,
            size: 100,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Contacts',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Your tracked contacts will appear here',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildWaypointsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.place,
            size: 100,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Waypoints',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Your saved waypoints will appear here',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
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
            // TODO: Navigate to connection settings
          },
        ),
        ListTile(
          leading: const Icon(Icons.location_on),
          title: const Text('Tracking'),
          subtitle: const Text('Location tracking preferences'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // TODO: Navigate to tracking settings
          },
        ),
        ListTile(
          leading: const Icon(Icons.person),
          title: const Text('Identification'),
          subtitle: const Text('Device and tracker ID'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // TODO: Navigate to identification settings
          },
        ),
        ListTile(
          leading: const Icon(Icons.security),
          title: const Text('Security'),
          subtitle: const Text('Encryption settings'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // TODO: Navigate to security settings
          },
        ),
        ListTile(
          leading: const Icon(Icons.notifications),
          title: const Text('Notifications'),
          subtitle: const Text('Alert preferences'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // TODO: Navigate to notification settings
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.info),
          title: const Text('About'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // TODO: Show about dialog
          },
        ),
      ],
    );
  }

  List<CircleMarker> _buildRegionCircles() {
    // TODO: Get regions from repository
    return [];
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // TODO: Add current location marker

    // TODO: Add friend markers

    // TODO: Add waypoint markers

    return markers;
  }

  void _centerOnCurrentLocation() {
    // TODO: Get current location and center map
    _mapController.move(_defaultLocation, 15.0);
  }

  void _publishLocation() {
    // TODO: Trigger location publish
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Publishing location...')),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}
