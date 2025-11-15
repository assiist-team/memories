## Database query best practices

- **Prevent SQL Injection**: Always use parameterized calls. With Supabase clients/PostgREST, use provided filter/query APIs—never build SQL strings from user input.
- **Avoid N+1**: Use PostgREST embedding (`select=*,related(*)`) or RPC for server-side joins to fetch related data efficiently.
- **Select only needed data**: Request explicit columns and avoid `SELECT *` to reduce payload and improve performance.
- **Index strategic columns**: Index columns used in filters/joins/order-by. Reassess indexes after major query pattern changes.
- **Use transactions for related changes**: Wrap related operations in transactions (SQL or RPC) to maintain consistency.
- **RLS first**: Enforce access rules via Postgres Row Level Security. Don’t re-implement authorization in the client.
- **Timeouts and limits**: Limit result sizes (pagination) and avoid long-running queries in user-facing paths.
- **Materialize when needed**: Use materialized views or edge caching (e.g., Cloudflare) for expensive, read-heavy queries.
