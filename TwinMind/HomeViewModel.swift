import Foundation
import Combine
import SwiftData

@MainActor
final class HomeViewModel: ObservableObject {
    enum Filter {
        case all
        case unfinished // sessions with incomplete segments
    }

    // Inputs
    @Published var searchText = ""
    @Published var filter: Filter = .all
    
    // Output
    @Published private(set) var sessions: [RecordingSession] = []
    
    private let pageSize = 50
    private var offset = 0
    private var canLoadMore = true
    private var cancellables: Set<AnyCancellable> = []
    private var context: ModelContext?
    
    init() {
        // react to search/filters
        $searchText
            .combineLatest($filter)
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in self?.resetAndLoad() }
            }
            .store(in: &cancellables)
        // wait for context set before loading
    }
    
    func setContext(_ ctx: ModelContext) {
        guard context == nil else { return }
        context = ctx
        resetAndLoad()

        NotificationCenter.default.addObserver(forName: .tmSessionCreated, object: nil, queue: .main) { [weak self] _ in
            self?.resetAndLoad()
        }
    }
    
    func loadNextPageIfNeeded(current item: RecordingSession?) {
        guard let item else { return }
        let threshold = max(sessions.count - 5, 0)
        if let idx = sessions.firstIndex(where: { $0.id == item.id }), idx >= threshold {
            loadPage()
        }
    }
    
    private func resetAndLoad() {
        sessions.removeAll()
        offset = 0
        canLoadMore = true
        loadPage()
    }
    
    private func loadPage() {
        guard let context = context else { return }
        guard canLoadMore else { return }
        do {
            var desc = FetchDescriptor<RecordingSession>()
            
            // When searching, fetch all results without pagination for proper search functionality
            if !searchText.isEmpty {
                desc.predicate = #Predicate<RecordingSession> { session in
                    session.title.contains(searchText) ||
                    session.segments.contains { seg in
                        seg.transcription?.text.contains(searchText) == true
                    }
                }
                // No pagination for search - get all results
                desc.fetchLimit = 0 // 0 means no limit
                desc.fetchOffset = 0
            } else {
                // Normal pagination when not searching
                desc.fetchLimit = pageSize
                desc.fetchOffset = offset
            }
            
            desc.sortBy = [SortDescriptor(\RecordingSession.createdAt, order: .reverse)]
            
            let page = try context.fetch(desc)
            
            // Apply case-insensitive filter if needed (only for search results)
            var filtered: [RecordingSession]
            if !searchText.isEmpty {
                let q = searchText.lowercased()
                filtered = page.filter { session in
                    session.title.lowercased().contains(q) ||
                    session.segments.contains { seg in
                        seg.transcription?.text.lowercased().contains(q) == true
                    }
                }
            } else {
                filtered = page
            }
            
            // Apply unfinished filter
            switch filter {
            case .all: break // no additional filtering needed
            case .unfinished:
                filtered = filtered.filter { $0.segments.contains { $0.status != .completed } }
            }
            
            sessions.append(contentsOf: filtered)
            
            // Update pagination state
            if !searchText.isEmpty {
                // When searching, we've loaded all results
                canLoadMore = false
            } else {
                canLoadMore = page.count == pageSize
                offset += page.count
            }
        } catch {
            print("[HomeVM] fetch error: \(error)")
        }
    }

    // Exposed to UI .refreshable
    func refresh() {
        resetAndLoad()
    }

    /// Removes the given session from the in-memory `sessions` collection so the UI updates immediately.
    func remove(session: RecordingSession) {
        if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions.remove(at: idx)
        }
    }
} 