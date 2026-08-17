import 'package:material_ui/material_ui.dart';
import 'package:owntrack/data/models/waypoint.dart';
import 'package:owntrack/presentation/widgets/waypoint_field_validators.dart';

/// Shows the edit form for [waypoint] and returns the edited copy.
///
/// Returns null when the user cancels. Every field is pre-filled and
/// editable; submitting preserves the waypoint's id and timestamp via
/// `copyWith`. Creation happens on the map via `AddWaypointPanel` — this
/// dialog only edits.
Future<Waypoint?> showWaypointFormDialog(
  BuildContext context, {
  required Waypoint initialWaypoint,
}) {
  return showDialog<Waypoint>(
    context: context,
    builder: (context) => WaypointFormDialog(initialWaypoint: initialWaypoint),
  );
}

/// Dialog that edits a [Waypoint].
///
/// Validation runs before the dialog closes, so invalid coordinates surface an
/// inline error instead of being silently discarded. Controllers are owned by
/// this State and disposed with the route, so the dialog's exit animation
/// never touches a disposed controller.
class WaypointFormDialog extends StatefulWidget {
  const WaypointFormDialog({super.key, required this.initialWaypoint});

  /// Waypoint being edited.
  final Waypoint initialWaypoint;

  @override
  State<WaypointFormDialog> createState() => _WaypointFormDialogState();
}

class _WaypointFormDialogState extends State<WaypointFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _descController;
  late final TextEditingController _latController;
  late final TextEditingController _lonController;
  late final TextEditingController _radiusController;

  @override
  void initState() {
    super.initState();
    final editing = widget.initialWaypoint;
    _descController = TextEditingController(text: editing.description);
    _latController = TextEditingController(text: editing.lat.toString());
    _lonController = TextEditingController(text: editing.lon.toString());
    _radiusController =
        TextEditingController(text: _formatRadius(editing.radius));
  }

  /// "150" rather than "150.0" for whole-number radii.
  static String _formatRadius(double radius) => radius == radius.roundToDouble()
      ? radius.toInt().toString()
      : radius.toString();

  @override
  void dispose() {
    _descController.dispose();
    _latController.dispose();
    _lonController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    Navigator.pop(
      context,
      widget.initialWaypoint.copyWith(
        lat: double.parse(_latController.text.trim()),
        lon: double.parse(_lonController.text.trim()),
        description: _descController.text.trim(),
        radius: double.tryParse(_radiusController.text.trim()) ?? 100,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Waypoint'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const Key('waypoint-description-field'),
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Home',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('waypoint-lat-field'),
                controller: _latController,
                decoration: const InputDecoration(
                  labelText: 'Latitude',
                  hintText: '37.7749',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                validator: validateLatitude,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('waypoint-lon-field'),
                controller: _lonController,
                decoration: const InputDecoration(
                  labelText: 'Longitude',
                  hintText: '-122.4194',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                validator: validateLongitude,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('waypoint-radius-field'),
                controller: _radiusController,
                decoration: const InputDecoration(
                  labelText: 'Radius (meters)',
                  hintText: '100',
                ),
                keyboardType: TextInputType.number,
                validator: validateRadius,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
