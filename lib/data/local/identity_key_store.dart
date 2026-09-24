abstract interface class IdentityKeyStore {
  Future<String?> read();

  Future<void> write(String value);
}
