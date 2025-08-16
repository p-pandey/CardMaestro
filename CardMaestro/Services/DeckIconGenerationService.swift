import Foundation
import SwiftUI

@MainActor
class DeckIconGenerationService: ObservableObject {
    static let shared = DeckIconGenerationService()
    
    @Published var isGenerating = false
    @Published var lastError: String?
    
    private let openAIAPIKey: String?
    private let baseURL = "https://api.openai.com/v1"
    
    private init() {
        // Try to get OpenAI API key from environment or keychain
        self.openAIAPIKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? KeychainManager.shared.getOpenAIKey()
    }
    
    private var hasValidOpenAIKey: Bool {
        return openAIAPIKey != nil && !openAIAPIKey!.isEmpty
    }
    
    /// Generates a custom icon for a deck using OpenAI's gpt-image-1
    func generateIconForDeck(name: String, description: String?) async -> UIImage? {
        guard hasValidOpenAIKey else {
            print("⚠️ No OpenAI API key available, falling back to SF Symbol")
            return nil
        }
        
        isGenerating = true
        lastError = nil
        
        do {
            // Create an intelligent image generation prompt
            let intelligentPrompt = buildIntelligentIconPrompt(deckName: name, description: description)
            
            // Use gpt-image-1 to generate the actual icon
            let generatedImage = try await generateImageWithOpenAI(prompt: intelligentPrompt)
            
            isGenerating = false
            return generatedImage
        } catch {
            lastError = "Failed to generate icon: \(error.localizedDescription)"
            isGenerating = false
            print("❌ Error generating deck icon: \(error)")
            return nil
        }
    }
    
    /// Creates an intelligent image generation prompt based on deck content
    private func buildIntelligentIconPrompt(deckName: String, description: String?) -> String {
        let deckInfo = description?.isEmpty == false ? description! : "General study deck"
        let _ = (deckName + " " + deckInfo).lowercased()
        
        // Base prompt with style requirements optimized for gpt-image-1
        var prompt = "Create a clean, modern, minimalist flat design app icon in a perfect square format. Use vibrant but professional colors with high contrast. Absolutely no text, letters, or words anywhere in the image. Simple geometric shapes and symbols only. Educational theme, suitable for a flashcard study application. "
        
        // General education theme - no content-specific assumptions
        prompt += "General education theme: open book symbol or graduation cap silhouette with scholarly blue and gold colors."
        
        prompt += " Professional app icon quality with crisp edges and clear visual hierarchy. Optimized for small sizes and retina displays. Single focal point, avoid cluttered details."
        
        print("🎨 Generated intelligent prompt for '\(deckName)': \(prompt)")
        return prompt
    }
    
