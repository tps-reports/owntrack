import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:owntrack/data/models/waypoint.dart';

/// Shows the waypoint form and returns the described waypoint.
///
/// Returns null when the user cancels. Three modes:
///  * no arguments — create, user types the coordinates;
///  * [initialPoint] — create from a map selection, coordinates locked;
///  * [initialWaypoint] — edit: every field prefilled and editable, and the
///    result carries the original's id and timestamp via `copyWith`.
Future<Waypoint?> showWaypointFormDialog(
  BuildContext context, {
  LatLng? initialPoint,
  Waypoint? initialWaypoint,
}) {
  assert(
    initialPoint == null || initialWaypoint == null,
    'A waypoint is either placed from the map or edited, not both.',
  );
  return showDialog<Waypoint>(
    context: context,
    builder: (context) => WaypointFormDialog(
      initialPoint: initialPoint,
      initialWaypoint: initialWaypoint,
    ),
  );
}

/// Dialog that collects the fields needed to build a [Waypoint].
///
/// Validation runs before the dialog closes, so invalid coordinates surface an
/// inline error instead of being silently discarded.
class WaypointFormDialog extends StatefulWidget {
  const WaypointFormDialog({super.key, this.initialPoint, this.initialWaypoint});

  /// Coordinates chosen on the map. When set, the coordinate fields are
  /// pre-filled and locked.
  final LatLng? initialPoint;

  /// Waypoint being edited. When set, every field is pre-filled and editable,
  /// and submitting preserves the waypoint's id and timestamp.
  final Waypoint? initialWaypoint;

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
  bool get _isEdit => widget.initialWaypoint != null;

  @override
  void initState() {
    super.initState();
    final editing = widget.initialWaypoint;
    _descController = TextEditingController(text: editing?.description ?? '');
    _latController = TextEditingController(
      text: editing?.lat.toString() ??
          widget.initialPoint?.latitude.toString() ??
          '',
    );
    _lonController = TextEditingController(
      text: editing?.lon.toString() ??
          widget.initialPoint?.longitude.toString() ??
          '',
    );
    _radiusController = TextEditingController(
      text: editing != null ? _formatRadius(editing.radius) : '100',
    );
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

    final lat = double.parse(_latController.text.trim());
    final lon = double.parse(_lonController.text.trim());
    final description = _descController.text.trim();
    final radius = double.tryParse(_radiusController.text.trim()) ?? 100;

    final editing = widget.initialWaypoint;
    final Waypoint waypoint;
    if (editing != null) {
      waypoint = editing.copyWith(
        lat: lat,
        lon: lon,
        description: description,
        radius: radius,
      );
    } else {
      final now = DateTime.now();
      waypoint = Waypoint(
        id: now.millisecondsSinceEpoch.toString(),
        lat: lat,
        lon: lon,
        timestamp: now.millisecondsSinceEpoch ~/ 1000,
        description: description,
        radius: radius,
      );
    }

    Navigator.pop(context, waypoint);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Waypoint' : 'Add Waypoint'),
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
          child: Text(_isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
