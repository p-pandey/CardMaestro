import Foundation
import Security

class KeychainManager {
    static let shared = KeychainManager()
    
    private init() {}
    
    private let serviceName = "CardMaestroAPIKeys"
    
    enum KeyType: String, CaseIterable {
        case openAI = "openai_api_key"
        case claude = "claude_api_key"
        
        var displayName: String {
            switch self {
            case .openAI: return "OpenAI API Key"
            case .claude: return "Claude API Key"
            }
        }
        
        var placeholder: String {
            switch self {
            case .openAI: return "sk-..."
            case .claude: return "sk-ant-..."
            }
        }
    }
    
    func save(_ value: String, for keyType: KeyType) -> Bool {
        guard !value.isEmpty else { return false }
        
        let data = value.data(using: .utf8)!
        
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: serviceName,
            kSecAttrAccount: keyType.rawValue,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ] as CFDictionary
        
        // Delete existing item first
        SecItemDelete(query)
        
        let status = SecItemAdd(query, nil)
        return status == errSecSuccess
    }
    
    func load(for keyType: KeyType) -> String? {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: serviceName,
            kSecAttrAccount: keyType.rawValue,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ] as CFDictionary
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return key
    }
    
    func delete(for keyType: KeyType) -> Bool {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: serviceName,
            kSecAttrAccount: keyType.rawValue
        ] as CFDictionary
        
        let status = SecItemDelete(query)
        return status == errSecSuccess
    }
    
    func deleteAll() -> Bool {
        var success = true
        for keyType in KeyType.allCases {
            success = success && delete(for: keyType)
        }
        return success
    }
    
    func hasValidKey(for keyType: KeyType) -> Bool {
        guard let key = load(for: keyType) else { return false }
        
        switch keyType {
        case .openAI:
            return key.hasPrefix("sk-") && key.count > 20
        case .claude:
            return key.hasPrefix("sk-ant-") && key.count > 30
        }
    }
    
    func getAllStoredKeys() -> [KeyType: String] {
        var keys: [KeyType: String] = [:]
        for keyType in KeyType.allCases {
            if let key = load(for: keyType) {
                keys[keyType] = key
            }
        }
        return keys
    }
    
    // MARK: - Convenience Methods
    
    func getOpenAIKey() -> String? {
        return load(for: .openAI)
    }
    
    func getClaudeKey() -> String? {
        return load(for: .claude)
    }
}