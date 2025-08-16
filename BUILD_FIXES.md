# CardMaestro Build Issues & Fixes

## Common Build Issues and Solutions

### 0. **All Build Errors (FIXED)** ✅
The following errors have been completely resolved:

**✅ macOS Platform Errors:**
- `'navigationBarTitleDisplayMode' is unavailable in macOS`
- **Fix:** Added `#if os(iOS)` conditionals and platform-specific toolbar placements
- **Fix:** Set `SUPPORTS_MACCATALYST = NO` to disable Mac Catalyst

**✅ Color Reference Errors:**
- `Reference to member 'systemGray6' cannot be resolved`
- `Reference to member 'systemBackground' cannot be resolved` 
- `Cannot find 'UIColor' in scope`
- `Instance member 'secondary' cannot be used on type 'Color.Resolved'`
- **Fix:** Used standard SwiftUI colors: `Color.gray.opacity(0.15)` and `Color.white`
- **Fix:** Added `colorFromString()` helper functions for dynamic colors

**✅ Identifiable Conformance Errors:**
- `'Card' conform to 'Identifiable'`
- `'Deck' conform to 'Identifiable'`
- **Fix:** Added `Identifiable` conformance to all Core Data models

**✅ Info.plist Duplicate Errors:**
- `Multiple commands produce Info.plist`
- **Fix:** Removed manual Info.plist file (project uses `GENERATE_INFOPLIST_FILE = YES`)

**Additional Checks if issues persist:**
1. **Clean Derived Data:** Xcode → Preferences → Locations → Derived Data → Delete
2. **Project Settings:** Ensure only iOS is selected under "Supported Destinations" 
3. **Clean Build:** Product → Clean Build Folder (⇧⌘K)
4. **Restart Xcode:** Sometimes needed for project file changes

## Common Build Issues and Solutions

### 1. **Missing Core Data Model Issues**
If you get errors about Core Data entities not being found:

**Solution:**
1. Open `CardMaestroDataModel.xcdatamodeld` in Xcode
2. Select the Data Model Inspector (right panel)
3. For each Entity (Card, Deck, ReviewHistory, StudySession, Tag):
   - Set **Codegen** to "Manual/None"
   - Set **Class** to the entity name (e.g., "Card")
   - Check "Use Core Data" checkbox

### 2. **Duplicate Symbol Errors**
If you get duplicate symbol errors for Core Data classes:

**Solution:**
1. In Xcode, select the Core Data model file
2. For each entity, make sure **Codegen** is set to "Manual/None"
3. Delete any duplicate Core Data class files if they exist

### 3. **Missing Files in Project**
If Xcode shows missing files (red names):

**Solution:**
1. Right-click on the project in Xcode
2. Choose "Add Files to CardMaestro"
3. Navigate to the missing files and add them
4. Make sure "Add to target: CardMaestro" is checked

### 4. **Preview Crashes**
If SwiftUI previews don't work:

**Solution:**
1. Make sure all `#Preview` blocks have proper Core Data context
2. Check that `PersistenceController.preview` is working
3. Try cleaning build folder: Product → Clean Build Folder

### 5. **ProgressView Naming Conflict**
Already fixed - renamed to `AnalyticsView` to avoid SwiftUI conflicts.

## Manual File Verification

### Required Files Checklist:
- ✅ `CardMaestroApp.swift`
- ✅ `ContentView.swift`
- ✅ `PersistenceController.swift`
- ✅ `CardMaestroDataModel.xcdatamodeld/`

**Models folder:**
- ✅ `Card+CoreDataClass.swift`
- ✅ `Card+CoreDataProperties.swift`
- ✅ `Deck+CoreDataClass.swift`
- ✅ `Deck+CoreDataProperties.swift`
- ✅ `ReviewHistory+CoreDataClass.swift`
- ✅ `ReviewHistory+CoreDataProperties.swift`
- ✅ `StudySession+CoreDataClass.swift`
- ✅ `StudySession+CoreDataProperties.swift`
- ✅ `Tag+CoreDataClass.swift`
- ✅ `Tag+CoreDataProperties.swift`

**Services folder:**
- ✅ `SpacedRepetitionService.swift`
- ✅ `StreakService.swift`

**Views folder:**
- ✅ `CardCreationView.swift`
- ✅ `DeckCreationView.swift`
- ✅ `DeckDetailView.swift`
- ✅ `DeckListView.swift`
- ✅ `AnalyticsView.swift`
- ✅ `StudyView.swift`

## Build Steps:
1. Open `CardMaestro.xcodeproj` in Xcode
2. Select iOS Simulator (iPhone 15 or similar)
3. Product → Clean Build Folder
4. Product → Build

## If Build Still Fails:

### Step 1: Check Project Settings
1. Select project root in Xcode
2. Go to Build Settings
3. Ensure deployment target is iOS 16.0+
4. Swift version should be 5.x

### Step 2: Re-create Core Data Model
If Core Data issues persist:
1. Delete the `.xcdatamodeld` file
2. Create new Data Model: File → New → Data Model
3. Add entities manually with the attributes from the `contents` file

### Step 3: Manual File Addition
If files aren't recognized:
1. Delete all files from Xcode project (keep on disk)
2. Re-add them using "Add Files to Project"
3. Ensure proper folder structure

### Step 4: Clean Start
If all else fails:
1. Create new Xcode project
2. Copy source files manually
3. Set up Core Data from scratch

## Known Working Configuration:
- iOS 16.0+ deployment target
- SwiftUI + Core Data
- Manual Core Data codegen
- All files properly added to project target

## Contact
If issues persist, the core architecture is sound. The problem is likely in Xcode project configuration rather than the code itself.