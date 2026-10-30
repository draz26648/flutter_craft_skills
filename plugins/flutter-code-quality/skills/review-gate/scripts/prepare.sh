#!/usr/bin/env bash
# Prepare the isolated parser; never alter the Flutter app's dependencies.
set -euo pipefail
TOOLS="$(cd "$(dirname "$0")/dart_checks" && pwd)"
cd "$TOOLS"
dart pub get
dart compile kernel bin/check.dart -o .dart_tool/check.dill
dart --version > .dart_tool/sdk-version