    /// Uses gpt-image-1 to generate the actual icon image
    private func generateImageWithOpenAI(prompt: String) async throws -> UIImage {
        guard let apiKey = openAIAPIKey else {
            throw ImageGenerationError.notAvailable
        }
        
        let requestBody: [String: Any] = [
            "model": "gpt-image-1",
            "prompt": prompt,
            "n": 1,
            "size": "1024x1024",      // Square format for fastest generation
            "quality": "low"          // Optimized for speed and cost
        ]
        
        let url = URL(string: "\(baseURL)/images/generations")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("📤 Sending deck icon request to OpenAI API...")
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let wallClockTime = endTime - startTime
        print("⏱️ OpenAI deck icon API call completed in \(String(format: "%.2f", wallClockTime))s")
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImageGenerationError.generationFailed("Invalid response")
        }
        
        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ImageGenerationError.generationFailed("OpenAI API error (\(httpResponse.statusCode)): \(errorMessage)")
        }
        
        print("✅ OpenAI deck icon generation successful")
        
        // Log cost information for gpt-image-1 (2025 token-based pricing)
        print("💰 OpenAI gpt-image-1 Icon API Usage:")
        print("   🖼️ Model: gpt-image-1")
        print("   📏 Size: 1024x1024")
        print("   ⭐ Quality: Low")
        print("   💵 Estimated cost: $0.020")
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let dataArray = json?["data"] as? [[String: Any]]
        let firstItem = dataArray?.first
        
        // Try base64 format first (should be primary with our request format)
        if let base64String = firstItem?["b64_json"] as? String,
           let imageData = Data(base64Encoded: base64String),
           let image = UIImage(data: imageData) {
            print("✅ Successfully generated deck icon using gpt-image-1 (base64)")
            return image
        }
        
        // Try URL format as fallback
        if let imageURL = firstItem?["url"] as? String,
           let url = URL(string: imageURL) {
            let (imageData, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: imageData) else {
                throw ImageGenerationError.generationFailed("Failed to decode image from URL")
            }
            print("✅ Successfully generated icon using gpt-image-1 (URL)")
            return image
        }
        
        throw ImageGenerationError.generationFailed("No valid image data found in response")
    }
    
    
    /// Creates a fallback icon using SF Symbols and gradients when image generation isn't available
    func createFallbackIcon(for deck: Deck, size: CGSize = CGSize(width: 60, height: 60)) -> UIImage? {
        // Validate input size
        guard size.width > 0 && size.height > 0 && size.width.isFinite && size.height.isFinite else {
            print("⚠️ Invalid size for fallback icon: \(size)")
            return nil
        }
        
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // Create gradient background with safe color handling
            guard let primaryColor = deck.deckColor.cgColor,
                  let secondaryColor = deck.deckColor.opacity(0.7).cgColor else {
                print("⚠️ Failed to get CGColors for deck gradient")
                // Fall back to a simple blue gradient
                cgContext.setFillColor(UIColor.systemBlue.cgColor)
                cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
                return
            }
            
            let colors = [primaryColor, secondaryColor]
            
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0.0, 1.0]
            ) else {
                print("⚠️ Failed to create gradient")
                // Fall back to solid color fill
                cgContext.setFillColor(primaryColor)
                cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
                return
            }
            
            // Calculate safe gradient parameters
            let centerX = size.width * 0.5
            let centerY = size.height * 0.5
            let startX = size.width * 0.3
            let startY = size.height * 0.3
            let radius = min(size.width, size.height) * 0.5
            
            // Validate gradient parameters
            guard centerX.isFinite && centerY.isFinite && startX.isFinite && startY.isFinite && radius.isFinite && radius > 0 else {
                print("⚠️ Invalid gradient parameters")
                cgContext.setFillColor(primaryColor)
                cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
                return
            }
            
            // Draw gradient circle
            cgContext.drawRadialGradient(
                gradient,
                startCenter: CGPoint(x: startX, y: startY),
                startRadius: 0,
                endCenter: CGPoint(x: centerX, y: centerY),
                endRadius: radius,
                options: []
            )
            
            // Add SF Symbol with safe sizing
            let symbolSize = min(size.width, size.height) * 0.5
            guard symbolSize > 0 && symbolSize.isFinite else {
                print("⚠️ Invalid symbol size: \(symbolSize)")
                return
            }
            
            let symbolConfig = UIImage.SymbolConfiguration(pointSize: symbolSize, weight: .medium)
            guard let symbolImage = UIImage(systemName: deck.deckIcon, withConfiguration: symbolConfig) else {
                print("⚠️ Failed to create symbol image for: \(deck.deckIcon)")
                return
            }
            
            // Calculate symbol rect with safe bounds
            let symbolWidth = symbolImage.size.width
            let symbolHeight = symbolImage.size.height
            
            guard symbolWidth.isFinite && symbolHeight.isFinite && symbolWidth > 0 && symbolHeight > 0 else {
                print("⚠️ Invalid symbol dimensions: \(symbolImage.size)")
                return
            }
            
            let symbolX = (size.width - symbolWidth) / 2
            let symbolY = (size.height - symbolHeight) / 2
            
            guard symbolX.isFinite && symbolY.isFinite else {
                print("⚠️ Invalid symbol position")
                return
            }
            
            let symbolRect = CGRect(
                x: symbolX,
                y: symbolY,
                width: symbolWidth,
                height: symbolHeight
            )
            
            // Draw symbol with white tint
            symbolImage.withTintColor(.white).draw(in: symbolRect)
        }
    }
}

enum ImageGenerationError: LocalizedError {
    case notAvailable
    case generationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Image generation not available on this device"
        case .generationFailed(let message):
            return "Image generation failed: \(message)"
        }
    }
}

// MARK: - Color Extension for CGColor
extension Color {
    var cgColor: CGColor? {
        let uiColor = UIColor(self)
        let cgColor = uiColor.cgColor
        
        // Validate that the CGColor has valid components
        guard let components = cgColor.components,
              !components.isEmpty,
              components.allSatisfy({ $0.isFinite && !$0.isNaN }) else {
            print("⚠️ Invalid CGColor components for color: \(self)")
            // Return a safe fallback color
            return UIColor.systemBlue.cgColor
        }
        
        return cgColor
    }
}