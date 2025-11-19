-- Migration: Create Storage Buckets for Moments and Stories
-- Description: Creates the required Supabase Storage buckets for photos, videos, and audio files
--              with appropriate file size limits, MIME type restrictions, and RLS policies.

-- Create moments-photos bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'moments-photos',
  'moments-photos',
  false,
  10485760, -- 10MB in bytes
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic']
)
ON CONFLICT (id) DO NOTHING;

-- Create moments-videos bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'moments-videos',
  'moments-videos',
  false,
  104857600, -- 100MB in bytes
  ARRAY['video/mp4', 'video/quicktime', 'video/x-msvideo']
)
ON CONFLICT (id) DO NOTHING;

-- Create stories-audio bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'stories-audio',
  'stories-audio',
  false,
  52428800, -- 50MB in bytes
  ARRAY['audio/m4a', 'audio/mpeg', 'audio/wav']
)
ON CONFLICT (id) DO NOTHING;

-- RLS Policies for moments-photos bucket
-- Path structure: {userId}/{filename}

-- Policy: Users can upload their own photos
CREATE POLICY "Users can upload their own photos"
ON storage.objects
FOR INSERT
WITH CHECK (
  bucket_id = 'moments-photos' AND
  auth.uid()::text = (string_to_array(name, '/'))[1]
);

-- Policy: Users can read their own photos
CREATE POLICY "Users can read their own photos"
ON storage.objects
FOR SELECT
USING (
  bucket_id = 'moments-photos' AND
  auth.uid()::text = (string_to_array(name, '/'))[1]
);

-- Policy: Users can update their own photos
CREATE POLICY "Users can update their own photos"
ON storage.objects
FOR UPDATE
USING (
  bucket_id = 'moments-photos' AND
  auth.uid()::text = (string_to_array(name, '/'))[1]
)
WITH CHECK (
  bucket_id = 'moments-photos' AND
  auth.uid()::text = (string_to_array(name, '/'))[1]
);

-- Policy: Users can delete their own photos
CREATE POLICY "Users can delete their own photos"
ON storage.objects
FOR DELETE
USING (
  bucket_id = 'moments-photos' AND
  auth.uid()::text = (string_to_array(name, '/'))[1]
);

-- RLS Policies for moments-videos bucket
-- Path structure: {userId}/{filename}

-- Policy: Users can upload their own videos
CREATE POLICY "Users can upload their own videos"
ON storage.objects
FOR INSERT
WITH CHECK (
  bucket_id = 'moments-videos' AND
  auth.uid()::text = (string_to_array(name, '/'))[1]
);

-- Policy: Users can read their own videos
CREATE POLICY "Users can read their own videos"
ON storage.objects
FOR SELECT
USING (
  bucket_id = 'moments-videos' AND
  auth.uid()::text = (string_to_array(name, '/'))[1]
);

-- Policy: Users can update their own videos
CREATE POLICY "Users can update their own videos"
ON storage.objects
FOR UPDATE
USING (
  bucket_id = 'moments-videos' AND
  auth.uid()::text = (string_to_array(name, '/'))[1]
)
WITH CHECK (
  bucket_id = 'moments-videos' AND
  auth.uid()::text = (string_to_array(name, '/'))[1]
);

-- Policy: Users can delete their own videos
CREATE POLICY "Users can delete their own videos"
ON storage.objects
FOR DELETE
USING (
  bucket_id = 'moments-videos' AND
  auth.uid()::text = (string_to_array(name, '/'))[1]
);

-- RLS Policies for stories-audio bucket
-- Path structure: stories/audio/{userId}/{storyId}/{timestamp}.m4a

-- Policy: Users can upload their own story audio
CREATE POLICY "Users can upload their own story audio"
ON storage.objects
FOR INSERT
WITH CHECK (
  bucket_id = 'stories-audio' AND
  auth.uid()::text = (string_to_array(name, '/'))[3]
);

-- Policy: Users can read their own story audio
CREATE POLICY "Users can read their own story audio"
ON storage.objects
FOR SELECT
USING (
  bucket_id = 'stories-audio' AND
  auth.uid()::text = (string_to_array(name, '/'))[3]
);

-- Policy: Users can update their own story audio
CREATE POLICY "Users can update their own story audio"
ON storage.objects
FOR UPDATE
USING (
  bucket_id = 'stories-audio' AND
  auth.uid()::text = (string_to_array(name, '/'))[3]
)
WITH CHECK (
  bucket_id = 'stories-audio' AND
  auth.uid()::text = (string_to_array(name, '/'))[3]
);

-- Policy: Users can delete their own story audio
CREATE POLICY "Users can delete their own story audio"
ON storage.objects
FOR DELETE
USING (
  bucket_id = 'stories-audio' AND
  auth.uid()::text = (string_to_array(name, '/'))[3]
);

