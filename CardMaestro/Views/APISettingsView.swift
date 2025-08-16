import SwiftUI

enum TextAPI: String, CaseIterable {
    case appleIntelligence = "apple"
    case gpt5Mini = "gpt5mini"
    
    var displayName: String {
        switch self {
        case .appleIntelligence: return "Apple Intelligence"
        case .gpt5Mini: return "GPT-5-mini"
        }
    }
    
    var description: String {
        switch self {
        case .appleIntelligence: return "On-device Apple Intelligence - Private, free, offline"
        case .gpt5Mini: return "OpenAI's GPT-5-mini - Latest technology, cost-effective"
        }
    }
    
    var costInfo: String {
        switch self {
        case .appleIntelligence: return "Free"
        case .gpt5Mini: return "~$0.0005 per card"
        }
    }
}

struct APISettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var openAIKey = ""
    @State private var useAppleIntelligence = UserDefaults.standard.bool(forKey: "useAppleIntelligence")
    @State private var allowOpenAIImageBackup = UserDefaults.standard.bool(forKey: "allowOpenAIImageBackup")
    @State private var selectedTextAPI: TextAPI = {
        let stored = UserDefaults.standard.string(forKey: "selectedTextAPI")
        return TextAPI(rawValue: stored ?? TextAPI.gpt5Mini.rawValue) ?? .gpt5Mini
    }()
    @State private var selectedImageStyleRaw: String = "illustration"
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingSuccess = false
    @State private var showingTestSuccess = false
    @State private var testSuccessMessage = ""
    
    private let keychain = KeychainManager.shared
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(.purple)
                            Text("Text Generation")
                                .font(.headline)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Text Generation API")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Picker("Text Generation API", selection: $selectedTextAPI) {
                                ForEach(TextAPI.allCases, id: \.self) { api in
                                    VStack(alignment: .leading) {
                                        Text(api.displayName)
                                        Text(api.costInfo)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .tag(api)
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: selectedTextAPI) { _, newValue in
                                UserDefaults.standard.set(newValue.rawValue, forKey: "selectedTextAPI")
                            }
                            
                            Text(selectedTextAPI.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                            
                            // Show requirements for Apple Intelligence
                            if selectedTextAPI == .appleIntelligence {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: "info.circle")
                                            .foregroundColor(.blue)
                                            .font(.caption)
                                        Text("Apple Intelligence must be enabled in Settings > Apple Intelligence & Siri")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    HStack {
                                        Image(systemName: "iphone")
                                            .foregroundColor(.blue)
                                            .font(.caption)
                                        Text("Requires iOS 18.4+ and compatible device")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Card Content")
                } footer: {
                    switch selectedTextAPI {
                    case .appleIntelligence:
                        Text("Apple Intelligence generates card content on-device for privacy and works offline. No API key required.")
                    case .gpt5Mini:
                        Text("GPT-5-mini will be used for card content generation with your OpenAI API key below.")
                    }
                }
                
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "photo.artframe")
                                .foregroundColor(.indigo)
                            Text("Image Generation")
                                .font(.headline)
                        }
                        
                        Toggle(isOn: $useAppleIntelligence) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Use Apple Intelligence")
                                    .font(.subheadline)
                                Text("Generate card images using on-device Apple Intelligence instead of OpenAI")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .onChange(of: useAppleIntelligence) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "useAppleIntelligence")
                        }
                        
                        if useAppleIntelligence {
                            Divider()
                            
                            if #available(iOS 18.4, *) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Image Style")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Picker("Image Style", selection: $selectedImageStyleRaw) {
                                        ForEach(ImageStyle.allCases, id: \.self) { style in
                                            Text(style.displayName).tag(style.rawValue)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .onChange(of: selectedImageStyleRaw) { _, newValue in
                                        UserDefaults.standard.set(newValue, forKey: "selectedImageStyle")
                                    }
                                    
                                    if let currentStyle = ImageStyle(rawValue: selectedImageStyleRaw) {
                                        Text(currentStyle.description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            } else {
                                Text("Image style selection requires iOS 18.4+")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if useAppleIntelligence {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                    Text("Apple Intelligence must be enabled in Settings > Apple Intelligence & Siri")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack {
                                    Image(systemName: "iphone")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                    Text("Requires iOS 18.4+ and compatible device")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.top, 4)
                        }
                        
                        // OpenAI Backup Setting
                        if useAppleIntelligence {
                            Divider()
                            
                            Toggle(isOn: $allowOpenAIImageBackup) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Allow OpenAI Backup")
                                        .font(.subheadline)
                                    Text("Use OpenAI as backup when Apple Intelligence fails (requires API key below)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .onChange(of: allowOpenAIImageBackup) { _, newValue in
                                UserDefaults.standard.set(newValue, forKey: "allowOpenAIImageBackup")
                            }
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Card Images")
                } footer: {
                    if useAppleIntelligence {
                        if allowOpenAIImageBackup {
                            Text("Apple Intelligence generates images on-device for privacy. OpenAI backup will be used if Apple Intelligence fails.")
                        } else {
                            Text("Apple Intelligence generates images on-device for privacy and works offline. No API key required.")
                        }
                    } else {
                        Text("OpenAI will be used for image generation with your API key below.")
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "wand.and.stars.inverse")
                                .foregroundColor(.purple)
                            Text("OpenAI API Key")
                                .font(.headline)
                        }
                        
                        Text("Enter your OpenAI API key to enable GPT-5-mini text generation, card suggestions, and GPT-Image-1 deck icons.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        SecureField("sk-...", text: $openAIKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                        
                        HStack {
                            Button("Test Key") {
                                testOpenAIAPIKey()
                            }
                            .buttonStyle(.bordered)
                            .disabled(openAIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            
                            Spacer()
                            
                            Button("Save") {
                                saveOpenAIAPIKey()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(openAIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        
                        if keychain.hasValidKey(for: .openAI) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("API key is saved and valid")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("OpenAI Integration")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How to get your OpenAI API key:")
                        Text("1. Visit platform.openai.com")
                        Text("2. Create an account or sign in")
                        Text("3. Go to API Keys section")
                        Text("4. Create a new API key")
                        Text("5. Copy and paste it here")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Section("Privacy & Security") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(.green)
                            Text("Secure Storage")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        Text("Your API keys are stored securely in the iOS Keychain and never leave your device.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("Delete Stored Keys") {
                            deleteAllKeys()
                        }
                        .foregroundColor(.red)
                        .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
                
                Section("Usage & Costs") {
                    VStack(alignment: .leading, spacing: 8) {
                        switch selectedTextAPI {
                        case .appleIntelligence:
                            Text("• Apple Intelligence: Used for card content generation (free, on-device)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        case .gpt5Mini:
                            Text("• GPT-5-mini API: Used for card content generation and suggestions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if useAppleIntelligence {
                            Text("• Apple Intelligence: Used for card image generation (free, on-device)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("• OpenAI API: Used for card image generation")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("• OpenAI API: Used for custom deck icon generation")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        let isAppleTextAPI = selectedTextAPI == .appleIntelligence
                        let isAppleImageAPI = useAppleIntelligence
                        
                        if isAppleTextAPI && isAppleImageAPI {
                            Text("Apple Intelligence runs entirely on-device with no additional costs or API calls.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if isAppleTextAPI || isAppleImageAPI {
                            Text("Apple Intelligence features run on-device at no cost. API calls are made to external providers for remaining services.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("API calls are made directly to OpenAI's servers using your API key. You will be charged by OpenAI based on your usage.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("Monitor usage at platform.openai.com")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("API Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                #endif
            }
        }
        .onAppear {
            loadSavedKey()
            selectedImageStyleRaw = UserDefaults.standard.string(forKey: "selectedImageStyle") ?? "illustration"
            let stored = UserDefaults.standard.string(forKey: "selectedTextAPI")
            selectedTextAPI = TextAPI(rawValue: stored ?? TextAPI.gpt5Mini.rawValue) ?? .gpt5Mini
        }
        .alert("Success", isPresented: $showingSuccess) {
            Button("OK") { }
        } message: {
            Text("API key saved successfully!")
        }
        .alert("Success", isPresented: $showingTestSuccess) {
            Button("OK") { }
        } message: {
            Text(testSuccessMessage)
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func loadSavedKey() {
        if let savedKey = keychain.load(for: .openAI) {
            openAIKey = savedKey
        }
    }
    
    
    private func saveOpenAIAPIKey() {
        let trimmedKey = openAIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedKey.isEmpty else {
            alertMessage = "Please enter a valid OpenAI API key"
            showingAlert = true
            return
        }
        
        if keychain.save(trimmedKey, for: .openAI) {
            showingSuccess = true
        } else {
            alertMessage = "Failed to save OpenAI API key to keychain"
            showingAlert = true
        }
    }
    
    
    private func testOpenAIAPIKey() {
        let trimmedKey = openAIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedKey.hasPrefix("sk-") && trimmedKey.count > 20 {
            testSuccessMessage = "OpenAI API key format looks correct! Save it to start using icon generation."
            showingTestSuccess = true
        } else {
            alertMessage = "OpenAI API key format appears invalid. OpenAI keys start with 'sk-' and are longer than 20 characters."
            showingAlert = true
        }
    }
    
    private func deleteAllKeys() {
        if keychain.deleteAll() {
            openAIKey = ""
            alertMessage = "All API keys deleted successfully"
            showingAlert = true
        } else {
            alertMessage = "Failed to delete API keys"
            showingAlert = true
        }
    }
}

#Preview {
    APISettingsView()
}