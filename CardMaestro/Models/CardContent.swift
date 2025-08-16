import Foundation

/// JSON-based content structures for different card types
protocol CardContent: Codable {
    var cardType: CardType { get }
}

/// Content structure for Vocabulary cards
/// Format: word/phrase + meaning + large image + optional detail
struct VocabularyContent: CardContent {
    let cardType: CardType = .vocabulary
    let meaning: String
    let detail: String?
    
    enum CodingKeys: String, CodingKey {
        case meaning, detail
    }
}

/// Content structure for Conjugation cards  
/// Format: verb + meaning + small image + conjugation table
/// The conjugations array contains rows, each with columns for that conjugation pattern
struct ConjugationContent: CardContent {
    let cardType: CardType = .conjugation
    let meaning: String
    let conjugations: [[String]] // Array of rows, each row is an array of columns
    
    enum CodingKeys: String, CodingKey {
        case meaning, conjugations
    }
}

/// Content structure for Fact cards
/// Format: question + answer + large image + optional detail
struct FactContent: CardContent {
    let cardType: CardType = .fact
    let answer: String
    let detail: String?
    
    enum CodingKeys: String, CodingKey {
        case answer, detail
    }
}

/// Helper for encoding/decoding different card content types
struct CardContentWrapper {
    
    /// Encodes any CardContent to JSON string
    static func encode<T: CardContent>(_ content: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(content)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw CardContentError.encodingFailed
        }
        return jsonString
    }
    
    /// Decodes JSON string to the appropriate CardContent type based on card type
    static func decode(jsonString: String, cardType: CardType) throws -> any CardContent {
        guard let data = jsonString.data(using: .utf8) else {
            throw CardContentError.invalidJSON
        }
        
        let decoder = JSONDecoder()
        
        switch cardType {
        case .vocabulary:
            return try decoder.decode(VocabularyContent.self, from: data)
        case .conjugation:
            return try decoder.decode(ConjugationContent.self, from: data)
        case .fact:
            return try decoder.decode(FactContent.self, from: data)
        }
    }
    
    /// Creates default content for a card type
    static func createDefault(for cardType: CardType) -> any CardContent {
        switch cardType {
        case .vocabulary:
            return VocabularyContent(meaning: "", detail: nil)
        case .conjugation:
            return ConjugationContent(meaning: "", conjugations: [])
        case .fact:
            return FactContent(answer: "", detail: nil)
        }
    }
}

/// Errors that can occur during card content processing
enum CardContentError: Error, LocalizedError {
    case encodingFailed
    case invalidJSON
    case unsupportedCardType
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode card content to JSON"
        case .invalidJSON:
            return "Invalid JSON format for card content"
        case .unsupportedCardType:
            return "Unsupported card type"
        }
    }
}