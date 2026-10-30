# Riverpod

Read this when the profile says `state: riverpod`. The four rules in `SKILL.md` are the
contract; this is what they look like in Riverpod.

Check `pubspec.lock` first. The main examples target Riverpod 3.x and use
`riverpod_generator` (`@riverpod`) only when the project already uses code generation. Without
codegen the same shapes exist as `NotifierProvider` and `AsyncNotifierProvider` declared
by hand — the rules are identical, only the declaration differs.

## State shape

For anything loaded asynchronously, `AsyncValue` is already the sealed union — `loading`,
`error`, `data`. Do not wrap it in a hand-written union with its own loading and failure
members; that is two state machines for one piece of state, and they drift.

```dart
@riverpod
class WalletController extends _$WalletController {
  @override
  Future<WalletData> build() =>
      ref.watch(walletRepositoryProvider).fetchWallet();
}
```

Write a sealed union (rule 1) when the feature has states `AsyncValue` cannot express —
a multi-step form, an editing mode, an optimistic update pending confirmation. Then it is
`Notifier<MyState>` with the union as its type.

`build()` runs on first read and again on every dependency change, so it holds the
initial load and nothing else. No analytics calls, no navigation, no writes — a side
effect in `build()` fires again on every invalidation, which is the Riverpod bug that
takes longest to find.

## Updating state

```dart
Future<void> refresh() async {
  state = const AsyncValue.loading();
  final next = await AsyncValue.guard(
    () => ref.read(walletRepositoryProvider).fetchWallet(),
  );
  if (!ref.mounted) return;
  state = next;
}
```

`AsyncValue.guard` routes a thrown error into `AsyncError` instead of an unhandled
exception, and it preserves the stack trace. A bare `try/catch` that assigns
`AsyncValue.error(e, StackTrace.current)` loses the original trace.

`guard` does not make the `await` safe. Assigning `state` after disposal throws, so the
liveness check (rule 2) sits between the `await` and the assignment — which is why the
result goes into a local first rather than straight into `state`. The same holds for any
other `await`:

```dart
Future<void> submit(Transfer transfer) async {
  final result = await ref.read(transferRepositoryProvider).send(transfer);
  if (!ref.mounted) return;
  state = AsyncValue.data(result);
}
```

Riverpod 2.x uses `valueOrNull` where 3.x uses `value`, and has no `ref.mounted`.
Do not mix these APIs. For 2.x use a cancellation/lifecycle token scoped to each build
and capture that token before awaiting. Invalidate it in `ref.onDispose`. A permanent
`_disposed` field can stay true when a Notifier rebuilds; a flag simply reset in build can
also admit a stale request. Track build/request identity as well as disposal.

For either major, define whether overlapping requests are latest-wins, serialized, or
ignored while in flight. Test reversed response order: mounted only proves liveness.
Runnable 2.x and 3.x examples are in `references/riverpod_lifecycle.dart`; the repository
fixture runner compiles and tests that source against both majors.

API changes: https://riverpod.dev/docs/3.0_migration and
https://riverpod.dev/docs/whats_new .

`autoDispose` (the default under `@riverpod`) makes this sharply more likely to matter,
not less: the provider is torn down as soon as the last listener leaves the screen, which
is exactly the navigate-away-mid-request case.

## Rebuild scope

```dart
final balance = ref.watch(
  walletControllerProvider.select((s) => s.value?.balance),
);
```

`select` is the narrowing primitive (rule 3) — the widget rebuilds only when the selected
value changes by `==`. Selecting an object without value equality selects nothing.

`ref.listen` in the widget for UI effects. Provider-to-provider listeners may be valid
for non-UI coordination; keep navigation and snackbars in the widget:

```dart
ref.listen(walletControllerProvider, (previous, next) {
  if (next case AsyncError(:final error)) showErrorSnackBar(context, error);
});
```

Render every branch of `AsyncValue` explicitly. `.when(data:, loading:, error:)` forces
that; `.value!` skips the loading and error cases and crashes on the first slow network.

## Dependency injection

Riverpod is the DI container — under `di: riverpod` there is no `get_it`. A repository is
a provider, and a controller reads it with `ref.watch`. Overriding that provider in a test
is what makes the controller testable, which is the same role the constructor parameter
plays under Bloc.

## Testing

```dart
test('refresh emits loading then data', () async {
  final container = ProviderContainer(
    overrides: [
      walletRepositoryProvider.overrideWithValue(FakeWalletRepository()),
    ],
  );
  addTearDown(container.dispose);

  // Finish build() before refresh(), so initial loading cannot race with this test.
  final subscription = container.listen(walletControllerProvider, (_, _) {});
  addTearDown(subscription.close);
  await container.read(walletControllerProvider.future);
  final states = <AsyncValue<WalletData>>[];
  container.listen(
    walletControllerProvider,
    (_, next) => states.add(next),
    fireImmediately: false,
  );

  await container.read(walletControllerProvider.notifier).refresh();

  expect(states.map((s) => s.runtimeType), [
    AsyncLoading<WalletData>,
    AsyncData<WalletData>,
  ]);
});
```

`addTearDown(container.dispose)` is not optional — a leaked container keeps its providers
alive across tests and produces failures that only appear when the whole file runs.

After awaiting initial load, `container.listen` records only refresh transitions, which makes
this the equivalent of `blocTest`'s `expect` list. Reading only the final value passes on
a controller that never emitted `loading`.

Test the failure path by overriding the repository with one that throws, and assert
`AsyncError` — not that an exception escaped.
