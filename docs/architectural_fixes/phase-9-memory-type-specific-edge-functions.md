# Phase 9: Memory Type-Specific Edge Functions

## Status: ✅ COMPLETED

**Implementation Date**: January 2025

All three type-specific edge functions have been implemented and integrated. The old `generate-title` function has been completely removed with no backward compatibility maintained.

## Objective

Refactor the shared `generate-title` edge function into three separate, memory-type-specific edge functions:
- `process-moment` - Handles moment-specific AI processing
- `process-memento` - Handles memento-specific AI processing  
- `process-story` - Handles story-specific AI processing (narrative generation, title generation, etc.)

## Problem Statement

Previously, we had a single `generate-title` edge function that handled title generation for all three memory types (moments, stories, mementos). This created several issues:

1. **Lack of Type-Specific Logic**: Each memory type has different processing needs:
   - **Moments**: Title generation + text processing (input_text → processed_text)
   - **Mementos**: Title generation + text processing (input_text → processed_text)
   - **Stories**: Complex processing including narrative generation, title generation, and status management

2. **Missing Text Processing**: The `input_text` field contains raw transcription from dictation, which often has:
   - Run-on sentences
   - Incomplete sentences
   - Poor readability
   - Information loss due to transcription errors
   
   The `processed_text` field is designed to contain AI-processed, cleaned-up text that:
   - Is optimized for human readability
   - Has proper sentence structure (breaks up run-on sentences)
   - Minimizes information loss
   - May not be perfectly grammatically correct, but is significantly better than raw transcription
   
   Previously, moments and mementos didn't have their `input_text` processed into `processed_text`, leaving users with poorly formatted text.

2. **Poor Separation of Concerns**: A single function handling all types violates single responsibility principle and makes it harder to:
   - Add type-specific features (e.g., story narrative generation)
   - Debug issues specific to one memory type
   - Scale processing differently per type
   - Maintain independent versioning

3. **Missing Story Processing**: Stories require a full processing pipeline (narrative generation, status updates, retry logic) that doesn't fit into a simple "generate-title" function.

4. **Future Extensibility**: As we add more memory types or processing features, a shared function will become increasingly complex and harder to maintain.

## Target Architecture

### Edge Functions Structure

```
supabase/functions/
├── process-moment/
│   └── index.ts          # Moment-specific processing
├── process-memento/
│   └── index.ts          # Memento-specific processing
└── process-story/
    └── index.ts          # Story-specific processing (narrative + title)
```

### Function Responsibilities

#### `process-moment`
- **Input**: `{ memoryId: string }` (fetches data from DB)
- **Output**: `{ title: string, processedText: string, status: "success" | "fallback" | "partial", generatedAt: string }`
- **Responsibilities**:
  - Fetch `input_text` from `memories` table using `memoryId`
  - Process `input_text` → `processed_text`:
    - Clean up run-on sentences
    - Break into proper sentence structure
    - Remove filler words that don't convey meaningful information (e.g., "um", "uh", "like", "you know")
    - Optimize for readability
    - Minimize information loss
  - Generate concise title from processed text (≤60 chars)
  - Update `memories` table:
    - `processed_text` = cleaned, readable text
    - `title` = generated title
    - `title_generated_at` = now()
  - Log generation metrics
  - Fallback to "Untitled Moment" if title generation fails
  - Return "partial" status if text processing succeeds but title generation fails

#### `process-memento`
- **Input**: `{ memoryId: string }` (fetches data from DB)
- **Output**: `{ title: string, processedText: string, status: "success" | "fallback" | "partial", generatedAt: string }`
- **Responsibilities**:
  - Fetch `input_text` from `memories` table using `memoryId`
  - Process `input_text` → `processed_text`:
    - Clean up run-on sentences
    - Break into proper sentence structure
    - Remove filler words that don't convey meaningful information (e.g., "um", "uh", "like", "you know")
    - Optimize for readability
    - Minimize information loss
    - May include memento-specific enhancements (e.g., emphasizing significance)
  - Generate title from processed text with memento-specific context/prompts
  - Update `memories` table:
    - `processed_text` = cleaned, readable text
    - `title` = generated title
    - `title_generated_at` = now()
  - Log generation metrics
  - Fallback to "Untitled Memento" if title generation fails
  - Return "partial" status if text processing succeeds but title generation fails

