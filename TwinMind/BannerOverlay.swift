import SwiftUI

struct BannerOverlay: View {
    @EnvironmentObject private var banner: BannerManager
    var body: some View {
        ZStack(alignment: .bottom) {
            if let data = banner.current {
                Banner(message: data.message, type: map(data.type), isPresented: .constant(true))
                    .accessibilityLabel(Text(data.message))
            }
        }
        .animation(.spring(), value: banner.current?.id)
    }
    private func map(_ t: BannerManager.BannerType) -> Banner.BannerType {
        switch t {
        case .info: return .info
        case .success: return .success
        case .warning: return .warning
        case .error: return .error
        }
    }
} 