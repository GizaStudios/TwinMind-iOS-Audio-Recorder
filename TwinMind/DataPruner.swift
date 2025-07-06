import Foundation
import SwiftData

struct DataPruner {
    static func pruneIfNeeded(context: ModelContext, retentionDays: Int = 90) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? .distantPast
        var sessionDesc = FetchDescriptor<RecordingSession>()
        sessionDesc.predicate = #Predicate<RecordingSession> { $0.createdAt < cutoff }
        if let oldSessions = try? context.fetch(sessionDesc) {
            for session in oldSessions { context.delete(session) }
            try? context.save()
            if !oldSessions.isEmpty { print("[Pruner] Deleted \(oldSessions.count) sessions older than \(retentionDays) days") }
        }
    }
} 