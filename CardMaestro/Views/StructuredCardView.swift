import SwiftUI
import CoreData

/// Helper functions for dynamic typography
struct DynamicTypography {
    /// Calculate font size for primary content based on word count
    static func primarySize(for content: String, cardType: CardType) -> CGFloat {
        let wordCount = content.split(separator: " ").count
        
        switch cardType {
        case .vocabulary, .conjugation:
            switch wordCount {
            case 1: return 48
            case 2...3: return 36
            case 4...6: return 28
            default: return 24
            }
        case .fact:
            // Facts are typically longer, use smaller base sizes
            switch wordCount {
            case 1: return 32
            case 2...3: return 28
            case 4...6: return 24
            default: return 20
            }
        }
    }
    
    /// Calculate font size for secondary content
    static func secondarySize(for content: String) -> CGFloat {
        let wordCount = content.split(separator: " ").count
        
        switch wordCount {
        case 1...3: return 22
        case 4...8: return 20
        default: return 18
        }
    }
    
    /// Tertiary content always uses fixed size
    static let tertiarySize: CGFloat = 14
}

/// Main card view that renders content based on card type and structured JSON content
struct StructuredCardView: View {
    let card: Card
    let side: CardSide
    let showFlipIcon: Bool
    @Environment(\.colorScheme) var colorScheme
    
    init(card: Card, side: CardSide, showFlipIcon: Bool = true) {
        self.card = card
        self.side = side
        self.showFlipIcon = showFlipIcon
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Card background
                cardBackground
                
                cardContentLayout
                
                // Image overlay (positioned based on card type)
                imageOverlay
            }
        }
        .frame(height: CardConstants.Dimensions.cardContentHeight)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .cardShadow(cardType: card.cardType)
    }
    
    @ViewBuilder
    private var cardContentLayout: some View {
        VStack(spacing: 0) {
            headerSection
            
            ScrollView(.vertical, showsIndicators: true) {
                contentSection
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .clipped() // Ensure content doesn't overflow into image area
            
            Spacer(minLength: 20)
        }
        .overlay(alignment: .center) {
            imageOverlay
        }
    }
    
    // MARK: - Background
    
    private var cardBackground: some View {
        OptimizedTexturedCardBackground(cardType: card.cardType)
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                // Front phrase overlay on back view (top left)
                if side == .back {
                    CardFrontOverlay(frontText: card.front, cardType: card.cardType)
                }
                
                Spacer()
                
                // Type icon (top right)
                HStack(spacing: 8) {
                    if showFlipIcon {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(card.cardType.color.opacity(0.6))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(8)
                            .liquidGlassIcon(baseColor: card.cardType.color)
                    }
                    
                    Image(systemName: card.cardType.icon)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(card.cardType.color)
                        .padding(8)
                        .liquidGlassIcon(baseColor: card.cardType.color)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var contentSection: some View {
        switch (card.cardType, side) {
        case (.vocabulary, .front):
            VocabularyFrontView(content: card.front)
            
        case (.vocabulary, .back):
            if let content = card.vocabularyContent {
                VocabularyBackView(content: content)
            } else {
                MissingContentView(cardType: card.cardType)
            }
            
        case (.conjugation, .front):
            ConjugationFrontView(content: card.front)
            
        case (.conjugation, .back):
            if let content = card.conjugationContent {
                ConjugationBackView(content: content)
            } else {
                MissingContentView(cardType: card.cardType)
            }
            
        case (.fact, .front):
            FactFrontView(content: card.front)
            
        case (.fact, .back):
            if let content = card.factContent {
                FactBackView(content: content)
            } else {
                MissingContentView(cardType: card.cardType)
            }
        }
    }
    
    // MARK: - Image Overlay
    
    @ViewBuilder
    private var imageOverlay: some View {
        if side == .back, let customImage = card.customImage {
            switch card.cardType {
            case .vocabulary, .fact:
                // Large image in center for vocabulary and fact cards
                VStack {
                    Spacer()
                    Image(uiImage: customImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 200, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .liquidGlassLargeImage(cornerRadius: 12)
                    Spacer()
                }
                
            case .conjugation:
                // Larger image in top right below type icon for conjugation cards
                VStack {
                    HStack {
                        Spacer()
                        Image(uiImage: customImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 78, height: 78) // 30% bigger than 60x60
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .liquidGlassSmallImage(cornerRadius: 10)
                            .padding(.top, 50) // Position below type icon
                            .padding(.trailing, 20)
                    }
                    Spacer()
                }
            }
        }
    }
    
}

enum CardSide {
    case front, back
}

// MARK: - Front Views

struct VocabularyFrontView: View {
    let content: String
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Text(content)
                .font(.system(size: DynamicTypography.primarySize(for: content, cardType: .vocabulary)))
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .lineLimit(nil)
                .minimumScaleFactor(0.7)
                .letterpress()
            
            Spacer()
        }
    }
}

struct ConjugationFrontView: View {
    let content: String
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Text(content)
                .font(.system(size: min(DynamicTypography.primarySize(for: content, cardType: .conjugation), 40)))
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .lineLimit(nil)
                .minimumScaleFactor(0.7)
                .letterpress()
            
            Spacer()
        }
    }
}

