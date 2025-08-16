import Foundation

/// Generates optimized prompts for different AI services
class PromptGenerator {
    
    // MARK: - Text Generation Prompts
    
    /// Generate Claude API optimized prompt for card back content
    static func claudeTextPrompt(
        front: String,
        deckName: String,
        deckDescription: String?,
        cardType: CardType = .vocabulary
    ) -> String {
        return sharedDetailedTextPrompt(
            front: front,
            deckName: deckName,
            deckDescription: deckDescription,
            cardType: cardType,
            apiName: "Claude"
        )
    }
    
    /// Generate GPT-5-mini optimized prompt for card back content (same as Claude)
    static func gpt5MiniTextPrompt(
        front: String,
        deckName: String,
        deckDescription: String?,
        cardType: CardType = .vocabulary
    ) -> String {
        return sharedDetailedTextPrompt(
            front: front,
            deckName: deckName,
            deckDescription: deckDescription,
            cardType: cardType,
            apiName: "GPT-5-mini"
        )
    }
    
    /// Shared detailed prompt template for Claude and GPT-5-mini
    private static func sharedDetailedTextPrompt(
        front: String,
        deckName: String,
        deckDescription: String?,
        cardType: CardType = .vocabulary,
        apiName: String
    ) -> String {
        let deckInfo = deckDescription?.isEmpty == false ? deckDescription! : "No description provided"
        
        // Use the card type's specific prompt template (optimized for detailed responses)
        let basePrompt = cardType.backPromptTemplate
            .replacingOccurrences(of: "{front}", with: front)
        
        return """
        You are helping create flashcards for a deck called "\(deckName)" (\(deckInfo)).
        
        This is a \(cardType.displayName) type flashcard.
        
        \(basePrompt)
        
        Keep content concise but comprehensive.
        
        IMPORTANT: Also provide a simple visual description for generating an educational image. End your response with:
        
        IMAGE_PROMPT: [visual description]
        
        For the image prompt, follow these guidelines:
        \(imagePromptGuidelines)
        """
    }
    
    /// Generate Apple Intelligence optimized prompt for card back content
    static func appleIntelligenceTextPrompt(
        front: String,
        deckName: String,
        deckDescription: String?,
        cardType: CardType = .vocabulary
    ) -> String {
        let deckInfo = deckDescription?.isEmpty == false ? deckDescription! : "No description provided"
        
        // Use the same JSON template as other services
        let simplifiedTemplate = cardType.backPromptTemplate
            .replacingOccurrences(of: "{front}", with: front)
        
        return """
        Create flashcard content for "\(front)" in deck "\(deckName)" (\(deckInfo)).
        
        \(simplifiedTemplate)
        
        Keep it concise and educational.
        """
    }
    
    /// Generate GPT-5-mini optimized prompt for bulk card suggestions
    static func gpt5MiniBulkSuggestionPrompt(
        deckName: String,
        deckDescription: String?,
        currentCards: [(front: String, type: String)],
        suggestedCards: [(front: String, type: String)],
        deletedCards: [(front: String, type: String)],
        count: Int
    ) -> String {
        let deckInfo = deckDescription?.isEmpty == false ? deckDescription! : "No description provided"
        
        let currentCardsText = currentCards.isEmpty ? "None" : 
            currentCards.map { "\"\($0.front)\" (\($0.type))" }.joined(separator: ", ")
        
        let suggestedCardsText = suggestedCards.isEmpty ? "None" : 
            suggestedCards.map { "\"\($0.front)\" (\($0.type))" }.joined(separator: ", ")
        
        let deletedCardsText = deletedCards.isEmpty ? "None" : 
            deletedCards.map { "\"\($0.front)\" (\($0.type))" }.joined(separator: ", ")
        
        return """
        Generate \(count) flashcard suggestions for the deck "\(deckName)" (\(deckInfo)).
        
        Current cards in deck: \(currentCardsText)
        Already suggested cards: \(suggestedCardsText)
        Deleted/rejected cards: \(deletedCardsText)
        
        CARD TYPE DECISION PROCESS:
        For each suggested card, first decide which type is most appropriate:
        
        1. **vocabulary** - For single words, phrases, or terms that need definition/translation
           • Examples: "house", "beautiful", "how are you?", "democracy"
           • Focus: Learning meaning and usage of words/phrases
        
        2. **conjugation** - For verbs that need conjugation practice
           • Examples: "to eat", "comer", "mangiare", "essen"
           • Focus: Learning verb forms and patterns
        
        3. **fact** - For factual information, questions, or knowledge-based content
           • Examples: "What is the capital of France?", "When did WWII end?"
           • Focus: Learning facts, dates, processes, explanations
        
        REQUIREMENTS:
        1. Each card front should focus on a SINGLE word, phrase, or concept
        2. Card front should only state the word or phrase, not combine multiple related concepts, and not include any notation about grammar etc.
        3. Base suggestions on current cards to create complementary, relevant content
        4. Do NOT suggest anything that matches already suggested or deleted cards
        5. Uniqueness is based on BOTH front text AND card type
        6. If current cards list is empty, suggest foundational cards for the deck topic
        
        For each card's image prompt, follow these guidelines:
        \(imagePromptGuidelines)
        
        JSON STRUCTURE BY CARD TYPE:
        
        **vocabulary cards:**
        {
          "meaning": "Clear, concise English definition (required)",
          "detail": "Optional single sentence with additional context, usage note, or null"
        }
        
        **conjugation cards:**
        {
          "meaning": "English translation (e.g., 'to eat', 'to speak')",
          "conjugations": [
            ["pronoun/subject", "conjugated form"],
            ["pronoun/subject", "conjugated form"],
            ["pronoun/subject", "conjugated form"]
          ]
        }
        Examples:
        • Italian: [["io", "mangio"], ["tu", "mangi"], ["lui/lei", "mangia"], ["noi", "mangiamo"], ["voi", "mangiate"], ["loro", "mangiano"]]
        • French: [["je", "mange"], ["tu", "manges"], ["il/elle", "mange"], ["nous", "mangeons"], ["vous", "mangez"], ["ils/elles", "mangent"]]
        
        **fact cards:**
        {
          "answer": "Direct, factual one-sentence answer (required)",
          "detail": "Optional second sentence with additional detail or null"
        }
        
        Respond with ONLY a JSON array in this exact format:
        [
            {
                "front": "single word/phrase/concept",
                "type": "vocabulary|conjugation|fact",
                "back": {JSON object matching the card type structure above},
                "imagePrompt": "descriptive image prompt or null"
            }
        ]
        """
    }
    
