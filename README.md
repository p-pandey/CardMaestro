# CardMaestro - iOS Flashcard App

A privacy-focused flashcard app for iOS that implements advanced spaced repetition algorithms to optimize learning retention. Built with SwiftUI and Core Data for a native iOS experience.

## Key Features

### 🎯 **Spaced Repetition System (SRS)**
- SM-2 algorithm implementation for optimal memory retention
- Confidence-based scheduling with Again/Hard/Good/Easy rating system
- Adaptive learning that adjusts to your personal patterns

### 📚 **Card & Deck Management**
- Create unlimited decks and flashcards
- Organize cards with tags and hierarchical deck structure
- Full-text search across all cards and decks
- Import/export capabilities for data portability

### 📈 **Study Tracking & Analytics**
- Daily study streak tracking
- Comprehensive learning analytics dashboard
- Session history and time tracking
- Progress visualization with charts and statistics

### 🏗️ **Privacy-First Architecture**
- Complete offline functionality
- Local-first data storage with Core Data
- Optional iCloud sync for personal devices only
- No external data collection or tracking

### 🍎 **Native iOS Experience**
- SwiftUI interface following Apple's Human Interface Guidelines
- Dark mode support with automatic switching
- Full accessibility support with VoiceOver
- Optimized for iPhone and iPad

## Architecture

### Core Components
- **Core Data Models**: Card, Deck, ReviewHistory, StudySession, Tag
- **Services**: SpacedRepetitionService, StreakService
- **Views**: StudyView, DeckListView, DeckDetailView, ProgressView
- **Algorithms**: SM-2 spaced repetition with modern enhancements

### Data Model
```
Deck (1:many) → Card (1:many) → ReviewHistory
StudySession (1:many) → ReviewHistory
Tag (many:many) → Deck
```

## Study Algorithm

The app implements the SM-2 algorithm with the following enhancements:
- Initial intervals: 1 day, 6 days, then calculated based on ease factor
- Ease factor adjustments based on review difficulty
- Confidence-based scheduling with four difficulty levels
- Intelligent daily limits for new cards and reviews

## Getting Started

### Requirements
- iOS 16.0+
- Xcode 15.0+
- Swift 5.9+

### Installation
1. Clone the repository
2. Open `CardMaestro.xcodeproj` in Xcode
3. Build and run on simulator or device

### Usage
1. Create your first deck by tapping the "+" button
2. Add cards to your deck using the "Add Card" option
3. Start studying with the "Study Now" button
4. Rate each card based on difficulty (Again/Hard/Good/Easy)
5. Track your progress in the Progress tab

## Features in Detail

### Study Interface
- Clean, distraction-free card display
- Smooth flip animations between front and back
- Progress indicator showing session completion
- Four-button rating system for spaced repetition

### Analytics Dashboard
- Current and longest study streaks
- Total study time and session statistics
- Cards reviewed and mastery progress
- Learning pattern analysis

### Deck Management
- Visual deck browser with progress indicators
- Card statistics (total, new, due)
- Bulk operations for editing
- Search and filtering capabilities

## Technical Implementation

### Spaced Repetition Algorithm
The app uses a modified SM-2 algorithm:

```swift
switch ease {
case .again:
    repetitions = 0
    interval = 1
    easeFactor = max(1.3, easeFactor - 0.2)
case .good:
    if repetitions == 0 { interval = 1 }
    else if repetitions == 1 { interval = 6 }
    else { interval = Int32(Double(interval) * Double(easeFactor)) }
    repetitions += 1
// ... other cases
}
```

### Data Persistence
- Core Data stack with background processing
- Automatic conflict resolution for multi-device sync
- Efficient queries with NSFetchRequest and predicates
- Data integrity with proper relationship management

## Privacy & Security

- **No external servers**: All data stored locally on device
- **No analytics**: Zero user behavior tracking or data collection
- **Optional sync**: iCloud integration only with user consent
- **Data ownership**: Complete control over your learning data
- **Export capabilities**: Never locked into the app

## Contributing

This is a personal learning project demonstrating iOS development best practices:
- SwiftUI declarative UI development
- Core Data relationship management
- MVVM architecture patterns
- iOS Human Interface Guidelines compliance

## License

Built as a demonstration of modern iOS development techniques following the specifications for a privacy-focused, locally-first flashcard application.