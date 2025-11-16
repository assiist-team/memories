# Tech Stack - Memories App

## Framework & Runtime
- **Application Framework:** Flutter (mobile-first, iOS and Android)
- **Language/Runtime:** Dart (Flutter), Python (backend processing)
- **Package Manager:** pub (Flutter/Dart), pip (Python)

## Frontend (Mobile)
- **UI Framework:** Flutter Material/Cupertino widgets with custom theming
- **State Management:** Riverpod
- **Voice Dictation:** In-house Flutter dictation plugin (custom Swift module)
- **Media Handling:** 
  - `image_picker` for photo/video selection
  - `camera` plugin for direct camera access
  - `video_player` for video playback
  - `audioplayers` for audio playback

## Database & Storage
- **Database:** Supabase (PostgreSQL)
- **Database Operations:** Cursor MCP for Supabase
- **Storage:** Supabase Storage (for photos, videos, audio files)
- **Full-Text Search:** PostgreSQL native text search with GIN indexes

## Backend & Serverless
- **Cloud Functions:** Supabase Edge Functions
  - Audio transcription processing
  - Narrative text generation from transcripts
  - Image optimization/thumbnail generation
  - Periodic digest generation (future)

## Authentication & Security
- **Authentication:** Supabase Auth
  - Email/password
  - Social OAuth (Google, Apple)
- **Row-Level Security:** PostgreSQL RLS policies for privacy controls

## Testing & Quality
- **Test Framework:** Flutter Test (widget, integration, unit tests)
- **Linting/Formatting:** flutter_lints (Dart), Black and Flake8 (Python)
- **Test Coverage:** Aim for >80% coverage on core business logic

## Deployment & Infrastructure
- **Mobile Distribution:**
  - iOS: App Store
  - Android: Google Play Store
- **CI/CD:** GitHub Actions
  - Automated testing on PR
  - Build and deploy to TestFlight/Play Console on merge to main
- **Monitoring:** Sentry (crash reporting, performance monitoring)

## Third-Party Services
- **Backend Platform:** Supabase (database, auth, storage, edge functions)
- **Email:** Supabase transactional email (for invites, notifications)
- **Error Tracking:** Sentry
- **Analytics:** TBD (consider PostHog or Mixpanel for privacy-friendly analytics)

## Development Tools
- **Version Control:** Git + GitHub
- **Database Migrations:** Supabase CLI + SQL migration files
- **API Testing:** Postman or Bruno for Edge Function testing
- **Design System:** Figma for UI/UX mockups and design system

## Database Schema Overview

### Core Tables
```sql
users (managed by Supabase Auth)

stories
- id (uuid, primary key)
- user_id (uuid, foreign key to auth.users)
- title (text, required)
- audio_url (text, Supabase Storage path)
- narrative_text (text, processed from audio)
- created_at (timestamptz)
- updated_at (timestamptz)

moments
- id (uuid, primary key)
- user_id (uuid, foreign key to auth.users)
- title (text, required)
- text_description (text, optional)
- photo_urls (text[], array of Supabase Storage paths)
- video_urls (text[], array of Supabase Storage paths)
- created_at (timestamptz)
- updated_at (timestamptz)

mementos
- id (uuid, primary key)
- user_id (uuid, foreign key to auth.users)
- title (text, required)
- description (text, required)
- image_url (text, Supabase Storage path)
- created_at (timestamptz)
- updated_at (timestamptz)
```

### Junction Tables (for associations)
```sql
story_moments
- story_id (uuid)
- moment_id (uuid)
- created_at (timestamptz)
- PRIMARY KEY (story_id, moment_id)

story_mementos
- story_id (uuid)
- memento_id (uuid)
- created_at (timestamptz)
- PRIMARY KEY (story_id, memento_id)

moment_mementos
- moment_id (uuid)
- memento_id (uuid)
- created_at (timestamptz)
- PRIMARY KEY (moment_id, memento_id)
```

### Future Tables (Sharing/Collaboration)
```sql
shared_memories
- id (uuid)
- memory_type (enum: story, moment, memento)
- memory_id (uuid)
- shared_with_user_id (uuid, nullable if public)
- permission_level (enum: view, edit)
- created_at (timestamptz)

collections
- id (uuid)
- name (text)
- owner_user_id (uuid)
- created_at (timestamptz)

collection_memories (many-to-many)
collection_collaborators (many-to-many)
```

## Notes
- Mobile-first approach: prioritize iOS and Android apps
- PostgreSQL with junction tables is sufficient for relationship complexity
- Full-text search using PostgreSQL native capabilities (no need for external search service)
- Supabase provides integrated solution for auth, database, storage, and serverless functions
- In-house dictation plugin is already available and should be integrated early