#### `process-story`
- **Input**: `{ memoryId: string }` (fetches data from DB)
- **Output**: `{ title: string, processedText: string, status: "success" | "fallback" | "failed", generatedAt: string }`
- **Responsibilities**:
  - Fetch story data (input_text, memory_type) from `memories` table
  - Fetch current retry_count from `story_fields` table
  - Validate that `input_text` exists, is not empty, and contains meaningful content (≥3 chars, ≥2 non-whitespace chars)
  - Generate narrative text from input_text using LLM
  - Generate title from narrative text
  - Update `memories` table:
    - `processed_text` = generated narrative
    - `title` = generated title
    - `title_generated_at` = now()
  - Update `story_fields` table:
    - `story_status` = 'complete' (on success) or 'failed' (on error)
    - `processing_completed_at` = now()
    - `narrative_generated_at` = now() (on success)
    - `processing_error` = error message (on failure)
    - `retry_count` = incremented (on failure)
    - `last_retry_at` = now() (on failure)
  - Log comprehensive processing metrics
  - Support retry mechanism (can be called multiple times for failed stories)

## Implementation Steps

### Step 1: Create `process-moment` Edge Function ✅
**File**: `supabase/functions/process-moment/index.ts`

**Implemented**:
1. ✅ Created new function with moment-specific logic
2. ✅ Accepts `memoryId` parameter (fetches data from DB)
3. ✅ Fetches `input_text` from `memories` table using `memoryId`
4. ✅ Validates memory type is 'moment'
5. ✅ Processes `input_text` → `processed_text` using text processing prompt
6. ✅ Generates title from `processed_text` with moment-specific prompt
7. ✅ Updates `memories` table with both `processed_text` and `title`
8. ✅ Returns response with title, processedText, and status
9. ✅ Handles partial success (text processed but title failed)
10. ✅ Logs comprehensive metrics

**Text Processing Prompt**:
```
Transform this transcribed text into clean, readable text optimized for human reading. The text comes from voice dictation and may contain run-on sentences, incomplete thoughts, and filler words. Your task is to:

- Break up run-on sentences into proper sentence structure
- Ensure sentences are complete and grammatically coherent
- Remove filler words that don't convey meaningful information (e.g., "um", "uh", "like", "you know", "I mean")
- Preserve all information and meaning from the original
- Maintain the natural flow and voice of the speaker
- Do not add information that wasn't in the original
- Keep the tone and style consistent

The output should be readable and well-structured, but doesn't need to be perfectly grammatically correct. Focus on readability and information preservation.

Original text: {input_text}

Return only the cleaned text, nothing else.
```

**Title Generation Prompt**:
```
Generate a concise, engaging title (maximum 60 characters) for a brief moment or memory based on this cleaned text. The title should be descriptive but brief, capturing the essence of what happened. Return only the title text, nothing else.

Text: {processed_text}
```

### Step 2: Create `process-memento` Edge Function ✅
**File**: `supabase/functions/process-memento/index.ts`

**Implemented**:
1. ✅ Created function based on `process-moment` logic
2. ✅ Updated text processing prompt to emphasize memento significance
3. ✅ Updated title generation prompt to use memento-specific context
4. ✅ Updated fallback title to "Untitled Memento"
5. ✅ Updated logging to indicate memento processing
6. ✅ Validates memory type is 'memento'
7. ✅ Handles partial success cases

