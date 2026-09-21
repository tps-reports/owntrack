/// A compare-and-swap is committed atomically before it completes. Implementations
/// must preserve the last committed snapshot after a failed write or restart.
abstract interface class OutboxStore {
  Future<String?> read();
  Future<bool> compareAndSet(String? expected, String value);
  Future<void> close();
}
