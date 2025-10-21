import 'package:flutter_test/flutter_test.dart';
import 'package:owntrack/data/models/friend.dart';
import 'package:owntrack/data/repositories/contacts_repository.dart';

void main() {
  group('ContactsRepository', () {
    late ContactsRepository repository;

    setUp(() {
      repository = ContactsRepository();
    });

    tearDown(() {
      repository.dispose();
    });

    test('should start with empty contacts', () {
      expect(repository.count, equals(0));
      expect(repository.getAllContacts(), isEmpty);
    });

    test('should add contact', () {
      const friend = Friend(
        id: 'friend1',
        topic: 'owntracks/user/device',
      );

      repository.updateContact(friend);

      expect(repository.count, equals(1));
      expect(repository.getContact('friend1'), equals(friend));
    });

    test('should emit ContactAdded event when adding new contact', () {
      const friend = Friend(
        id: 'friend1',
        topic: 'owntracks/user/device',
      );

      expectLater(
        repository.changes,
        emits(isA<ContactAdded>()),
      );

      repository.updateContact(friend);
    });

    test('should update existing contact', () {
      const friend = Friend(
        id: 'friend1',
        topic: 'owntracks/user/device',
        name: 'John',
      );

      repository.updateContact(friend);

      final updated = friend.copyWith(name: 'Jane');
      repository.updateContact(updated);

      expect(repository.count, equals(1));
      expect(repository.getContact('friend1')?.name, equals('Jane'));
    });

    test('should emit ContactUpdated event when updating contact', () async {
      const friend = Friend(
        id: 'friend1',
        topic: 'owntracks/user/device',
        name: 'John',
      );

      repository.updateContact(friend);

      expectLater(
        repository.changes,
        emits(isA<ContactUpdated>()),
      );

      final updated = friend.copyWith(name: 'Jane');
      repository.updateContact(updated);
    });

    test('should remove contact', () {
      const friend = Friend(
        id: 'friend1',
        topic: 'owntracks/user/device',
      );

      repository.updateContact(friend);
      repository.removeContact('friend1');

      expect(repository.count, equals(0));
      expect(repository.getContact('friend1'), isNull);
    });

    test('should emit ContactRemoved event when removing contact', () async {
      const friend = Friend(
        id: 'friend1',
        topic: 'owntracks/user/device',
      );

      repository.updateContact(friend);

      expectLater(
        repository.changes,
        emits(isA<ContactRemoved>()),
      );

      repository.removeContact('friend1');
    });

    test('should get all contacts', () {
      const friend1 = Friend(id: 'friend1', topic: 'owntracks/user1/device');
      const friend2 = Friend(id: 'friend2', topic: 'owntracks/user2/device');

      repository.updateContact(friend1);
      repository.updateContact(friend2);

      final contacts = repository.getAllContacts();
      expect(contacts.length, equals(2));
      expect(contacts, containsAll([friend1, friend2]));
    });

    test('should clear all contacts', () {
      const friend1 = Friend(id: 'friend1', topic: 'owntracks/user1/device');
      const friend2 = Friend(id: 'friend2', topic: 'owntracks/user2/device');

      repository.updateContact(friend1);
      repository.updateContact(friend2);

      repository.clearAll();

      expect(repository.count, equals(0));
      expect(repository.getAllContacts(), isEmpty);
    });
  });
}
