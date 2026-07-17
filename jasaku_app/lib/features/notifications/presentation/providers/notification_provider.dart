import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/storage.dart';

const _unreadKey = 'unread_notif_count';

final unreadNotifProvider =
    StateNotifierProvider<UnreadNotifNotifier, int>((ref) => UnreadNotifNotifier());

class UnreadNotifNotifier extends StateNotifier<int> {
  UnreadNotifNotifier() : super(0) {
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await StorageService.read(_unreadKey);
      if (raw != null) state = int.tryParse(raw) ?? 0;
    } catch (_) {}
  }

  Future<void> increment() async {
    state = state + 1;
    await StorageService.write(_unreadKey, '$state');
  }

  Future<void> reset() async {
    state = 0;
    await StorageService.write(_unreadKey, '0');
  }
}
