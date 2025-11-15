## Test coverage best practices

- **Pyramid over blanket coverage**: Emphasize fast unit tests, add widget tests for UI behavior, and write targeted integration tests for critical flows.
- **Test behavior, not implementation**: Validate observable outcomes to keep tests resilient to refactors.
- **Critical user journeys**: Authenticate, fetch/update core data, and handle failures gracefully—these paths must be covered.
- **Flutter tests**:
  - Use `flutter_test` for unit and widget tests.
  - Prefer widget tests for interactive components, navigation, and theming.
  - Consider golden tests for visual regressions where designs are stable.
- **Integration tests**: Use Flutter's `integration_test` package for full-app flows. Run on real devices/emulators via `flutter test integration_test/`.
- **Python tests**: Use `pytest` for Python utilities or scripts included in the project.
- **Mocks and fakes**: Isolate external dependencies (Supabase, network, file system). In Dart, use `mocktail` or `mockito` patterns.
- **Deterministic tests**: Avoid nondeterminism; inject clocks and random sources when needed.
- **Fast feedback**: Keep tests fast so they run on every change locally and in CI (GitHub Actions).
