import Foundation
import SwiftUI
import CoreData
import ImagePlayground
import UIKit

struct ImageGenerationTask: Identifiable {
    let id = UUID()
    let type: ImageType
    let objectId: NSManagedObjectID?  // Optional for suggestion tasks
    let suggestionId: UUID?           // For invisible suggestion tasks
    let prompt: String
    let priority: Priority
    let createdAt: Date
    
    enum ImageType {
        case deckIcon           // Always uses OpenAI
        case cardImage          // Uses user settings (Apple Intelligence or OpenAI)
        case suggestionImage    // For invisible suggestions - no Core Data object yet
    }
    
    enum Priority: Int, Comparable {
        case low = 0
        case normal = 1
        case high = 2
        case user_requested = 3
        
        static func < (lhs: Priority, rhs: Priority) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
}

// All suggestion structures moved to Core Data entities:
// - Card with suggestion/suggestionPending states (for suggestions)
// - DeletedSuggestion (for tracking deleted suggestions)
// No in-memory structures needed

@MainActor
class BackgroundImageGenerationService: ObservableObject {
    static let shared = BackgroundImageGenerationService()
    
    @Published var isGenerating = false
    @Published var queueCount = 0
    @Published var generatedCount = 0
    @Published var failedCount = 0
    
    private let openAIAPIKey: String?
    private let baseURL = "https://api.openai.com/v1"
    private var taskQueue: [ImageGenerationTask] = []
    private let maxConcurrentTasks = 2
    private var activeTasks = 0
    private let retryDelays: [TimeInterval] = [60, 300, 900] // 1min, 5min, 15min
    
    // Singleton sweeper control
    private var sweeperTask: Task<Void, Never>?
    private var shouldWakeUpSweeper = false
    
    // All suggestion management is now handled via Core Data (Card entities with states)
    // No in-memory storage needed
    
    // State blocking
    @Published var isUserReviewingSuggestions = false
    
    // App state tracking
    @Published private var isAppInForeground = true
    
    private let persistentContainer: NSPersistentContainer
    
    // Apple Intelligence settings
    private var useAppleIntelligence: Bool {
        UserDefaults.standard.bool(forKey: "useAppleIntelligence")
    }
    
    @available(iOS 18.4, *)
    private var selectedImageStyle: ImageStyle {
        ImageStyle(rawValue: UserDefaults.standard.string(forKey: "selectedImageStyle") ?? ImageStyle.illustration.rawValue) ?? .illustration
    }
    
    private init() {
        // Get OpenAI API key
        self.openAIAPIKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? KeychainManager.shared.getOpenAIKey()
        
        // Get persistent container directly from PersistenceController
        self.persistentContainer = PersistenceController.shared.container
        
        // Set up app state monitoring
        setupAppStateMonitoring()
        
        // Start the singleton sweeper
        startSweeper()
    }
    
    // MARK: - Public Methods
    
    /// Queue a deck icon for generation
    func generateDeckIcon(for deck: Deck, priority: ImageGenerationTask.Priority = .normal) {
        let prompt = buildDeckIconPrompt(name: deck.name, description: deck.deckDescription)
        let task = ImageGenerationTask(
            type: .deckIcon,
            objectId: deck.objectID,
            suggestionId: nil,
            prompt: prompt,
            priority: priority,
            createdAt: Date()
        )
        
        addTaskToQueue(task)
        
        // Wake up sweeper for immediate processing
        wakeUpSweeper()
    }
    
    /// Queue a card image for generation
    func generateCardImage(for card: Card, priority: ImageGenerationTask.Priority = .normal, customImagePrompt: String? = nil) {
        // Check if we should attempt image generation for this card
        guard card.shouldAttemptImageGeneration else {
            print("⏸️ Skipping image generation queue for card '\(card.front)' due to previous failures")
            return
        }
        
        let prompt = buildCardImagePrompt(front: card.front, back: getCardContentSummary(card), deck: card.deck, customImagePrompt: customImagePrompt)
        let task = ImageGenerationTask(
            type: .cardImage,
            objectId: card.objectID,
            suggestionId: nil,
            prompt: prompt,
            priority: priority,
            createdAt: Date()
        )
        
        addTaskToQueue(task)
        
        // Wake up sweeper for immediate processing
        wakeUpSweeper()
    }
    
    /// Remove existing image and wake sweeper for regeneration
    func regenerateImage(for deck: Deck) {
        // Clear existing custom icon
        deck.clearCustomIcon()
        try? persistentContainer.viewContext.save()
        
        // Wake up sweeper to detect and process missing icon
        wakeUpSweeper()
    }
    
    /// Remove existing image and wake sweeper for regeneration
    func regenerateImage(for card: Card) {
        // Clear existing custom image
        clearCardImage(card)
        try? persistentContainer.viewContext.save()
        
        // Wake up sweeper to detect and process missing image
        wakeUpSweeper()
    }
    
    /// Trigger sweeper to scan and process missing images
    func scanAndQueueMissingImages() {
        wakeUpSweeper()
    }
    
    // MARK: - Suggestion Management
    
    /// Get suggestions for a specific deck
    func getSuggestions(for deck: Deck) -> [Card] {
        // Debug: Check what we have in Core Data
        let allSuggestions = deck.allSuggestionCards
        let visibleSuggestions = deck.visibleSuggestions
        let invisibleSuggestions = deck.invisibleSuggestions
        
        print("🔍 Debug getSuggestions for deck '\(deck.name)':")
        print("   📊 Total suggestions: \(allSuggestions.count)")
        print("   👁️ Visible suggestions: \(visibleSuggestions.count)")
        print("   👻 Invisible suggestions: \(invisibleSuggestions.count)")
        
        if !allSuggestions.isEmpty {
            for suggestion in allSuggestions {
                print("   📋 Suggestion: '\(suggestion.front)' state=\(suggestion.state) hasImage=\(suggestion.customImageData != nil)")
            }
        }
        
        print("   ✅ Returning \(visibleSuggestions.count) Card objects for UI")
        return visibleSuggestions
    }
    
    /// Get current suggestion for a deck (first visible suggestion)
    func getCurrentSuggestion(for deck: Deck) -> Card? {
        let suggestions = getSuggestions(for: deck)
        return suggestions.first
    }
    