struct FactFrontView: View {
    let content: String
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Text(content)
                .font(.system(size: DynamicTypography.primarySize(for: content, cardType: .fact)))
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .lineLimit(nil)
                .minimumScaleFactor(0.7)
                .letterpress()
            
            Spacer()
        }
    }
}

// MARK: - Back Views

struct VocabularyBackView: View {
    let content: VocabularyContent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Primary meaning with script font
            Text(content.meaning)
                .font(.custom("Georgia", size: min(DynamicTypography.primarySize(for: content.meaning, cardType: .vocabulary), 36)))
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(nil)
                .minimumScaleFactor(0.8)
                .italic()
                .letterpress()
                .padding(.bottom, 20)
            
            // Flexible space that accounts for image
            Spacer(minLength: 180) // Space for 150px image + margins
            
            // Optional detail firmly positioned at bottom
            if let detail = content.detail, !detail.isEmpty {
                VStack(spacing: 0) {
                    Spacer(minLength: 20) // Minimum spacing from image
                    
                    Text(detail)
                        .font(.system(size: DynamicTypography.secondarySize(for: detail)))
                        .fontWeight(.regular)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.8)
                        .padding(.top, 16)
                }
            }
        }
    }
}

struct ConjugationBackView: View {
    let content: ConjugationContent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // English meaning with script font and space for larger image
            HStack(alignment: .bottom) { // Changed to align bottom with image
                Text(content.meaning)
                    .font(.custom("Georgia", size: min(DynamicTypography.secondarySize(for: content.meaning), 24)))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .italic()
                    .letterpress()
                
                Spacer(minLength: 98) // Space for 78px image + margins (30% bigger)
            }
            .padding(.top, 50) // Extra space for image positioning
            
            // Conjugation table with improved styling - no background
            if !content.conjugations.isEmpty {
                VStack(spacing: 10) {
                    ForEach(Array(content.conjugations.enumerated()), id: \.offset) { index, row in
                        if row.count >= 2 {
                            HStack(spacing: 20) {
                                Text(row[0]) // Pronoun/subject - smaller
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundColor(pronounColor)
                                    .frame(width: 80, alignment: .leading)
                                
                                Text(row[1]) // Conjugated form - bigger and more prominent
                                    .font(.system(size: 18, design: .monospaced))
                                    .fontWeight(.semibold)
                                    .foregroundColor(conjugatedWordColor)
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                        }
                    }
                }
            }
        }
    }
    
    @Environment(\.colorScheme) var colorScheme
    
    private var pronounColor: Color {
        colorScheme == .dark ? .gray : .secondary
    }
    
    private var conjugatedWordColor: Color {
        colorScheme == .dark ? .white : .black
    }
}

struct FactBackView: View {
    let content: FactContent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Primary answer with script font
            Text(content.answer)
                .font(.custom("Georgia", size: min(DynamicTypography.primarySize(for: content.answer, cardType: .fact), 32)))
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(nil)
                .minimumScaleFactor(0.8)
                .italic()
                .letterpress()
                .padding(.bottom, 20)
            
            // Flexible space that accounts for image
            Spacer(minLength: 180) // Space for 150px image + margins
            
            // Optional detail firmly positioned at bottom
            if let detail = content.detail, !detail.isEmpty {
                VStack(spacing: 0) {
                    Spacer(minLength: 20) // Minimum spacing from image
                    
                    Text(detail)
                        .font(.system(size: DynamicTypography.secondarySize(for: detail)))
                        .fontWeight(.regular)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.8)
                        .padding(.top, 16)
                }
            }
        }
    }
}

// MARK: - Missing Content View

struct MissingContentView: View {
    let cardType: CardType
    
    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundColor(.orange)
                .padding(8)
                .liquidGlassIcon(baseColor: .orange)
            
            Text("Content Missing")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("This \(cardType.displayName.lowercased()) card needs to be regenerated with structured content.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding()
    }
}

// MARK: - Shared Components

/// Shared card background with paper texture and layered shadows
struct CardBackgroundView: View {
    let cardType: CardType
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                // Paper-like texture background
                LinearGradient(
                    colors: [
                        paperColor.opacity(0.95),
                        paperColor.opacity(0.85),
                        paperColor.opacity(0.95)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                // Subtle card type accent
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                cardType.color.opacity(0.3),
                                cardType.color.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
    
    private var paperColor: Color {
        colorScheme == .dark ? Color(red: 0.3, green: 0.2, blue: 0.1) : Color(red: 0.98, green: 0.96, blue: 0.9)
    }
}

/// Front phrase overlay for back side of cards
struct CardFrontOverlay: View {
    let frontText: String
    let cardType: CardType
    
    var body: some View {
        HStack {
            Text(frontText)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(textColor)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(backgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(cardType.color.opacity(0.4), lineWidth: 1.0)
                        )
                )
        }
    }
    
    @Environment(\.colorScheme) var colorScheme
    
    private var textColor: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark 
            ? Color.black.opacity(0.7)
            : Color.white.opacity(0.9)
    }
}