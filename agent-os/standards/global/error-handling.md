## Error handling best practices

- **User-Friendly Messages**: Provide clear, actionable error messages to users without exposing technical details or security information
- **Fail Fast and Explicitly**: Validate input and check preconditions early; fail with clear error messages rather than allowing invalid state
- **Specific Exception Types**: Use specific exception/error types rather than generic ones to enable targeted handling
- **Centralized Error Handling**: Handle errors at appropriate boundaries (controllers, API layers) rather than scattering try-catch blocks everywhere
- **Graceful Degradation**: Design systems to degrade gracefully when non-critical services fail rather than breaking entirely
- **Retry Strategies**: Implement exponential backoff for transient failures in external service calls
- **Clean Up Resources**: Always clean up resources (file handles, connections) in finally blocks or equivalent mechanisms
- **Sentry integration**: Capture unhandled errors and significant exceptions in Sentry across Flutter and Edge Functions. Include useful context (user ID, device, release, request ID).
- **Flutter specifics**: Use `FlutterError.onError` and `runZonedGuarded` for global capture. Show a user-friendly fallback UI and avoid crashing loops.
- **Edge Functions**: Return structured JSON errors with appropriate HTTP status codes. Log internal details server-side; never leak stack traces to clients.
