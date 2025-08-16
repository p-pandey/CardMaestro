# Card Types Implementation Plan

## Overview
Add support for different card types (Vocabulary, Grammar, Facts, Conjugation, etc.) to CardMaestro with type-specific formatting, prompting, and reverse logic.

## 1. Core Data Model Updates
- Add `CardType` entity with properties:
  - `name: String` - Display name (e.g., "Vocabulary")
  - `identifier: String` - Code identifier (e.g., "vocabulary")
  - `backPromptTemplate: String` - Template for Claude prompts
  - `reverseLogic: String` - How to handle card reversal
  - `icon: String` - SF Symbol name for UI
  - `color: String` - Associated color name

- Add `cardType` relationship to `Card` entity
- Create Core Data migration to add card type to existing cards (default to "Vocabulary")

## 2. Card Type Definitions

### Initial Card Types:
1. **Vocabulary** 
   - Front: Word/phrase in target language
   - Back: Translation + context + examples
   - Reverse: Show meaning → recall word

2. **Grammar**
   - Front: Grammar concept/rule
   - Back: Explanation + examples + usage notes
   - Reverse: Show example → identify rule

3. **Facts**
   - Front: Question
   - Back: Factual answer with explanation
   - Reverse: Show answer → recall question

4. **Conjugation** ⭐ *Perfect for Spanish word forms!*
   - Front: Verb infinitive (e.g., "hablar")
   - Back: Complete conjugation table with tenses
   - Reverse: Show random conjugated form → recall infinitive
   - Special formatting for verb tables

5. **Phrases**
   - Front: Common phrase/idiom
   - Back: Translation + cultural context + usage
   - Reverse: Show context → recall phrase

## 3. Backend Integration

### Claude Service Updates:
```swift
// Add to ClaudeService.swift
func generateCardBack(for front: String, cardType: CardType, deck: Deck) -> String
```

### Type-Specific Prompt Templates:
- **Vocabulary**: Focus on translations, synonyms, usage context
- **Grammar**: Emphasize rules, patterns, exceptions
- **Facts**: Provide comprehensive factual explanations
- **Conjugation**: Generate complete verb conjugation tables
- **Phrases**: Include cultural context and usage scenarios

### Card Generation:
- Update `CardCreationView` to include card type selection
- Modify suggestion system to generate type-appropriate content
- Update prompts based on selected card type

## 4. UI/UX Changes

### Card Creation/Edit:
- Add card type picker in `CardCreationView`
- Type-specific form fields and hints
- Preview of how card will be formatted

### Card Display:
- Update `StructuredCardContentView` for type-specific formatting
- Visual indicators (icons, colors) for different card types
- Specialized layouts (e.g., conjugation tables)

### Study Mode:
- Type-aware reverse logic in `StudyView`
- Different reversal patterns per card type
- Type-specific progress tracking

## 5. Spanish Conjugation Type - Detailed Design

### Perfect for memorizing Spanish verb forms!

**Front Side:**
```
hablar
(to speak)
```

**Back Side:**
```
🔄 Present Tense
yo hablo          nosotros hablamos
tú hablas         vosotros habláis  
él/ella habla     ellos/ellas hablan

📝 Usage Notes
• Regular -ar verb
• Common in everyday conversation
• Example: "Yo hablo español"
```

**Reverse Mode Logic:**
- Show random conjugated form: "nosotros hablamos"
- User must recall: "hablar" (infinitive)
- Or show: "I speak" → User recalls: "yo hablo"

**Claude Prompt Template:**
```
Create a comprehensive conjugation guide for the Spanish verb "{front}". Include:
1. Present tense conjugation table
2. Key usage notes
3. Common example sentences
4. Any irregular patterns or exceptions
Format as structured content with clear sections.
```

## 6. Implementation Phases

### Phase 1: Foundation
1. Create Core Data model updates and migration
2. Define CardType enum and basic logic
3. Add type selection to CardCreationView

### Phase 2: Backend
1. Implement type-specific Claude prompt templates
2. Update card generation logic
3. Add type-aware suggestion system

### Phase 3: UI Polish
1. Create specialized card formatters per type
2. Implement type-specific reverse logic
3. Add visual indicators and icons

### Phase 4: Advanced Features
1. Type-specific study statistics
2. Import/export with card types
3. Advanced conjugation features (multiple tenses)

## 7. Database Migration Strategy
```swift
// Add migration to set default card type for existing cards
NSMigrationManager.map { card in
    card.cardType = CardType.vocabulary // Default
}
```

## 8. Future Extensions
- **Audio Pronunciation** type for listening practice
- **Image Recognition** type with visual cues
- **Conversation** type with dialogue practice
- **Cultural Context** type for cultural learning

## Success Metrics
- Improved learning outcomes for different content types
- Higher user engagement with specialized card formats
- Better retention rates for Spanish conjugation practice
- Positive user feedback on type-specific features

---

This plan provides a solid foundation for making CardMaestro more versatile and effective for different types of language learning content, with special emphasis on Spanish verb conjugation practice.