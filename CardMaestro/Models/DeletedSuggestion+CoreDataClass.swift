import Foundation
import CoreData

@objc(DeletedSuggestion)
public class DeletedSuggestion: NSManagedObject, Identifiable {
    
    /// Check if this deletion record matches a suggestion
    func matches(front: String, cardType: String) -> Bool {
        return self.front == front && self.cardType == cardType
    }
}