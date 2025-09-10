
import Foundation
import CoreData

final class ProgressStore {
    static let shared = ProgressStore()
    private let ctx = PersistenceController.shared.container.viewContext

    func saveProgress(bookId: String, chapterId: String, position: Double) {
        let req = NSFetchRequest<NSManagedObject>(entityName: "Progress")
        req.predicate = NSPredicate(format: "bookId == %@ AND chapterId == %@", bookId, chapterId)
        req.fetchLimit = 1
        do {
            if let existing = try ctx.fetch(req).first {
                existing.setValue(position, forKey: "positionSec")
                existing.setValue(Date(), forKey: "updatedAt")
            } else {
                let entity = NSEntityDescription.entity(forEntityName: "Progress", in: ctx)!
                let obj = NSManagedObject(entity: entity, insertInto: ctx)
                obj.setValue(bookId, forKey: "bookId")
                obj.setValue(chapterId, forKey: "chapterId")
                obj.setValue(position, forKey: "positionSec")
                obj.setValue(Date(), forKey: "updatedAt")
            }
            try ctx.save()
        } catch { print("Progress save error:", error) }
    }

    func loadProgress(bookId: String, chapterId: String) -> Double? {
        let req = NSFetchRequest<NSManagedObject>(entityName: "Progress")
        req.predicate = NSPredicate(format: "bookId == %@ AND chapterId == %@", bookId, chapterId)
        req.fetchLimit = 1
        if let res = try? ctx.fetch(req).first, let pos = res.value(forKey: "positionSec") as? Double { return pos }
        return nil
    }

    func clearProgress(bookId: String, chapterId: String) {
        let req = NSFetchRequest<NSManagedObject>(entityName: "Progress")
        req.predicate = NSPredicate(format: "bookId == %@ AND chapterId == %@", bookId, chapterId)
        if let list = try? ctx.fetch(req) { for o in list { ctx.delete(o) } ; try? ctx.save() }
    }
}
