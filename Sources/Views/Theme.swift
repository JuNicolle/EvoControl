import SwiftUI

/// Warm, stove-themed palette and small shared view helpers.
enum Theme {
    static let ember = Color(red: 1.0, green: 0.42, blue: 0.13)
    static let emberLight = Color(red: 1.0, green: 0.65, blue: 0.30)
    static let ash = Color(red: 0.11, green: 0.11, blue: 0.13)
    static let ashLight = Color(red: 0.17, green: 0.17, blue: 0.19)

    static var background: LinearGradient {
        LinearGradient(
            colors: [ash, ashLight],
            startPoint: .top, endPoint: .bottom
        )
    }

    static func flameGradient(active: Bool) -> RadialGradient {
        RadialGradient(
            colors: active
                ? [emberLight, ember, ember.opacity(0.0)]
                : [Color.white.opacity(0.18), Color.white.opacity(0.05), .clear],
            center: .center, startRadius: 4, endRadius: 150
        )
    }
}

/// A soft, dark "card" container used throughout the dashboard.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial.opacity(0.5), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(.white.opacity(0.06))
            )
    }
}

struct CardTitle: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}
