## Flutter styling and theming best practices

- **Use the app theme**: Define a single source of truth with `ThemeData` and `ColorScheme`; access colors, text styles, and component themes via `Theme.of(context)`.
- **Centralize design tokens**: Keep spacing, radii, elevations, and typography tokens in one place (Theme extensions or constants). Avoid magic numbers in widgets.
- **Prefer stock widgets**: Use Material and Cupertino widgets first. Only drop to `CustomPainter` or bespoke visuals when requirements cannot be met with standard components.
- **Component theming**: Configure `TextTheme`, `ElevatedButtonTheme`, `FilledButtonTheme`, `InputDecorationTheme`, `CardTheme`, etc., instead of styling per usage.
- **Light/dark and high-contrast**: Support both themes and ensure sufficient contrast in each. Test key screens in both modes.
- **No hardcoded colors**: Use semantic colors from the theme (e.g., `colorScheme.primary`) rather than hex values in widgets.
- **Responsive sizing**: Prefer constraints, `Flexible`/`Expanded`, and intrinsic layout over fixed pixel sizes. Use a spacing scale for paddings/margins.
- **Assets and icons**: Prefer vector assets and built-in `Icons` where possible. Manage assets via `pubspec.yaml` and respect device pixel density.
- **Encapsulate styles**: Extract frequently reused styled elements into small, reusable widgets to reduce one-off styling and drift.
