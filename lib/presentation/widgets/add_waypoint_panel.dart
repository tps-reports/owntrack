import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:owntrack/data/models/waypoint.dart';
import 'package:owntrack/presentation/widgets/waypoint_field_validators.dart';

/// Non-modal add-waypoint form shown over the map.
///
/// The map behind it stays interactive: each tap arrives here as a new
/// [point] and overwrites the coordinate fields, while the fields remain
/// hand-editable. Save validates and is the single approval; Cancel discards.
class AddWaypointPanel extends StatefulWidget {
  const AddWaypointPanel({
    super.key,
    required this.point,
    required this.onSave,
    required this.onCancel,
  });

  /// Latest point tapped on the map, if any.
  final LatLng? point;

  /// Called with the completed waypoint when the form validates.
  final ValueChanged<Waypoint> onSave;

  /// Called when the user discards the form.
  final VoidCallback onCancel;

  @override
  State<AddWaypointPanel> createState() => _AddWaypointPanelState();
}

class _AddWaypointPanelState extends State<AddWaypointPanel> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _descController;
  late final TextEditingController _latController;
  late final TextEditingController _lonController;
  late final TextEditingController _radiusController;

  @override
  void initState() {
    super.initState();
    _descController = TextEditingController();
    _latController =
        TextEditingController(text: widget.point?.latitude.toString() ?? '');
    _lonController =
        TextEditingController(text: widget.point?.longitude.toString() ?? '');
    _radiusController = TextEditingController(text: '100');
  }

  @override
  void didUpdateWidget(AddWaypointPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final point = widget.point;
    if (point != null && point != oldWidget.point) {
      _latController.text = point.latitude.toString();
      _lonController.text = point.longitude.toString();
    }
  }

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

    final now = DateTime.now();
    widget.onSave(
      Waypoint(
        id: now.millisecondsSinceEpoch.toString(),
        lat: double.parse(_latController.text.trim()),
        lon: double.parse(_lonController.text.trim()),
        timestamp: now.millisecondsSinceEpoch ~/ 1000,
        description: _descController.text.trim(),
        radius: double.tryParse(_radiusController.text.trim()) ?? 100,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'New waypoint',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tap the map to set coordinates',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              TextFormField(
                key: const Key('waypoint-description-field'),
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Home',
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const Key('waypoint-lat-field'),
                      controller: _latController,
                      decoration:
                          const InputDecoration(labelText: 'Latitude'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      validator: validateLatitude,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      key: const Key('waypoint-lon-field'),
                      controller: _lonController,
                      decoration:
                          const InputDecoration(labelText: 'Longitude'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      validator: validateLongitude,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      key: const Key('waypoint-radius-field'),
                      controller: _radiusController,
                      decoration:
                          const InputDecoration(labelText: 'Radius (m)'),
                      keyboardType: TextInputType.number,
                      validator: validateRadius,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: widget.onCancel,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _submit,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
