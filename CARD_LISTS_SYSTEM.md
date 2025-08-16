# Card Lists System Documentation

This document describes the comprehensive card list system in CardMaestro, including all card states, storage mechanisms, and the ways cards can move between different lists.

## Overview

CardMaestro manages cards across several distinct lists, each serving a specific purpose in the learning workflow. All lists are now stored persistently in Core Data, ensuring data survives app restarts.

## Card Lists

### 1. Current Cards (`deck.activeCards`)
**Storage**: Core Data (`deck.cards` relationship where `isArchived = false`)
**Purpose**: Cards currently available for study in a deck
**Access**: `deck.activeCards` computed property

**Properties**:
- Not archived (`isArchived = false`)
- Belong to a specific deck
- Can be new (never reviewed) or due for review
- Have complete content (front, back, and optionally images)

### 2. Archived Cards (`deck.archivedCards`)
**Storage**: Core Data (`deck.cards` relationship where `isArchived = true`)
**Purpose**: Cards removed from active study but kept for reference
**Access**: `deck.archivedCards` computed property

**Properties**:
- Archived (`isArchived = true`)
- Have archived date (`archivedAt`)
- Cannot be studied but can be restored
- Sorted by archive date (most recent first)

### 3. Visible Suggestions (`deck.visibleSuggestions`)
**Storage**: Core Data (`deck.suggestions` relationship where `isVisible = true`)
**Purpose**: AI-generated card suggestions ready for user review (have images)
**Access**: `deck.visibleSuggestions` computed property

**Properties**:
- Have generated images (`customImageData != nil`)
- Ready for user review and acceptance/rejection
- Not yet added to the main deck
- Can be converted to current cards when accepted

### 4. Invisible Suggestions (`deck.invisibleSuggestions`)
**Storage**: Core Data (`deck.suggestions` relationship where `isVisible = false`)
**Purpose**: AI-generated suggestions awaiting image generation
**Access**: `deck.invisibleSuggestions` computed property

**Properties**:
- Complete card content (front, back, type)
- Awaiting background image generation
- Automatically move to visible suggestions when images are ready
- Not shown to user until images are generated

### 5. Deleted/Rejected Suggestions (`deck.deletedSuggestionArray`)
**Storage**: Core Data (`deck.deletedSuggestions` relationship)
**Purpose**: Track rejected suggestions to prevent re-suggestion
**Access**: `deck.deletedSuggestionArray` computed property

**Properties**:
- Only store front text and card type for matching
- Include deletion/rejection date
- Prevent AI from suggesting the same content again
- Automatically cleaned up periodically

## Core Data Entities

### Card
```swift
// Main card entity for current and archived cards
@NSManaged public var id: UUID
@NSManaged public var front: String
@NSManaged public var back: String
@NSManaged public var cardTypeRaw: String?
@NSManaged public var jsonContent: String?
@NSManaged public var imagePrompt: String?
@NSManaged public var customImageData: Data?
@NSManaged public var isArchived: Bool           // NEW: Replaces UserDefaults
@NSManaged public var archivedAt: Date?          // NEW: Replaces UserDefaults
@NSManaged public var isIncomplete: Bool
@NSManaged public var deck: Deck
// ... spaced repetition fields
```

### SuggestionCard
```swift
// NEW: Entity for suggestion cards (visible and invisible)
@NSManaged public var id: UUID
@NSManaged public var front: String
@NSManaged public var back: String             // Complete JSON content
@NSManaged public var cardTypeRaw: String
@NSManaged public var imagePrompt: String?
@NSManaged public var context: String         // Why suggested
@NSManaged public var category: String        // Suggestion category
@NSManaged public var isVisible: Bool         // Has image, ready for review
@NSManaged public var customImageData: Data?
@NSManaged public var deck: Deck
```

### DeletedSuggestion
```swift
// NEW: Entity to track rejected suggestions
@NSManaged public var id: UUID
@NSManaged public var front: String
@NSManaged public var cardType: String
@NSManaged public var deletedAt: Date
@NSManaged public var deck: Deck
```