**Text Processing Prompt**:
```
Transform this transcribed text into clean, readable text optimized for human reading. The text describes a special memento or keepsake. The text comes from voice dictation and may contain run-on sentences, incomplete thoughts, and filler words. Your task is to:

- Break up run-on sentences into proper sentence structure
- Ensure sentences are complete and grammatically coherent
- Remove filler words that don't convey meaningful information (e.g., "um", "uh", "like", "you know", "I mean")
- Preserve all information and meaning from the original
- Emphasize the significance and meaning of the memento
- Maintain the natural flow and voice of the speaker
- Do not add information that wasn't in the original
- Keep the tone and style consistent

The output should be readable and well-structured, but doesn't need to be perfectly grammatically correct. Focus on readability, information preservation, and highlighting the memento's importance.

Original text: {input_text}

Return only the cleaned text, nothing else.
```

**Title Generation Prompt**:
```
Generate a concise, engaging title (maximum 60 characters) for a special memento or keepsake based on this cleaned text. The title should capture the significance and meaning of this memento. Return only the title text, nothing else.

Text: {processed_text}
```

### Step 3: Create `process-story` Edge Function ✅
**File**: `supabase/functions/process-story/index.ts`

**Implemented**:
1. ✅ Created new function with story-specific logic
2. ✅ Accepts `memoryId` parameter
3. ✅ Fetches story data from `memories` table:
   - `input_text`
   - `memory_type` / `capture_type` (verifies it's 'story')
4. ✅ Fetches retry_count from `story_fields` table
5. ✅ Validates that `input_text` exists, is not empty, and contains meaningful content
6. ✅ Generates narrative text:
   - Uses LLM to transform `input_text` into polished narrative paragraphs
   - Stores in `processed_text` in `memories` table
7. ✅ Generates title:
   - Uses narrative text (or input_text if narrative generation failed)
   - Stores in `title` and `title_generated_at` in `memories` table
8. ✅ Updates `story_fields` table with status, timestamps, and error handling
9. ✅ Handles errors with retry logic (increments retry_count, sets last_retry_at)
10. ✅ Logs comprehensive metrics
11. ✅ Returns appropriate status: "success", "fallback", or "failed"

**Note**: This function processes text only. Audio upload happens independently and does not block text processing. The audio file is stored for archival/replay purposes but is not used in the text processing pipeline.

**Narrative Prompt Example**:
```
Transform this transcript into a polished, engaging narrative story. The transcript comes from voice dictation and may contain filler words and incomplete thoughts. The narrative should:
- Be written in first or third person as appropriate
- Flow naturally with proper paragraphs
- Remove filler words that don't convey meaningful information (e.g., "um", "uh", "like", "you know", "I mean")
- Capture the emotion and context of the memory
- Be engaging and readable
- Preserve the key details and meaning

Transcript: {input_text}

Return only the narrative text, nothing else.
```

**Title Prompt Example**:
```
Generate a concise, engaging title (maximum 60 characters) for this story narrative. The title should capture the essence and emotion of the story. Return only the title text, nothing else.

Narrative: {processed_text or input_text}
```

### Step 4: Update Flutter Service Layer ✅
**File**: `lib/services/memory_processing_service.dart` (new service created)

**Implemented**:
1. ✅ Created new `MemoryProcessingService` service
2. ✅ Implemented methods to call appropriate edge function:
   - `processMoment({ required String memoryId })` → Returns `MemoryProcessingResponse`
   - `processMemento({ required String memoryId })` → Returns `MemoryProcessingResponse`
   - `processStory({ required String memoryId })` → Returns `MemoryProcessingResponse`
3. ✅ Created response model with all required fields:
   ```dart
   class MemoryProcessingResponse {
     final String title;
     final String processedText;
     final String status; // 'success' | 'fallback' | 'partial' | 'failed'
     final DateTime generatedAt;
   }
   ```
4. ✅ Handles errors with proper exception messages
5. ✅ Uses Riverpod for dependency injection

### Step 5: Update Save Service ✅
**File**: `lib/services/memory_save_service.dart`

**Implemented**:
1. ✅ Updated `saveMoment()` method:
   - After creating memory record, calls appropriate processing function:
     - Moments: `processMoment(memoryId: memoryId)` → Waits for completion, updates `processed_text` and `title`
     - Mementos: `processMemento(memoryId: memoryId)` → Waits for completion, updates `processed_text` and `title`
     - Stories: `processStory(memoryId: memoryId)` → Fire-and-forget (async, non-blocking)
2. ✅ Updated `updateMemory()` method with same processing logic
3. ✅ For stories, processing happens asynchronously (fire and forget) - doesn't block save operation
4. ✅ For moments/mementos, waits for processing to complete before returning
5. ✅ Removed all `generate-title` calls and `TitleGenerationService` dependency
6. ✅ Updated progress callbacks to show "Processing text..." message
7. ✅ Handles partial success cases (text processed but title failed)
8. ✅ Uses fallback titles when processing fails or no input_text available

### Step 6: Update Story Processing Flow ✅
**Files**: 
- `lib/services/memory_save_service.dart`

**Implemented**:
1. ✅ When story is saved, `process-story` edge function is called asynchronously
2. ✅ Processing doesn't block save operation (fire-and-forget pattern)
3. ✅ Story detail view can check `story_fields.story_status` to show processing status
4. ✅ Processing failures are handled gracefully with error logging
5. ✅ Retry mechanism supported (function can be called multiple times for failed stories)

### Step 7: Add Database Triggers (Optional) ⏭️
**Status**: Not implemented - using client-side calls for better error handling and retry control

**Note**: Database triggers could be added in the future if automatic processing is desired.

### Step 8: Remove `generate-title` Function ✅
**File**: `supabase/functions/generate-title/index.ts`

**Completed**:
1. ✅ Removed `generate-title` edge function completely
2. ✅ Removed `TitleGenerationService` and all related files
3. ✅ Removed test files for old service
4. ✅ Updated migration comments to reference new processing functions
5. ✅ No backward compatibility maintained - clean break

## Implementation Summary

### Completed Implementation

All three edge functions have been created and integrated:

1. **Edge Functions Created**:
   - ✅ `supabase/functions/process-moment/index.ts` - 460 lines
   - ✅ `supabase/functions/process-memento/index.ts` - 460 lines  
   - ✅ `supabase/functions/process-story/index.ts` - 460+ lines

2. **Flutter Services**:
   - ✅ Created `lib/services/memory_processing_service.dart` - New unified service
   - ✅ Updated `lib/services/memory_save_service.dart` - Uses new processing service
   - ✅ Removed `lib/services/title_generation_service.dart` - Old service deleted

3. **Cleanup**:
   - ✅ Removed `generate-title` edge function completely
   - ✅ Removed all related test files
   - ✅ Updated migration comments
   - ✅ No backward compatibility maintained

### Key Implementation Details

- **Text Processing**: All functions process `input_text` → `processed_text` with type-specific prompts
- **Title Generation**: Titles generated from processed text (or narrative for stories)
- **Story Processing**: Asynchronous, non-blocking with status tracking in `story_fields` table
- **Error Handling**: Comprehensive error handling with retry logic for stories
- **Status Tracking**: Stories track processing status, retry count, and errors in `story_fields` table

## Testing Strategy

### Unit Tests (Edge Functions)
- Test each function with valid inputs
- Test text processing (verify run-on sentences are broken up, readability improved)
- Test error handling (missing API keys, invalid memoryId, etc.)
- Test fallback behavior
- Test partial success (text processed but title failed)
- Test story processing with/without audio

### Integration Tests
- Test end-to-end flow: save memory → process → verify database updates
- Test that `processed_text` is populated and improved (readability, sentence structure)
- Test that `input_text` remains unchanged (preserved as raw transcription)
- Test story processing with audio upload delay
- Test retry mechanism for failed story processing
- Test concurrent processing of multiple memories

### Flutter Tests
- Test service layer calls to new functions
- Test error handling in save service
- Test story processing status updates

## Success Criteria

1. ✅ Three separate edge functions exist (`process-moment`, `process-memento`, `process-story`)
2. ✅ Each function handles its memory type's specific processing needs
3. ✅ Story processing includes narrative generation and status management
4. ✅ Flutter services call appropriate function per memory type
5. ✅ All existing functionality continues to work
6. ✅ Story processing completes successfully with narrative generation
7. ✅ Error handling and retry logic work correctly
8. ✅ `generate-title` function is deprecated/removed

## Risk Assessment

**Risk Level**: Medium

**Risks**:
1. **Breaking Changes**: Existing clients calling `generate-title` will break
   - **Mitigation**: Keep function during migration, add deprecation warnings
2. **Story Processing Complexity**: Story function is more complex, higher chance of bugs
   - **Mitigation**: Thorough testing, incremental rollout, monitoring
3. **Database Load**: Story processing may increase database queries
   - **Mitigation**: Optimize queries, add indexes, monitor performance
4. **Audio Upload Timing**: Story processing may start before audio upload completes
   - **Mitigation**: Implement polling/timeout logic, handle gracefully

**Dependencies**:
- None (can be done independently)
- May benefit from Phase 7 (Story Fields Extension) being complete first

## Files Created/Modified

### New Files Created ✅
- ✅ `supabase/functions/process-moment/index.ts` - Moment processing edge function
- ✅ `supabase/functions/process-memento/index.ts` - Memento processing edge function
- ✅ `supabase/functions/process-story/index.ts` - Story processing edge function
- ✅ `lib/services/memory_processing_service.dart` - New unified processing service
- ✅ `lib/services/memory_processing_service.g.dart` - Generated Riverpod code

### Modified Files ✅
- ✅ `lib/services/memory_save_service.dart` - Updated to use `MemoryProcessingService`
- ✅ `supabase/migrations/20250116000000_extend_moments_table_for_text_media_capture.sql` - Updated comments
- ✅ `supabase/migrations/_deprecated/20251117173014_rename_moments_to_memories.sql` - Updated comments

### Files Removed ✅
- ✅ `supabase/functions/generate-title/index.ts` - Old edge function removed
- ✅ `lib/services/title_generation_service.dart` - Old service removed
- ✅ `lib/services/title_generation_service.g.dart` - Generated file removed
- ✅ `test/services/title_generation_service_test.dart` - Test file removed

## Related Documentation

- [Voice Story Recording & Processing Spec](../../agent-os/specs/2025-11-16-voice-story-recording-processing/spec.md)
- [Phase 7: Story Fields Extension](./phase-7-story-fields-extension-plan.md)
- [Phase 6: Text Model Normalization](./phase-6-text-model-normalization.md)

## Notes

- **Text Processing Purpose**: The `processed_text` field is designed for AI-processed, cleaned-up text that is optimized for human readability. It should:
  - Break up run-on sentences from dictation
  - Ensure proper sentence structure
  - Remove filler words that don't convey meaningful information (e.g., "um", "uh", "like", "you know")
  - Preserve all information from `input_text`
  - Be readable but doesn't need to be perfectly grammatically correct
  - Minimize information loss

- **Audio Transcription Validation (Stories)**: For stories, "transcription validation" refers to:
  - Verifying that `input_text` exists and is not empty before processing
  - Ensuring the transcript contains meaningful content (not just whitespace or single characters)
  - This validation happens before narrative generation to avoid processing invalid or empty transcripts

- **Processing Flow**:
  - Moments/Mementos: `input_text` (raw dictation) → `processed_text` (cleaned) → `title` (generated)
  - Stories: `input_text` (raw dictation) → `processed_text` (narrative) → `title` (generated)

- Story processing should be asynchronous and non-blocking
- Audio upload happens independently and does not block text processing - the function only processes the `input_text` that's already been transcribed
- May want to add rate limiting per memory type
- Consider adding processing queue for high-volume scenarios
- Story processing may need to handle partial failures (title succeeds, narrative fails)
- Text processing should preserve the user's voice and tone, not rewrite it completely

