import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Sample data for previews
        let deck = Deck(context: viewContext)
        deck.name = "Sample Deck"
        deck.createdAt = Date()
        deck.id = UUID()
        
        let card = Card(context: viewContext)
        card.front = "Sample Front"
        card.jsonContent = "{\"meaning\": \"Sample meaning\", \"detail\": \"Sample detail\"}"
        card.cardType = .vocabulary
        card.createdAt = Date()
        card.id = UUID()
        card.deck = deck
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "CardMaestroDataModel")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}