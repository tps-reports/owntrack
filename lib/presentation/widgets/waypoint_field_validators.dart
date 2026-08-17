/// Shared validators for waypoint form fields, used by every surface that
/// collects waypoint input so the rules cannot drift apart.
library;

String? validateLatitude(String? value) => _validateCoordinate(
      value,
      max: 90,
      rangeMessage: 'Latitude must be between -90 and 90',
    );

String? validateLongitude(String? value) => _validateCoordinate(
      value,
      max: 180,
      rangeMessage: 'Longitude must be between -180 and 180',
    );

String? validateRadius(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null; // caller falls back to its default

  final parsed = double.tryParse(text);
  if (parsed == null) return 'Enter a valid number';
  if (parsed <= 0) return 'Radius must be greater than 0';
  return null;
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