    /// Move to next suggestion for a deck (removes current suggestion and tracks as deleted)
    func nextSuggestion(for deck: Deck) {
        guard let currentSuggestion = deck.visibleSuggestions.first else { return }
        
        // Create deleted suggestion record
        let deletedSuggestion = DeletedSuggestion(context: persistentContainer.viewContext)
        deletedSuggestion.id = UUID()
        deletedSuggestion.front = currentSuggestion.front
        deletedSuggestion.cardType = currentSuggestion.cardType.rawValue
        deletedSuggestion.deletedAt = Date()
        deletedSuggestion.deck = deck
        
        // Remove the suggestion card
        persistentContainer.viewContext.delete(currentSuggestion)
        
        do {
            try persistentContainer.viewContext.save()
            print("🗑️ Marked suggestion as skipped: '\(currentSuggestion.front)' (\(currentSuggestion.cardType.rawValue))")
        } catch {
            print("❌ Failed to save suggestion deletion: \(error)")
        }
        
        // Wake up sweeper to maintain suggestion count
        wakeUpSweeper()
    }
    
    /// Track when a suggestion is added as a card
    func trackAddedSuggestion(_ front: String, type: String, for deck: Deck) {
        // Create deleted suggestion record to prevent re-suggestion
        let deletedSuggestion = DeletedSuggestion(context: persistentContainer.viewContext)
        deletedSuggestion.id = UUID()
        deletedSuggestion.front = front
        deletedSuggestion.cardType = type
        deletedSuggestion.deletedAt = Date()
        deletedSuggestion.deck = deck
        
        do {
            try persistentContainer.viewContext.save()
            print("🎯 Tracked added suggestion: '\(front)' (\(type))")
        } catch {
            print("❌ Failed to save added suggestion tracking: \(error)")
        }
        
        // Wake up sweeper to maintain suggestion count
        wakeUpSweeper()
    }
    
    
    // MARK: - Private Methods
    
    /// Set up app state monitoring to pause image generation when app is in background
    private func setupAppStateMonitoring() {
        // Monitor app state changes
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isAppInForeground = false
            print("📱 App entered background - pausing image generation")
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isAppInForeground = true
            print("📱 App entering foreground - resuming image generation")
            self?.wakeUpSweeper()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isAppInForeground = true
            print("📱 App became active - resuming image generation")
            self?.wakeUpSweeper()
        }
    }
    
    private func addTaskToQueue(_ task: ImageGenerationTask) {
        // Check if similar task already exists
        if taskQueue.contains(where: { $0.objectId == task.objectId && $0.type == task.type }) {
            return
        }
        
        taskQueue.append(task)
        taskQueue.sort { $0.priority > $1.priority } // Higher priority first
        
        queueCount = taskQueue.count
        
        print("📝 Queued \(task.type) generation (priority: \(task.priority)) - Queue: \(queueCount)")
    }
    
    /// Wake up the sweeper to process pending tasks immediately
    private func wakeUpSweeper() {
        shouldWakeUpSweeper = true
    }
    
    /// Start the singleton sweeper that processes all image generation
    private func startSweeper() {
        // Cancel any existing sweeper
        sweeperTask?.cancel()
        
        sweeperTask = Task {
            while !Task.isCancelled {
                // Process all pending tasks
                await processPendingTasks()
                
                // Process each deck synchronously (only when queue is empty)
                if taskQueue.isEmpty {
                    await processAllDecks()
                }
                
                // Sleep until woken up or timeout (30 seconds)
                await sleepUntilWakeUp()
            }
        }
    }
    