### Deck
```swift
// Updated with new relationships and persistent suggestions count
@NSManaged public var queuedSuggestions: Int32  // NEW: Was in UserDefaults
@NSManaged public var cards: NSSet?             // Current & archived cards
@NSManaged public var suggestions: NSSet?       // NEW: Suggestion cards
@NSManaged public var deletedSuggestions: NSSet? // NEW: Deleted suggestions
```

## Card Movement Flows

### 1. Adding Cards to Current Deck

#### User Creates Card Manually
```
User Input → CardCreationView → New Card Entity → deck.cards (isArchived=false)
```

#### User Accepts Suggestion
```
Visible Suggestion → SuggestionCard.convertToCard() → New Card Entity → deck.cards (isArchived=false)
Original SuggestionCard → Deleted from deck.suggestions
```

#### User Imports Cards
```
Import Source → Batch Card Creation → Multiple Card Entities → deck.cards (isArchived=false)
```

### 2. Removing Cards from Current Deck

#### User Archives Card
```
Current Card → card.setArchived(true) → Still in deck.cards (isArchived=true)
```

#### User Deletes Card Permanently
```
Current Card → viewContext.delete(card) → Removed from deck.cards entirely
```

### 3. Suggestion Card Lifecycle

#### AI Generation
```
AI Service → Create SuggestionCard (isVisible=false) → deck.suggestions
```

#### Image Generation Complete
```
Background Service → suggestionCard.isVisible = true → Moves to visible suggestions
```

#### User Accepts Suggestion
```
Visible Suggestion → Convert to Card → Add to deck.cards → Remove from deck.suggestions
```

#### User Rejects Suggestion
```
Visible Suggestion → Create DeletedSuggestion → Add to deck.deletedSuggestions → Remove from deck.suggestions
```

#### User Skips Suggestion
```
Visible Suggestion → Create DeletedSuggestion → Add to deck.deletedSuggestions → Keep in deck.suggestions (hidden)
```

### 4. Archived Card Management

#### User Restores Archived Card
```
Archived Card → card.setArchived(false) → Moves to current cards
```

#### User Deletes Archived Card
```
Archived Card → viewContext.delete(card) → Removed from deck.cards entirely
```

### 5. Bulk Operations

#### Archive All Due Cards
```
deck.dueCards.forEach { card.setArchived(true) }
```

#### Clear All Suggestions
```
deck.suggestions.forEach { viewContext.delete($0) }
```

#### Reset Deleted Suggestions
```
deck.deletedSuggestions.forEach { viewContext.delete($0) }
```

## Configuration

### Automatic Suggestions
- `deck.queuedSuggestions >= 1`: AI generates suggestions automatically
- `deck.queuedSuggestions = 0`: Disables automatic suggestion generation
- Background service respects this setting when maintaining suggestion queues

### Suggestion Categories
- `related_vocabulary`: Words related to existing cards
- `usage_examples`: Example sentences and usage contexts  
- `opposites`: Antonyms and contrasting concepts
- `progressive_complexity`: More advanced related concepts

## Background Processing

### Image Generation Pipeline
1. AI creates SuggestionCard with `isVisible = false`
2. Background service queues image generation
3. When image is ready, sets `isVisible = true`
4. Card becomes available in visible suggestions

### Suggestion Maintenance
1. Service counts current suggestions (visible + invisible)
2. If count < `deck.queuedSuggestions`, generates more
3. Respects deleted suggestions to avoid duplicates
4. Balances across different suggestion categories

## Data Persistence

### Removed UserDefaults Usage
- ✅ `queuedSuggestions`: Now in Core Data
- ✅ `isArchived`/`archivedAt`: Now in Core Data  
- ✅ `cardType`: Already in Core Data
- ✅ Suggestion tracking: Now in Core Data

### Migration Notes
- All backward-compatibility code removed
- New installations start with proper Core Data storage
- No migration needed as UserDefaults usage was temporary

## Error Handling

### Core Data Errors
- Failed saves rollback transactions
- Relationship integrity maintained automatically
- Cascade deletes handle cleanup

### Image Generation Failures
- Failed suggestions remain invisible
- Retry mechanism with backoff
- Eventually removed after max failures

This system ensures all card data persists across app restarts while maintaining clean separation between different card states and efficient background processing.