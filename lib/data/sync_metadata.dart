import 'dart:math';

const syncStatusPending = 'pending';

final Random _secureRandom = Random.secure();

String newSyncUuid() {
  final bytes = List<int>.generate(16, (_) => _secureRandom.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  String hex(int byte) => byte.toRadixString(16).padLeft(2, '0');
  final chars = bytes.map(hex).join();
  return '${chars.substring(0, 8)}-'
      '${chars.substring(8, 12)}-'
      '${chars.substring(12, 16)}-'
      '${chars.substring(16, 20)}-'
      '${chars.substring(20)}';
}