    /// Sleep until woken up by new tasks or timeout
    private func sleepUntilWakeUp() async {
        shouldWakeUpSweeper = false
        
        // Sleep for up to 30 seconds, but wake up early if needed
        for _ in 0..<30 {
            if shouldWakeUpSweeper {
                print("🔔 Sweeper woken up by new task")
                break
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
    }
    
    /// Process all pending tasks in the queue
    private func processPendingTasks() async {
        while !taskQueue.isEmpty && activeTasks < maxConcurrentTasks {
            await processNextTask()
        }
    }
    
    private func processNextTask() async {
        guard activeTasks < maxConcurrentTasks,
              !taskQueue.isEmpty else {
            return
        }
        
        let task = taskQueue.removeFirst()
        queueCount = taskQueue.count
        
        // Check if we have a valid generation method
        // For deck icons, we ALWAYS need OpenAI key since deck icons never use Apple Intelligence
        // For card images, we can use either Apple Intelligence or OpenAI based on user settings
        let needsOpenAIKey = task.type == .deckIcon || !useAppleIntelligence
        
        if needsOpenAIKey && !hasValidOpenAIKey {
            print("⚠️ Removing \(task.type) task from queue - requires OpenAI API key but none available")
            // Task is already removed from queue, so we just return without processing
            return
        }
        
        activeTasks += 1
        
        await MainActor.run {
            isGenerating = activeTasks > 0
        }
        
        do {
            let image: UIImage
            
            // Separate clear paths for deck icons vs card images
            switch task.type {
            case .deckIcon:
                // Deck icons ALWAYS use OpenAI via DeckIconGenerationService
                print("🎯 Generating deck icon using OpenAI DeckIconGenerationService...")
                if let objectId = task.objectId,
                   let deck = try? persistentContainer.viewContext.existingObject(with: objectId) as? Deck {
                    if let deckIcon = await DeckIconGenerationService.shared.generateIconForDeck(name: deck.name, description: deck.deckDescription) {
                        image = deckIcon
                    } else {
                        throw NSError(domain: "BackgroundImageGeneration", code: 10, userInfo: [NSLocalizedDescriptionKey: "DeckIconGenerationService failed to generate icon"])
                    }
                } else {
                    throw NSError(domain: "BackgroundImageGeneration", code: 11, userInfo: [NSLocalizedDescriptionKey: "Could not find deck for icon generation"])
                }
                
            case .cardImage, .suggestionImage:
                // Card images and suggestion images follow user settings
                if useAppleIntelligence {
                    print("🎯 Generating card image using Apple Intelligence...")
                    if #available(iOS 18.4, *) {
                        image = try await generateImageWithAppleIntelligence(prompt: task.prompt)
                    } else {
                        throw NSError(domain: "BackgroundImageGeneration", code: 9, userInfo: [NSLocalizedDescriptionKey: "Apple Intelligence requires iOS 18.4 or later"])
                    }
                } else {
                    print("🎯 Generating card image using OpenAI...")
                    image = try await generateImageWithOpenAI(prompt: task.prompt)
                }
            }
            
            await applyGeneratedImage(image, to: task)
            
            await MainActor.run {
                generatedCount += 1
            }
            
            print("✅ Successfully generated \(task.type)")
            
        } catch {
            print("❌ Failed to generate \(task.type): \(error)")
            await handleFailedTask(task)
            
            await MainActor.run {
                failedCount += 1
            }
        }
        
        activeTasks -= 1
        
        await MainActor.run {
            isGenerating = activeTasks > 0
        }
    }
    
    private func applyGeneratedImage(_ image: UIImage, to task: ImageGenerationTask) async {
        await persistentContainer.performBackgroundTask { context in
            // First check if the object still exists
            guard let objectId = task.objectId,
                  let object = try? context.existingObject(with: objectId) else {
                print("⚠️ Object with ID \(task.objectId?.description ?? "nil") no longer exists in store - skipping image save")
                print("🔍 This could indicate a race condition where image generation was queued before the object was saved")
                return
            }
            
            // Ensure the object is not deleted
            if object.isDeleted {
                print("⚠️ Object with ID \(objectId) has been deleted - skipping image save")
                return
            }
            
            switch task.type {
            case .deckIcon:
                if let deck = object as? Deck {
                    deck.setCustomIcon(image)
                    print("🖼️ Set custom icon for deck '\(deck.name)' - hasIconData: \(deck.customIconData != nil), dataSize: \(deck.customIconData?.count ?? 0)")
                }
            case .cardImage, .suggestionImage:
                if let card = object as? Card {
                    self.setCardImage(card, image: image)
                    print("🖼️ Set custom image for card '\(card.front)' - hasImageData: \(card.customImageData != nil), dataSize: \(card.customImageData?.count ?? 0)")
                }
            }
            
            do {
                try context.save()
                print("💾 Saved generated image to Core Data")
            } catch {
                print("❌ Failed to save generated image: \(error)")
            }
        }
        
        // Refresh the main context after the background task completes
        await MainActor.run {
            // Check if object still exists in main context before refreshing
            guard let objectId = task.objectId,
                  let mainObject = try? self.persistentContainer.viewContext.existingObject(with: objectId) else {
                print("⚠️ Object with ID \(task.objectId?.description ?? "nil") no longer exists in main context - skipping refresh")
                return
            }
            
            if mainObject.isDeleted {
                print("⚠️ Object with ID \(task.objectId?.description ?? "nil") has been deleted from main context - skipping refresh")
                return
            }
            
            if let deck = mainObject as? Deck {
                print("🔄 Before refresh - Deck '\(deck.name)' hasIconData: \(deck.customIconData != nil), dataSize: \(deck.customIconData?.count ?? 0)")
            }
            
            self.persistentContainer.viewContext.refresh(mainObject, mergeChanges: true)
            
            if let deck = mainObject as? Deck {
                print("🔄 After refresh - Deck '\(deck.name)' hasIconData: \(deck.customIconData != nil), dataSize: \(deck.customIconData?.count ?? 0)")
            }
        }
    }
    
    private func handleFailedTask(_ task: ImageGenerationTask) async {
        await persistentContainer.performBackgroundTask { context in
            guard let objectId = task.objectId else { return }
            
            switch task.type {
            case .cardImage, .suggestionImage:
                if let card = try? context.existingObject(with: objectId) as? Card {
                    print("❌ Image generation failed for card: '\(card.front)'")
                    
                    // Record the failure
                    card.recordImageGenerationFailure()
                    
                    do {
                        try context.save()
                        print("📉 Recorded image generation failure for card: '\(card.front)' (total: \(card.imageGenerationFailureCount))")
                    } catch {
                        print("❌ Failed to save image generation failure tracking: \(error)")
                    }
                }
            case .deckIcon:
                // For deck icons, we don't have failure tracking yet, just log
                if let deck = try? context.existingObject(with: objectId) as? Deck {
                    print("❌ Image generation failed for deck icon: '\(deck.name)'")
                }
            }
        }
        
        // Implement retry logic with exponential backoff for regular cards
        let retryCount = taskQueue.filter { $0.objectId == task.objectId && $0.type == task.type }.count
        
        if retryCount < retryDelays.count {
            let delay = retryDelays[retryCount]
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.addTaskToQueue(task)
                print("🔄 Retrying \(task.type) generation in \(Int(delay))s (attempt \(retryCount + 1))")
            }
        } else {
            print("❌ Giving up on \(task.type) generation after \(retryCount) retries")
        }
    }
    
    /// Process all decks synchronously, one by one
    private func processAllDecks() async {
        print("🔄 Starting deck processing cycle...")
        
        // Check if app is in foreground before processing
        guard isAppInForeground else {
            print("📱 App is in background - skipping deck processing to avoid Apple Intelligence errors")
            return
        }
        
        // Check if we have valid generation methods
        let gptService = GPT5MiniService()
        let canGenerateContent = gptService.hasValidKey
        let canGenerateImages = useAppleIntelligence || hasValidOpenAIKey
        
        if !canGenerateContent && !canGenerateImages {
            print("🔄 No valid generation methods available - skipping processing")
            return
        }
        
        await withCheckedContinuation { continuation in
            persistentContainer.performBackgroundTask { context in
                do {
                    let deckRequest: NSFetchRequest<Deck> = Deck.fetchRequest()
                    let decks = try context.fetch(deckRequest)
                    
                    print("🔄 Processing \(decks.count) decks sequentially...")
                    
                    Task {
                        for deck in decks {
                            await self.processSingleDeck(deck, in: context)
                        }
                        continuation.resume()
                    }
                } catch {
                    print("❌ Failed to fetch decks: \(error)")
                    continuation.resume()
                }
            }
        }
        
        print("🔄 Deck processing cycle complete")
    }
    
    /// Process a single deck synchronously through all phases
    private func processSingleDeck(_ deck: Deck, in context: NSManagedObjectContext) async {
        print("🔄 Processing deck: '\(deck.name)'")
        
        // Phase 1: Generate suggestions if needed
        if deck.queuedSuggestions > 0 {
            await generateSuggestionsIfNeeded(for: deck, in: context)
        }
        
        // Phase 2: Process invisible cards (generate images and make visible)
        await processInvisibleCards(for: deck, in: context)
        
        // Phase 3: Process visible suggestion cards (add missing images)
        await processVisibleSuggestions(for: deck, in: context)
        
        // Phase 4: Process current cards (add missing images)  
        await processCurrentCards(for: deck, in: context)
        
        // Phase 5: Generate deck icon if missing
        await processDeckIcon(for: deck, in: context)
        
        // Final refresh to ensure UI sees all changes
        await MainActor.run {
            persistentContainer.viewContext.refreshAllObjects()
        }
        
        print("✅ Completed processing deck: '\(deck.name)'")
    }
    
