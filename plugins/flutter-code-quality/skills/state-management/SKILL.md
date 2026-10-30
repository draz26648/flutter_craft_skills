---
name: state-management
description: "Implement or review Flutter state transitions, async lifecycle safety, subscriptions, and state tests using the existing stack and resolved package versions."
---

# State Management

> **Profile first.** Read `.agents/flutter-profile.yaml` in the project root, falling
> back to legacy `.claude/flutter-profile.yaml`, and take the
> stack from `state`. With no profile or field, inspect the affected feature and
> dependencies; do not introduce Bloc or Freezed by default. Read resolved versions
> before selecting APIs. Local setState can coexist with a feature state library.
> Then read the reference for that stack before writing code:
>
> | `state` | Read |
> |---|---|
> | `bloc` | `references/bloc.md` |
> | `riverpod` | `references/riverpod.md` |
> | `provider`, `signals`, `setstate` | Neither — apply the four rules below directly, using the translation table at the bottom |
>
> Do not mix stacks. Adding a Cubit to a Riverpod codebase because a Cubit is what you
> know is the single most damaging thing an agent does to a state layer: it compiles, it
> works on the screen it was added to, and it leaves the project with two sources of truth
> that no reviewer asked for. Field list:
> `../architecture/references/flutter-profile.md`, relative to this skill directory.

The four rules below hold under every stack. The references only differ in what the code
for them looks like.

## 1. State shape: one type, exhaustively switchable

Use sealed alternatives for mutually exclusive states. Keep immutable data-class state
for independent fields, forms, or retained data during refresh. Do not force a union onto
a checkbox or rewrite a valid existing state model. Avoid impossible combinations in a
class with many nullable fields. A
nullable-everything state makes every widget check three fields to work out what to
render, and the compiler stops helping.

Under `models: freezed` or `dart_mappable`, that is a sealed union. Under `models:
manual`, it is a sealed class hierarchy written by hand — Dart 3 gives you exhaustive
`switch` on any sealed type, so the guarantee does not depend on codegen.

The point is the exhaustiveness. Adding a state member should produce a compile error
everywhere it needs handling, rather than a silently missing case at runtime.

## 2. Never update state after disposal

Every state update that follows an `await` needs a liveness guard in front of it. Without
one, navigating away mid-request throws. It is intermittent, it depends on network
timing, and it is very hard to reproduce from a bug report — which is exactly why an
agent will not add the guard unless told to.

Each stack spells the guard differently (`isClosed`, `ref.mounted`, `mounted`). All of
them need it. See your stack's reference.

## 3. Subscribe to the narrowest slice that works

A widget reading one field should rebuild when that field changes, and not otherwise. On
a screen where a transaction list and a balance header read the same state, a
whole-state subscription on the header rebuilds it on every list update.

Not fatal on its own, but it compounds, and it is free to avoid at authoring time and
tedious to retrofit. Every stack has a narrowing primitive — `BlocSelector`,
`ref.watch(p.select(...))`, `context.select`. Use it.

Side effects — navigation, snackbars, dialogs — are a separate subscription from
rendering, never a branch inside a builder. A builder can run more than once for the same
state; a snackbar that fires from inside one will eventually fire twice.

## 4. No `BuildContext` in the state holder

Navigation and snackbars are the widget's job. A Cubit or Notifier holding a
`BuildContext` has bound business logic to the widget tree and cannot be tested without
pumping one.

## Testing

Test observable transitions for changed behavior: success and failure for fallible
operations, disposal and out-of-order completion for overlapping async operations. A
synchronous setter does not need an invented failure case.
The failure path is the one that ships broken, because it is the one nobody clicks
through manually.

Assert on the *sequence* of states, not just the final one. A method that reaches
`loaded` without passing through `loading` renders no spinner, and a test that only
checks the endpoint passes anyway.

## Stacks without a reference file

| Rule | `provider` | `signals` | `setstate` |
|---|---|---|---|
| Liveness guard | `ChangeNotifier` has no `mounted` — set a `_disposed` flag in `dispose()` and return before `notifyListeners()` | disposal check before assigning | `if (!mounted) return;` in the `State` |
| Narrow subscription | `context.select` | fine-grained signal reads | n/a — keep the `State` small instead |
| Side effects | listener outside `build` | `effect` | after the `await`, not in `build` |
| Test entry point | construct the notifier directly | read the signal | `testWidgets` + `pumpWidget` |

`setstate` is legitimate for local state and state lifted to a suitable common ancestor.
Use the existing shared-state mechanism when lifetime or complexity warrants it; lifting
a checkbox value does not by itself justify a new dependency.

## Common mistakes, every stack

- Business logic in the state holder that belongs in domain. It orchestrates; it does not
  decide business rules.
- One holder for a whole screen with eight unrelated responsibilities. Split by concern,
  not by route.
- Emitting or assigning a value equal to the current state and expecting a rebuild. Bloc,
  Cubit, Riverpod, and signals compare the new state with the current one and skip the
  update when they match. `setState` and `notifyListeners` rebuild regardless, which hides
  the mistake until the code moves to a stack that compares. If a list changed in place,
  produce a new list rather than mutating the existing one.
- Reading state non-reactively inside `build` (`context.read`, `ref.read`). It does not
  subscribe, so the UI goes stale in a way that looks like a caching bug.
