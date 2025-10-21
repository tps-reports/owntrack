import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:owntrack/data/models/region.dart';
import 'package:owntrack/domain/providers/app_providers.dart';

/// Regions/Geofence management screen for viewing and managing geofence regions
class RegionsScreen extends ConsumerWidget {
  const RegionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regionsAsync = ref.watch(regionsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Regions'),
      ),
      body: regionsAsync.when(
        data: (regions) {
          if (regions.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.builder(
            itemCount: regions.length,
            itemBuilder: (context, index) {
              final region = regions[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: region.enabled
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                    child: const Icon(Icons.location_searching, color: Colors.white),
                  ),
                  title: Text(
                    region.displayDescription,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${region.lat.toStringAsFixed(4)}, ${region.lon.toStringAsFixed(4)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        'Radius: ${region.radius.toInt()}m',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        region.enabled ? 'Active' : 'Disabled',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: region.enabled ? Colors.green : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: region.enabled,
                        onChanged: (value) => _toggleRegion(ref, region, value),
                      ),
                      PopupMenuButton(
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: ListTile(
                              leading: Icon(Icons.edit),
                              title: Text('Edit'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              leading: Icon(Icons.delete, color: Colors.red),
                              title: Text('Delete', style: TextStyle(color: Colors.red)),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'edit') {
                            _editRegion(context, ref, region);
                          } else if (value == 'delete') {
                            _deleteRegion(context, ref, region);
                          }
                        },
                      ),
                    ],
                  ),
                  onTap: () => _showRegionDetails(context, region),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading regions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addRegion(context, ref),
        icon: const Icon(Icons.add_circle_outline),
        label: const Text('Add Region'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_searching,
            size: 100,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No Regions',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Create geofence regions to track when you enter or leave areas',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _showRegionDetails(BuildContext context, Region region) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(region.displayDescription),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status:', style: Theme.of(context).textTheme.titleSmall),
            Text(region.enabled ? 'Active' : 'Disabled'),
            const SizedBox(height: 16),
            Text('Location:', style: Theme.of(context).textTheme.titleSmall),
            Text('Lat: ${region.lat.toStringAsFixed(6)}'),
            Text('Lon: ${region.lon.toStringAsFixed(6)}'),
            const SizedBox(height: 16),
            Text('Radius:', style: Theme.of(context).textTheme.titleSmall),
            Text('${region.radius.toInt()} meters'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleRegion(WidgetRef ref, Region region, bool enabled) async {
    final repository = ref.read(regionsRepositoryProvider);
    final updated = region.copyWith(enabled: enabled);
    await repository.updateRegion(updated);
  }

  Future<void> _addRegion(BuildContext context, WidgetRef ref) async {
    final descController = TextEditingController();
    final latController = TextEditingController();
    final lonController = TextEditingController();
    final radiusController = TextEditingController(text: '200');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Region'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Home',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: latController,
                decoration: const InputDecoration(
                  labelText: 'Latitude',
                  hintText: '37.7749',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: lonController,
                decoration: const InputDecoration(
                  labelText: 'Longitude',
                  hintText: '-122.4194',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: radiusController,
                decoration: const InputDecoration(
                  labelText: 'Radius (meters)',
                  hintText: '200',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      final lat = double.tryParse(latController.text);
      final lon = double.tryParse(lonController.text);
      final radius = double.tryParse(radiusController.text) ?? 200;

      if (lat != null && lon != null) {
        final region = Region(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          lat: lat,
          lon: lon,
          radius: radius,
          description: descController.text,
          enabled: true,
        );

        final repository = ref.read(regionsRepositoryProvider);
        await repository.addRegion(region);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Region added')),
          );
        }
      }
    }

    descController.dispose();
    latController.dispose();
    lonController.dispose();
    radiusController.dispose();
  }

  Future<void> _editRegion(
    BuildContext context,
    WidgetRef ref,
    Region region,
  ) async {
    final descController = TextEditingController(text: region.description);
    final latController = TextEditingController(text: region.lat.toString());
    final lonController = TextEditingController(text: region.lon.toString());
    final radiusController =
        TextEditingController(text: region.radius.toInt().toString());

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Region'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: latController,
                decoration: const InputDecoration(labelText: 'Latitude'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: lonController,
                decoration: const InputDecoration(labelText: 'Longitude'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: radiusController,
                decoration: const InputDecoration(labelText: 'Radius (meters)'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      final lat = double.tryParse(latController.text);
      final lon = double.tryParse(lonController.text);
      final radius = double.tryParse(radiusController.text) ?? 200;

      if (lat != null && lon != null) {
        final updated = region.copyWith(
          description: descController.text,
          lat: lat,
          lon: lon,
          radius: radius,
        );

        final repository = ref.read(regionsRepositoryProvider);
        await repository.updateRegion(updated);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Region updated')),
          );
        }
      }
    }

    descController.dispose();
    latController.dispose();
    lonController.dispose();
    radiusController.dispose();
  }

  Future<void> _deleteRegion(
    BuildContext context,
    WidgetRef ref,
    Region region,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Region'),
        content: Text('Are you sure you want to delete "${region.displayDescription}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      final repository = ref.read(regionsRepositoryProvider);
      await repository.deleteRegion(region.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Region deleted')),
        );
      }
    }
  }
}
