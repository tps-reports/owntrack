import 'package:owntrack/data/models/friend.dart';
import 'package:owntrack/data/repositories/contacts_repository.dart';

/// Only location data can mutate contacts; remote commands are not authorized.
class ContactMessageRouter {
  final ContactsRepository contacts;
  ContactMessageRouter(this.contacts);

  bool accept(Map<String, dynamic> message) {
    if (message['_type'] != 'location') return false;
    final topic = message['topic'];
    final lat = message['lat'];
    final lon = message['lon'];
    final timestamp = message['tst'];
    final accuracy = message['acc'];
    final battery = message['batt'];
    final tid = message['tid'];
    if (topic is! String ||
        !RegExp(r'^owntracks/[^/+#]+/[^/+#]+$').hasMatch(topic) ||
        lat is! num ||
        !lat.isFinite ||
        lat.abs() > 90 ||
        lon is! num ||
        !lon.isFinite ||
        lon.abs() > 180 ||
        timestamp is! int ||
        timestamp < 0 ||
        timestamp > DateTime.now().millisecondsSinceEpoch ~/ 1000 + 300 ||
        (accuracy != null && (accuracy is! int || accuracy < 0)) ||
        (battery != null &&
            (battery is! int || battery < 0 || battery > 100)) ||
        (tid != null && tid is! String)) {
      return false;
    }
    final existing = contacts.getContact(topic);
    if (existing?.timestamp != null && timestamp < existing!.timestamp!) {
      return false;
    }
    contacts.updateContact(
      Friend(
        id: topic,
        topic: topic,
        name: existing?.name,
        imageUrl: existing?.imageUrl,
        lat: lat.toDouble(),
        lon: lon.toDouble(),
        timestamp: timestamp,
        accuracy: accuracy as int?,
        battery: battery as int?,
        trackerId: tid as String?,
      ),
    );
    return true;
  }
}
