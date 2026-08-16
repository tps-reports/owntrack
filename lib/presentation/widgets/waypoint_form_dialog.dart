import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:owntrack/data/models/waypoint.dart';

/// Shows the waypoint entry form and returns the described waypoint.
///
/// Returns null when the user cancels. When [initialPoint] is supplied the
/// coordinates come from a map selection and are shown read-only; otherwise
/// the user types them in.
Future<Waypoint?> showWaypointFormDialog(
  BuildContext context, {
  LatLng? initialPoint,
}) {
  return showDialog<Waypoint>(
    context: context,
    builder: (context) => WaypointFormDialog(initialPoint: initialPoint),
  );
}

/// Dialog that collects the fields needed to build a [Waypoint].
///
/// Validation runs before the dialog closes, so invalid coordinates surface an
/// inline error instead of being silently discarded.
class WaypointFormDialog extends StatefulWidget {
  const WaypointFormDialog({super.key, this.initialPoint});

  /// Coordinates chosen on the map. When set, the coordinate fields are
  /// pre-filled and locked.
  final LatLng? initialPoint;

  @override
  State<WaypointFormDialog> createState() => _WaypointFormDialogState();
}

class _WaypointFormDialogState extends State<WaypointFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _descController;
  late final TextEditingController _latController;
  late final TextEditingController _lonController;
  late final TextEditingController _radiusController;

  bool get _fromMap => widget.initialPoint != null;

  @override
  void initState() {
    super.initState();
    _descController = TextEditingController();
    _latController = TextEditingController(
      text: widget.initialPoint?.latitude.toString() ?? '',
    );
    _lonController = TextEditingController(
      text: widget.initialPoint?.longitude.toString() ?? '',
    );
    _radiusController = TextEditingController(text: '100');
  }

  @override
  void dispose() {
    _descController.dispose();
    _latController.dispose();
    _lonController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  String? _validateCoordinate(
    String? value, {
    required double max,
    required String rangeMessage,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Required';

    final parsed = double.tryParse(text);
    if (parsed == null) return 'Enter a valid number';
    if (parsed < -max || parsed > max) return rangeMessage;
    return null;
  }

  String? _validateRadius(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null; // falls back to the default below

    final parsed = double.tryParse(text);
    if (parsed == null) return 'Enter a valid number';
    if (parsed <= 0) return 'Radius must be greater than 0';
    return null;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final now = DateTime.now();
    final waypoint = Waypoint(
      id: now.millisecondsSinceEpoch.toString(),
      lat: double.parse(_latController.text.trim()),
      lon: double.parse(_lonController.text.trim()),
      timestamp: now.millisecondsSinceEpoch ~/ 1000,
      description: _descController.text.trim(),
      radius: double.tryParse(_radiusController.text.trim()) ?? 100,
    );

    Navigator.pop(context, waypoint);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Waypoint'),
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
                enabled: !_fromMap,
                decoration: InputDecoration(
                  labelText: 'Latitude',
                  hintText: '37.7749',
                  helperText: _fromMap ? 'Selected on map' : null,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                validator: (v) => _validateCoordinate(
                  v,
                  max: 90,
                  rangeMessage: 'Latitude must be between -90 and 90',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('waypoint-lon-field'),
                controller: _lonController,
                enabled: !_fromMap,
                decoration: InputDecoration(
                  labelText: 'Longitude',
                  hintText: '-122.4194',
                  helperText: _fromMap ? 'Selected on map' : null,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                validator: (v) => _validateCoordinate(
                  v,
                  max: 180,
                  rangeMessage: 'Longitude must be between -180 and 180',
                ),
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
                validator: _validateRadius,
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
          child: const Text('Add'),
        ),
      ],
    );
  }
}
