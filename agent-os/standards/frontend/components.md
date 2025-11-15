## Flutter widget best practices

- **Single responsibility**: Each widget should do one thing well. Compose small widgets to build complex UIs.
- **Reusability**: Extract reusable widgets and keep APIs minimal yet expressive.
- **Clear interface**: Prefer required named parameters for constructor inputs; document with concise Dart doc comments.
- **Encapsulation**: Keep implementation details internal; expose only what callers need.
- **Consistent naming**: Use descriptive names aligned with app conventions and widget roles.
- **State management**: Prefer `StatelessWidget` when possible. Keep ephemeral UI state local; use Riverpod providers for shared/cross-cutting state. Avoid global mutable state.
- **Provider types**: Use `Provider` for immutable services, `StateProvider` for simple state, `StateNotifierProvider` for complex state, `FutureProvider`/`StreamProvider` for async data, and `ChangeNotifierProvider` sparingly (prefer `StateNotifier`).
- **Minimal parameters**: If a widget accrues many parameters, consider composition or splitting responsibilities.
- **Keys and identity**: Use `Key`s for dynamic collections to preserve state and improve update correctness.
- **Theming first**: Rely on the app theme for colors/typography/sizes rather than hardcoding values.
- **Testing**: Write focused widget tests for interactive widgets and edge cases that impact users.