    /// Shared image prompt guidelines used by both single and bulk generation
    private static var imagePromptGuidelines: String {
        return """
        - For concrete objects: Use descriptive scenes without people (e.g., "small house on green hill", "red car on sunny road", "open book on wooden table")
        - For actions that would show people: Use professional animals with clear job titles (e.g., "bear teacher writing on blackboard", "raccoon chef cooking pasta", "fox secretary writing letters")
        - For abstract concepts: Use creative visual metaphors with animals or inanimate objects (e.g., "elephant scientist with lightbulb", "two swans with hearts floating")
        - For adjectives: Use inanimate objects that clearly show the quality (e.g., "big" → "giant mountain next to tiny house", "fast" → "racing car with speed lines")
        - Make prompts descriptive enough for Apple Image Playground (5-8 words typical)
        - When an image would normally need people, use appropriate professional animals instead
        """
    }
    
    // MARK: - Image Generation Prompts
    
    /// Generate Claude API optimized prompt for image description
    static func claudeImagePrompt(concept: String) -> String {
        return """
        Generate a creative visual description for an educational illustration of "\(concept)".
        
        The description should:
        - Be descriptive enough for Apple Image Playground (5-8 words)
        - When an image would normally need people, use professional animals with clear job titles (teacher, chef, secretary, doctor, etc.)
        - Use inanimate objects to visualize concepts when appropriate
        - Create clear, educational visual scenes
        - Be suitable for Apple Image Playground generation
        - ALWAYS include the profession/job title when using animals for human activities
        
        Examples:
        - "house" → "small house on green hill with flowers"
        - "car" → "red car driving on sunny mountain road"
        - "book" → "open book on wooden desk with warm light"
        - "big" → "giant mountain towering over tiny village below"
        - "fast" → "racing car with motion blur and speed lines"
        - "to eat" → "raccoon chef eating pasta at restaurant table"
        - "to write" → "fox secretary writing letters at wooden desk"
        - "mathematics" → "elephant professor solving equations on blackboard"
        - "friendship" → "fox and rabbit hugging under rainbow"
        - "what's your name" → "bear teacher introducing himself to class"
        - "love" → "two swans with hearts floating around lake"
        - "courage" → "lion superhero with cape standing proudly"
        - "wisdom" → "owl professor with ancient books and glowing brain"
        - "hope" → "owl astronomer looking at bright star in sky"
        - "beauty" → "butterfly artist painting colorful flowers in garden"
        
        Response format: Just the visual description, nothing else.
        """
    }
    
    /// Use the image prompt exactly as received from LLM API
    static func appleIntelligenceImagePrompt(concept: String) -> String {
        // Use the prompt exactly as received from the LLM, with minimal cleanup
        return concept.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Generate OpenAI optimized image prompt
    static func openAIImagePrompt(concept: String) -> String {
        // Get the creative animal prompt and expand it for OpenAI
        let animalPrompt = appleIntelligenceImagePrompt(concept: concept)
        return "Create a clean, modern, educational illustration featuring \(animalPrompt). Flat design style, vibrant but professional colors, clear and simple composition suitable for a flashcard app. The animals should be cute and friendly with clear professional attire."
    }
    
    // MARK: - Private Helper Methods
}