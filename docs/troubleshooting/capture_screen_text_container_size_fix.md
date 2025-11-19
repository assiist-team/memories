# Fix: Text Container Size Consistency Between Dictation and Type Modes

## Problem
The text capture containers in dictation mode and type mode are not the same size in the capture memory screen. They need to:
1. Start at the same size
2. Grow in exactly the same way

## Current State
- Both containers use `Expanded` widgets within `_SwipeableInputContainer`
- Dictation mode uses `_DictationTextContainer` widget
- Type mode uses a `Container` with `TextField` directly
- Both are wrapped in `Expanded` but still render at different sizes

## Files to Modify
- `lib/screens/capture/capture_screen.dart`
  - `_SwipeableInputContainer.build()` method (around line 950)
  - `_DictationTextContainer` widget (around line 715)
  - Type mode container (around line 1112)

## What to Check
1. Ensure both containers receive identical constraints from their parent `Expanded` widgets
2. Verify padding, margins, and decoration are identical (currently both use `padding: EdgeInsets.all(16)`)
3. Check if simulator banner in dictation mode affects layout differently
4. Ensure both containers use the same flex behavior and constraints

## Goal
Both text containers must be pixel-perfect identical in size and grow/shrink together when the parent container size changes.

