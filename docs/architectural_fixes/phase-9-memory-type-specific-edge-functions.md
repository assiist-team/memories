# Phase 9: Memory Type-Specific Edge Functions

## Objective

Refactor the shared `generate-title` edge function into three separate, memory-type-specific edge functions:
- `process-moment` - Handles moment-specific AI processing
- `process-memento` - Handles memento-specific AI processing  
- `process-story` - Handles story-specific AI processing (narrative generation, title generation, etc.)

## Problem Statement

Currently, we have a single `generate-title` edge function that handles title generation for all three memory types (moments, stories, mementos). This creates several issues:

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
   
   Currently, moments and mementos don't have their `input_text` processed into `processed_text`, leaving users with poorly formatted text.

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
  - Fetch story data (input_text, story_status) from `memories` table
  - Validate that `input_text` exists and is not empty
  - Generate narrative text from input_text using LLM
  - Generate title from narrative/input_text
  - Update `memories` table:
    - `processed_text` = generated narrative
    - `title` = generated title
    - `story_status` = 'complete'
    - `processing_completed_at` = now()
    - `narrative_generated_at` = now()
    - `title_generated_at` = now()
  - Handle failures:
    - Set `story_status` = 'failed'
    - Set `processing_error` = error message
    - Increment `retry_count`
    - Set `last_retry_at` = now()
  - Log comprehensive processing metrics
  - Support retry mechanism (can be called multiple times for failed stories)

## Implementation Steps

### Step 1: Create `process-moment` Edge Function
**File**: `supabase/functions/process-moment/index.ts`

**Changes**:
1. Copy current `generate-title` logic as base
2. Accept `memoryId` parameter (fetch data from DB)
3. Fetch `input_text` from `memories` table using `memoryId`
4. Process `input_text` → `processed_text` using text processing prompt
5. Generate title from `processed_text` with moment-specific prompt
6. Update `memories` table with both `processed_text` and `title`
7. Return response with title, processedText, and status

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

### Step 2: Create `process-memento` Edge Function
**File**: `supabase/functions/process-memento/index.ts`

**Changes**:
1. Copy `process-moment` logic as base
2. Update text processing prompt to emphasize memento significance
3. Update title generation prompt to use memento-specific context
4. Update fallback title to "Untitled Memento"
5. Update logging to indicate memento processing

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

### Step 3: Create `process-story` Edge Function
**File**: `supabase/functions/process-story/index.ts`

**Changes**:
1. Create new function with story-specific logic
2. Accept `memoryId` parameter
3. Fetch story data from `memories` table:
   - `input_text` (or `raw_transcript` if available)
   - `story_status`
   - `capture_type` (verify it's 'story')
4. Validate that `input_text` exists and is not empty
5. Generate narrative text:
   - Use LLM to transform `input_text` into polished narrative paragraphs
   - Store in `processed_text`
6. Generate title:
   - Use narrative text (or input_text if narrative generation failed)
   - Store in `title` and `generated_title`
7. Update `memories` table with all generated content and status
8. Handle errors with retry logic
9. Log comprehensive metrics

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

### Step 4: Update Flutter Service Layer
**File**: `lib/services/title_generation_service.dart` (or create new service)

**Changes**:
1. Rename service to `MemoryProcessingService` (or create separate services)
2. Update methods to call appropriate edge function:
   - `processMoment({ required String memoryId })` → Returns `{ title, processedText, status }`
   - `processMemento({ required String memoryId })` → Returns `{ title, processedText, status }`
   - `processStory({ required String memoryId })` → Returns `{ title, processedText, status }`
3. Update response models to include `processedText` field:
   ```dart
   class MemoryProcessingResponse {
     final String title;
     final String processedText;
     final String status; // 'success' | 'fallback' | 'partial' | 'failed'
     final DateTime generatedAt;
   }
   ```
4. Handle partial success cases (text processed but title failed, etc.)

**Alternative Approach**: Create separate services:
- `MomentProcessingService`
- `MementoProcessingService`
- `StoryProcessingService`

### Step 5: Update Save Service
**File**: `lib/services/memory_save_service.dart`

**Changes**:
1. Update `saveMemory()` method:
   - After creating memory record, call appropriate processing function:
     - Moments: `processMoment(memoryId: memoryId)` → Updates `processed_text` and `title`
     - Mementos: `processMemento(memoryId: memoryId)` → Updates `processed_text` and `title`
     - Stories: `processStory(memoryId: memoryId)` → Updates `processed_text`, `title`, and `story_status` (async, non-blocking)
2. For stories, don't wait for processing to complete (fire and forget)
3. For moments/mementos, wait for processing to complete (or handle async)
4. Remove direct `generate-title` calls
5. Update progress callbacks to reflect new function names ("Processing text..." → "Generating title...")
6. Handle cases where text processing succeeds but title generation fails (partial success)

### Step 6: Update Story Processing Flow
**Files**: 
- `lib/services/memory_save_service.dart`
- `lib/services/memory_sync_service.dart` (if applicable)

**Changes**:
1. When story is saved, call `process-story` edge function
2. Don't block on processing completion
3. Story detail view should poll/refresh to show processing status
4. Handle processing failures gracefully

### Step 7: Add Database Triggers (Optional)
**File**: `supabase/migrations/[timestamp]_add_story_processing_trigger.sql`

**Changes**:
1. Create database trigger to automatically call `process-story` when:
   - New story is created with `story_status = 'processing'`
   - Story audio upload completes (via storage webhook or trigger)
2. This ensures processing happens automatically without client-side calls

**Note**: This is optional - client-side calls may be preferred for better error handling and retry control.

### Step 8: Deprecate `generate-title` Function
**File**: `supabase/functions/generate-title/index.ts`

**Changes**:
1. Add deprecation notice in function comments
2. Keep function for backward compatibility during migration
3. Add logging to track usage
4. Remove after migration is complete and all clients updated

## Migration Strategy

### Phase 1: Parallel Implementation
1. Create new functions (`process-moment`, `process-memento`, `process-story`)
2. Keep `generate-title` functional
3. Update Flutter code to use new functions
4. Deploy and test

### Phase 2: Verification
1. Monitor logs to ensure new functions are being called
2. Verify all memory types process correctly
3. Check that story processing completes successfully
4. Validate error handling and retry logic

### Phase 3: Cleanup
1. Remove `generate-title` function after migration period
2. Update documentation
3. Remove any remaining references

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

## Files to Modify

### New Files
- `supabase/functions/process-moment/index.ts`
- `supabase/functions/process-memento/index.ts`
- `supabase/functions/process-story/index.ts`
- `supabase/migrations/[timestamp]_add_story_processing_trigger.sql` (optional)

### Modified Files
- `lib/services/title_generation_service.dart` (or create new services)
- `lib/services/memory_save_service.dart`
- `lib/services/memory_sync_service.dart` (if story sync exists)
- `lib/models/memory_type.dart` (if needed for API values)

### Deprecated Files (to be removed)
- `supabase/functions/generate-title/index.ts` (after migration)

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

