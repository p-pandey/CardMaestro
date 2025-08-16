import SwiftUI
import ImagePlayground

@available(iOS 18.4, macOS 15.4, *)
enum ImageStyle: String, CaseIterable {
    case sketch = "sketch"
    case illustration = "illustration"
    case animation = "animation"
    
    var displayName: String {
        switch self {
        case .sketch: return "Sketch"
        case .illustration: return "2D Illustration" 
        case .animation: return "3D Animation"
        }
    }
    
    var description: String {
        switch self {
        case .sketch: return "Hand-drawn style"
        case .illustration: return "Flat 2D illustration style"
        case .animation: return "3D Pixar-like animation style"
        }
    }
    
    var imagePlaygroundStyle: ImagePlaygroundStyle {
        switch self {
        case .sketch: return .sketch
        case .illustration: return .illustration
        case .animation: return .animation
        }
    }
}