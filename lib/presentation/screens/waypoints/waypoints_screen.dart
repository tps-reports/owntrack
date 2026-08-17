import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:owntrack/core/utils/app_logger.dart';
import 'package:owntrack/data/models/waypoint.dart';
import 'package:owntrack/domain/providers/app_providers.dart';
import 'package:owntrack/presentation/widgets/waypoint_form_dialog.dart';

/// Waypoints management screen for viewing and managing waypoints
class WaypointsScreen extends ConsumerWidget {
  const WaypointsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waypointsAsync = ref.watch(waypointsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Waypoints'),
      ),
      body: waypointsAsync.when(
        data: (waypoints) {
          if (waypoints.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.builder(
            itemCount: waypoints.length,
            itemBuilder: (context, index) {
              final waypoint = waypoints[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.tertiary,
                    child: const Icon(Icons.place, color: Colors.white),
                  ),
                  title: Text(
                    waypoint.description.isNotEmpty ? waypoint.description : 'Waypoint ${waypoint.id.substring(0, 8)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${waypoint.lat.toStringAsFixed(4)}, ${waypoint.lon.toStringAsFixed(4)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (waypoint.radius > 0)
                        Text(
                          'Radius: ${waypoint.radius.toInt()}m',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                  trailing: PopupMenuButton(
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
                        _editWaypoint(context, ref, waypoint);
                      } else if (value == 'delete') {
                        _deleteWaypoint(context, ref, waypoint);
                      }
                    },
                  ),
                  onTap: () => _showWaypointDetails(context, waypoint),
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
                'Error loading waypoints',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.place_outlined,
            size: 100,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No Waypoints',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Add waypoints to mark important locations',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _showWaypointDetails(BuildContext context, Waypoint waypoint) {
    final displayName = waypoint.description.isNotEmpty
        ? waypoint.description
        : 'Waypoint ${waypoint.id.substring(0, 8)}';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(displayName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Location:', style: Theme.of(context).textTheme.titleSmall),
            Text('Lat: ${waypoint.lat.toStringAsFixed(6)}'),
            Text('Lon: ${waypoint.lon.toStringAsFixed(6)}'),
            if (waypoint.radius > 0) ...[
              const SizedBox(height: 16),
              Text('Radius:', style: Theme.of(context).textTheme.titleSmall),
              Text('${waypoint.radius.toInt()} meters'),
            ],
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

  Future<void> _editWaypoint(
    BuildContext context,
    WidgetRef ref,
    Waypoint waypoint,
  ) async {
    final updated =
        await showWaypointFormDialog(context, initialWaypoint: waypoint);
    if (updated == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(waypointsRepositoryProvider).updateWaypoint(updated);
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Waypoint updated')),
      );
    } catch (e) {
      AppLogger.e('Failed to update waypoint: $e');
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not update waypoint: $e')),
      );
    }
  }

  Future<void> _deleteWaypoint(
    BuildContext context,
    WidgetRef ref,
    Waypoint waypoint,
  ) async {
    final displayName = waypoint.description.isNotEmpty
        ? waypoint.description
        : 'Waypoint ${waypoint.id.substring(0, 8)}';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Waypoint'),
        content: Text('Are you sure you want to delete "$displayName"?'),
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
      final repository = ref.read(waypointsRepositoryProvider);
      await repository.deleteWaypoint(waypoint.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Waypoint deleted')),
        );
      }
    }
  }
}
