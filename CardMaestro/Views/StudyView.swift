import SwiftUI
import CoreData

struct StudyView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let deck: Deck
    @StateObject private var srsService: SpacedRepetitionService
    @StateObject private var streakService: StreakService
    
    @State private var studyCards: [Card] = []
    @State private var currentCardIndex = 0
    @State private var showingBack = false
    @State private var sessionStartTime = Date()
    @State private var cardStartTime = Date()
    @State private var cardsStudied = 0
    @State private var studySession: StudySession?
    @State private var sessionStats = [ReviewEase: Int]()
    @State private var reviewedCards: [Card] = []
    
    // Computed property to get unique card images from reviewed cards
    private var uniqueCardImages: [UIImage] {
        var seenImages: Set<Data> = []
        var uniqueImages: [UIImage] = []
        
        for card in reviewedCards {
            if let image = card.customImage,
               let imageData = image.pngData(),
               !seenImages.contains(imageData) {
                seenImages.insert(imageData)
                uniqueImages.append(image)
            }
        }
        
        return uniqueImages
    }
    
    // 100 motivational messages for session completion
    private var motivationalMessages: [String] {
        [
            "Knowledge is power! 💪",
            "Your mind just got stronger! 🧠",
            "Every card mastered is progress made! ✨",
            "You're building brilliance, one card at a time! 🌟",
            "Learning never felt so good! 🎯",
            "Your dedication is paying off! 🏆",
            "Another step closer to mastery! 🎓",
            "You're on fire today! 🔥",
            "Excellence in motion! ⚡",
            "Your brain thanks you! 🙏",
            "Consistency creates champions! 👑",
            "You're unstoppable! 🚀",
            "Knowledge collected, wisdom gained! 📚",
            "Your future self is proud! ✨",
            "Progress over perfection! 📈",
            "You're investing in yourself! 💎",
            "Small steps, big results! 👣",
            "Your commitment shines through! ✨",
            "Learning is your superpower! 🦸‍♂️",
            "You're writing your success story! 📖",
            "Memory muscles getting stronger! 💪",
            "You're a learning machine! 🤖",
            "Knowledge is your currency! 💰",
            "You're becoming unstoppable! ⚡",
            "Your persistence pays! 🎯",
            "Brain training complete! 🏋️‍♀️",
            "You're leveling up! 🎮",
            "Excellence is your habit! ⭐",
            "You're creating your future! 🌈",
            "Your mindset is magnetic! 🧲",
            "Learning is your lifestyle! 🎪",
            "You're a knowledge ninja! 🥷",
            "Your potential is unlimited! ∞",
            "You're building mental strength! 💪",
            "Success is in your DNA! 🧬",
            "You're a study superstar! ⭐",
            "Your focus is phenomenal! 🎯",
            "You're creating magic! ✨",
            "Your growth is guaranteed! 📊",
            "You're absolutely crushing it! 💥",
            "Learning looks good on you! 😎",
            "You're a retention rockstar! 🎸",
            "Your discipline is inspiring! 🌟",
            "You're making it happen! 🎉",
            "Your mind is expanding! 🌌",
            "You're a knowledge collector! 🏆",
            "Your effort equals results! ⚖️",
            "You're becoming brilliant! 💡",
            "Your journey continues! 🛤️",
            "You're a learning legend! 👑",
            "Your dedication is admirable! 🙌",
            "You're writing history! 📜",
            "Your progress is powerful! ⚡",
            "You're achieving greatness! 🏆",
            "Your mind is your weapon! ⚔️",
            "You're a wisdom warrior! 🛡️",
            "Your consistency counts! ⏰",
            "You're building your empire! 🏰",
            "Your future is bright! ☀️",
            "You're a memory master! 🧙‍♂️",
            "Your growth is gorgeous! 🌸",
            "You're absolutely amazing! 🌟",
            "Your learning is legendary! 📚",
            "You're creating excellence! 💎",
            "Your mind is magnificent! 🧠",
            "You're a study sensation! 🎭",
            "Your progress is priceless! 💰",
            "You're becoming unstoppable! 🚄",
            "Your knowledge is your kingdom! 👑",
            "You're a brain-building boss! 💼",
            "Your effort is everything! 🌟",
            "You're mastering mastery! 🎯",
            "Your learning is luminous! ✨",
            "You're a cognitive champion! 🏆",
            "Your growth is glorious! 🌅",
            "You're absolutely brilliant! 💡",
            "Your mind is a masterpiece! 🎨",
            "You're a learning luminary! 🌟",
            "Your progress is phenomenal! 📈",
            "You're creating your legacy! 🏛️",
            "Your knowledge is your strength! 💪",
            "You're a study superhero! 🦸‍♀️",
            "Your dedication is dazzling! ✨",
            "You're building your brilliance! 🏗️",
            "Your mind is marvelous! 🎪",
            "You're a learning lighthouse! 🗼",
            "Your growth is guaranteed! ✅",
            "You're absolutely incredible! 🌟",
            "Your journey is inspiring! 🗺️",
            "You're a knowledge knight! ⚔️",
            "Your progress is perfect! 👌",
            "You're creating your destiny! 🔮",
            "Your mind is your magic! ✨",
            "You're a retention ruler! 👑",
            "Your effort is extraordinary! 🚀",
            "You're building your brand! 🏷️",
            "Your learning is life-changing! 🔄",
            "You're a study star! ⭐",
            "Your dedication is divine! 🙏",
            "You're creating cognitive gold! 🥇",
            "Your mind is mighty! ⚡",
            "You're a learning lion! 🦁",
            "Your progress is pure power! 💥",
            "You're absolutely awesome! 🎉",
            "Your knowledge is your crown! 👑",
            "You're a brain-building beast! 🦁"
        ]
    }
    
    init(deck: Deck, viewContext: NSManagedObjectContext) {
        self.deck = deck
        self._srsService = StateObject(wrappedValue: SpacedRepetitionService(viewContext: viewContext))
        self._streakService = StateObject(wrappedValue: StreakService(viewContext: viewContext))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if studyCards.isEmpty {
                    emptyStateView
                } else if currentCardIndex < studyCards.count {
                    studyCardView
                } else {
                    completionView
                }
            }
            .background(
                LinearGradient(
                    colors: [
                        deck.deckColor.opacity(0.08),
                        deck.deckColor.opacity(0.02),
                        Color(.systemBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle(deck.name)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                // Only show Done button when not on completion screen
                if currentCardIndex < studyCards.count {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") {
                            handleSessionEnd()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Only show counter when not on completion screen
                    if currentCardIndex < studyCards.count {
                        Text("\(currentCardIndex + 1)/\(studyCards.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                #else
                // Only show Done button when not on completion screen
                if currentCardIndex < studyCards.count {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            handleSessionEnd()
                        }
                    }
                }
                
                ToolbarItem(placement: .status) {
                    // Only show counter when not on completion screen
                    if currentCardIndex < studyCards.count {
                        Text("\(currentCardIndex + 1)/\(studyCards.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                #endif
            }
        }
        .onAppear {
            loadStudyCards()
            if !studyCards.isEmpty {
                SoundService.shared.playStudyStart()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("No cards to study")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Great job! All cards in this deck are up to date.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
    
    private var studyCardView: some View {
        let currentCard = studyCards[currentCardIndex]
        
        return VStack(spacing: 16) {
            CardView(
                card: currentCard,
                showingBack: $showingBack
            )
            .id(currentCardIndex) // Force view refresh when card changes
            
            Spacer(minLength: 8)
            
            if showingBack {
                reviewButtonsView
            } else {
                Button("Show Answer") {
                    SoundService.shared.playCardFlip()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingBack = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .font(.headline)
                .tint(deck.deckColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var reviewButtonsView: some View {
        HStack(spacing: 8) {
            ForEach(ReviewEase.allCases, id: \.rawValue) { ease in
                Button(action: {
                    reviewCard(ease: ease)
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: iconForEase(ease))
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        Text(ease.title)
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(backgroundColorForEase(ease))
                    )
                    .foregroundColor(textColorForEase(ease))
                    .shadow(color: shadowColorForEase(ease), radius: 2, x: 0, y: 1)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    private var completionView: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    deck.deckColor.opacity(0.15),
                    deck.deckColor.opacity(0.05),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Flying card animations (on top layer) - use each unique icon only once
            ForEach(Array(uniqueCardImages.prefix(5).enumerated()), id: \.offset) { index, image in
                FlyingCardView(image: image, index: index)
            }
            .zIndex(100) // Ensure cards fly on top
            
ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 30) {
                    Spacer(minLength: 40)
                    
                    // Animated trophy
                    VStack(spacing: 16) {
                        AnimatedTrophyView()
                        
                        Text("Session Complete!")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text(motivationalMessages.randomElement() ?? "Great work! 🎉")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Session summary card
                    VStack(spacing: 20) {
                        HStack(spacing: 30) {
                            StatisticView(
                                title: "Cards Studied",
                                value: "\(cardsStudied)",
                                color: deck.deckColor
                            )
                            
                            let duration = Date().timeIntervalSince(sessionStartTime)
                            StatisticView(
                                title: "Session Time",
                                value: formatDuration(duration),
                                color: .blue
                            )
                        }
                        
                        // Review breakdown
                        if !sessionStats.isEmpty {
                            VStack(spacing: 12) {
                                Text("Review Breakdown")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                                    ForEach(ReviewEase.allCases, id: \.rawValue) { ease in
                                        if let count = sessionStats[ease], count > 0 {
                                            SequentialReviewStatView(
                                                ease: ease, 
                                                count: count,
                                                animationDelay: Double(ease.rawValue) * 1.5 + 2.0 // At least 1.5s between each statistic
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.secondarySystemGroupedBackground))
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    )
                    
                    // Continue studying or finish session button
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Finish Session")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(deck.deckColor)
                            )
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
        }
        .onAppear {
            // End the study session when completion view appears
            endStudySession()
            
            // Additional haptic feedback on appear
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.success)
            }
        }
    }
    
    private func loadStudyCards() {
        studyCards = srsService.getStudyCards(from: deck)
        sessionStartTime = Date()
        cardStartTime = Date()
        
        if !studyCards.isEmpty {
            startStudySession()
        }
    }
    
    private func reviewCard(ease: ReviewEase) {
        let currentCard = studyCards[currentCardIndex]
        let timeSpent = Date().timeIntervalSince(cardStartTime)
        
        // Play sound based on review ease
        switch ease {
        case .again:
            SoundService.shared.playWrongAnswer()
        case .hard:
            SoundService.shared.playHardAnswer()
        case .good:
            SoundService.shared.playCorrectAnswer()
        case .easy:
            SoundService.shared.playEasyAnswer()
        }
        
        srsService.reviewCard(currentCard, ease: ease, timeSpent: timeSpent)
        cardsStudied += 1
        
        // Track session statistics and reviewed cards
        sessionStats[ease, default: 0] += 1
        if !reviewedCards.contains(where: { $0.objectID == currentCard.objectID }) {
            reviewedCards.append(currentCard)
        }
        
        // Check if session is complete
        if currentCardIndex + 1 >= studyCards.count {
            // Enhanced completion feedback
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Enhanced haptics
                let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                impactFeedback.impactOccurred()
                
                // Enhanced sound
                SoundService.shared.playSessionComplete()
            }
        }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            showingBack = false
            currentCardIndex += 1
        }
        
        cardStartTime = Date()
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func colorFromString(_ colorName: String) -> Color {
        switch colorName.lowercased() {
        case "red": return .red
        case "orange": return .orange
        case "green": return .green
        case "blue": return .blue
        default: return .primary
        }
    }
    
    private func iconForEase(_ ease: ReviewEase) -> String {
        switch ease {
        case .again: return "xmark.circle.fill"
        case .hard: return "exclamationmark.triangle.fill"
        case .good: return "checkmark.circle.fill"
        case .easy: return "star.circle.fill"
        }
    }
    
    private func backgroundColorForEase(_ ease: ReviewEase) -> Color {
        switch ease {
        case .again: return Color.red.opacity(0.1)
        case .hard: return Color.orange.opacity(0.1)
        case .good: return Color.green.opacity(0.1)
        case .easy: return Color.blue.opacity(0.1)
        }
    }
    
    private func textColorForEase(_ ease: ReviewEase) -> Color {
        switch ease {
        case .again: return .red
        case .hard: return .orange
        case .good: return .green
        case .easy: return .blue
        }
    }
    
    private func shadowColorForEase(_ ease: ReviewEase) -> Color {
        switch ease {
        case .again: return Color.red.opacity(0.3)
        case .hard: return Color.orange.opacity(0.3)
        case .good: return Color.green.opacity(0.3)
        case .easy: return Color.blue.opacity(0.3)
        }
    }
    
    private func startStudySession() {
        let session = StudySession(context: viewContext)
        session.id = UUID()
        session.startTime = sessionStartTime
        session.cardsReviewed = 0
        studySession = session
        
        do {
            try viewContext.save()
        } catch {
            print("Error starting study session: \(error)")
        }
    }
    
    private func handleSessionEnd() {
        // Show celebration if user completed all cards or at least 3 cards
        if cardsStudied >= 3 || currentCardIndex >= studyCards.count {
            // Force transition to completion view
            withAnimation(.easeInOut(duration: 0.3)) {
                currentCardIndex = studyCards.count
            }
        } else {
            // Directly end session and dismiss
            endStudySession()
            dismiss()
        }
    }
    
    private func endStudySession() {
        guard let session = studySession else { return }
        
        session.endTime = Date()
        session.cardsReviewed = Int32(cardsStudied)
        
        if cardsStudied > 0 {
            streakService.recordStudySession()
        }
        
        do {
            try viewContext.save()
        } catch {
            print("Error ending study session: \(error)")
        }
    }
}

struct CardView: View {
    let card: Card
    @Binding var showingBack: Bool
    @State private var flipDegrees = 0.0
    
    var body: some View {
        ZStack {
            // Front of card
            StructuredCardView(
                card: card,
                side: .front,
                showFlipIcon: true
            )
            .opacity(flipDegrees > 90 ? 0 : 1)
            .rotation3DEffect(
                .degrees(flipDegrees),
                axis: (x: 0, y: 1, z: 0)
            )
            
            // Back of card
            StructuredCardView(
                card: card,
                side: .back,
                showFlipIcon: false
            )
            .opacity(flipDegrees > 90 ? 1 : 0)
            .rotation3DEffect(
                .degrees(flipDegrees - 180),
                axis: (x: 0, y: 1, z: 0)
            )
        }
        .frame(minHeight: CardConstants.Dimensions.totalContainerHeight)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, CardConstants.Dimensions.horizontalPadding)
        .onTapGesture {
            SoundService.shared.playCardFlip()
            withAnimation(.easeInOut(duration: 0.6)) {
                showingBack.toggle()
            }
        }
        .onChange(of: showingBack) { _, newValue in
            withAnimation(.easeInOut(duration: 0.6)) {
                flipDegrees = newValue ? 180 : 0
            }
        }
    }
}

// MARK: - Supporting Views for Enhanced Completion

struct FlyingCardView: View {
    let image: UIImage
    let index: Int
    @State private var position = CGPoint.zero
    @State private var opacity: Double = 1.0
    
    var body: some View {
        Image(uiImage: image)
            .resizable()
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(opacity)
            .position(position)
            .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
            .onAppear {
                setupRandomAnimation()
            }
    }
    
    private func setupRandomAnimation() {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        // Random delay up to 100ms before previous icon (0-100ms for each subsequent icon)
        let maxDelay = Double(index) * 0.1
        let actualDelay = Double.random(in: 0...maxDelay)
        
        // Random starting position in bottom 1/4 (left or right side)
        let startFromLeft = Bool.random()
        let startX = startFromLeft ? -25 : screenWidth + 25
        let startY = screenHeight * 0.75 + Double.random(in: 0...(screenHeight * 0.25))
        
        // Random ending position on opposite side in top 1/4
        let endX = startFromLeft ? screenWidth + 25 : -25
        let endY = Double.random(in: 0...(screenHeight * 0.25))
        
        // Random flight duration between 6.0 and 9.0 seconds (2x slower than previous)
        let duration = Double.random(in: 6.0...9.0)
        
        // Set initial position and make icons visible from start
        position = CGPoint(x: startX, y: startY)
        opacity = 1.0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + actualDelay) {
            withAnimation(.easeInOut(duration: duration)) {
                // Create smooth arc by using control points - no rotation
                position = CGPoint(x: endX, y: endY)
            }
        }
    }
}

struct AnimatedTrophyView: View {
    @State private var rotationAngle: Double = 0
    @State private var scaleEffect: Double = 0.1
    @State private var selectedTrophy: String = ""
    @State private var confettiTrigger = false
    @State private var showRays = false
    @State private var rayRotation: Double = 0
    
    private let trophyTypes = [
        // Classic Trophies
        "trophy.fill", "crown.fill", "medal.fill",
        // Special Achievement Symbols
        "star.circle.fill", "rosette", "checkmark.seal.fill"
    ]
    
    var body: some View {
        ZStack {
            // Background rays of light
            if showRays {
                ForEach(0..<8, id: \.self) { index in
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [Color.yellow.opacity(0.6), Color.clear],
                            startPoint: .center,
                            endPoint: .trailing
                        ))
                        .frame(width: 150, height: 3)
                        .offset(x: 75)
                        .rotationEffect(.degrees(Double(index) * 45 + rayRotation))
                        .animation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true), value: rayRotation)
                }
            }
            
            
            // Confetti particles
            ForEach(0..<20, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill([Color.red, Color.blue, Color.green, Color.yellow, Color.purple].randomElement() ?? Color.red)
                    .frame(width: 8, height: 8)
                    .offset(
                        x: Double.random(in: -200...200),
                        y: confettiTrigger ? 300 : -50
                    )
                    .opacity(confettiTrigger ? 0 : 1)
                    .animation(
                        .easeInOut(duration: Double.random(in: 2.0...3.0))
                        .delay(Double(index) * 0.1),
                        value: confettiTrigger
                    )
            }
            
            // Main trophy icon
            Image(systemName: selectedTrophy.isEmpty ? "trophy.fill" : selectedTrophy)
                .font(.system(size: 100))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange, .red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(scaleEffect)
                .rotationEffect(.degrees(rotationAngle))
                .shadow(color: Color.orange.opacity(0.8), radius: 20, x: 0, y: 8)
                .overlay {
                    // Inner glow effect
                    Image(systemName: selectedTrophy.isEmpty ? "trophy.fill" : selectedTrophy)
                        .font(.system(size: 100))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white.opacity(0.8), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .scaleEffect(scaleEffect * 0.8)
                        .rotationEffect(.degrees(rotationAngle))
                        .blendMode(.overlay)
                }
        }
        .onAppear {
            // Select random trophy
            selectedTrophy = trophyTypes.randomElement() ?? "trophy.fill"
            
            // 4-second main animation sequence
            // 1. Dramatic entrance (0.0 - 1.5s)
            withAnimation(.spring(response: 1.0, dampingFraction: 0.6).delay(0.2)) {
                scaleEffect = 1.3
            }
            
            // 2. Settle to final size (1.5 - 2.5s)
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(1.5)) {
                scaleEffect = 1.0
            }
            
            // 3. Gentle rotation throughout (0.0 - 4.0s)
            withAnimation(.linear(duration: 4.0)) {
                rotationAngle = 15
            }
            
            // 4. Background rays appear (0.5s)
            withAnimation(.easeIn(duration: 0.5).delay(0.5)) {
                showRays = true
                rayRotation = 30
            }
            
            
            // 6. Confetti explosion (1.5s)
            withAnimation(.easeOut(duration: 0.1).delay(1.5)) {
                confettiTrigger = true
            }
            
            // 7. Final celebration pulse (3.0 - 4.0s)
            withAnimation(.easeInOut(duration: 0.4).delay(3.0)) {
                scaleEffect = 1.1
            }
            withAnimation(.easeInOut(duration: 0.4).delay(3.4)) {
                scaleEffect = 1.0
            }
        }
    }
}

struct StatisticView: View {
    let title: String
    let value: String
    let color: Color
    @State private var animateValue = false
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .scaleEffect(animateValue ? 1.1 : 1.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: animateValue)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.medium)
        }
        .onAppear {
            animateValue = true
        }
    }
}

struct SequentialReviewStatView: View {
    let ease: ReviewEase
    let count: Int
    let animationDelay: Double
    
    @State private var isVisible = false
    @State private var animateCount = false
    @State private var currentDisplayCount = 0
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconForEase(ease))
                .font(.title3)
                .foregroundColor(colorForEase(ease))
                .frame(width: 24)
                .scaleEffect(isVisible ? 1.0 : 0.3)
                .opacity(isVisible ? 1.0 : 0.0)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(ease.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .opacity(isVisible ? 1.0 : 0.0)
                
                Text("\(currentDisplayCount) cards")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .opacity(isVisible ? 1.0 : 0.0)
            }
            
            Spacer()
            
            Text("\(currentDisplayCount)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(colorForEase(ease))
                .scaleEffect(animateCount ? 1.2 : 0.5)
                .opacity(isVisible ? 1.0 : 0.0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(colorForEase(ease).opacity(isVisible ? 0.1 : 0.0))
                .scaleEffect(isVisible ? 1.0 : 0.8)
        )
        .onAppear {
            // Delayed reveal animation
            DispatchQueue.main.asyncAfter(deadline: .now() + animationDelay) {
                // Play reveal sound
                playStatRevealSound()
                
                // Slide in animation
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isVisible = true
                }
                
                // Count up animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    animateCountUp()
                }
            }
        }
    }
    
    private func animateCountUp() {
        let duration = 0.8
        let steps = max(count, 10) // At least 10 steps for smooth animation
        let stepDuration = duration / Double(steps)
        
        for step in 1...count {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(step)) {
                withAnimation(.easeOut(duration: 0.1)) {
                    currentDisplayCount = step
                    animateCount = true
                }
                
                // Play tick sound for each count
                if step < count {
                    SoundService.shared.playStatTick()
                } else {
                    // Final reveal sound
                    SoundService.shared.playStatComplete()
                    
                    // Final emphasis animation
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        animateCount = false
                    }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6).delay(0.1)) {
                        animateCount = true
                    }
                }
            }
        }
    }
    
    private func playStatRevealSound() {
        switch ease {
        case .again:
            SoundService.shared.playWrongAnswer()
        case .hard:
            SoundService.shared.playHardAnswer()
        case .good:
            SoundService.shared.playCorrectAnswer()
        case .easy:
            SoundService.shared.playEasyAnswer()
        }
    }
    
    private func iconForEase(_ ease: ReviewEase) -> String {
        switch ease {
        case .again: return "xmark.circle.fill"
        case .hard: return "exclamationmark.triangle.fill"
        case .good: return "checkmark.circle.fill"
        case .easy: return "star.circle.fill"
        }
    }
    
    private func colorForEase(_ ease: ReviewEase) -> Color {
        switch ease {
        case .again: return .red
        case .hard: return .orange
        case .good: return .green
        case .easy: return .blue
        }
    }
}


#Preview {
    let context = PersistenceController.preview.container.viewContext
    let deck = Deck(context: context)
    deck.name = "Sample Deck"
    deck.createdAt = Date()
    deck.id = UUID()
    
    return StudyView(deck: deck, viewContext: context)
        .environment(\.managedObjectContext, context)
}