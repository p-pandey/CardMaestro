import SwiftUI
import CoreData

enum CardSortOrder: String, CaseIterable {
    case creationTime = "creation_time"
    case lastSeenTime = "last_seen_time"
    case lastSuccessTime = "last_success_time"
    case nextDueTime = "next_due_time"
    
    var displayName: String {
        switch self {
        case .creationTime: return "Creation Time"
        case .lastSeenTime: return "Last Seen"
        case .lastSuccessTime: return "Last Success"
        case .nextDueTime: return "Next Due"
        }
    }
    
    var systemImage: String {
        switch self {
        case .creationTime: return "clock"
        case .lastSeenTime: return "eye"
        case .lastSuccessTime: return "checkmark.circle"
        case .nextDueTime: return "calendar"
        }
    }
}

struct DeckDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @ObservedObject var deck: Deck
    
    @State private var showingCreateCard = false
    @State private var showingStudy = false
    @State private var currentSortOrder: CardSortOrder = .creationTime
    @State private var sortAscending = false
    @State private var showingSortMenu = false
    @State private var showingSuggestions = false
    @State private var showingSuggestedCards = false
    @State private var showingEditDeck = false
    @State private var showingArchive = false
    @StateObject private var backgroundImageService = BackgroundImageGenerationService.shared
    
    var body: some View {
        listContent
            .navigationTitle(deck.name)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        showingEditDeck = true
                    }
                }
            }
            .background(
                LinearGradient(
                    colors: [
                        deck.deckColor.opacity(0.1),
                        deck.deckColor.opacity(0.03),
                        Color(.systemGroupedBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .sheet(isPresented: $showingCreateCard) {
                CardCreationView(deck: deck)
            }
            .sheet(isPresented: $showingStudy) {
                StudyView(deck: deck, viewContext: viewContext)
            }
.sheet(isPresented: $showingSuggestions) {
                CardSuggestionView(deck: deck)
            }
            .sheet(isPresented: $showingSuggestedCards) {
                SuggestedCardsView(deck: deck)
            }
            .sheet(isPresented: $showingEditDeck) {
                DeckEditView(deck: deck)
            }
            .sheet(isPresented: $showingArchive) {
                ArchiveView(deck: deck)
            }
            .overlay(toastOverlay)
    }
    
    private var listContent: some View {
        List {
            deckStatsSection
            actionsSection
            cardsSection
            // Archive section removed - accessed via action menu
        }
    }
    
    private var deckStatsSection: some View {
        Section {
            VStack(spacing: 16) {
                // Colorful header with deck icon
                HStack {
                    ZStack {
                        if let customIcon = deck.customIcon {
                            // Display custom generated icon with safe aspect ratio handling
                            Group {
                                if customIcon.size.width > 0 && customIcon.size.height > 0 {
                                    Image(uiImage: customIcon)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 50, height: 50)
                                        .clipShape(Circle())
                                        .shadow(color: deck.deckColor.opacity(0.4), radius: 6, x: 0, y: 3)
                                } else {
                                    // Fall back to SF Symbol if custom icon is invalid
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [deck.deckColor, deck.deckColor.opacity(0.8)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 50, height: 50)
                                        .shadow(color: deck.deckColor.opacity(0.4), radius: 6, x: 0, y: 3)
                                    
                                    Image(systemName: deck.deckIcon)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                }
                            }
                        } else {
                            // Fall back to SF Symbol with gradient background
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [deck.deckColor, deck.deckColor.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 50, height: 50)
                                .shadow(color: deck.deckColor.opacity(0.4), radius: 6, x: 0, y: 3)
                            
                            Image(systemName: deck.deckIcon)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        
                    }
                    .contextMenu {
                        Button {
                            regenerateDeckIcon()
                        } label: {
                            Label("Regenerate Icon", systemImage: "arrow.clockwise")
                        }
                        
                        if deck.hasCustomIcon {
                            Button {
                                clearDeckIcon()
                            } label: {
                                Label("Remove Custom Icon", systemImage: "trash")
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(deck.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        if let description = deck.deckDescription, !description.isEmpty {
                            Text(description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    
                    Spacer()
                }
                
                DeckStatsView(deck: deck)
            }
        }
    }
    
    private var actionsSection: some View {
        Section("Actions") {
            studyButton
            addCardButton
            suggestionsButton
            viewArchiveButton
        }
    }
    
    private var studyButton: some View {
        Button {
            SoundService.shared.playButtonTap()
            showingStudy = true
        } label: {
            Label("Study Now", systemImage: "play.fill")
                .foregroundColor(deck.dueCount > 0 ? .primary : .secondary)
        }
        .disabled(deck.totalCards == 0)
    }
    
    private var addCardButton: some View {
        Button {
            SoundService.shared.playButtonTap()
            showingCreateCard = true
        } label: {
            Label("Add Card", systemImage: "plus")
        }
    }
    
    private var suggestionsButton: some View {
        let suggestionCount = backgroundImageService.getSuggestions(for: deck).count
        
        return Button {
            SoundService.shared.playButtonTap()
            showingSuggestedCards = true
        } label: {
            Label("View suggestions (\(suggestionCount))", systemImage: "lightbulb")
                .foregroundColor(suggestionCount > 0 ? .primary : .secondary)
        }
        .disabled(suggestionCount == 0)
    }
    
    private var viewArchiveButton: some View {
        let archiveCount = deck.archivedCards.count
        
        return Button {
            SoundService.shared.playButtonTap()
            showingArchive = true
        } label: {
            Label("View Archive (\(archiveCount))", systemImage: "archivebox")
                .foregroundColor(archiveCount > 0 ? .primary : .secondary)
        }
        .disabled(archiveCount == 0)
    }
    
    private var cardsSection: some View {
        Section {
            cardsSectionHeader
            ForEach(sortedCards, id: \.objectID) { card in
                EnhancedCardRowView(card: card, viewContext: viewContext, deck: deck) {
                    deleteCard(card)
                }
            }
        }
    }
    
    private var cardsSectionHeader: some View {
        HStack {
            Text("Cards (\(deck.totalCards))")
                .font(.headline)
            
            Spacer()
            
            sortButton
        }
        .listRowInsets(EdgeInsets())
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }
    
    private var sortButton: some View {
        Button(action: {
            showingSortMenu = true
        }) {
            HStack(spacing: 4) {
                Image(systemName: currentSortOrder.systemImage)
                Text(currentSortOrder.displayName)
                Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .confirmationDialog("Sort Cards", isPresented: $showingSortMenu, titleVisibility: .visible) {
            sortMenuContent
        }
    }
    
    private var sortMenuContent: some View {
        Group {
            ForEach(CardSortOrder.allCases, id: \.rawValue) { sortOrder in
                Button(sortOrder.displayName) {
                    if currentSortOrder == sortOrder {
                        sortAscending.toggle()
                    } else {
                        currentSortOrder = sortOrder
                        sortAscending = false
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    
    
    @ViewBuilder
    private var archiveSection: some View {
        if !deck.archivedCards.isEmpty {
            Section {
                ForEach(deck.archivedCards, id: \.objectID) { card in
                    ArchivedCardRowView(card: card, viewContext: viewContext)
                }
            } header: {
                HStack {
                    Image(systemName: "archivebox")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Archive (\(deck.archivedCards.count))")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    
private var toastOverlay: some View {
        VStack {
            Spacer()
            // Toast functionality can be added back later if needed
        }
        .padding(.bottom, 100)
    }
    
    var sortedCards: [Card] {
        let cards = deck.activeCards.filter { !$0.isDeleted }
        
        let sorted = cards.sorted { card1, card2 in
            switch currentSortOrder {
            case .creationTime:
                return card1.createdAt < card2.createdAt
            case .lastSeenTime:
                let date1 = card1.lastReviewedAt ?? Date.distantPast
                let date2 = card2.lastReviewedAt ?? Date.distantPast
                return date1 < date2
            case .lastSuccessTime:
                // For last success, we need to check review history
                let lastSuccess1 = getLastSuccessDate(for: card1)
                let lastSuccess2 = getLastSuccessDate(for: card2)
                return lastSuccess1 < lastSuccess2
            case .nextDueTime:
                let due1 = card1.dueDate ?? Date.distantFuture
                let due2 = card2.dueDate ?? Date.distantFuture
                return due1 < due2
            }
        }
        
        return sortAscending ? sorted : sorted.reversed()
    }
    
    private func getLastSuccessDate(for card: Card) -> Date {
        // Get the most recent successful review (ease >= good)
        let successfulReviews = card.reviewHistoryArray.filter { $0.ease >= ReviewEase.good.rawValue }
        return successfulReviews.max(by: { $0.reviewDate < $1.reviewDate })?.reviewDate ?? Date.distantPast
    }
    
    
    private func deleteCard(_ card: Card) {
        // Archive card instead of deleting
        print("📦 Archiving card: \(card.front)")
        
        do {
            // Check if card is already deleted or archived
            guard !card.isDeleted && card.state != .archived else {
                print("⚠️ Card is already deleted or archived")
                return
            }
            
            // Archive the card
            card.setArchived(true, at: Date())
            
            // Play deletion sound
            SoundService.shared.playCardDeleted()
            
            // Save changes
            print("💾 Saving context")
            try viewContext.save()
            
            print("✅ Card archival successful")
            
            // Force deck refresh to update UI
            viewContext.refresh(deck, mergeChanges: true)
            
            print("🔄 Context refresh completed")
            
        } catch {
            print("❌ Error archiving card: \(error)")
            if let coreDataError = error as NSError? {
                print("Core Data Error Code: \(coreDataError.code)")
                print("Core Data Error Domain: \(coreDataError.domain)")
                print("Core Data Error UserInfo: \(coreDataError.userInfo)")
            }
            
            // Rollback the context on error
            viewContext.rollback()
        }
    }
    
    private func deleteCards(offsets: IndexSet) {
        let sortedCards = self.sortedCards
        let cardsToDelete = offsets.map { sortedCards[$0] }
        
        do {
            for card in cardsToDelete {
                // Delete associated review history
                if let reviewHistorySet = card.reviewHistory {
                    for case let history as ReviewHistory in reviewHistorySet {
                        viewContext.delete(history)
                    }
                }
                
                // Remove from deck relationship
                deck.removeFromCards(card)
                
                // Delete the card
                viewContext.delete(card)
            }
            
            try viewContext.save()
            
            // Force deck refresh
            viewContext.refresh(deck, mergeChanges: true)
            
        } catch {
            print("Error deleting cards: \(error.localizedDescription)")
            viewContext.rollback()
        }
    }
    
    // MARK: - Icon Management
    
    private func regenerateDeckIcon() {
        print("🎨 Regenerating deck icon for: \(deck.name) using OpenAI")
        SoundService.shared.playButtonTap()
        Task {
            if let newIcon = await DeckIconGenerationService.shared.generateIconForDeck(name: deck.name, description: deck.deckDescription) {
                await MainActor.run {
                    deck.setCustomIcon(newIcon)
                    try? viewContext.save()
                }
            }
        }
    }
    
    private func clearDeckIcon() {
        print("🗑️ Clearing custom icon for: \(deck.name)")
        SoundService.shared.playButtonTap()
        deck.clearCustomIcon()
        try? viewContext.save()
    }
}

struct DeckStatsView: View {
    @ObservedObject var deck: Deck
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                StatView(title: "Total", value: "\(deck.totalCards)", color: deck.deckColor)
                StatView(title: "New", value: "\(deck.newCount)", color: .green)
                StatView(title: "Due", value: "\(deck.dueCount)", color: .red)
            }
            
            if deck.totalCards > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Progress")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(Int(deck.completionPercentage * 100))%")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    
                    let progress = deck.completionPercentage
                    ProgressView(value: progress.isNaN ? 0 : progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: deck.deckColor))
                }
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}

struct StatView: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct EnhancedCardRowView: View {
    @ObservedObject var card: Card
    let viewContext: NSManagedObjectContext
    let deck: Deck
    let onDelete: () -> Void
    
    @State private var dragOffset = CGSize.zero
    @State private var isAnimating = false
    @State private var showingCardPreview = false
    @State private var viewRefreshTrigger = UUID()
    @StateObject private var backgroundImageService = BackgroundImageGenerationService.shared
    
    var body: some View {
        // Guard against deleted cards
        if card.isDeleted {
            EmptyView()
        } else {
            cardContent
        }
    }
    
    private var cardContent: some View {
        HStack(spacing: 0) {
            // Right swipe action (Mark as success)
            if dragOffset.width > 0 {
                HStack {
                    Button(action: markAsSuccess) {
                        VStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                            Text("Success")
                                .font(.caption2)
                        }
                        .foregroundColor(.white)
                    }
                    .frame(width: min(dragOffset.width, 80))
                    Spacer()
                }
                .frame(height: 80)
                .background(Color.green)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Card content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // Card image (small thumbnail)
                    ZStack {
                        if let customImage = card.customImage {
                            Image(uiImage: customImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.tertiarySystemGroupedBackground))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                )
                        }
                        
                    }
                    .id(viewRefreshTrigger) // Force refresh when trigger changes
                    .contextMenu {
                        Button {
                            regenerateCardImage()
                        } label: {
                            Label("Generate Image", systemImage: "photo.badge.plus")
                        }
                        
                        if card.hasCustomImage {
                            Button {
                                clearCardImage()
                            } label: {
                                Label("Remove Image", systemImage: "trash")
                            }
                        }
                    }
                    
                    HStack {
                        Text(card.front)
                            .font(.body)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                        
                        // Card type indicator
                        Image(systemName: card.cardType.icon)
                            .font(.caption)
                            .foregroundColor(card.cardType.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(card.cardType.color.opacity(0.1))
                            )
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        if card.isNew {
                            StatusBadge(text: "New", color: .green)
                        } else if card.isDue {
                            StatusBadge(text: "Due", color: .red)
                        } else if let dueDate = card.dueDate {
                            StatusBadge(text: formatDueDate(dueDate), color: .blue)
                        }
                        
                        Text("×\(card.reviewCount)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Progress indicator
                if !card.isNew {
                    HStack(spacing: 4) {
                        Text("Progress:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        ForEach(0..<5, id: \.self) { index in
                            Circle()
                                .fill(index < Int(card.repetitions) ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: 6, height: 6)
                        }
                        
                        Spacer()
                        
                        if let lastReview = card.lastReviewedAt {
                            Text("Last: \(formatDate(lastReview))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
            .offset(x: dragOffset.width)
            
            // Left swipe action (Delete)
            if dragOffset.width < 0 {
                HStack {
                    Spacer()
                    Button(action: onDelete) {
                        VStack {
                            Image(systemName: "archivebox.fill")
                                .font(.title2)
                            Text("Archive")
                                .font(.caption2)
                        }
                        .foregroundColor(.white)
                    }
                    .frame(width: min(-dragOffset.width, 80))
                }
                .frame(height: 80)
                .background(Color.red)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .gesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    // Don't allow gestures on deleted cards
                    guard !card.isDeleted else { return }
                    
                    // Only register horizontal swipe if horizontal movement is significantly more than vertical
                    let horizontalMovement = abs(value.translation.width)
                    let verticalMovement = abs(value.translation.height)
                    
                    // Require horizontal movement to be at least 2x vertical movement to activate swipe
                    // Only allow left swipe (negative width)
                    if horizontalMovement > verticalMovement * 2 && horizontalMovement > 30 && value.translation.width < 0 {
                        dragOffset = value.translation
                    } else if horizontalMovement <= 30 {
                        // Reset offset for small movements to allow scrolling
                        dragOffset = .zero
                    }
                }
                .onEnded { value in
                    // Don't allow gestures on deleted cards
                    guard !card.isDeleted else { return }
                    
                    let horizontalMovement = abs(value.translation.width)
                    let verticalMovement = abs(value.translation.height)
                    
                    // Only trigger swipe action if it's a deliberate horizontal gesture
                    if horizontalMovement > verticalMovement * 2 {
                        if value.translation.width < -100 {
                            // Left swipe threshold reached - archive action
                            withAnimation(.easeOut(duration: 0.3)) {
                                dragOffset = .zero
                            }
                            onDelete()
                        } else {
                            withAnimation(.easeOut(duration: 0.3)) {
                                dragOffset = .zero
                            }
                        }
                    } else {
                        // Reset for non-horizontal gestures
                        withAnimation(.easeOut(duration: 0.3)) {
                            dragOffset = .zero
                        }
                    }
                }
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragOffset)
        .onTapGesture {
            // Only allow tap when not dragging
            if dragOffset == .zero {
                showingCardPreview = true
            }
        }
        .sheet(isPresented: $showingCardPreview) {
            CardPreviewView(card: card, deck: deck)
        }
    }
    
    private func markAsSuccess() {
        // Check if card is still valid (not deleted)
        guard !card.isDeleted else { return }
        
        card.scheduleReview(ease: .good)
        
        do {
            try viewContext.save()
            // Force refresh of the deck to update counts
            viewContext.refresh(card.deck, mergeChanges: true)
        } catch {
            print("Error marking card as success: \(error)")
            viewContext.rollback()
        }
    }
    
    private func formatDueDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    // MARK: - Card Image Management
    
    private func regenerateCardImage() {
        print("🎨 Regenerating card image for: \(card.front)")
        SoundService.shared.playButtonTap()
        backgroundImageService.regenerateImage(for: card)
    }
    
    private func clearCardImage() {
        print("🗑️ Clearing custom image for card: \(card.front)")
        SoundService.shared.playButtonTap()
        
        // 1. Force the observed object to notify of changes
        card.objectWillChange.send()
        
        // 2. Clear the custom image from the card
        card.clearCustomImage()
        
        // 3. Save the change immediately
        do {
            try viewContext.save()
            
            // 4. Force refresh the entire managed object context
            viewContext.refreshAllObjects()
            
            // 5. Force refresh the specific card object
            viewContext.refresh(card, mergeChanges: true)
            
            // 6. Trigger view recreation by changing the UUID
            viewRefreshTrigger = UUID()
            
            print("🔄 Refreshed card row thumbnail for card: \(card.front)")
        } catch {
            print("❌ Failed to save after clearing card image: \(error)")
        }
    }
    
}

struct StatusBadge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color)
            .clipShape(Capsule())
    }
}

struct CardRowView: View {
    let card: Card
    
    var body: some View {
        HStack {
            Text(card.front)
                .font(.body)
                .lineLimit(1)
            
            Spacer()
            
            HStack(spacing: 8) {
                if card.isNew {
                    Text("New")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green)
                        .clipShape(Capsule())
                } else if card.isDue {
                    Text("Due")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .clipShape(Capsule())
                } else if let dueDate = card.dueDate {
                    Text("Due \(formatDueDate(dueDate))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("×\(card.reviewCount)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDueDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "today"
        } else if calendar.isDateInTomorrow(date) {
            return "tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

struct ArchivedCardRowView: View {
    @ObservedObject var card: Card
    let viewContext: NSManagedObjectContext
    
    @State private var dragOffset = CGSize.zero
    @State private var isDeleting = false
    
    var body: some View {
        // Guard against deleted cards or cards being deleted
        if card.isDeleted || isDeleting {
            EmptyView()
        } else {
            cardContent
        }
    }
    
    private var cardContent: some View {
        HStack(spacing: 0) {
            // Right swipe action (Restore)
            if dragOffset.width > 0 {
                HStack {
                    Button(action: restoreCard) {
                        VStack {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                .font(.title2)
                            Text("Restore")
                                .font(.caption2)
                        }
                        .foregroundColor(.white)
                    }
                    .frame(width: min(dragOffset.width, 80))
                    Spacer()
                }
                .frame(height: 60)
                .background(Color.green)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Archived card content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.front)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        Text(card.structuredContent != nil ? "\(card.cardType.displayName) (structured)" : "Legacy content")
                            .font(.caption)
                            .foregroundColor(Color(.tertiaryLabel))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Image(systemName: "archivebox.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let archivedDate = card.archivedAt {
                            Text(formatDate(archivedDate))
                                .font(.caption2)
                                .foregroundColor(Color(.tertiaryLabel))
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.tertiarySystemGroupedBackground))
                    .opacity(0.5)
            )
            .offset(x: dragOffset.width)
            
            // Left swipe action (Delete permanently)
            if dragOffset.width < 0 {
                HStack {
                    Spacer()
                    Button(action: deleteCard) {
                        VStack {
                            Image(systemName: "trash.fill")
                                .font(.title2)
                            Text("Delete")
                                .font(.caption2)
                        }
                        .foregroundColor(.white)
                    }
                    .frame(width: min(-dragOffset.width, 80))
                }
                .frame(height: 60)
                .background(Color.red)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Don't allow gestures on deleted or deleting cards
                    guard !card.isDeleted && !isDeleting else { return }
                    dragOffset = value.translation
                }
                .onEnded { value in
                    // Don't allow gestures on deleted or deleting cards
                    guard !card.isDeleted && !isDeleting else { return }
                    
                    if value.translation.width > 60 {
                        // Right swipe - restore
                        withAnimation(.easeOut(duration: 0.3)) {
                            dragOffset = .zero
                        }
                        restoreCard()
                    } else if value.translation.width < -60 {
                        // Left swipe - delete permanently
                        withAnimation(.easeOut(duration: 0.3)) {
                            dragOffset = .zero
                        }
                        deleteCard()
                    } else {
                        withAnimation(.easeOut(duration: 0.3)) {
                            dragOffset = .zero
                        }
                    }
                }
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragOffset)
    }
    
    private func restoreCard() {
        print("🔄 Restoring card: \(card.front)")
        card.setArchived(false, at: nil)
        
        do {
            try viewContext.save()
            // Force refresh of the deck to update UI
            viewContext.refresh(card.deck, mergeChanges: true)
            print("✅ Card restoration successful")
        } catch {
            print("❌ Error restoring card: \(error)")
            viewContext.rollback()
        }
    }
    
    private func deleteCard() {
        print("🗑️ Permanently deleting card: \(card.front)")
        
        // Guard against already deleted or deleting cards
        guard !card.isDeleted && !isDeleting else {
            print("⚠️ Card is already deleted or being deleted")
            return
        }
        
        // Immediately hide the card from UI
        isDeleting = true
        
        // Perform deletion asynchronously to avoid blocking UI updates
        Task {
            await performDeletion()
        }
    }
    
    private func performDeletion() async {
        await MainActor.run {
            do {
                let cardFront = self.card.front // Store for logging
                let deck = self.card.deck // Store deck reference before deletion
                
                // Core Data will handle cascading deletes for review history
                // Just delete the card - Core Data relationships will clean up automatically
                self.viewContext.delete(self.card)
                
                try self.viewContext.save()
                print("✅ Card '\(cardFront)' permanently deleted")
                
                // Force a refresh of the deck to ensure UI consistency
                self.viewContext.refresh(deck, mergeChanges: false)
            } catch {
                print("❌ Error deleting card permanently: \(error)")
                if let coreDataError = error as NSError? {
                    print("Core Data Error Code: \(coreDataError.code)")
                    print("Core Data Error Domain: \(coreDataError.domain)")
                    print("Core Data Error UserInfo: \(coreDataError.userInfo)")
                }
                self.viewContext.rollback()
                // Reset deleting state on error so user can try again
                self.isDeleting = false
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

struct IncompleteCardRowView: View {
    @ObservedObject var card: Card
    let viewContext: NSManagedObjectContext
    let deck: Deck
    
    @State private var showingEdit = false
    @State private var dragOffset = CGSize.zero
    @State private var isDeleting = false
    
    var body: some View {
        // Guard against deleted cards or cards being deleted
        if card.isDeleted || isDeleting {
            EmptyView()
        } else {
            cardContent
        }
    }
    
    private var cardContent: some View {
        HStack(spacing: 0) {
            // Card content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.front)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        
                        Text("Back content needed")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .italic()
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        
                        Text(formatDate(card.createdAt))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )
            .offset(x: dragOffset.width)
            
            // Left swipe action (Delete)
            if dragOffset.width < 0 {
                HStack {
                    Spacer()
                    Button(action: deleteCard) {
                        VStack {
                            Image(systemName: "trash.fill")
                                .font(.title2)
                            Text("Delete")
                                .font(.caption2)
                        }
                        .foregroundColor(.white)
                    }
                    .frame(width: min(-dragOffset.width, 80))
                }
                .frame(height: 60)
                .background(Color.red)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .gesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    // Don't allow gestures on deleted or deleting cards
                    guard !card.isDeleted && !isDeleting else { return }
                    
                    // Only register horizontal swipe if horizontal movement is significantly more than vertical
                    let horizontalMovement = abs(value.translation.width)
                    let verticalMovement = abs(value.translation.height)
                    
                    // Require horizontal movement to be at least 2x vertical movement to activate swipe
                    // Only allow left swipe (negative translation)
                    if horizontalMovement > verticalMovement * 2 && horizontalMovement > 30 && value.translation.width <= 0 {
                        dragOffset = value.translation
                    } else if horizontalMovement <= 30 {
                        // Reset offset for small movements to allow scrolling
                        dragOffset = .zero
                    }
                }
                .onEnded { value in
                    // Don't allow gestures on deleted or deleting cards
                    guard !card.isDeleted && !isDeleting else { return }
                    
                    let horizontalMovement = abs(value.translation.width)
                    let verticalMovement = abs(value.translation.height)
                    
                    // Only trigger swipe action if it's a deliberate horizontal gesture
                    if horizontalMovement > verticalMovement * 2 {
                        if value.translation.width < -100 {
                            // Left swipe threshold reached - higher threshold for more deliberate action
                            withAnimation(.easeOut(duration: 0.3)) {
                                dragOffset = .zero
                            }
                            deleteCard()
                        } else {
                            withAnimation(.easeOut(duration: 0.3)) {
                                dragOffset = .zero
                            }
                        }
                    } else {
                        // Reset for non-horizontal gestures
                        withAnimation(.easeOut(duration: 0.3)) {
                            dragOffset = .zero
                        }
                    }
                }
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragOffset)
        .onTapGesture {
            // Only allow tap when not dragging
            if dragOffset == .zero {
                showingEdit = true
            }
        }
.sheet(isPresented: $showingEdit) {
            FieldLevelCardEditView(card: card, deck: deck)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
    
    private func deleteCard() {
        print("🗑️ Deleting card: \(card.front)")
        
        // Guard against already deleted or deleting cards
        guard !card.isDeleted && !isDeleting else {
            print("⚠️ Card is already deleted or being deleted")
            return
        }
        
        // Immediately hide the card from UI
        isDeleting = true
        
        // Perform deletion asynchronously to avoid blocking UI updates
        Task {
            await performDeletion()
        }
    }
    
    private func performDeletion() async {
        await MainActor.run {
            do {
                let cardFront = self.card.front // Store for logging
                let deck = self.card.deck // Store deck reference before deletion
                
                
                // Core Data will handle cascading deletes for review history
                // Just delete the card - Core Data relationships will clean up automatically
                self.viewContext.delete(self.card)
                
                try self.viewContext.save()
                print("✅ Card '\(cardFront)' deleted")
                
                // Force a refresh of the deck to ensure UI consistency
                self.viewContext.refresh(deck, mergeChanges: false)
            } catch {
                print("❌ Error deleting card: \(error)")
                if let coreDataError = error as NSError? {
                    print("Core Data Error Code: \(coreDataError.code)")
                    print("Core Data Error Domain: \(coreDataError.domain)")
                    print("Core Data Error UserInfo: \(coreDataError.userInfo)")
                }
                self.viewContext.rollback()
                // Reset deleting state on error so user can try again
                self.isDeleting = false
            }
        }
    }
}

// MARK: - Helper Functions


#Preview {
    let context = PersistenceController.preview.container.viewContext
    let deck = Deck(context: context)
    deck.name = "Sample Deck"
    deck.createdAt = Date()
    deck.id = UUID()
    
    return NavigationView {
        DeckDetailView(deck: deck)
    }
    .environment(\.managedObjectContext, context)
}