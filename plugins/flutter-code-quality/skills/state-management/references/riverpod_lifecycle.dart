// Compiled by scripts/test_flutter_examples.py against Riverpod 2.x and 3.x.
// This no-codegen variant deliberately uses the shared API of both majors.
import 'package:riverpod/riverpod.dart';

final walletProvider = NotifierProvider<WalletController, AsyncValue<int>>(
  WalletController.new,
);

class _Lifetime {
  bool alive = true;
}

class WalletController extends Notifier<AsyncValue<int>> {
  late _Lifetime _lifetime;
  int _request = 0;

  @override
  AsyncValue<int> build() {
    final lifetime = _Lifetime();
    _lifetime = lifetime;
    ref.onDispose(() => lifetime.alive = false);
    return const AsyncData(0);
  }

  // Latest request wins. Supply the project's repository operation as fetch.
  Future<void> refresh(Future<int> Function() fetch) async {
    final lifetime = _lifetime;
    final request = ++_request;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(fetch);
    if (!lifetime.alive ||
        !identical(lifetime, _lifetime) ||
        request != _request) {
      return;
    }
    state = result;
  }
}
