## Accessibility best practices (Flutter)

- **Semantics**: Use `Semantics` to convey roles and labels. Provide `semanticLabel` for images when informative; use `ExcludeSemantics` for decorative content.
- **Keyboard navigation**: Support keyboard traversal with `Focus`, `FocusTraversalGroup`, `Shortcuts`, and `Actions`. Ensure visible focus indicators.
- **Color contrast**: Maintain at least 4.5:1 contrast for text. Use `ColorScheme` and test in light/dark modes.
- **Text scaling**: Respect system text scaling. Avoid fixed text sizes and verify no overflow at larger scales.
- **Screen readers**: Test with TalkBack (Android), VoiceOver (iOS), and screen readers on web. Verify reading order and labels.
- **Structure and grouping**: While Flutter isn’t HTML, use semantics to group related elements and convey hierarchy where it improves comprehension.
- **Focus management**: Manage focus explicitly for modals, dialogs, and dynamic content (`FocusScope.of(context).requestFocus(...)`).
- **Touch targets**: Ensure interactive controls are at least 44 logical px in both dimensions.
