import SwiftUI

/// Constants for consistent card sizing across the application
struct CardConstants {
    /// Standard card dimensions that should be used across all views
    /// Based on the optimal size from study mode back card (with content + buttons)
    struct Dimensions {
        /// The actual visible card content height (the white rounded rectangle)
        /// Optimized for iPhone 15 to maximize content while fitting all UI elements
        static let cardContentHeight: CGFloat = 560
        
        /// Standard horizontal padding for card containers
        static let horizontalPadding: CGFloat = 20
        
        /// Standard corner radius for cards
        static let cornerRadius: CGFloat = 20
        
        /// Standard spacing within card content
        static let contentSpacing: CGFloat = 16
        
        /// Standard padding inside card content
        static let contentPadding: CGFloat = 24
        
        /// Total height including minimal padding for containers
        static let totalContainerHeight: CGFloat = cardContentHeight + 20 // Reduced extra space for better fit
    }
}