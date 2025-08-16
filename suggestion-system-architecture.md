# CardMaestro Suggestion System Architecture

## Overview
The suggestion system maintains a pipeline that automatically generates and manages card suggestions for each deck while ensuring optimal user experience during review sessions.

## Core Components

### 1. Suggestion Count Management
- **Target**: Maintain 50 total suggestions per deck (visible + invisible combined)
- **Monitoring**: Sweeper continuously monitors suggestion counts across all decks
- **Triggering**: When total suggestions < 50, LLM API requests are triggered for the remaining count

### 2. Two-Stage Suggestion Pipeline

#### Stage 1: Invisible Suggestions (Awaiting Images)
- **Purpose**: Store LLM-generated suggestions that need image generation
- **Storage**: `invisibleSuggestions: [NSManagedObjectID: [InvisibleSuggestion]]`
- **Filtering**: Suggestions without image prompts are immediately discarded
- **State**: Not visible to users, awaiting image generation completion

#### Stage 2: Visible Suggestions (Ready for Review)
- **Purpose**: Store fully-processed suggestions ready for user interaction
- **Storage**: `deckSuggestions: [NSManagedObjectID: [Card]]` (published for UI binding)
- **Requirements**: Must have both content and generated images
- **State**: Available in suggestion review interface

### 3. Image Generation Process
The sweeper's image generation phase processes **all card types** systematically:

- **Current deck cards** (active, incomplete, archived)
- **Invisible suggestion cards** (awaiting promotion)
- **Visible suggestion cards** (already promoted)

**Processing criteria:**
- Card must have an `imagePrompt` property (non-empty)
- Card must not already have an existing image (`customImageData` is nil)
- Image generation uses Apple Intelligence → OpenAI fallback strategy

### 4. Promotion System
**Trigger**: When image generation completes for an invisible suggestion
**Process**: 
1. Create Card entity from InvisibleSuggestion data
2. Apply generated image to card
3. Move from `invisibleSuggestions` to `deckSuggestions`
4. Remove from invisible list

**Critical safeguard**: 
```swift
guard !isUserReviewingSuggestions else {
    print("🚫 User is reviewing suggestions, blocking promotion")
    return
}
```

### 5. State Blocking During User Review
- **Purpose**: Prevent suggestion list changes while user is actively reviewing
- **Mechanism**: `isUserReviewingSuggestions` flag blocks both generation and promotion
- **Activation**: Set to `true` when SuggestedCardsView appears
- **Deactivation**: Set to `false` when SuggestedCardsView disappears

## Process Flow

```
1. Sweeper Check → Count < 50?
   ↓ YES
2. LLM API Request → Generate new suggestions
   ↓
3. Filter → Keep only suggestions with image prompts
   ↓
4. Store in Invisible List → await image generation
   ↓
5. Image Generation Sweeper → Process all cards needing images
   ↓
6. Image Complete → Promote to visible (if user not reviewing)
   ↓
7. Suggestion Available → User can review in UI
```

## Key Benefits

1. **Seamless UX**: Users never see suggestions without images
2. **Performance**: Background processing doesn't block UI
3. **Consistency**: State blocking prevents mid-review changes
4. **Efficiency**: Batch processing and deduplication prevent redundancy
5. **Reliability**: Automatic cleanup and failure handling

## Implementation Notes

- All suggestion operations are @MainActor for thread safety
- Image generation uses background contexts to avoid blocking
- Deduplication prevents duplicate suggestions across all card states
- API rate limiting with delays between batch requests