import Foundation

class GPT5MiniService: ObservableObject {
    private let apiEndpoint = "https://api.openai.com/v1/responses"
    private let model = "gpt-5-mini"
    
    @Published var isGenerating = false
    @Published var lastError: String?
    
    private var apiKey: String? {
        return KeychainManager.shared.load(for: .openAI)
    }
    
    var hasValidKey: Bool {
        return KeychainManager.shared.hasValidKey(for: .openAI)
    }
    
    func generateCardBack(
        front: String,
        deckName: String,
        deckDescription: String?,
        cardType: CardType = .vocabulary
    ) async throws -> CardBackSuggestion {
        
        guard let apiKey = apiKey else {
            print("❌ No OpenAI API key found")
            throw GPT5MiniError.missingAPIKey
        }
        
        await MainActor.run {
            self.isGenerating = true
            self.lastError = nil
        }
        
        defer {
            Task { @MainActor in
                self.isGenerating = false
            }
        }
        
        let prompt = PromptGenerator.gpt5MiniTextPrompt(
            front: front,
            deckName: deckName,
            deckDescription: deckDescription,
            cardType: cardType
        )
        
        print("🤖 GPT-5-mini text prompt: \(prompt.prefix(200))...")
        
        let requestBody = GPT5MiniRequest(
            model: model,
            input: prompt,
            maxOutputTokens: 1000,
            reasoning: GPT5MiniReasoning(effort: "minimal"),
            text: GPT5MiniTextOptions(verbosity: "low")
        )
        
        guard let url = URL(string: apiEndpoint) else {
            throw GPT5MiniError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        do {
            let jsonData = try JSONEncoder().encode(requestBody)
            request.httpBody = jsonData
            
            print("📤 Sending request to GPT-5-mini API...")
            let startTime = CFAbsoluteTimeGetCurrent()
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            let endTime = CFAbsoluteTimeGetCurrent()
            let wallClockTime = endTime - startTime
            print("⏱️ GPT-5-mini API call completed in \(String(format: "%.2f", wallClockTime))s")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GPT5MiniError.networkError("Invalid response")
            }
            
            print("📊 GPT-5-mini HTTP Status Code: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 401 {
                print("❌ Authentication failed - Invalid OpenAI API key")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📄 401 Error details: \(responseString)")
                }
                throw GPT5MiniError.invalidAPIKey
            }
            
            if httpResponse.statusCode != 200 {
                print("❌ GPT-5-mini API Error: HTTP \(httpResponse.statusCode)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📄 Error response: \(responseString)")
                }
                throw GPT5MiniError.apiError("HTTP \(httpResponse.statusCode)")
            }
            
            print("✅ Received successful response from GPT-5-mini")
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            print("📄 Response: \(responseString)")
            
            let gptResponse = try JSONDecoder().decode(GPT5MiniResponse.self, from: data)
            
            // Find the message output in the response
            guard let messageOutput = gptResponse.output?.first(where: { $0.type == "message" }),
                  let textContent = messageOutput.content?.first(where: { $0.type == "output_text" }),
                  let content = textContent.text else {
                throw GPT5MiniError.invalidResponse("No text content in response")
            }
            
            print("💬 GPT-5-mini response content: \(content)")
            
            // Log usage information if available
            if let usage = gptResponse.usage {
                let totalTokens = usage.totalTokens
                // Current cost calculation for GPT-5-mini (2025 pricing)
                // Input: $0.25 per 1M tokens, Output: $2.00 per 1M tokens
                let inputCost = Double(usage.inputTokens) * 0.25 / 1_000_000
                let outputCost = Double(usage.outputTokens) * 2.00 / 1_000_000
                let totalCost = inputCost + outputCost
                
                print("💰 GPT-5-mini API Usage:")
                print("   📥 Input tokens: \(usage.inputTokens)")
                print("   📤 Output tokens: \(usage.outputTokens)")
                print("   🔢 Total tokens: \(totalTokens)")
                print("   💵 Estimated cost: $\(String(format: "%.6f", totalCost))")
            }
            
