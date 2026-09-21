enum CredentialSource { secure, legacy }

/// Safe metadata for a migration choice. Secret values never enter UI state.
class CredentialConflict {
  final String key;
  final String label;

  const CredentialConflict({required this.key, required this.label});
}

/// Captures the reviewed versions privately in its resolver. Applying a choice
/// requires explicit selection for every conflict and revalidation of storage.
class CredentialMigrationConflict extends StateError {
  final List<CredentialConflict> conflicts;
  final Future<void> Function(Map<String, CredentialSource>) _resolve;

  CredentialMigrationConflict({
    required List<CredentialConflict> conflicts,
    required Future<void> Function(Map<String, CredentialSource>) resolve,
  }) : conflicts = List.unmodifiable(conflicts),
       _resolve = resolve,
       super(
         'Legacy and secure credentials conflict. Both copies have been retained.',
       );

  Future<void> resolve(Map<String, CredentialSource> choices) =>
      _resolve(Map.unmodifiable(choices));
}
