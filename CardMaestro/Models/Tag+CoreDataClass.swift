import Foundation
import CoreData
import SwiftUI

@objc(Tag)
public class Tag: NSManagedObject, Identifiable {
    var deckArray: [Deck] {
        let set = decks as? Set<Deck> ?? []
        return set.sorted { $0.name < $1.name }
    }
    
    var tagColor: Color {
        guard let colorName = color else { return .blue }
        switch colorName.lowercased() {
        case "red": return .red
        case "green": return .green
        case "blue": return .blue
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "yellow": return .yellow
        default: return .blue
        }
    }
}