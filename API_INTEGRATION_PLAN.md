# 🔐 Smart Content Suggestions - API Integration Plan

## Missing Features from Original Spec

### 1. Smart Content Suggestions
- **OpenAI DALL-E**: Generate images for visual flashcards
- **Claude API**: Generate related cards and content suggestions
- **Image Recognition**: Analyze uploaded images to suggest card content

### 2. Advanced Study Features
- **Adaptive Learning**: Adjust difficulty based on performance
- **Smart Scheduling**: ML-based review timing optimization
- **Content Analysis**: Suggest improvements to existing cards

## 🔑 API Key Security Strategy

### Recommended: User-Provided Keys
```swift
// Settings view for API keys
struct APISettingsView: View {
    @State private var openAIKey = ""
    @State private var claudeKey = ""
    
    var body: some View {
        Form {
            Section("API Keys") {
                SecureField("OpenAI API Key", text: $openAIKey)
                SecureField("Claude API Key", text: $claudeKey)
                
                Button("Save Keys") {
                    KeychainManager.shared.save(openAIKey, for: "openai_key")
                    KeychainManager.shared.save(claudeKey, for: "claude_key")
                }
            }
        }
    }
}
```

### Keychain Storage Implementation
```swift
class KeychainManager {
    static let shared = KeychainManager()
    
    func save(_ value: String, for key: String) {
        let data = value.data(using: .utf8)!
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData: data
        ] as CFDictionary
        
        SecItemDelete(query)
        SecItemAdd(query, nil)
    }
    
    func load(for key: String) -> String? {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ] as CFDictionary
        
        var result: AnyObject?
        if SecItemCopyMatching(query, &result) == errSecSuccess {
            return String(data: result as! Data, encoding: .utf8)
        }
        return nil
    }
}
```

## 🤖 API Service Implementation

### 1. OpenAI Service (Image Generation)
```swift
class OpenAIService: ObservableObject {
    private let apiKey: String
    
    init() {
        self.apiKey = KeychainManager.shared.load(for: "openai_key") ?? ""
    }
    
    func generateImage(prompt: String) async throws -> URL {
        // DALL-E API call implementation
    }
    
    func analyzeImage(_ image: UIImage) async throws -> String {
        // GPT-4V image analysis implementation
    }
}
```

### 2. Claude Service (Content Generation)
```swift
class ClaudeService: ObservableObject {
    private let apiKey: String
    
    init() {
        self.apiKey = KeychainManager.shared.load(for: "claude_key") ?? ""
    }
    
    func generateRelatedCards(topic: String, existingCards: [Card]) async throws -> [CardSuggestion] {
        // Claude API call for content generation
    }
    
    func improvCardContent(_ card: Card) async throws -> CardImprovement {
        // Suggest improvements to existing cards
    }
}
```

## 📱 Smart Features Implementation

### 1. Visual Card Creation
```swift
struct SmartCardCreationView: View {
    @State private var generatedImage: UIImage?
    @StateObject private var openAIService = OpenAIService()
    
    var body: some View {
        VStack {
            if let image = generatedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
            
            Button("Generate Visual") {
                Task {
                    // Generate image for flashcard
                }
            }
        }
    }
}
```

### 2. Content Suggestions
```swift
struct ContentSuggestionsView: View {
    @StateObject private var claudeService = ClaudeService()
    @State private var suggestions: [CardSuggestion] = []
    
    var body: some View {
        List(suggestions) { suggestion in
            VStack(alignment: .leading) {
                Text(suggestion.front)
                    .font(.headline)
                Text(suggestion.back)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
    }
}
```

## 🔒 Security Best Practices

### .gitignore Additions
```gitignore
# API Keys and Secrets
APIKeys.plist
Secrets.xcconfig
*.key
*secrets*

# Environment files
.env
.env.local
.env.production
```

### Runtime Key Validation
```swift
extension APIService {
    var hasValidKeys: Bool {
        guard let openAIKey = KeychainManager.shared.load(for: "openai_key"),
              let claudeKey = KeychainManager.shared.load(for: "claude_key") else {
            return false
        }
        return !openAIKey.isEmpty && !claudeKey.isEmpty
    }
    
    func validateKeys() async -> Bool {
        // Test API calls to validate keys
        return await testOpenAIConnection() && testClaudeConnection()
    }
}
```

## 💰 Cost Management

### Usage Tracking
```swift
class APIUsageTracker: ObservableObject {
    @Published var openAIUsage: Double = 0
    @Published var claudeUsage: Double = 0
    @Published var monthlyBudget: Double = 10.0
    
    func trackUsage(service: APIService, cost: Double) {
        // Track API usage and costs
    }
}
```

### User Controls
```swift
struct UsageLimitsView: View {
    @StateObject private var usageTracker = APIUsageTracker()
    
    var body: some View {
        Form {
            Section("Monthly Budget") {
                HStack {
                    Text("$")
                    TextField("Budget", value: $usageTracker.monthlyBudget, format: .currency(code: "USD"))
                }
            }
            
            Section("Current Usage") {
                HStack {
                    Text("OpenAI")
                    Spacer()
                    Text("$\(usageTracker.openAIUsage, specifier: "%.2f")")
                }
                
                HStack {
                    Text("Claude")
                    Spacer()
                    Text("$\(usageTracker.claudeUsage, specifier: "%.2f")")
                }
            }
        }
    }
}
```

## 🎯 Implementation Priority

1. **Keychain Manager** - Secure key storage
2. **API Settings UI** - User key input interface
3. **Basic API Services** - OpenAI and Claude clients
4. **Content Suggestions** - Claude-powered card generation
5. **Image Generation** - DALL-E integration
6. **Usage Tracking** - Cost monitoring
7. **Advanced Features** - ML-based scheduling, etc.

## Alternative: Backend Proxy

If you prefer not to have users manage API keys:

### Backend Service Architecture
```
iOS App ←→ Your Backend Server ←→ OpenAI/Claude APIs
```

### Benefits
- Users don't need API keys
- Centralized cost control
- Enhanced security
- Usage analytics

### Implementation
- Create Express.js/FastAPI backend
- Store keys in environment variables
- Implement authentication (Firebase Auth, etc.)
- Add rate limiting and usage quotas

Would you like me to implement the user-provided keys approach or set up a backend proxy service?