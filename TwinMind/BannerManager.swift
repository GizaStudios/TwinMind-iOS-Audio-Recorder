import Foundation
import Combine
import SwiftUI

@MainActor
final class BannerManager: ObservableObject {
    enum BannerType { case info, success, warning, error }
    struct BannerData: Identifiable { let id = UUID(); let message: String; let type: BannerType }

    @Published var current: BannerData?
    @Published var isOnline: Bool = true

    static let shared = BannerManager()
    private init() {}

    func show(message: String, type: BannerType, duration: TimeInterval = 2.5) {
        current = BannerData(message: message, type: type)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1e9))
            if self.current?.message == message { self.current = nil }
        }
    }
} 