    // MARK: - Synchronous Phase Processing
    
    /// Phase 1: Generate suggestions if needed and add to invisible list
    private func generateSuggestionsIfNeeded(for deck: Deck, in context: NSManagedObjectContext) async {
        let currentSuggestionCount = deck.visibleSuggestions.count + deck.invisibleSuggestions.count
        let targetCount = Int(deck.queuedSuggestions)
        
        if currentSuggestionCount >= targetCount {
            return // Already have enough suggestions
        }
        
        let needed = targetCount - currentSuggestionCount
        print("🤖 Generating \(needed) suggestions for deck '\(deck.name)'")
        
        // Make synchronous LLM call to generate suggestions
        let gptService = GPT5MiniService()
        guard gptService.hasValidKey else {
            print("❌ No valid GPT API key for suggestion generation")
            return
        }
        
        do {
            let existingCards = deck.activeCards + deck.archivedCards
            let currentCards = existingCards.map { (front: $0.front, type: $0.cardType.rawValue) }
            let deletedCards = deck.deletedSuggestionArray.map { (front: $0.front, type: $0.cardType) }
            
            // Include existing suggestions to prevent duplicates
            let existingSuggestions = (deck.visibleSuggestions + deck.invisibleSuggestions).map { (front: $0.front, type: $0.cardType.rawValue) }
            
            let suggestions = try await gptService.generateCardSuggestions(
                deckName: deck.name,
                deckDescription: deck.deckDescription,
                currentCards: currentCards,
                suggestedCards: existingSuggestions,
                deletedCards: deletedCards,
                count: needed
            )
            
            // Synchronously add suggestions as Cards with suggestionPending state
            // Track what we're adding to prevent internal duplicates
            var addedInThisBatch: Set<String> = []
            var actuallyAdded = 0
            
            for suggestion in suggestions {
                // Create unique key for this suggestion
                let uniqueKey = "\(suggestion.front.lowercased())|\(suggestion.type.lowercased())"
                
                // Check if we already have this suggestion in the deck or are adding it in this batch
                let isDuplicateInDeck = (deck.activeCards + deck.archivedCards).contains { card in
                    card.front.lowercased() == suggestion.front.lowercased() && 
                    card.cardType.rawValue.lowercased() == suggestion.type.lowercased()
                }
                
                let isDuplicateInBatch = addedInThisBatch.contains(uniqueKey)
                
                if isDuplicateInDeck {
                    print("⚠️ Skipping duplicate suggestion (already in deck): '\(suggestion.front)'")
                    continue
                }
                
                if isDuplicateInBatch {
                    print("⚠️ Skipping duplicate suggestion (already in this batch): '\(suggestion.front)'")
                    continue
                }
                
                let suggestionCard = Card(context: context)
                suggestionCard.id = UUID()
                suggestionCard.front = suggestion.front
                suggestionCard.jsonContent = suggestion.back
                suggestionCard.back = "" // Clear legacy back field
                suggestionCard.cardType = CardType.from(string: suggestion.type)
                suggestionCard.imagePrompt = suggestion.imagePrompt
                suggestionCard.makeSuggestionPending(context: suggestion.context, category: "ai_generated")
                suggestionCard.createdAt = Date()
                suggestionCard.deck = deck
                
                addedInThisBatch.insert(uniqueKey)
                actuallyAdded += 1
                print("➕ Added pending suggestion: '\(suggestion.front)'")
            }
            
            try context.save()
            print("✅ Generated and saved \(actuallyAdded) out of \(suggestions.count) pending suggestions (duplicates filtered)")
            
            // Merge changes to main context so UI sees the updates
            await MainActor.run {
                persistentContainer.viewContext.refreshAllObjects()
            }
            
        } catch {
            print("❌ Failed to generate suggestions: \(error)")
        }
    }
    
    /// Phase 2: Process invisible suggestions (generate images and make visible)
    private func processInvisibleCards(for deck: Deck, in context: NSManagedObjectContext) async {
        let invisibleCards = deck.invisibleSuggestions
        
        if invisibleCards.isEmpty {
            return
        }
        
        print("🖼️ Processing \(invisibleCards.count) pending suggestions for deck '\(deck.name)'")
        
        for suggestionCard in invisibleCards {
            guard let imagePrompt = suggestionCard.imagePrompt else {
                print("⚠️ No image prompt for suggestion: '\(suggestionCard.front)'")
                continue
            }
            
            // Check if we should attempt image generation for this card
            guard suggestionCard.shouldAttemptImageGeneration else {
                print("⏸️ Skipping image generation for suggestion '\(suggestionCard.front)' due to previous failures")
                continue
            }
            
            print("🎨 Generating image for pending suggestion: '\(suggestionCard.front)'")
            
            do {
                let image: UIImage
                
                if useAppleIntelligence {
                    if #available(iOS 18.4, *) {
                        image = try await generateImageWithAppleIntelligence(prompt: imagePrompt)
                    } else {
                        throw NSError(domain: "BackgroundImageGeneration", code: 9, userInfo: [NSLocalizedDescriptionKey: "Apple Intelligence requires iOS 18.4 or later"])
                    }
                } else {
                    image = try await generateImageWithOpenAI(prompt: imagePrompt)
                }
                
                // Synchronously apply image and make suggestion (ready for review)
                suggestionCard.setCustomImage(image)
                suggestionCard.state = .suggestion
                
                print("✅ Generated image and made ready for review: '\(suggestionCard.front)'")
                
            } catch {
                print("❌ Failed to generate image for suggestion '\(suggestionCard.front)': \(error)")
                
                // Record the failure
                suggestionCard.recordImageGenerationFailure()
            }
        }
        
