## Responsive design best practices (Flutter)

- **Mobile-first**: Design for small screens first, then scale layouts up for tablet and desktop.
- **Use layout primitives**: Prefer `LayoutBuilder`, `MediaQuery`, `Flexible`, `Expanded`, and `FittedBox` to adapt to available space.
- **Canonical breakpoints**: Define app breakpoints in code (e.g., 0–600, 600–1024, 1024+ logical px) and reuse them via a shared constants file.
- **Adaptive grids**: For grid content, use `SliverGridDelegateWithFixedCrossAxisCount` or `SliverGridDelegateWithMaxCrossAxisExtent` depending on the need.
- **Maintain aspect ratios**: Use `AspectRatio`, `BoxFit`, and constrained boxes to prevent overflows and layout shifts.
- **Touch targets**: Ensure interactive elements are at least 44 logical px in both dimensions.
- **Typography scaling**: Respect user text scaling and use `TextTheme` consistently; avoid hardcoded text sizes.
- **Test on devices**: Verify on multiple sizes and platforms (`flutter run -d chrome`, iOS, Android). Resize browser windows for web.
- **Avoid nested scrollables**: Prefer `CustomScrollView` and slivers to compose scrollable content cleanly.
- **Performance**: Use `ListView.builder`/`GridView.builder` for large lists; avoid expensive layouts inside item builders.
