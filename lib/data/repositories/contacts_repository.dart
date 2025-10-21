import 'dart:async';

import 'package:owntrack/data/models/friend.dart';

/// Change events for contacts
sealed class ContactsRepoChange {
  const ContactsRepoChange();
}

class ContactAdded extends ContactsRepoChange {
  final Friend friend;
  const ContactAdded(this.friend);
}

class ContactUpdated extends ContactsRepoChange {
  final Friend friend;
  const ContactUpdated(this.friend);
}

class ContactRemoved extends ContactsRepoChange {
  final String id;
  const ContactRemoved(this.id);
}

/// In-memory repository for contacts (matching Android MemoryContactsRepo)
class ContactsRepository {
  final Map<String, Friend> _contacts = {};
  final StreamController<ContactsRepoChange> _changeController =
      StreamController<ContactsRepoChange>.broadcast();

  /// Stream of contact changes
  Stream<ContactsRepoChange> get changes => _changeController.stream;

  /// Get all contacts
  List<Friend> getAllContacts() => _contacts.values.toList();

  /// Get contact by ID
  Friend? getContact(String id) => _contacts[id];

  /// Get contact by topic
  Friend? getContactByTopic(String topic) {
    return _contacts.values.firstWhere(
      (friend) => friend.topic == topic,
      orElse: () => _contacts.values.first,
    );
  }

  /// Add or update contact
  void updateContact(Friend friend) {
    final exists = _contacts.containsKey(friend.id);
    _contacts[friend.id] = friend;

    if (exists) {
      _changeController.add(ContactUpdated(friend));
    } else {
      _changeController.add(ContactAdded(friend));
    }
  }

  /// Remove contact
  void removeContact(String id) {
    if (_contacts.remove(id) != null) {
      _changeController.add(ContactRemoved(id));
    }
  }

  /// Clear all contacts
  void clearAll() {
    final ids = _contacts.keys.toList();
    _contacts.clear();
    for (final id in ids) {
      _changeController.add(ContactRemoved(id));
    }
  }

  /// Get number of contacts
  int get count => _contacts.length;

  /// Dispose resources
  void dispose() {
    _changeController.close();
  }
}
