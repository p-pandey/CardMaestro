import SwiftUI

/// Represents different types of flashcards with specific JSON-based formatting and behavior
enum CardType: String, CaseIterable, Identifiable {
    case vocabulary = "vocabulary"
    case conjugation = "conjugation"
    case fact = "fact"
    
    var id: String { rawValue }
    
    /// Display name for UI
    var displayName: String {
        switch self {
        case .vocabulary: return "Vocabulary"
        case .conjugation: return "Conjugation"
        case .fact: return "Fact"
        }
    }
    
    /// SF Symbol icon for UI
    var icon: String {
        switch self {
        case .vocabulary: return "book.fill"
        case .conjugation: return "table"
        case .fact: return "info.circle.fill"
        }
    }
    
    /// Associated color for UI theming
    var color: Color {
        switch self {
        case .vocabulary: return .blue
        case .conjugation: return .purple
        case .fact: return .orange
        }
    }
    
    /// Description of what this card type is used for
    var description: String {
        switch self {
        case .vocabulary:
            return "Word/phrase on front, meaning + large image + optional detail on back"
        case .conjugation:
            return "Verb on front, meaning + small image + conjugation table on back"
        case .fact:
            return "Question on front, answer + large image + optional detail on back"
        }
    }
    
    /// Claude prompt template for generating JSON card content
    var backPromptTemplate: String {
        switch self {
        case .vocabulary:
            return """
            Create vocabulary card data for "{front}". Return ONLY valid JSON in this exact format:
            
            {
              "meaning": "The primary definition in English",
              "detail": "Optional single sentence with additional context or usage note"
            }
            
            IMPORTANT:
            - meaning: Clear, concise English definition (required)
            - detail: Optional additional context, example, or usage note (single sentence only)
            - Return only the JSON, no markdown or extra text
            - If no detail is needed, set it to null
            """
            
        case .conjugation:
            return """
            Create conjugation card data for verb "{front}". Determine the language from context and return ONLY valid JSON in this exact format:
            
            {
              "meaning": "English translation of the verb",
              "conjugations": [
                ["pronoun/subject", "conjugated form"],
                ["pronoun/subject", "conjugated form"],
                ["pronoun/subject", "conjugated form"]
              ]
            }
            
            IMPORTANT:
            - meaning: English translation (e.g., "to eat", "to speak")
            - conjugations: Array of [pronoun, verb form] pairs appropriate for the language
            - Use the language's actual pronoun/subject system (appropriate for the language)
            - Include all common persons/forms for that language
            - Return only the JSON, no markdown or extra text
            - Examples:
              * Italian: [["io", "mangio"], ["tu", "mangi"], ["lui/lei", "mangia"], ["noi", "mangiamo"], ["voi", "mangiate"], ["loro", "mangiano"]]
              * French: [["je", "mange"], ["tu", "manges"], ["il/elle", "mange"], ...]
              * German: [["ich", "esse"], ["du", "isst"], ["er/sie/es", "isst"], ...]
            """
            
        case .fact:
            return """
            Create fact card data for question "{front}". Return ONLY valid JSON in this exact format:
            
            {
              "answer": "Primary one-sentence answer to the question",
              "detail": "Optional second sentence with additional detail or secondary fact"
            }
            
            IMPORTANT:
            - answer: Direct, factual one-sentence answer (required)
            - detail: Optional additional information or secondary fact (single sentence only)
            - Return only the JSON, no markdown or extra text
            - If no detail is needed, set it to null
            """
        }
    }
    
    /// Logic for how this card type handles reverse mode
    var reverseLogic: ReverseLogic {
        switch self {
        case .vocabulary:
            return .showMeaning
        case .conjugation:
            return .showRandomForm
        case .fact:
            return .showAnswer
        }
    }
}

/// Defines how different card types handle reverse mode
enum ReverseLogic {
    case showMeaning      // Show meaning → recall word
    case showExample      // Show example → identify rule/concept
    case showAnswer       // Show answer → recall question
    case showRandomForm   // Show conjugated form → recall infinitive
    case showContext      // Show context → recall phrase
    
    var description: String {
        switch self {
        case .showMeaning:
            return "Shows the meaning so you can recall the word"
        case .showExample:
            return "Shows an example so you can identify the rule"
        case .showAnswer:
            return "Shows the answer so you can recall the question"
        case .showRandomForm:
            return "Shows a conjugated form so you can recall the infinitive"
        case .showContext:
            return "Shows the context so you can recall the phrase"
        }
    }
}

/// Extension to help with Core Data integration
extension CardType {
    /// Default card type for existing cards
    static let defaultType: CardType = .vocabulary
    
    /// Creates CardType from stored string value
    static func from(string: String?) -> CardType {
        guard let string = string,
              let cardType = CardType(rawValue: string) else {
            return .defaultType
        }
        return cardType
    }
}