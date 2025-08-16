# Card Design Specifications

## Design Principles

### Visual Hierarchy (3 Levels Maximum)
- **Level 1 (Primary)**: Most important content, largest size, highest contrast
- **Level 2 (Secondary)**: Supporting content, medium size, medium contrast  
- **Level 3 (Tertiary)**: Supplementary content, smallest size, lowest contrast

### Typography Scaling Rules
- **Single Word**: Use largest available size that fits
- **Short Phrase (2-5 words)**: Scale down proportionally
- **Long Content (6+ words)**: Use minimum readable size with line spacing

### Symbol Usage (No Text Labels)
- **Vocabulary**: `📚` (book.fill) - Blue theme
- **Conjugation**: `📋` (table) - Purple theme  
- **Fact**: `ℹ️` (info.circle.fill) - Orange theme

### Image Sizes (Fixed per Card Type)
- **Vocabulary**: 200×150px (large, centered)
- **Conjugation**: 80×80px (small, top-right)  
- **Fact**: 200×150px (large, centered)

---

## Vocabulary Card Design

### Front Side
```
┌─────────────────────────────────────────┐
│ 📚                              ⟲       │ Level 3: Symbol & flip icon
│                                         │
│                                         │
│            [WORD/PHRASE]                │ Level 1: Dynamic size (28-48pt)
│                                         │ - 1 word: 48pt bold
│                                         │ - 2-3 words: 36pt bold  
│                                         │ - 4+ words: 28pt bold
│                                         │
│                                         │
└─────────────────────────────────────────┘
```

### Back Side
```
┌─────────────────────────────────────────┐
│ 📚                              [WORD]  │ Level 3: Symbol + original word
│ ────────────────────────────────────────│
│                                         │
│              [MEANING]                  │ Level 1: Primary definition
│                                         │ - Dynamic: 24-32pt semibold
│          ┌─────────────────┐             │
│          │                 │             │ Fixed: 200×150px
│          │     [IMAGE]     │             │ Centered, rounded corners
│          │                 │             │ Shadow: 0.3 opacity
│          └─────────────────┘             │
│                                         │
│            [DETAIL]                     │ Level 2: Optional context
│         (if available)                  │ - Dynamic: 16-20pt regular
│                                         │ - Secondary color
│                                         │
└─────────────────────────────────────────┘
```

---

## Conjugation Card Design

### Front Side  
```
┌─────────────────────────────────────────┐
│ 📋                              ⟲       │ Level 3: Symbol & flip icon
│                                         │
│                                         │
│            [VERB]                       │ Level 1: Dynamic size (28-40pt)
│                                         │ - Infinitive form
│                                         │ - Bold weight
│                                         │
│                                         │
└─────────────────────────────────────────┘
```

### Back Side
```
┌─────────────────────────────────────────┐
│ 📋    ┌──────────┐              [VERB]  │ Level 3: Symbol + original
│       │  [IMAGE] │              ────────│ Image: 80×80px, top-right
│       │   80×80  │                     │ Shadow: 0.2 opacity
│       └──────────┘                     │
│                                         │
│        [ENGLISH MEANING]                │ Level 2: Translation
│                                         │ - 18-22pt semibold
│                                         │
│    ┌─────────────────────────────────┐   │
│    │  pronoun     conjugated form   │   │ Level 1: Conjugation table
│    │  ────────    ──────────────    │   │ - 16pt regular/medium
│    │  yo          hablo             │   │ - Monospace alignment
│    │  tú          hablas            │   │ - Background: secondary
│    │  él/ella     habla             │   │ - Rounded corners
│    │  nosotros    hablamos          │   │
│    │  vosotros    habláis           │   │
│    │  ellos       hablan            │   │
│    └─────────────────────────────────┘   │
│                                         │
└─────────────────────────────────────────┘
```

---

## Fact Card Design

### Front Side
```
┌─────────────────────────────────────────┐
│ ℹ️                               ⟲       │ Level 3: Symbol & flip icon
│                                         │
│                                         │
│          [QUESTION]                     │ Level 1: Dynamic size (20-32pt)
│                                         │ - Questions are typically longer
│                                         │ - Semibold weight
│                                         │ - Multi-line support
│                                         │
│                                         │
└─────────────────────────────────────────┘
```

### Back Side
```
┌─────────────────────────────────────────┐
│ ℹ️                           [QUESTION] │ Level 3: Symbol + question
│ ────────────────────────────────────────│
│                                         │
│              [ANSWER]                   │ Level 1: Primary answer
│                                         │ - 22-28pt semibold
│          ┌─────────────────┐             │
│          │                 │             │ Fixed: 200×150px
│          │     [IMAGE]     │             │ Centered, rounded corners
│          │                 │             │ Shadow: 0.3 opacity
│          └─────────────────┘             │
│                                         │
│             [DETAIL]                    │ Level 2: Additional info
│          (if available)                 │ - 16-20pt regular
│                                         │ - Secondary color
│                                         │
└─────────────────────────────────────────┘
```

---

## Dynamic Typography Rules

### Content Length → Font Size Mapping

#### Primary Content (Level 1)
- **1 word**: 48pt → 32pt (vocabulary/conjugation → fact)
- **2-3 words**: 36pt → 28pt
- **4-6 words**: 28pt → 24pt  
- **7+ words**: 24pt → 20pt (minimum readable)

#### Secondary Content (Level 2)
- **1-3 words**: 22pt
- **4-8 words**: 20pt
- **9+ words**: 18pt

#### Tertiary Content (Level 3)
- **All lengths**: 14pt (symbols, hints, originals)

### Font Weights
- **Level 1**: Bold/Semibold
- **Level 2**: Medium/Semibold  
- **Level 3**: Regular

### Colors (iOS Dynamic)
- **Level 1**: Primary label color
- **Level 2**: Secondary label color
- **Level 3**: Tertiary label color

---

## Layout Specifications

### Spacing
- **Card padding**: 24pt horizontal, 20pt vertical
- **Element spacing**: 16pt between major elements
- **Table row spacing**: 8pt between conjugation rows
- **Image margins**: 12pt from content edges

### Alignment
- **Front cards**: Center-aligned primary content
- **Back cards**: Left-aligned text content
- **Images**: Center-aligned (vocab/fact), top-right (conjugation)
- **Tables**: Left-aligned with consistent column widths

### Card Dimensions
- **Height**: Fixed at CardConstants.Dimensions.cardContentHeight
- **Width**: Full available width
- **Corner radius**: 16pt (card background), 12pt (images), 8pt (tables)

---

## Implementation Notes

1. **Dynamic Font Sizing**: Use GeometryReader to measure available space
2. **Symbol Consistency**: Always use SF Symbols with consistent sizing
3. **Color Theming**: Leverage card.cardType.color for accents
4. **Image Handling**: Maintain aspect ratio with .aspectRatio(.fill)
5. **Accessibility**: Ensure minimum touch targets and readable contrast