## Security best practices

- **JWT token management**: Use Supabase's automatic token refresh. Handle `onAuthStateChange` in Flutter to catch expired sessions and prompt re-authentication.
- **Service role key protection**: Never embed service-role keys in client apps. Store in environment variables, CI secrets, or Supabase Vault. Use anon key in clients; enforce permissions via RLS.
- **Secure storage**: Use `flutter_secure_storage` for sensitive data on device (refresh tokens, user preferences). Never use SharedPreferences for secrets.
- **CORS configuration**: Configure allowed origins for Edge Functions explicitly. Avoid wildcards (`*`) in production; list specific domains.
- **RLS policy testing**: Write tests for RLS policies. Use `SET LOCAL role` in SQL to verify policies work correctly for different user contexts.
- **API key rotation**: Rotate anon keys if compromised. Service role keys should be treated like production passwords—rotate regularly and on security events.
- **Input sanitization**: Sanitize user input to prevent injection attacks. Supabase PostgREST is parameterized, but validate/sanitize in Edge Functions and SQL functions.
- **HTTPS only**: Enforce HTTPS for all production traffic. Supabase provides this by default; ensure custom domains use valid certificates.
- **Secrets management**: Use Supabase Edge Function environment variables for secrets (API keys, webhooks). Load via `Deno.env.get()` and never commit to version control.
- **Authentication state**: Always check `supabase.auth.currentUser` or session validity before privileged operations. Don't rely on client-side state alone.
- **Audit logging**: Log sensitive operations (user deletions, permission changes, data exports) with user ID, timestamp, and action for compliance and forensics.
- **Dependency scanning**: Regularly update dependencies and scan for vulnerabilities using `flutter pub outdated`, Dependabot, or GitHub security alerts.

