import Foundation
import CoreData

class SpacedRepetitionService: ObservableObject {
    private let viewContext: NSManagedObjectContext
    
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
    }
    
    func getStudyCards(from deck: Deck, maxNew: Int = 20, maxReview: Int = 100) -> [Card] {
        var studyCards: [Card] = []
        
        let dueCards = deck.dueCards.filter { !$0.isNew }
        let newCards = deck.newCards
        
        studyCards.append(contentsOf: Array(dueCards.prefix(maxReview)))
        studyCards.append(contentsOf: Array(newCards.prefix(maxNew)))
        
        return studyCards.shuffled()
    }
    
    func reviewCard(_ card: Card, ease: ReviewEase, timeSpent: TimeInterval) {
        let history = ReviewHistory(context: viewContext)
        history.id = UUID()
        history.reviewDate = Date()
        history.ease = ease.rawValue
        history.timeSpent = Int32(timeSpent)
        history.card = card
        
        card.scheduleReview(ease: ease)
        card.addToReviewHistory(history)
        
        saveContext()
        
        // Force refresh of the card and its deck to ensure UI updates
        viewContext.refresh(card, mergeChanges: true)
        viewContext.refresh(card.deck, mergeChanges: true)
    }
    
    func getDueCardsCount(for deck: Deck) -> Int {
        return deck.dueCount
    }
    
    func getNewCardsCount(for deck: Deck) -> Int {
        return deck.newCount
    }
    
    func getAllDueCards() -> [Card] {
        let request: NSFetchRequest<Card> = Card.fetchRequest()
        request.predicate = NSPredicate(format: "dueDate <= %@ OR dueDate == nil", Date() as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Card.dueDate, ascending: true)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching due cards: \(error)")
            return []
        }
    }
    
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
}

extension SpacedRepetitionService {
    static let preview: SpacedRepetitionService = {
        let service = SpacedRepetitionService(viewContext: PersistenceController.preview.container.viewContext)
        return service
    }()
}