            return try parseCardBack(from: content)
            
        } catch let error as GPT5MiniError {
            await MainActor.run {
                self.lastError = error.localizedDescription
            }
            throw error
        } catch {
            let gptError = GPT5MiniError.networkError(error.localizedDescription)
            await MainActor.run {
                self.lastError = gptError.localizedDescription
            }
            throw gptError
        }
    }
    
    private func parseCardBack(from content: String) throws -> CardBackSuggestion {
        let cleanedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Extract image prompt if present (same logic as Claude)
        var imagePrompt: String?
        var finalContent = cleanedContent
        
        if let imagePromptRange = cleanedContent.range(of: "IMAGE_PROMPT:") {
            let afterPromptLabel = cleanedContent[imagePromptRange.upperBound...]
            let promptLine = afterPromptLabel.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let prompt = promptLine, !prompt.isEmpty {
                imagePrompt = prompt
                print("🖼️ Extracted image prompt from GPT-5-mini: '\(prompt)'")
            }
            
            // Remove the IMAGE_PROMPT section from the final content
            finalContent = String(cleanedContent[..<imagePromptRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Validate that the content is valid JSON
        guard let jsonData = finalContent.data(using: .utf8),
              let _ = try? JSONSerialization.jsonObject(with: jsonData) else {
            print("❌ GPT-5-mini content is not valid JSON: \(finalContent)")
            throw GPT5MiniError.invalidResponse("Generated content is not valid JSON")
        }
        
        return CardBackSuggestion(
            formattedBack: finalContent,
            imagePrompt: imagePrompt,
            meaning: "Generated with GPT-5-mini",
            usage: "Generated with GPT-5-mini",
            example: "Generated with GPT-5-mini",
            exampleMeaning: "Generated with GPT-5-mini"
        )
    }
    
    // MARK: - Card Suggestions
    
    func generateCardSuggestions(
        deckName: String,
        deckDescription: String?,
        currentCards: [(front: String, type: String)],
        suggestedCards: [(front: String, type: String)],
        deletedCards: [(front: String, type: String)],
        count: Int
    ) async throws -> [EnhancedCardSuggestion] {
        
        guard let apiKey = apiKey else {
            print("❌ No OpenAI API key found")
            throw GPT5MiniError.missingAPIKey
        }
        
        await MainActor.run {
            self.isGenerating = true
            self.lastError = nil
        }
        
        defer {
            Task { @MainActor in
                self.isGenerating = false
            }
        }
        
        let prompt = PromptGenerator.gpt5MiniBulkSuggestionPrompt(
            deckName: deckName,
            deckDescription: deckDescription,
            currentCards: currentCards,
            suggestedCards: suggestedCards,
            deletedCards: deletedCards,
            count: count
        )
        
        print("🤖 GPT-5-mini suggestion prompt: \(prompt.prefix(200))...")
        
let requestBody = GPT5MiniRequest(
            model: model,
            input: prompt,
maxOutputTokens: 25000, // Much higher limit - GPT-5-mini supports up to 128k
            reasoning: GPT5MiniReasoning(effort: "minimal"), // Keep minimal for speed
text: GPT5MiniTextOptions(verbosity: "low") // Keep low verbosity as requested
        )
        
        guard let url = URL(string: apiEndpoint) else {
            throw GPT5MiniError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        do {
            let jsonData = try JSONEncoder().encode(requestBody)
            request.httpBody = jsonData
            
            print("📤 Sending suggestion request to GPT-5-mini API...")
            let startTime = CFAbsoluteTimeGetCurrent()
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            let endTime = CFAbsoluteTimeGetCurrent()
            let wallClockTime = endTime - startTime
            print("⏱️ GPT-5-mini suggestion API call completed in \(String(format: "%.2f", wallClockTime))s")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GPT5MiniError.networkError("Invalid response")
            }
            
            print("📊 GPT-5-mini HTTP Status Code: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 401 {
                print("❌ Authentication failed - Invalid OpenAI API key")
                throw GPT5MiniError.invalidAPIKey
            }
            
            if httpResponse.statusCode != 200 {
                print("❌ GPT-5-mini API Error: HTTP \(httpResponse.statusCode)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📄 Error response: \(responseString)")
                }
                throw GPT5MiniError.apiError("HTTP \(httpResponse.statusCode)")
            }
            
            print("✅ Received successful response from GPT-5-mini")
            
            let gptResponse = try JSONDecoder().decode(GPT5MiniResponse.self, from: data)
            
            guard let messageOutput = gptResponse.output?.first(where: { $0.type == "message" }),
                  let textContent = messageOutput.content?.first(where: { $0.type == "output_text" }),
                  let content = textContent.text else {
                throw GPT5MiniError.invalidResponse("No text content in response")
            }
            
            print("💬 GPT-5-mini suggestion response: \(content)")
            
            // Log usage information if available
            if let usage = gptResponse.usage {
                let totalCost = Double(usage.inputTokens) * 0.25 / 1_000_000 + Double(usage.outputTokens) * 2.00 / 1_000_000
                print("💰 GPT-5-mini Suggestion API Usage:")
                print("   📥 Input tokens: \(usage.inputTokens)")
                print("   📤 Output tokens: \(usage.outputTokens)")
                print("   💵 Estimated cost: $\(String(format: "%.6f", totalCost))")
            }
            
            return try parseSuggestionResponse(content)
            
        } catch let error as GPT5MiniError {
            await MainActor.run {
                self.lastError = error.localizedDescription
            }
            throw error
        } catch {
            let gptError = GPT5MiniError.networkError(error.localizedDescription)
            await MainActor.run {
                self.lastError = gptError.localizedDescription
            }
            throw gptError
        }
    }
    
    
private func parseSuggestionResponse(_ content: String) throws -> [EnhancedCardSuggestion] {
        guard content.data(using: .utf8) != nil else {
            throw GPT5MiniError.invalidResponse("Could not encode response as UTF-8")
        }
        
        // Handle potentially truncated JSON by trying to fix it
        var cleanedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If the response doesn't end with ], it was likely truncated - try to close the array
        if !cleanedContent.hasSuffix("]") {
            print("⚠️ Detected truncated JSON response, attempting to repair...")
            // Find the last complete suggestion
            if let lastCompleteEntry = cleanedContent.range(of: "}", options: .backwards) {
                cleanedContent = String(cleanedContent[...lastCompleteEntry.upperBound]) + "]"
                print("🔧 Repaired JSON: \(cleanedContent.suffix(100))")
            }
        }
        
        guard let cleanedData = cleanedContent.data(using: .utf8) else {
            throw GPT5MiniError.invalidResponse("Could not encode cleaned response as UTF-8")
        }
        
        do {
            let jsonArray = try JSONSerialization.jsonObject(with: cleanedData) as? [[String: Any]] ?? []
            
            return jsonArray.compactMap { dict in
                guard let front = dict["front"] as? String,
                      let typeString = dict["type"] as? String,
                      let backContent = dict["back"] else {
                    print("⚠️ Skipping malformed suggestion: \(dict)")
                    return nil
                }
                
                // Convert back content to JSON string
                guard let backData = try? JSONSerialization.data(withJSONObject: backContent),
                      let backString = String(data: backData, encoding: .utf8) else {
                    print("⚠️ Could not serialize back content: \(backContent)")
                    return nil
                }
                
                let imagePrompt = dict["imagePrompt"] as? String
                
                return EnhancedCardSuggestion(
                    front: front,
                    type: typeString,
                    back: backString,
                    imagePrompt: imagePrompt,
                    context: "Generated suggestion" // Default context since removed from prompt
                )
            }
        } catch {
            print("❌ Error parsing suggestion response: \(error)")
            throw GPT5MiniError.invalidResponse("Failed to parse JSON response: \(error.localizedDescription)")
        }
    }
}

struct EnhancedCardSuggestion {
    let front: String
    let type: String
    let back: String
    let imagePrompt: String?
    let context: String
}

// MARK: - API Models

struct GPT5MiniRequest: Codable {
    let model: String
    let input: String
    let maxOutputTokens: Int
    let reasoning: GPT5MiniReasoning
    let text: GPT5MiniTextOptions
    
    enum CodingKeys: String, CodingKey {
        case model
        case input
        case maxOutputTokens = "max_output_tokens"
        case reasoning
        case text
    }
}

struct GPT5MiniReasoning: Codable {
    let effort: String
}

struct GPT5MiniTextOptions: Codable {
    let verbosity: String
}

struct GPT5MiniResponse: Codable {
    let output: [GPT5MiniOutput]?
    let usage: GPT5MiniUsage?
}

struct GPT5MiniOutput: Codable {
    let type: String
    let content: [GPT5MiniContent]?
}

struct GPT5MiniContent: Codable {
    let type: String
    let text: String?
}

struct GPT5MiniUsage: Codable {
    let inputTokens: Int
    let outputTokens: Int
    let totalTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case totalTokens = "total_tokens"
    }
}

// MARK: - Error Handling

enum GPT5MiniError: LocalizedError {
    case missingAPIKey
    case invalidAPIKey
    case invalidURL
    case networkError(String)
    case apiError(String)
    case invalidResponse(String)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API key not found. Please add your API key in Settings."
        case .invalidAPIKey:
            return "Invalid OpenAI API key. Please check your key in Settings."
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