        // Save all changes
        do {
            try context.save()
            print("💾 Saved pending suggestion updates")
            
            // Merge changes to main context so UI sees the updates
            await MainActor.run {
                persistentContainer.viewContext.refreshAllObjects()
            }
        } catch {
            print("❌ Failed to save pending suggestion updates: \(error)")
        }
    }
    
    /// Phase 3: Process visible suggestions (add missing images)
    private func processVisibleSuggestions(for deck: Deck, in context: NSManagedObjectContext) async {
        let visibleSuggestions = deck.visibleSuggestions.filter { 
            !$0.hasCustomImage && $0.shouldAttemptImageGeneration 
        }
        
        if visibleSuggestions.isEmpty {
            return
        }
        
        print("🖼️ Processing \(visibleSuggestions.count) visible suggestions needing images for deck '\(deck.name)'")
        
        for suggestionCard in visibleSuggestions {
            await generateImageForCard(suggestionCard, in: context)
        }
    }
    
    /// Phase 4: Process current cards (add missing images)
    private func processCurrentCards(for deck: Deck, in context: NSManagedObjectContext) async {
        let cardsNeedingImages = deck.activeCards.filter { card in
            guard let imagePrompt = card.imagePrompt, !imagePrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
            guard getCardImageData(card) == nil else { return false }
            // Check if we should attempt image generation for this card
            return card.shouldAttemptImageGeneration
        }
        
        if cardsNeedingImages.isEmpty {
            return
        }
        
        print("🖼️ Processing \(cardsNeedingImages.count) current cards needing images for deck '\(deck.name)'")
        
        for card in cardsNeedingImages {
            await generateImageForCard(card, in: context)
        }
    }
    
    /// Phase 5: Generate deck icon if missing
    private func processDeckIcon(for deck: Deck, in context: NSManagedObjectContext) async {
        if deck.customIconData != nil {
            return // Already has icon
        }
        
        print("🎨 Generating icon for deck: '\(deck.name)'")
        
        do {
            if let icon = await DeckIconGenerationService.shared.generateIconForDeck(
                name: deck.name,
                description: deck.deckDescription
            ) {
                deck.setCustomIcon(icon)
                try context.save()
                print("✅ Generated and saved icon for deck '\(deck.name)'")
            } else {
                print("❌ Failed to generate icon for deck '\(deck.name)'")
            }
        } catch {
            print("❌ Failed to save deck icon: \(error)")
        }
    }
    
    // MARK: - Helper Methods for Image Generation
    
    
    /// Generate image for a current card
    private func generateImageForCard(_ card: Card, in context: NSManagedObjectContext) async {
        guard let imagePrompt = card.imagePrompt else {
            print("⚠️ No image prompt for card: '\(card.front)'")
            return
        }
        
        // Check if we should attempt image generation for this card
        guard card.shouldAttemptImageGeneration else {
            print("⏸️ Skipping image generation for card '\(card.front)' due to previous failures")
            return
        }
        
        print("🎨 Generating image for card: '\(card.front)'")
        
        do {
            let image: UIImage
            
            if useAppleIntelligence {
                if #available(iOS 18.4, *) {
                    image = try await generateImageWithAppleIntelligence(prompt: imagePrompt)
                } else {
                    throw NSError(domain: "BackgroundImageGeneration", code: 9, userInfo: [NSLocalizedDescriptionKey: "Apple Intelligence requires iOS 18.4 or later"])
                }
            } else {
                image = try await generateImageWithOpenAI(prompt: imagePrompt)
            }
            
            card.setCustomImage(image)
            try context.save()
            
            print("✅ Generated and saved image for card: '\(card.front)'")
            
        } catch {
            print("❌ Failed to generate image for card '\(card.front)': \(error)")
            
            // Record the failure
            card.recordImageGenerationFailure()
            
            // Save the failure tracking
            do {
                try context.save()
            } catch {
                print("❌ Failed to save image generation failure tracking: \(error)")
            }
        }
    }
    
    // All suggestion management is now handled by the synchronous deck processing in processAllDecks()
    // No separate suggestion maintenance methods needed
    
    // Deduplication is now handled by the generateSuggestionsIfNeeded method using Core Data entities
    
    /// Scan decks and process missing icons immediately
    private func scanAndProcessDecks(in context: NSManagedObjectContext) async {
        let deckRequest: NSFetchRequest<Deck> = Deck.fetchRequest()
        
        do {
            let decks = try context.fetch(deckRequest)
            print("🔍 Scanning \(decks.count) decks for missing icons...")
            
            let decksNeedingIcons = decks.filter { $0.customIconData == nil }
            print("🔍 Found \(decksNeedingIcons.count) decks needing icons")
            
            for deck in decksNeedingIcons {
                print("🔍 Processing deck icon: '\(deck.name)'")
                
                // Generate icon immediately
                if let icon = await DeckIconGenerationService.shared.generateIconForDeck(
                    name: deck.name, 
                    description: deck.deckDescription
                ) {
                    // Apply the generated icon
                    await self.applyDeckIcon(icon, to: deck.objectID)
                    print("✅ Generated and applied icon for deck '\(deck.name)'")
                } else {
                    print("❌ Failed to generate icon for deck '\(deck.name)'")
                }
            }
        } catch {
            print("❌ Failed to scan decks: \(error)")
        }
    }
    
    /// Scan cards (including suggestion cards) and process missing images immediately
    private func scanAndProcessCards(in context: NSManagedObjectContext) async {
        let cardRequest: NSFetchRequest<Card> = Card.fetchRequest()
        
        do {
            let allCards = try context.fetch(cardRequest)
            
            // Filter cards that need images: complete cards with image prompts but no images
            let cardsNeedingImages = allCards.filter { card in
                // Must be complete (have content)
                
                // Must have an image prompt (from suggestion or manually set)
                guard let imagePrompt = card.imagePrompt, !imagePrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
                
                // Must not already have an image
                guard self.getCardImageData(card) == nil else { return false }
                
                // Exclude very recently created cards (likely temporary suggestion cards)
                // This prevents race condition with suggestion pipeline
                let timeSinceCreation = Date().timeIntervalSince(card.createdAt)
                guard timeSinceCreation > 30 else { return false } // Skip cards created in last 30 seconds
                
                return true
            }
            
            let recentCards = allCards.filter { 
                guard let _ = $0.imagePrompt else { return false }
                return self.getCardImageData($0) == nil && Date().timeIntervalSince($0.createdAt) <= 30
            }
            
            print("🔍 Found \(cardsNeedingImages.count) cards needing images (from \(allCards.count) total cards)")
            if !recentCards.isEmpty {
                print("🕒 Skipped \(recentCards.count) recently created cards (likely suggestion pipeline)")
            }
            
            for card in cardsNeedingImages {
                print("🔍 Processing card image: '\(card.front)' with prompt: '\(card.imagePrompt ?? "")'")
                
                // Use the stored image prompt directly
                let prompt = card.imagePrompt!
                
                // Generate image immediately
                do {
                    let image: UIImage
                    
                    if self.useAppleIntelligence {
                        if #available(iOS 18.4, *) {
                            image = try await self.generateImageWithAppleIntelligence(prompt: prompt)
                        } else {
                            throw NSError(domain: "BackgroundImageGeneration", code: 9, userInfo: [NSLocalizedDescriptionKey: "Apple Intelligence requires iOS 18.4 or later"])
                        }
                    } else {
                        image = try await self.generateImageWithOpenAI(prompt: prompt)
                    }
                    
                    // Apply the generated image
                    await self.applyCardImage(image, to: card.objectID)
                    print("✅ Generated and applied image for card '\(card.front)'")
                    
                } catch {
                    print("❌ Failed to generate image for card '\(card.front)': \(error)")
                }
            }
        } catch {
            print("❌ Failed to scan cards: \(error)")
        }
    }
    
    /// Apply generated deck icon to deck
    private func applyDeckIcon(_ image: UIImage, to objectId: NSManagedObjectID) async {
        await persistentContainer.performBackgroundTask { context in
            guard let deck = try? context.existingObject(with: objectId) as? Deck else {
                print("⚠️ Deck with ID \(objectId) no longer exists")
                return
            }
            
            deck.setCustomIcon(image)
            
            do {
                try context.save()
                print("💾 Saved deck icon to Core Data")
            } catch {
                print("❌ Failed to save deck icon: \(error)")
            }
        }
    }
    
    /// Apply generated card image to card
    private func applyCardImage(_ image: UIImage, to objectId: NSManagedObjectID) async {
        await persistentContainer.performBackgroundTask { context in
            guard let card = try? context.existingObject(with: objectId) as? Card else {
                print("⚠️ Card with ID \(objectId) no longer exists")
                return
            }
            
            card.setCustomImage(image)
            
            do {
                try context.save()
                print("💾 Saved card image to Core Data")
            } catch {
                print("❌ Failed to save card image: \(error)")
            }
        }
    }
    
    private var hasValidOpenAIKey: Bool {
        return openAIAPIKey != nil && !openAIAPIKey!.isEmpty
    }
    
    private var allowOpenAIImageBackup: Bool {
        return UserDefaults.standard.bool(forKey: "allowOpenAIImageBackup")
    }
    
    // MARK: - Content Helpers
    
    /// Extracts a content summary from structured card content for image generation
    private func getCardContentSummary(_ card: Card) -> String {
        switch card.cardType {
        case .vocabulary:
            if let content = card.vocabularyContent {
                return content.meaning
            }
        case .conjugation:
            if let content = card.conjugationContent {
                return content.meaning
            }
        case .fact:
            if let content = card.factContent {
                return content.answer
            }
        }
        
        // Fallback to empty string for cards without structured content
        return ""
    }
    
    // MARK: - Prompt Generation
    
    private func buildDeckIconPrompt(name: String, description: String?) -> String {
        let deckInfo = description?.isEmpty == false ? description! : "General study deck"
        let content = (name + " " + deckInfo).lowercased()
        
        var prompt = "Create a clean, modern, minimalist flat design icon for a flashcard study app. Square format, vibrant but professional colors, no text or letters, educational theme. "
        
        // Add content-specific imagery (same logic as before)
        if content.contains("italian") || content.contains("italiano") {
            prompt += "Italian language learning theme with artistic elements, green, white, and red colors."
        } else if content.contains("french") || content.contains("français") {
            prompt += "French language learning theme with elegant cultural symbols, blue and white colors."
        } else if content.contains("math") || content.contains("calculus") || content.contains("algebra") {
            prompt += "Mathematics theme with geometric shapes, equations symbols, graphs, blue and purple colors."
        } else if content.contains("science") || content.contains("biology") {
            prompt += "Science theme with leaf patterns, DNA helixes, cell structures, green and natural colors."
        } else {
            prompt += "General education theme with book symbols, learning elements, graduation cap, scholarly blue and gold colors."
        }
        
        prompt += " Professional app icon quality, suitable for iOS/Android app stores."
        return prompt
    }
    
    private func buildCardImagePrompt(front: String, back: String, deck: Deck?, customImagePrompt: String? = nil) -> String {
        print("🎨 Building card image prompt for front: '\(front)' with back content length: \(back.count)")
        
        // If we have a custom image prompt from LLM, use it exactly as-is
        if let customPrompt = customImagePrompt?.trimmingCharacters(in: .whitespacesAndNewlines), !customPrompt.isEmpty {
            print("🎯 Using stored LLM-generated image prompt: '\(customPrompt)'")
            return customPrompt
        }
        
        // If no custom prompt, generate a fallback based on card content
        print("🎯 No stored image prompt (received: '\(customImagePrompt ?? "nil")'), generating fallback prompt")
        
        let cardType = inferCardTypeFromContent(back: back)
        print("🎯 Inferred card type: \(cardType)")
        
        let concept: String
        switch cardType {
        case .fact:
            concept = front.trimmingCharacters(in: .whitespacesAndNewlines)
            print("🎯 Using front for fact card: '\(concept)'")
        case .vocabulary, .conjugation:
            concept = extractMeaningFromBack(back: back, front: front)
            print("🎯 Extracted meaning from back for \(cardType): '\(concept)'")
        }
        
        // Generate appropriate prompt based on user settings
        if useAppleIntelligence {
            let prompt = PromptGenerator.appleIntelligenceImagePrompt(concept: concept)
            print("🎨 Generated Apple Intelligence prompt: '\(prompt)'")
            return prompt
        } else {
            let prompt = PromptGenerator.openAIImagePrompt(concept: concept)
            print("🎨 Generated OpenAI prompt: '\(prompt)'")
            return prompt
        }
    }
    
    
    // Infer card type from the structure of the back content
    private func inferCardTypeFromContent(back: String) -> CardType {
        let content = back.lowercased()
        
        // Check for conjugation patterns (pronouns with verb forms)
        if content.contains("io ") && content.contains("tu ") && content.contains("lui/lei") ||
           content.contains("je ") && content.contains("tu ") && content.contains("il/elle") ||
           content.contains("ich ") && content.contains("du ") && content.contains("er/sie") {
            return .conjugation
        }
        
        // Check for fact patterns (bullet points or info sections)
        if content.contains("- ") && (content.contains("## ℹ️ info") || content.contains("## 💬 did you know")) {
            return .fact
        }
        
        // Check for other patterns that might indicate facts
        if content.contains("## 📝 usage notes") && (content.contains("formal") || content.contains("informal")) {
            return .vocabulary // Treat usage notes as vocabulary since there's no phrases type
        }
        
        // Default to vocabulary if no other pattern matches
        return .vocabulary
    }
    
    // Extract the English meaning from card back content
    private func extractMeaningFromBack(back: String, front: String) -> String {
        let lines = back.components(separatedBy: .newlines)
        
        // Look for the title line (starts with # and contains the English meaning)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") && !trimmed.hasPrefix("##") {
                // Remove the # and any emojis/extra formatting
                let title = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                let cleanTitle = title.replacingOccurrences(of: "💡", with: "").trimmingCharacters(in: .whitespaces)
                if !cleanTitle.isEmpty {
                    return cleanTitle
                }
            }
        }
        
        // Fallback: look for the first substantial definition line
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && 
               !trimmed.hasPrefix("#") && 
               !trimmed.hasPrefix("*") &&
               !trimmed.hasPrefix("-") &&
               !trimmed.hasPrefix("**") &&
               trimmed.count > 10 && 
               trimmed.count < 100 {
                return trimmed
            }
        }
        
        // Final fallback: use the front if we can't extract anything useful
        print("⚠️ Could not extract meaning from back, using front: '\(front)'")
        return front.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Image Generation APIs
    
    @available(iOS 18.4, *)
    private func generateImageWithAppleIntelligence(prompt: String) async throws -> UIImage {
        print("🎯 Starting Apple Intelligence generation with prompt: '\(prompt)'")
        print("📱 Device iOS version: \(UIDevice.current.systemVersion)")
        
        // Check if app is in foreground before Apple Intelligence generation
        guard isAppInForeground else {
            throw NSError(domain: "BackgroundImageGeneration", code: 12, userInfo: [NSLocalizedDescriptionKey: "Apple Intelligence image generation is not available when the app is in the background. The app must be in the foreground for Apple Intelligence to work."])
        }
        
        // Try the main prompt first
        let mainResult = await tryImageGeneration(with: prompt)
        switch mainResult {
        case .success(let image):
            return image
        case .failure(let error):
            print("⚠️ First attempt failed, waiting 1 second and retrying same prompt...")
            
            // Wait 1 second and try the same prompt again
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            let retryResult = await tryImageGeneration(with: prompt)
            switch retryResult {
            case .success(let image):
                print("✅ Retry succeeded!")
                return image
            case .failure(_):
                print("❌ Retry failed, falling back to OpenAI if available...")
                
                // If we have OpenAI available AND user allows backup, try that as fallback
                if hasValidOpenAIKey && allowOpenAIImageBackup {
                    print("🔄 Switching to OpenAI fallback (user enabled backup)...")
                    return try await generateImageWithOpenAI(prompt: prompt)
                } else if hasValidOpenAIKey && !allowOpenAIImageBackup {
                    print("🚫 OpenAI backup available but disabled by user setting")
                } else {
                    print("🚫 No OpenAI backup available - no API key")
                }
                
                // If no OpenAI fallback available, throw the original error
                throw error
            }
        }
    }
    
    @available(iOS 18.4, *)
    private func tryImageGeneration(with prompt: String) async -> Result<UIImage, Error> {
        do {
            print("🔧 Initializing ImageCreator...")
            let imageCreator = try await ImageCreator()
            print("✅ ImageCreator initialized successfully")
            
            let style = selectedImageStyle.imagePlaygroundStyle
            print("🎨 Using Apple Intelligence style: \(selectedImageStyle.displayName)")
            print("🎯 Generating image with concept: .text('\(prompt)')")
            
            let images = imageCreator.images(
                for: [.text(prompt)],
                style: style,
                limit: 1
            )
            
            print("🔄 Starting image generation loop...")
            
            for try await image in images {
                let uiImage = UIImage(cgImage: image.cgImage)
                print("🎉 Apple Intelligence image generated successfully!")
                print("💰 Apple Intelligence Image Usage:")
                print("   🖼️ Model: On-device Image Playground")
                print("   📏 Style: \(selectedImageStyle.displayName)")
                print("   💵 Cost: $0.00 (on-device, free)")
                return .success(uiImage)
            }
            
            let noImagesError = NSError(domain: "BackgroundImageGeneration", code: 6, userInfo: [NSLocalizedDescriptionKey: "No images generated"])
            return .failure(noImagesError)
            
        } catch ImageCreator.Error.notSupported {
            let notSupportedError = NSError(domain: "BackgroundImageGeneration", code: 7, userInfo: [NSLocalizedDescriptionKey: "Apple Intelligence image creation not supported on this device. Enable Apple Intelligence in Settings or use OpenAI instead."])
            return .failure(notSupportedError)
        } catch {
            print("🚨 Detailed Apple Intelligence error: \(error)")
            print("🚨 Error domain: \((error as NSError).domain)")
            print("🚨 Error code: \((error as NSError).code)")
            print("🚨 Error userInfo: \((error as NSError).userInfo)")
            
            // Provide more specific error messages based on error code
            let nsError = error as NSError
            let errorMessage: String
            switch nsError.code {
            case 11:
                errorMessage = "Apple Intelligence generation failed. This might be due to: content restrictions, prompt complexity, or temporary service issues. Try a simpler prompt or switch to OpenAI."
            case 1:
                errorMessage = "Apple Intelligence is not available. Make sure it's enabled in Settings > Apple Intelligence & Siri."
            case 2:
                errorMessage = "Apple Intelligence request was cancelled or timed out."
            default:
                errorMessage = "Apple Intelligence error (code \(nsError.code)): \(error.localizedDescription). Try switching to OpenAI for more reliable generation."
            }
            
            let finalError = NSError(domain: "BackgroundImageGeneration", code: 8, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            return .failure(finalError)
        }
    }
    
    private func generateImageWithOpenAI(prompt: String) async throws -> UIImage {
        guard let apiKey = openAIAPIKey else {
            throw NSError(domain: "BackgroundImageGeneration", code: 1, userInfo: [NSLocalizedDescriptionKey: "No API key"])
        }
        
        // Get user's image style preference, default to 2D illustration
        let userStyle = UserDefaults.standard.string(forKey: "selectedImageStyle") ?? "illustration"
        let styleDescription: String
        
        switch userStyle {
        case "sketch":
            styleDescription = "hand-drawn sketch style, black and white line art"
        case "animation":
            styleDescription = "3D Pixar-style animation, colorful and vibrant"
        default: // "illustration"
            styleDescription = "2D flat illustration style, clean and modern"
        }
        
        // Combine the original prompt with the style
        let styledPrompt = "\(prompt), \(styleDescription)"
        
        print("🎨 Original prompt: '\(prompt)'")
        print("🎨 User style setting: '\(userStyle)'")
        print("🎨 OpenAI styled prompt: '\(styledPrompt)'")
        
        let model = "gpt-image-1"
        let size = "1024x1024"  // Square images are fastest to generate
        let quality = "low"     // Optimized for speed and cost
        let n = 1
        
        let requestBody: [String: Any] = [
            "model": model,
            "prompt": styledPrompt,
            "n": n,
            "size": size,
            "quality": quality
        ]
        
        print("📤 OpenAI request: model=\(model), size=\(size), quality=\(quality), n=\(n)")
        
        let url = URL(string: "\(baseURL)/images/generations")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("📤 Sending card image request to OpenAI API...")
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let wallClockTime = endTime - startTime
        print("⏱️ OpenAI card image API call completed in \(String(format: "%.2f", wallClockTime))s")
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "BackgroundImageGeneration", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ OpenAI API Error (\(httpResponse.statusCode)): \(errorMessage)")
            throw NSError(domain: "BackgroundImageGeneration", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
        
        print("✅ OpenAI image generation successful")
        
        // Log cost information for gpt-image-1 (2025 token-based pricing)
        // Approximate costs: $0.02 (low), $0.07 (medium), $0.19 (high) per image for 1024x1024
        let imageCost: Double = {
            switch quality {
            case "low": return 0.02
            case "medium": return 0.07
            case "high": return 0.19
            default: return 0.02 // fallback to low
            }
        }()
        print("💰 OpenAI gpt-image-1 API Usage:")
        print("   🖼️ Model: \(model)")
        print("   📏 Size: \(size)")
        print("   ⭐ Quality: \(quality.capitalized)")
        print("   💵 Estimated cost: $\(String(format: "%.3f", imageCost))")
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let dataArray = json?["data"] as? [[String: Any]]
        let firstItem = dataArray?.first
        
        // Try base64 format first
        if let base64String = firstItem?["b64_json"] as? String,
           let imageData = Data(base64Encoded: base64String),
           let image = UIImage(data: imageData) {
            return image
        }
        
        // Try URL format as fallback
        if let imageURL = firstItem?["url"] as? String,
           let url = URL(string: imageURL) {
            let (imageData, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: imageData) else {
                throw NSError(domain: "BackgroundImageGeneration", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to decode image"])
            }
            return image
        }
        
        throw NSError(domain: "BackgroundImageGeneration", code: 4, userInfo: [NSLocalizedDescriptionKey: "No valid image data"])
    }
    
    // MARK: - Card Image Handling
    
    private func getCardImageData(_ card: Card) -> Data? {
        return card.customImageData
    }
    
    private func setCardImage(_ card: Card, image: UIImage) {
        card.setCustomImage(image)
    }
    
    private func clearCardImage(_ card: Card) {
        card.clearCustomImage()
    }
    
    // MARK: - Placeholder Image Generation
    
    /// Creates a placeholder image for immediate display while generating the real one
    func createPlaceholderImage(for type: ImageGenerationTask.ImageType, size: CGSize = CGSize(width: 200, height: 200)) -> UIImage? {
        guard size.width > 0 && size.height > 0 && size.width.isFinite && size.height.isFinite else {
            print("⚠️ Invalid size for placeholder image: \(size)")
            return nil
        }
        
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // Create gradient background based on type
            let colors: [UIColor] = {
                switch type {
                case .deckIcon:
                    return [UIColor.systemBlue.withAlphaComponent(0.3), UIColor.systemPurple.withAlphaComponent(0.2)]
                case .cardImage:
                    return [UIColor.systemGreen.withAlphaComponent(0.3), UIColor.systemTeal.withAlphaComponent(0.2)]
                case .suggestionImage:
                    return [UIColor.systemOrange.withAlphaComponent(0.3), UIColor.systemYellow.withAlphaComponent(0.2)]
                }
            }()
            
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors.map(\.cgColor) as CFArray,
                locations: [0.0, 1.0]
            ) else {
                // Fallback to solid color
                cgContext.setFillColor(colors[0].cgColor)
                cgContext.fill(CGRect(origin: .zero, size: size))
                return
            }
            
            // Draw gradient background
            cgContext.drawLinearGradient(
                gradient,
                start: CGPoint.zero,
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
            
            // Add icon and text
            let symbolName: String = {
                switch type {
                case .deckIcon:
                    return "folder.badge.plus"
                case .cardImage:
                    return "photo.badge.plus"
                case .suggestionImage:
                    return "lightbulb.badge.plus"
                }
            }()
            
            let symbolSize = min(size.width, size.height) * 0.3
            let symbolConfig = UIImage.SymbolConfiguration(pointSize: symbolSize, weight: .medium)
            
            guard let symbolImage = UIImage(systemName: symbolName, withConfiguration: symbolConfig) else {
                return
            }
            
            // Center the symbol
            let symbolRect = CGRect(
                x: (size.width - symbolImage.size.width) / 2,
                y: (size.height - symbolImage.size.height) / 2 - 10,
                width: symbolImage.size.width,
                height: symbolImage.size.height
            )
            
            symbolImage.withTintColor(.white.withAlphaComponent(0.8)).draw(in: symbolRect)
            
            // Add "Generating..." text
            let text = "Generating..."
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: min(size.width, size.height) * 0.08, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.7)
            ]
            
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: symbolRect.maxY + 8,
                width: textSize.width,
                height: textSize.height
            )
            
            text.draw(in: textRect, withAttributes: attributes)
        }
    }
    
    /// Sets a placeholder image immediately while queuing the real generation
    func setPlaceholderAndQueue(for deck: Deck, priority: ImageGenerationTask.Priority = .normal) {
        // Create and set placeholder immediately
        if let placeholder = createPlaceholderImage(for: .deckIcon, size: CGSize(width: 200, height: 200)) {
            deck.setCustomIcon(placeholder)
            try? persistentContainer.viewContext.save()
        }
        
        // Queue the real generation
        generateDeckIcon(for: deck, priority: priority)
    }
    
    /// Sets a placeholder image immediately while queuing the real generation
    func setPlaceholderAndQueue(for card: Card, priority: ImageGenerationTask.Priority = .normal) {
        
        // Create and set placeholder immediately
        if let placeholder = createPlaceholderImage(for: .cardImage, size: CGSize(width: 200, height: 200)) {
            card.setCustomImage(placeholder)
            try? persistentContainer.viewContext.save()
        }
        
        // Queue the real generation
        generateCardImage(for: card, priority: priority)
    }
    
    // All suggestion management is now handled via Core Data (Card entities with states)
    // The background sweeper processes suggestions directly through Core Data in processAllDecks()
    
}
