## Performance best practices

- **Profile before optimizing**: Use Flutter DevTools (Timeline, Memory, Network tabs) to identify actual bottlenecks rather than premature optimization.
- **Image optimization**: Use `cached_network_image` for remote images with caching. Compress images before upload; serve via Supabase Storage with CDN caching (Cloudflare).
- **Lazy loading**: Use `ListView.builder`, `GridView.builder`, and `PageView.builder` for large lists. Load data on-demand rather than upfront.
- **Widget rebuilds**: Minimize rebuilds with `const` constructors, `RepaintBoundary` for expensive widgets, and selective provider listening (Riverpod's `.select()`).
- **Async operations**: Keep heavy computation off the UI thread. Use `compute()` for isolates when processing large data sets.
- **Database query optimization**: Use `EXPLAIN ANALYZE` in Supabase SQL Editor to profile slow queries. Add indexes, optimize joins, and limit result sets.
- **Supabase connection pooling**: Supabase handles pooling; avoid creating multiple clients. Reuse a single instance across the app.
- **Bundle size**: Analyze app size with `flutter build --analyze-size`. Remove unused dependencies and assets. Use deferred loading for large features.
- **Startup time**: Minimize work in app initialization. Defer non-critical operations and lazy-load providers/services.
- **Network efficiency**: Batch API calls where possible. Use PostgREST's select filtering to fetch only required columns and related data in single requests.
- **Caching strategy**: Cache frequently accessed, rarely changing data locally (Hive, Isar, or SQLite). Set appropriate TTLs and invalidation logic.
- **Edge caching**: Configure Cloudflare caching rules for static assets and cacheable API responses. Use appropriate `Cache-Control` headers from Edge Functions.
- **Memory leaks**: Dispose controllers, streams, and listeners properly. Use DevTools Memory tab to detect leaks during development.
- **Release builds**: Always test performance on release builds (`flutter build --release`), not debug. Debug builds are significantly slower.

