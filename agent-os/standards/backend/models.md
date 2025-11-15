## Database model best practices

- **Clear Naming**: Use singular names for models and plural for tables following your framework's conventions
- **Timestamps**: Include created and updated timestamps on all tables for auditing and debugging
- **Data Integrity**: Use database constraints (NOT NULL, UNIQUE, foreign keys) to enforce data rules at the database level
- **Appropriate Data Types**: Choose data types that match the data's purpose and size requirements
- **Indexes on Foreign Keys**: Index foreign key columns and other frequently queried fields for performance
- **Validation at Multiple Layers**: Implement validation at both model and database levels for defense in depth
- **Relationship Clarity**: Define relationships clearly with appropriate cascade behaviors and naming conventions
- **Avoid Over-Normalization**: Balance normalization with practical query performance needs
- **Row Level Security (RLS)**: Enable RLS on user/tenant data and write explicit policies that match business rules. Favor RLS over app-layer checks.
- **Generated columns and triggers**: Use generated columns and triggers for `updated_at` and audit fields to ensure consistency.
- **Enums for domain states**: Prefer Postgres enums for stable, finite state fields (with migration plans for changes).
