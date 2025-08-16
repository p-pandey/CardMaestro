import Foundation

struct CardBackSuggestion {
    let formattedBack: String
    let imagePrompt: String? // New: simple image prompt for Apple Intelligence
    
    // Legacy properties for backward compatibility (not used in rendering)
    let meaning: String
    let usage: String
    let example: String
    let exampleMeaning: String
}

class ClaudeService: ObservableObject {
    @Published var isGenerating = false
    @Published var lastError: String?
    
    var hasValidKey: Bool {
        let selectedTextAPIString = UserDefaults.standard.string(forKey: "selectedTextAPI") ?? TextAPI.gpt5Mini.rawValue
        let selectedTextAPI = TextAPI(rawValue: selectedTextAPIString) ?? .gpt5Mini
        
        switch selectedTextAPI {
        case .appleIntelligence:
            if #available(iOS 18.4, *) {
                return true // Apple Intelligence doesn't need an API key
            } else {
                return KeychainManager.shared.hasValidKey(for: .openAI) // Fallback to GPT-5-mini
            }
        case .gpt5Mini:
            return KeychainManager.shared.hasValidKey(for: .openAI) // GPT-5-mini uses OpenAI key
        }
    }
    
    func generateCardBack(
        front: String,
        deckName: String,
        deckDescription: String?,
        cardType: CardType = .vocabulary
    ) async throws -> CardBackSuggestion {
        
        // Check which text generation API the user has selected
        let selectedTextAPIString = UserDefaults.standard.string(forKey: "selectedTextAPI") ?? TextAPI.gpt5Mini.rawValue
        let selectedTextAPI = TextAPI(rawValue: selectedTextAPIString) ?? .gpt5Mini
        
        switch selectedTextAPI {
        case .appleIntelligence:
            if #available(iOS 18.4, *) {
                print("🧠 Using Apple Intelligence for text generation")
                let appleService = AppleIntelligenceTextService()
                return try await appleService.generateCardBack(
                    front: front,
                    deckName: deckName,
                    deckDescription: deckDescription,
                    cardType: cardType
                )
            } else {
                print("⚠️ Apple Intelligence text generation requires iOS 18.4+, falling back to GPT-5-mini")
                let gptService = GPT5MiniService()
                return try await gptService.generateCardBack(
                    front: front,
                    deckName: deckName,
                    deckDescription: deckDescription,
                    cardType: cardType
                )
            }
        case .gpt5Mini:
            print("🤖 Using GPT-5-mini for text generation")
            let gptService = GPT5MiniService()
            return try await gptService.generateCardBack(
                front: front,
                deckName: deckName,
                deckDescription: deckDescription,
                cardType: cardType
            )
        }
    }
}

// MARK: - Error Handling

enum ClaudeError: LocalizedError {
    case missingAPIKey
    case invalidAPIKey
    case invalidURL
    case networkError(String)
    case apiError(String)
    case invalidResponse(String)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API key not found. Please add your API key in Settings."
        case .invalidAPIKey:
            return "Invalid API key. Please check your key in Settings."
        case .invalidURL:
            return "Invalid API endpoint URL."
        case .networkError(let message):
            return "Network error: \(message)"
        case .apiError(let message):
            return "API error: \(message)"
        case .invalidResponse(let message):
            return "Invalid response: \(message)"
        }
    }
}