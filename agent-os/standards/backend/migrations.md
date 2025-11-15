## Database migration best practices

- **Reversible Migrations**: Always implement rollback/down methods to enable safe migration reversals
- **Small, Focused Changes**: Keep each migration focused on a single logical change for clarity and easier troubleshooting
- **Zero-Downtime Deployments**: Consider deployment order and backwards compatibility for high-availability systems
- **Separate Schema and Data**: Keep schema changes separate from data migrations for better rollback safety
- **Index Management**: Create indexes on large tables carefully, using concurrent options when available to avoid locks
- **Naming Conventions**: Use clear, descriptive names that indicate what the migration does
- **Version Control**: Always commit migrations to version control and never modify existing migrations after deployment
- **Supabase workflow**: Use Supabase CLI-generated SQL migrations for database changes. Don't edit past migrations; create new ones for incremental changes.
- **Preview environments**: Test migrations in Supabase preview branches before applying to production. Use `supabase db push --linked` for branch deployments.
- **Policy-first**: When adding tables with user/tenant data, add RLS policies in the same migration to avoid windows with open access.
- **Safety checks**: Prefer additive changes (new columns, backfilled values) and phased rollouts over destructive operations. Plan safe roll-forwards if rollbacks aren't feasible.
