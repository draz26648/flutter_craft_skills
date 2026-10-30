---
name: architecture
description: "Place or refactor Flutter feature code using the project’s existing architecture and dependency boundaries. Use for structural changes, not every new file."
---

# Architecture

> **Profile first.** Read `.agents/flutter-profile.yaml` in the project root before
> placing any file. This skill is governed by `structure`, `state`, and `di`. With no
> profile, discover the architecture and stack from source before using the example
> below. The example is not a migration target. Under `structure: layer_first` the layers are top-level directories and features
> are subdirectories inside them; the rules about which direction dependencies point are
> unchanged. If the `.agents` profile is absent, check legacy
> `.claude/flutter-profile.yaml`. Field list: `references/flutter-profile.md`.

The following feature-first example fits layered projects. Preserve simpler or custom
architectures when that is what the project uses. The rules exist to keep business logic testable
without a Flutter binding and swappable without touching the UI.

## Structure

```
lib/
├── core/                      # shared across features
│   ├── theme/                 # tokens, ThemeExtension
│   ├── network/               # Dio setup, interceptors
│   ├── errors/                # Failure types
│   └── widgets/               # genuinely shared widgets
└── features/
    └── wallet/
        ├── domain/            # pure Dart — no flutter/ imports at all
        │   ├── entities/
        │   ├── repositories/  # abstract interfaces only
        │   └── usecases/
        ├── data/
        │   ├── models/        # DTOs with fromJson/toJson
        │   ├── datasources/   # remote and local
        │   └── repositories/  # concrete implementations
        └── presentation/
            ├── cubit/
            ├── pages/
            └── widgets/
```

## The rules and why

**Domain imports nothing from Flutter.** Not `material.dart`, not `widgets.dart`, not
even for `Color` or `IconData`. Keeping domain independent of Flutter lets its tests run as ordinary Dart tests and
avoids unnecessary widget/runtime coupling. If domain needs to express a
visual concept, it returns an enum and presentation maps it.

**Dependencies point inward.** Presentation knows domain. Data knows domain. Domain
knows nothing about either. A domain file importing from `data/` is the inversion this
structure exists to prevent.

**Repositories are interfaces in domain, implementations in data.** The Cubit depends on
the interface, which is what makes it testable with a mock instead of a live API.

**No `BuildContext` below presentation.** A use case taking a context has bound business
logic to the widget tree.

**Separate entities and DTOs when their shapes or responsibilities differ.** Preserve
existing simple models when a second type would only duplicate fields. Keep transport
conversion at the data boundary.

## Where things go

| Thing | Layer |
|---|---|
| "Transfer requires balance ≥ amount" | domain/usecases |
| "Balance shows two decimals" | presentation |
| "The API returns cents as an int" | data/models |
| "Failed transfers retry twice" | data/repositories |
| "The button is disabled while loading" | presentation/cubit |

## When to skip a use case

A use case that only forwards a call to a repository adds a file and no behaviour. For a
straight read with no rules, let the Cubit call the repository directly. Add the use case
when there is actual logic to hold — validation, orchestration across repositories,
business rules. Ceremony for its own sake makes a codebase harder to read, not more
correct.

## Common mistakes

- A `utils/` or `helpers/` folder at the root. It becomes a dumping ground within a
  month. Put the function next to what uses it.
- Shared widgets moved to `core/widgets/` on first reuse. Wait for the third usage —
  two usages that diverge later are cheaper to split than to un-merge.
- Cubits calling data sources directly, skipping the repository. That couples
  presentation to the transport layer.
