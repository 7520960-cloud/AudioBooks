
import Foundation
import CoreData

struct PersistenceController {
    static let shared = PersistenceController()
    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        let model = NSManagedObjectModel()
        let progressEntity = NSEntityDescription()
        progressEntity.name = "Progress"
        progressEntity.managedObjectClassName = "NSManagedObject"

        let bookId = NSAttributeDescription()
        bookId.name = "bookId"
        bookId.attributeType = .stringAttributeType
        bookId.isOptional = false

        let chapterId = NSAttributeDescription()
        chapterId.name = "chapterId"
        chapterId.attributeType = .stringAttributeType
        chapterId.isOptional = false

        let pos = NSAttributeDescription()
        pos.name = "positionSec"
        pos.attributeType = .doubleAttributeType
        pos.isOptional = false

        let updated = NSAttributeDescription()
        updated.name = "updatedAt"
        updated.attributeType = .dateAttributeType
        updated.isOptional = false

        progressEntity.properties = [bookId, chapterId, pos, updated]
        model.entities = [progressEntity]

        container = NSPersistentContainer(name: "AudiobooksModel", managedObjectModel: model)
        if inMemory {
            let desc = NSPersistentStoreDescription()
            desc.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [desc]
        }
        container.loadPersistentStores { _, error in
            if let error = error { fatalError("CoreData error: \(error)") }
        }
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}
